import assert from 'node:assert/strict';
import test from 'node:test';
import { distribution, summarizeDevicePhase } from '../../tool/performance_math.mjs';

const phase = { duration_ms: 600000, cpu_ms: 6000, screen_off_verified: true,
  battery_start: { plugged: 0, status: 3, level: 80, scale: 100, charge_counter_microah: 4000000 },
  battery_end: { plugged: 0, status: 3, level: 79, scale: 100, charge_counter_microah: 3950000 },
  samples: [{ pss_kib: 10000, temperature_tenths_c: 320, plugged: 0, battery_status: 3 },
    { pss_kib: 12000, temperature_tenths_c: 330, plugged: 0, battery_status: 3 }],
  persisted_bytes_added: 1048576, gnss_samples_added: 600, accelerometer_samples_added: 60000, gyroscope_samples_added: 60000 };

test('nearest-rank distributions retain tails and reject invalid observations', () => {
  assert.deepEqual(distribution([3, 1, 2, 40]), { count: 4, p50: 2, p95: 40, p99: 40, max: 40 });
  for (const values of [[], [NaN], [-1]]) assert.throws(() => distribution(values));
});

test('rates use elapsed hours, CPU one-core normalization and binary MiB', () => {
  const result = summarizeDevicePhase(phase);
  assert.equal(result.cpu_percent_one_core, 1);
  assert.equal(result.observed_level_drop_percentage_points_per_hour, 6);
  assert.equal(result.one_level_step_percentage_points_per_hour, 6);
  assert.equal(result.charge_counter_estimated_ma, 300);
  assert.equal(result.raw_mib_per_hour_committed_interval, 6);
  assert.equal(result.accelerometer_effective_hz, 100);
  assert.equal(result.temperature_c_max, 33);
});

test('zero rounded battery delta remains explicitly unresolved, unavailable counters stay null', () => {
  const result = summarizeDevicePhase({ ...phase, battery_end: { ...phase.battery_start, charge_counter_microah: null } });
  assert.equal(result.zero_rounded_change_is_not_zero_consumption, true);
  assert.equal(result.charge_counter_estimated_ma, null);
  assert.equal(result.charge_counter_resolution_and_calibration_validated, false);
});

test('charging, mismatched scales and invalid durations never become drain estimates', () => {
  for (const changed of [{ duration_ms: 0 }, { cpu_ms: -1 },
    { battery_start: { ...phase.battery_start, plugged: 2 } },
    { battery_end: { ...phase.battery_end, scale: 200 } }]) {
    assert.throws(() => summarizeDevicePhase({ ...phase, ...changed }));
  }
});

test('stalled motion or invalid committed evidence cannot look like an efficient recorder', () => {
  for (const changed of [{ accelerometer_samples_added: 0 }, { gyroscope_samples_added: 0 },
    { persisted_bytes_added: -1 }, { gnss_samples_added: -1 }]) {
    assert.throws(() => summarizeDevicePhase({ ...phase, ...changed }), /recorder_workload_did_not_advance/);
  }
  assert.equal(summarizeDevicePhase({ ...phase, gnss_samples_added: 0 }).gnss_samples_in_interval, 0);
});

test('screen-on or charging observations are rejected; suspend time stays visible', () => {
  for (const changed of [{ screen_off_verified: false }, { screen_on_samples: 1 },
    { samples: [{ ...phase.samples[0], plugged: 2 }] },
    { samples: [{ ...phase.samples[0], battery_status: 2 }] }]) {
    assert.throws(() => summarizeDevicePhase({ ...phase, ...changed }));
  }
  const measured = summarizeDevicePhase({ ...phase, uptime_ms: 580000 });
  assert.equal(measured.reported_suspend_seconds, 20);
  assert.equal(measured.uptime_seconds, 580);
  for (const uptime_ms of [-1, 600001, NaN]) {
    assert.throws(() => summarizeDevicePhase({ ...phase, uptime_ms }), /invalid_uptime/);
  }
});
