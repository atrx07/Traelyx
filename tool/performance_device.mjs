import { execFile as callback } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve, relative, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mainPreservationFingerprint } from './android_qa_preservation.mjs';
import { summarizeDevicePhase } from './performance_math.mjs';

const execFile = promisify(callback);
const qa = 'io.github.atrx07.traelyx.hardening';
const runner = `${qa}.test/io.github.atrx07.traelyx.recorder.RecorderPerformanceInstrumentation`;

function localArtifact(path) {
  const suffix = relative(resolve('.dart_tool'), resolve(path ?? ''));
  if (!suffix || suffix.startsWith('..') || isAbsolute(suffix)) throw new Error('artifact_must_stay_in_dart_tool');
  return path;
}

async function main() {
  const options = {};
  for (let index = 2; index < process.argv.length; index += 2) {
    const key = process.argv[index];
    if (!['--adb', '--serial', '--phase', '--checkpoint', '--output'].includes(key) || !process.argv[index + 1]) {
      throw new Error('invalid_arguments');
    }
    options[key.slice(2)] = process.argv[index + 1];
  }
  if (!options.adb || !/^[A-Za-z0-9_.:-]+$/.test(options.serial ?? '') ||
      !['replay', 'recorder', 'collect'].includes(options.phase)) throw new Error('invalid_scope');
  localArtifact(options.checkpoint);
  if (options.output) localArtifact(options.output);
  const adb = async (args, timeout = 20000) => (await execFile(options.adb, ['-s', options.serial, ...args],
    { timeout, maxBuffer: 16 * 1024 * 1024 })).stdout;
  if ((await adb(['get-state'])).trim() !== 'device' ||
      (await adb(['shell', 'getprop', 'ro.product.model'])).trim() !== 'TECNO LH8n' ||
      (await adb(['shell', 'getprop', 'sys.boot_completed'])).trim() !== '1') throw new Error('wrong_or_unready_device');
  let baseline;
  if (options.phase === 'collect') {
    baseline = JSON.parse(await readFile(options.checkpoint, 'utf8'));
  } else {
    baseline = { contract_version: 1, phase: options.phase, fingerprints: await mainPreservationFingerprint(adb) };
    await writeFile(options.checkpoint, JSON.stringify(baseline), { flag: 'wx' });
    process.stdout.write(`Starting isolated profile QA ${options.phase}; main recorder/Guardian/preferences fingerprinted.\n`);
    if (options.phase === 'recorder') {
      await adb(['shell', 'input', 'keyevent', '224']);
      await adb(['shell', 'am', 'start', '-W', '-n',
        `${qa}/io.github.atrx07.traelyx.recorder.PerformanceControlActivity`,
        '-a', 'io.github.atrx07.traelyx.PERFORMANCE_START']);
      const deadline = Date.now() + 45000;
      while (Date.now() < deadline) {
        let state;
        try { state = JSON.parse(await adb(['shell', 'run-as', qa, 'cat', 'no_backup/performance-progress-v1.json'])); }
        catch { state = {}; }
        if (state.stage === 'ready_to_unplug_and_lock') {
          process.stdout.write('Independent QA controller ready. Wait for Codex instructions, then unplug and manually lock. No instrumentation/ADB connection is required for the measurement.\n');
          return;
        }
        if (state.stage === 'failed') throw new Error('controller_failed_before_unplug');
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      throw new Error('controller_not_ready');
    }
    try {
      await adb(['shell', 'am', 'instrument', '-w', '-r', '-e', 'phase', options.phase, runner],
        options.phase === 'recorder' ? 1200000 : 180000);
    } catch (error) {
      throw new Error('instrumentation_transport_failed');
    }
  }
  if (baseline.contract_version !== 1 || !['replay', 'recorder'].includes(baseline.phase) ||
      !Array.isArray(baseline.fingerprints)) throw new Error('invalid_checkpoint');
  const report = JSON.parse(await adb(['shell', 'run-as', qa, 'cat',
    `no_backup/performance-${baseline.phase}-result-v1.json`]));
  if (report.contract_version !== 1 || report.phase !== baseline.phase || typeof report.passed !== 'boolean') {
    throw new Error('invalid_device_report');
  }
  if (JSON.stringify(baseline.fingerprints) !== JSON.stringify(await mainPreservationFingerprint(adb))) {
    throw new Error('main_preservation_changed');
  }
  report.main_recorder_guardian_preferences_preserved = true;
  if (report.passed && baseline.phase === 'recorder') {
    report.summary = { idle: summarizeDevicePhase(report.instrumented_idle), recorder: summarizeDevicePhase(report.recorder) };
  }
  if (!options.output) throw new Error('missing_output');
  await writeFile(options.output, JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  process.stdout.write(JSON.stringify({ phase: report.phase, passed: report.passed,
    failed_stage: report.failed_stage, preserved: true, summary: report.summary }) + '\n');
  if (!report.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => {
    process.stderr.write(`Performance operator failed: ${/^[a-z_]+$/.test(error.message) ? error.message : 'command_failed'}.\n`);
    process.exitCode = 1;
  });
}
