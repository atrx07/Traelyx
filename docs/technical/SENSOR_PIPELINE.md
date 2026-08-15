# SENSOR_PIPELINE.md — Sensor Processing & Confidence Pipeline

## When to read

Read for filtering, alignment, calibration, gravity removal, orientation, vehicle frame transforms, sensor fusion, confidence, or replay channel generation.

## 1. Principle

Physics establishes measured reality before ML interprets behavior.

Pipeline concept:

```text
raw GNSS + raw IMU
       │
       ▼
validate timestamps / quality
       │
       ▼
time alignment / resampling
       │
       ▼
device calibration / bias handling
       │
       ▼
gravity + orientation estimation
       │
       ▼
vehicle/world frame transformation
       │
       ▼
noise filtering / robust outlier handling
       │
       ▼
derived motion channels
       │
       ▼
confidence propagation
       │
       ├── events/scoring
       ├── ML features
       └── replay display channels
```

### M3.1 implemented decode/alignment boundary

Native Kotlin remains the authority for precise raw chunk bytes. The version-1 trip decoder reuses the checksummed chunk decoder, then fails closed on an empty/corrupt input, unknown chunk contract, mixed trip or version, non-contiguous sequence, overlapping chunk bounds, global record reordering, duplicate record keys, or non-increasing per-channel trip time.

The version-1 analysis timebase is deterministic and monotonic. GNSS remains sparse original evidence for the next sanity-filtering stage. Device-frame accelerometer and gyroscope values use bounded linear interpolation only when two valid neighboring samples support it; missingness and exact/interpolated provenance are first-class output. Raw coordinates, vectors, timestamps, status, and flags are not normalized or transferred to Flutter by this stage.

## 2. Calibration

A calibration procedure may use stationary periods and/or stable-motion segments to estimate bias/orientation.

Requirements:

- calibration state is visible;
- poor calibration reduces confidence;
- phone movement during a trip can invalidate/restart orientation assumptions;
- do not require one perfect fixed mount for all users, but classify unsupported/unreliable states honestly.

### M3.3 implemented stationary/bias baseline

IMU stationary calibration version 1 scans the aligned native timeline with bounded memory and selects the quietest qualifying two-second window. Missing channels and raw dropout/clock-discontinuity evidence break a candidate. Default instantaneous gates require accelerometer magnitude within 0.75 m/s² of standard gravity (9.80665 m/s²) and gyroscope magnitude at most 0.05 rad/s; a window additionally requires every accelerometer axis at or below 0.15 m/s² standard deviation and every gyroscope axis at or below 0.01 rad/s standard deviation. All thresholds and duration are snapshotted in the versioned configuration.

The result is explicitly `calibrated`, `calibrated_degraded`, or `insufficient_evidence`, with counts and reasons for missing, discontinuous, moving, non-gravity-like, unstable, or too-short evidence. Android accuracy status zero or below and `SENSOR_UNRELIABLE` remain visible and produce degraded calibration rather than rewritten raw samples; exact/interpolated provenance also remains explicit.

A single stationary orientation identifies the zero-rate gyroscope bias and only the accelerometer bias component observable parallel to the measured gravity vector. Version 1 therefore reports the raw mean gravity vector, its unit direction, and the observable radial magnitude bias; it does not claim a fully identifiable three-axis accelerometer bias, remove gravity, apply corrections to raw evidence, or perform the M3.4 device-movement/orientation work.

## 3. Motorcycle vibration

Motorcycles may produce significant high-frequency vibration. Filters must be validated on actual motorcycle fixtures rather than tuned only on smooth car data.

Do not over-smooth away meaningful control transitions.

## 4. Gravity removal

Raw accelerometer includes gravity depending on sensor/API. The implementation must document whether it consumes raw acceleration, linear acceleration, rotation vector, etc., and must test stationary orientation cases.

## 5. Heading / vehicle alignment

Vehicle-forward direction may be estimated from GNSS course when moving sufficiently, device orientation/mount calibration, or fused sources.

Do not trust GNSS bearing near standstill.

Orientation confidence should degrade when:

- speed too low for stable course;
- device rotates/moves;
- magnetic interference affects magnetometer if used;
- GNSS quality is poor;
- sensor gaps occur.

## 6. Filters

Initial baseline should favor explainable filters:

- median/outlier rejection for isolated spikes;
- low-pass/high-pass filters where justified;
- complementary/Kalman-style fusion only when the state model is understood and tested;
- robust derivative estimation for jerk rather than naive differencing of noisy signals.

Filter parameters are versioned/configured, not magic numbers scattered across code.

## 7. Distance

Distance accumulation should reject impossible jumps and account for GNSS accuracy. Do not count obvious noise while stationary as travel.

### M3.2 implemented GNSS sanity/distance baseline

GNSS processing version 1 consumes the original ordered sparse fixes from M3.1 and retains every raw sample unchanged beside an explicit decision/evidence record. Its default configuration accepts at most 50 m horizontal accuracy, breaks a distance chain after a gap greater than 5 s, rejects an accuracy-adjusted minimum plausible speed above 100 m/s, and treats source speed at or below 0.75 m/s as stationary evidence. These are versioned configuration values, not claims that GNSS is exact to those thresholds.

Low-accuracy or clock-discontinuity fixes are excluded and reset the anchor. A long gap accepts the current fix as a new anchor without bridging distance. An impossible jump is excluded while retaining the last valid anchor so one isolated spike does not displace the route. Great-circle distance uses the short Earth path, including across the antimeridian.

For a plausible segment beyond the sum of both horizontal-accuracy radii, full geodesic distance is accumulated as resolved distance. A segment within that envelope is accumulated separately as motion-supported distance only when at least one plausible source-speed estimate exceeds the stationary threshold. When both endpoints support stationary state it is explicit stationary jitter; without motion evidence it is explicit unresolved-within-accuracy evidence. Neither contributes distance. Mock-location and implausible source-speed signals remain visible evidence and never become a sole automatic integrity verdict.

## 8. Moving/stopped state

Combine speed persistence and confidence rather than toggling on a single sample threshold. Use hysteresis/debounce.

## 9. Confidence model

Telemetry confidence should be composed from interpretable subcomponents such as:

- GNSS accuracy/continuity;
- IMU sample continuity/rate;
- calibration confidence;
- orientation confidence;
- source agreement;
- device-movement state;
- clock integrity.

Do not treat one global confidence percentage as mathematically precise before calibration. Persist subcomponents so the displayed summary can be explained.

## 10. Confidence propagation

Downstream logic should consume confidence:

- low-confidence corner → weak/no score impact;
- impossible GPS jump with normal IMU → integrity anomaly;
- phone-movement segment → exclude/mark affected frame-derived metrics;
- severe Guardian state requires higher corroboration.

## 11. Dynamic sampling / battery

Sampling rate may adapt to trip state if carefully designed, but never change silently without preserving enough detail for event detection.

Any dynamic strategy requires real-device battery and dropped-sample benchmarks.

## 12. Test cases

At minimum:

- stationary phone in multiple orientations;
- straight constant-speed drive;
- smooth acceleration/braking;
- deliberate hard brake in safe controlled testing environment;
- left/right corners;
- pothole/road bump;
- phone moved mid-trip;
- GNSS dropout and recovery;
- screen lock/background;
- low-speed bearing instability;
- motorcycle vibration.

Safety note: never design a test plan that asks a developer to perform dangerous maneuvers on public roads. Use controlled environments, existing natural events, simulation, or datasets.
