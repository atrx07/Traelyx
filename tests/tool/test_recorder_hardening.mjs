import assert from 'node:assert/strict';
import test from 'node:test';
import { parseResult, run, validateOptions } from '../../tool/recorder_hardening.mjs';

const options = { adb: 'adb', serial: 'emulator-5554', kind: 'pixel', phase: 'matrix' };
const result = { contractVersion: 1, api: 37, phase: 'matrix', rows: [
  { case: 'background', status: 'passed', verifiedChunks: 5, observedMillis: 8000 },
], passed: true };
const output = value => `INSTRUMENTATION_RESULT: stream=\r\nM8_HARDENING_RESULT=${JSON.stringify(value)}\r\nINSTRUMENTATION_CODE: -1\r\n`;

test('requires explicit valid device, known kind and bounded phase', () => {
  assert.equal(validateOptions(options), options);
  for (const change of [{ serial: '' }, { serial: 'x;rm' }, { kind: 'other' }, { phase: 'guardian-hosted-receipt' }]) {
    assert.throws(() => validateOptions({ ...options, ...change }));
  }
});

test('parses actual Windows instrumentation framing and rejects duplicated/missing reports', () => {
  assert.deepEqual(parseResult(output(result)), result);
  assert.throws(() => parseResult(output(result) + output(result)));
  assert.throws(() => parseResult('INSTRUMENTATION_CODE: -1'));
});

test('fails closed on extra/private output, malformed counts and result schema', () => {
  for (const change of [{ route: [1, 2] }, { contractVersion: 2 }, { passed: 'true' }, { failedStage: '/private/path' },
    { rows: [{ case: 'background', status: 'passed', rawVector: [0, 0, 9] }] },
    { rows: [{ case: 'background', status: 'passed', verifiedChunks: -1 }] }]) {
    assert.throws(() => parseResult(output({ ...result, ...change })));
  }
});

test('wrong AVD is refused before instrumentation, injection or storage inspection', async () => {
  const seen = [];
  const fake = async (_exe, args) => {
    seen.push(args);
    if (args.includes('get-state')) return { stdout: 'device\n' };
    if (args.includes('getprop')) return { stdout: '1\n' };
    return { stdout: 'Another_AVD\nOK\n' };
  };
  await assert.rejects(run(options, fake), /wrong_avd/);
  assert.equal(seen.some(args => args.includes('instrument') || args.includes('fix') || args.includes('run-as')), false);
});

test('existing main trip is refused before running the QA recorder', async () => {
  const seen = [];
  const fake = async (_exe, args) => {
    seen.push(args);
    if (args.includes('get-state')) return { stdout: 'device\n' };
    if (args.includes('getprop')) return { stdout: '1\n' };
    if (args.includes('avd')) return { stdout: 'Pixel_10\nOK\n' };
    return { stdout: 'active_trip_v1.bin\ntrips\n' };
  };
  await assert.rejects(run(options, fake), /main_recorder_not_idle/);
  assert.equal(seen.some(args => args.includes('instrument')), false);
});

test('checks main preservation after execution and restores screen on failure', async () => {
  let snapshots = 0;
  const seen = [];
  const fake = async (_exe, args) => {
    seen.push(args);
    if (args.includes('get-state')) return { stdout: 'device\n' };
    if (args.includes('sys.boot_completed')) return { stdout: '1\n' };
    if (args.includes('ro.product.model')) return { stdout: 'TECNO LH8n\n' };
    if (args.includes('ls')) return { stdout: 'trips\n' };
    if (args.includes('find')) return { stdout: `hash-${snapshots++} path\n` };
    if (args.includes('dumpsys')) return { stdout: 'mWakefulness=Awake\n' };
    if (args.includes('instrument')) return { stdout: output({ ...result, phase: 'cleanup' }) };
    return { stdout: '' };
  };
  await assert.rejects(run({ ...options, kind: 'tecno', phase: 'cleanup' }, fake), /main_preservation_changed/);
  assert.deepEqual(seen.at(-1).slice(-3), ['input', 'keyevent', '224']);
  assert.equal(seen.some(args => args.includes('clear') || args.includes('install') || args.includes('uninstall')), false);
  assert.ok(seen.find(args => args.includes('instrument')).at(-1).startsWith('io.github.atrx07.traelyx.hardening.test/'));
  assert.ok(seen.find(args => args.includes('force-stop')).at(-1).endsWith('.hardening'));
});

test('a timed-out Pixel test stops only QA and restores every captured platform setting', async () => {
  const seen = [];
  const fake = async (_exe, args) => {
    seen.push(args);
    if (args.includes('get-state')) return { stdout: 'device\n' };
    if (args.includes('getprop')) return { stdout: '1\n' };
    if (args.includes('avd')) return { stdout: 'Pixel_10\nOK\n' };
    if (args.includes('ls')) return { stdout: 'trips\n' };
    if (args.includes('find')) return { stdout: 'fixedhash path\n' };
    if (args.includes('dumpsys')) return { stdout: 'mWakefulness=Awake\n' };
    if (args.includes('settings')) return { stdout: '0\n' };
    if (args.includes('is-location-enabled')) return { stdout: 'true\n' };
    if (args.includes('instrument')) throw new Error('timeout');
    return { stdout: 'OK\n' };
  };
  await assert.rejects(run(options, fake), /timeout/);
  const stopIndex = seen.findIndex(args => args.includes('force-stop'));
  assert.ok(stopIndex >= 0);
  assert.equal(seen[stopIndex].at(-1), 'io.github.atrx07.traelyx.hardening');
  for (const operation of ['set-location-enabled', 'airplane-mode', 'wifi', 'data', 'set-mode']) {
    assert.ok(seen.slice(stopIndex + 1).some(args => args.includes(operation)));
  }
  assert.deepEqual(seen.at(-1).slice(-3), ['input', 'keyevent', '224']);
});
