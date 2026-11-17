import { execFile as execFileCallback } from 'node:child_process';
import { createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { pathToFileURL } from 'node:url';
import { writeFile } from 'node:fs/promises';

const execFile = promisify(execFileCallback);
export const qaPackage = 'io.github.atrx07.traelyx.hardening';
const mainPackage = 'io.github.atrx07.traelyx';
const runner = `${qaPackage}.test/io.github.atrx07.traelyx.recorder.RecorderHardeningInstrumentation`;
const phases = new Set(['matrix', 'prepare', 'resume', 'cleanup']);

export function validateOptions(options) {
  if (!options.adb || !/^[A-Za-z0-9_.:-]+$/.test(options.serial ?? '')) throw new Error('invalid_device_selection');
  if (!['pixel', 'tecno'].includes(options.kind) || !phases.has(options.phase)) throw new Error('invalid_scope');
  return options;
}

export function parseResult(output) {
  const matches = [...output.matchAll(/^M8_HARDENING_RESULT=(\{[^\r\n]+\})\r?$/gm)];
  if (matches.length !== 1) throw new Error('missing_or_duplicate_result');
  const result = JSON.parse(matches[0][1]);
  const keys = new Set(['contractVersion', 'api', 'phase', 'rows', 'passed', 'failedStage', 'failureCode', 'gnssHealth']);
  if (Object.keys(result).some(key => !keys.has(key)) || result.contractVersion !== 1 ||
      !Number.isInteger(result.api) || !phases.has(result.phase) || typeof result.passed !== 'boolean' ||
      !Array.isArray(result.rows)) throw new Error('invalid_result_contract');
  if (result.failedStage !== undefined && !/^[a-z_]+$/.test(result.failedStage)) throw new Error('invalid_failure_code');
  if (result.failureCode !== undefined && !/^[a-z_]+$/.test(result.failureCode)) throw new Error('invalid_failure_code');
  if (result.gnssHealth !== undefined) {
    const health = result.gnssHealth;
    if (Object.keys(health).some(key => !['state', 'accepted', 'rejected', 'registrationFailures'].includes(key)) ||
        !/^[a-z_]+$/.test(health.state) || ['accepted', 'rejected', 'registrationFailures'].some(
          key => !Number.isSafeInteger(health[key]) || health[key] < 0)) throw new Error('invalid_health_contract');
  }
  for (const row of result.rows) {
    if (Object.keys(row).some(key => !['case', 'status', 'verifiedChunks', 'observedMillis'].includes(key)) ||
        !/^[a-z_]+$/.test(row.case) || !/^[a-z_]+$/.test(row.status)) throw new Error('invalid_result_row');
    for (const key of ['verifiedChunks', 'observedMillis']) {
      if (row[key] !== undefined && (!Number.isSafeInteger(row[key]) || row[key] < 0)) throw new Error('invalid_result_count');
    }
  }
  return result;
}

export async function run(options, command = execFile) {
  validateOptions(options);
  const adb = async (args, timeout = 20_000, encoding = 'utf8') =>
    (await command(options.adb, ['-s', options.serial, ...args], { timeout, maxBuffer: 128 * 1024 * 1024, encoding })).stdout;
  if ((await adb(['get-state'])).trim() !== 'device' ||
      (await adb(['shell', 'getprop', 'sys.boot_completed'])).trim() !== '1') throw new Error('device_not_ready');
  if (options.kind === 'pixel') {
    if (!(await adb(['emu', 'avd', 'name'])).startsWith('Pixel_10\r') &&
        !(await adb(['emu', 'avd', 'name'])).startsWith('Pixel_10\n')) throw new Error('wrong_avd');
  } else if ((await adb(['shell', 'getprop', 'ro.product.model'])).trim() !== 'TECNO LH8n') {
    throw new Error('wrong_physical_model');
  }

  // Reads only main-package directory metadata and hashes. Raw output never leaves this process.
  const preserved = async () => {
    const directories = ['no_backup/recorder', 'no_backup/guardian', 'shared_prefs'];
    const hashes = [];
    for (const directory of directories) {
      let listing;
      try { listing = await adb(['shell', 'run-as', mainPackage, 'ls', directory]); }
      catch (error) {
        if (String(error.stderr).includes('No such file or directory')) { hashes.push('absent'); continue; }
        throw new Error('main_preservation_unreadable');
      }
      if (directory === 'no_backup/recorder' && /active_trip_v1\.bin/.test(listing)) throw new Error('main_recorder_not_idle');
      const data = await adb(['shell', 'run-as', mainPackage, 'find', directory, '-type', 'f',
        '-exec', 'sha256sum', '{}', '+'], 60_000);
      hashes.push(createHash('sha256').update(data.split(/\r?\n/).filter(Boolean).sort().join('\n')).digest('hex'));
    }
    return hashes;
  };
  const before = await preserved();
  const powerState = await adb(['shell', 'dumpsys', 'power']);
  const interactive = /mWakefulness=Awake\b/.test(powerState);
  if (!interactive && !/mWakefulness=(Asleep|Dozing)\b/.test(powerState)) throw new Error('unknown_screen_state');
  const settings = {};
  if (options.kind === 'pixel' && options.phase === 'matrix') {
    for (const key of ['airplane_mode_on', 'wifi_on', 'mobile_data', 'low_power']) {
      settings[key] = (await adb(['shell', 'settings', 'get', 'global', key])).trim();
      if (!['0', '1'].includes(settings[key])) throw new Error('unknown_platform_setting');
    }
    settings.location = (await adb(['shell', 'cmd', 'location', 'is-location-enabled', '--user', '0'])).trim();
    if (!['true', 'false'].includes(settings.location)) throw new Error('unknown_location_setting');
  }
  let timer;
  let injecting = false;
  let injectionFailed = false;
  try {
    if (options.kind === 'pixel' && options.phase === 'matrix') {
      const inject = async () => {
        if (injecting) return;
        injecting = true;
        try {
          if (!(await adb(['emu', 'geo', 'fix', '1', '1'])).includes('OK')) injectionFailed = true;
        } catch { injectionFailed = true; }
        finally { injecting = false; }
      };
      await inject();
      timer = setInterval(inject, 1_000);
    }
    const output = await adb(['shell', 'am', 'instrument', '-w', '-r', '-e', 'phase', options.phase,
      '-e', 'platformFaults', options.kind === 'pixel' ? 'true' : 'false', runner], 150_000);
    const result = parseResult(output);
    if (result.phase !== options.phase || injectionFailed) throw new Error('operator_observation_failed');
    const after = await preserved();
    if (JSON.stringify(before) !== JSON.stringify(after)) throw new Error('main_preservation_changed');
    return { ...result, mainRecorderGuardianPreferencesPreserved: true };
  } catch (error) {
    // A timed-out shell client may leave remote instrumentation running. Stop only QA before restoring settings.
    await adb(['shell', 'am', 'force-stop', qaPackage]);
    throw error;
  } finally {
    clearInterval(timer);
    if (settings.location !== undefined) {
      await adb(['shell', 'cmd', 'location', 'set-location-enabled', settings.location, '--user', '0']);
      await adb(['shell', 'cmd', 'connectivity', 'airplane-mode', settings.airplane_mode_on === '1' ? 'enable' : 'disable']);
      await adb(['shell', 'svc', 'wifi', settings.wifi_on === '1' ? 'enable' : 'disable']);
      await adb(['shell', 'svc', 'data', settings.mobile_data === '1' ? 'enable' : 'disable']);
      await adb(['shell', 'cmd', 'power', 'set-mode', settings.low_power]);
      for (const key of ['airplane_mode_on', 'wifi_on', 'mobile_data', 'low_power']) {
        if ((await adb(['shell', 'settings', 'get', 'global', key])).trim() !== settings[key]) throw new Error('setting_restore_failed');
      }
      if ((await adb(['shell', 'cmd', 'location', 'is-location-enabled', '--user', '0'])).trim() !== settings.location) {
        throw new Error('location_restore_failed');
      }
    }
    await adb(['shell', 'input', 'keyevent', interactive ? '224' : '223']);
  }
}

async function main() {
  const options = {};
  for (let index = 2; index < process.argv.length; index += 2) {
    const key = process.argv[index];
    if (!['--adb', '--serial', '--kind', '--phase', '--output'].includes(key) || !process.argv[index + 1]) {
      throw new Error('invalid_arguments');
    }
    options[key.slice(2)] = process.argv[index + 1];
  }
  const result = await run(options);
  if (options.output) await writeFile(options.output, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => {
    const code = /^[a-z_]+$/.test(error.message) ? error.message : 'command_failed';
    process.stderr.write(`Recorder hardening operator failed: ${code}.\n`);
    process.exitCode = 1;
  });
}
