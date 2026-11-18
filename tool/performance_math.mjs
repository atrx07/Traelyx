export function distribution(values) {
  if (!values.length || values.some(value => !Number.isFinite(value) || value < 0)) throw new Error('invalid_measurements');
  const sorted = [...values].sort((a, b) => a - b);
  const rank = fraction => sorted[Math.max(1, Math.ceil(fraction * sorted.length)) - 1];
  return { count: sorted.length, p50: rank(.5), p95: rank(.95), p99: rank(.99), max: sorted.at(-1) };
}

export function summarizeDevicePhase(phase) {
  const duration = phase.duration_ms;
  const start = phase.battery_start;
  const end = phase.battery_end;
  if (!Number.isFinite(duration) || duration <= 0 || !Number.isFinite(phase.cpu_ms) || phase.cpu_ms < 0 ||
      phase.screen_off_verified !== true || phase.screen_on_samples > 0 ||
      !phase.samples?.length || start.plugged !== 0 || end.plugged !== 0 ||
      start.status !== 3 || end.status !== 3 || start.scale <= 0 || start.scale !== end.scale ||
      ![start.level, end.level].every(value => Number.isInteger(value) && value >= 0 && value <= start.scale)) {
    throw new Error('invalid_unplugged_phase');
  }
  if (phase.samples.some(sample => sample.plugged !== 0 || sample.battery_status !== 3)) {
    throw new Error('invalid_unplugged_samples');
  }
  if (phase.uptime_ms !== undefined &&
      (!Number.isFinite(phase.uptime_ms) || phase.uptime_ms < 0 || phase.uptime_ms > duration)) {
    throw new Error('invalid_uptime');
  }
  if (phase.persisted_bytes_added !== undefined &&
      (!Number.isSafeInteger(phase.persisted_bytes_added) || phase.persisted_bytes_added <= 0 ||
       !Number.isSafeInteger(phase.accelerometer_samples_added) || phase.accelerometer_samples_added <= 0 ||
       !Number.isSafeInteger(phase.gyroscope_samples_added) || phase.gyroscope_samples_added <= 0 ||
       !Number.isSafeInteger(phase.gnss_samples_added) || phase.gnss_samples_added < 0)) {
    throw new Error('recorder_workload_did_not_advance');
  }
  const elapsedHours = duration / 3600000;
  const levelDrop = (start.level - end.level) * 100 / start.scale;
  const counterSupported = [start.charge_counter_microah, end.charge_counter_microah]
    .every(value => Number.isFinite(value) && value > 0);
  const chargeDrop = counterSupported ? start.charge_counter_microah - end.charge_counter_microah : null;
  const pss = distribution(phase.samples.map(sample => sample.pss_kib));
  const temperatures = phase.samples.map(sample => sample.temperature_tenths_c);
  const validTemperatures = temperatures.every(value => Number.isInteger(value) && value > -1000 && value < 1000);
  return {
    duration_seconds: duration / 1000,
    cpu_percent_one_core: phase.cpu_ms * 100 / duration,
    pss_kib: pss,
    screen_off_verified: phase.screen_off_verified,
    ...(phase.uptime_ms !== undefined ? {
      uptime_seconds: phase.uptime_ms / 1000,
      reported_suspend_seconds: (duration - phase.uptime_ms) / 1000,
    } : {}),
    temperature_c_min: validTemperatures ? Math.min(...temperatures) / 10 : null,
    temperature_c_max: validTemperatures ? Math.max(...temperatures) / 10 : null,
    observed_level_drop_percentage_points: levelDrop,
    observed_level_drop_percentage_points_per_hour: levelDrop / elapsedHours,
    one_level_step_percentage_points_per_hour: (100 / start.scale) / elapsedHours,
    zero_rounded_change_is_not_zero_consumption: levelDrop === 0,
    charge_counter_drop_microah: chargeDrop,
    charge_counter_estimated_ma: chargeDrop !== null && chargeDrop > 0 ? chargeDrop / 1000 / elapsedHours : null,
    charge_counter_resolution_and_calibration_validated: false,
    measurement_scope: 'instrumented native-only profile QA process; includes monitor overhead',
    ...(phase.persisted_bytes_added !== undefined ? {
      raw_mib_per_hour_committed_interval: phase.persisted_bytes_added / 1048576 / elapsedHours,
      gnss_samples_in_interval: phase.gnss_samples_added,
      accelerometer_effective_hz: phase.accelerometer_samples_added / (duration / 1000),
      gyroscope_effective_hz: phase.gyroscope_samples_added / (duration / 1000),
    } : {}),
  };
}
