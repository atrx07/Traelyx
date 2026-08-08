# Stage 3 Playbook — Telemetry Processing

## Goal

Convert raw sensor data into physically meaningful, confidence-aware channels without pretending noise is truth.

## Minimum references

`TELEMETRY_SPEC.md`, `SENSOR_PIPELINE.md`, `PERFORMANCE_BUDGETS.md`, telemetry fixtures.

## Work units

1. Versioned chunk decoder.
2. Build aligned analysis timeline while preserving raw timestamps.
3. GNSS sanity filtering and distance calculation.
4. Stationary/bias calibration state.
5. Orientation/device-movement detection.
6. Device/world/vehicle frame transform.
7. Filter acceleration/angular channels with tunable versioned config.
8. Derive speed/longitudinal/lateral/vertical/jerk/yaw channels.
9. Implement moving/stopped state with hysteresis.
10. Implement confidence subcomponents and aggregation.
11. Generate downsampled replay stream.
12. Expand fixtures across car/motorcycle/device-move/GNSS-loss cases.

## Acceptance

- units and frames validated by synthetic tests;
- stationary phone does not become a moving vehicle;
- left/right and forward/brake signs are correct after calibration;
- low GNSS/orientation quality visibly degrades confidence;
- derived channels are deterministic from the same source/version.
