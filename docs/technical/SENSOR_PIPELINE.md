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

### M3.4 implemented orientation/frame baseline

Orientation/frame transform version 1 follows ADR-0013. Android device axes remain +X right, +Y device-top, +Z screen-out. The navigation frame is right-handed ENU (+X east, +Y north, +Z up), and the vehicle frame is right-handed forward-left-up (+X forward, +Y left, +Z up). Orthonormal positive-determinant matrices map source coordinates into target coordinates without changing vector magnitude.

M3.3 gravity evidence resolves device tilt into a leveled right/forward/up frame, using projected device-top as a deterministic horizontal reference and device-right only when device-top is vertical. This local horizontal reference is not north: geographic yaw remains explicit as unobservable. A later non-overlapping stationary calibration invalidates the tilt assumption when its gravity direction differs by more than the default 10-degree threshold; insufficient, degraded, or unevaluated comparison evidence remains visible, and yaw-only phone rotation cannot be claimed detected.

Device-to-vehicle transformation requires an explicit device-frame forward mount hint and never silently assumes phone-top-forward. Vehicle-to-ENU additionally requires an M3.2-usable GNSS course with default speed at least 3 m/s, bearing accuracy at most 30 degrees, and source age at most 2 seconds. Rejected/implausible/stale/future course is unavailable; mock evidence degrades rather than solely rejects. World output is unavailable when either prerequisite is unavailable, and provenance includes calibration/course times and quality evidence. Version 1 does not remove gravity, filter vectors, or derive M3.5 motion channels.

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

### M3.5 implemented derived-channel baseline

Derived telemetry version 1 is a repeatable lazy native pipeline over M3.1–M3.4 evidence. It fails closed if the M3.2 summary does not exactly match the raw trip, and processes long timelines with bounded filter/derivative windows rather than eagerly materializing the trip. Available channels retain structured provenance and resolved/degraded state; missing sources, filter warmup, context gaps, device-moved mount invalidation, rejected GNSS, and stale evidence remain typed unavailable results. Raw evidence and prior-stage results are never rewritten or bridged to Flutter.

The default IMU path removes the selected stationary accelerometer mean, subtracts zero-rate gyro bias, transforms through the active vehicle forward-left-up mount, applies a causal three-sample median prefilter, and then applies one-pole smoothing (200 ms acceleration, 150 ms yaw rate). Jerk is a robust seven-frame median-slope derivative rather than a single noisy difference. Any missing/discontinuous IMU frame, context boundary, or gap over 50 ms resets affected state. The stationary reference naturally captures the observable bias measured for that calibration window; there is no built-in Tecno or phone-model correction, and dynamic tilt/grade precision remains a physical-validation limitation.

Filtered speed uses plausible platform speed or an explicitly degraded M3.2 accuracy-resolved displacement fallback, with a three-source median and 1 s smoothing. GNSS-derived heading rate wraps north-crossing deltas and retains the M3.4 course gates, then uses a three-rate median and 500 ms smoothing. Both become unavailable when their source is more than 2 seconds old; invalid/gapped sources reset state. Moving/stopped classification uses a 1.5/0.5 m/s hysteresis band plus distinct-source and elapsed-time confirmation (moving: two samples and 1 second; stopped: three samples and 2 seconds), so one fix cannot toggle motion state.

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

### M3.6 implemented confidence baseline

Telemetry confidence version 1 emits one repeatable lazy confidence frame for every M3.5 derived frame. It does not manufacture a global percentage. Each frame instead exposes categorical `supported`, `degraded`, `unavailable`, or `invalidated` assessments for GNSS, accelerometer, gyroscope, calibration, orientation, source agreement, device movement, and clock integrity, together with the exact typed reasons and upstream decisions, flags, accuracies, alignments, timestamps, and mount/calibration evidence needed to explain the result.

The GNSS component retains the latest M3.2 fix within the M3.5 two-second source-age limit. Hard low-accuracy, clock-discontinuity, and impossible-jump decisions invalidate GNSS evidence; stale or absent evidence is unavailable. A first anchor, post-gap reset, unresolved/stationary displacement, mock signal, implausible source speed, or accepted horizontal accuracy above the versioned 15 m preferred-quality threshold is degraded rather than presented as precise. The 15 m value is a conservative quality tier inside M3.2's separate acceptance boundary, not an accuracy claim.

Accelerometer and gyroscope confidence remain separate so a GNSS or one-sensor fault cannot erase healthy independent evidence. Exact clean frames are supported; interpolation, unreliable status, and raw non-fatal quality flags degrade the affected source; dropout, source discontinuity, oversized interpolation gaps, and source clock discontinuity invalidate it. Calibration, vehicle orientation, and device-movement assessments preserve M3.3/M3.4 state. An unevaluated or indeterminate movement check is degraded; an invalidated orientation is unusable for dependent vehicle-frame channels. The Tecno rehearsal remains ordinary `SENSOR_UNRELIABLE` evidence—there is no device-specific confidence exception.

Yaw/heading source agreement is assessed only while movement is confirmed, both filtered channels are available, and both source times are within one second of the confidence target. Version 1 treats an absolute rate difference up to 0.5 rad/s as consistent; degraded inputs keep agreement degraded, and a larger difference marks the corroborated-motion aggregate invalidated without deciding which source is correct or declaring an integrity/safety event. Clock integrity separately identifies stable, partially discontinuous, fully discontinuous, and unassessed source sets.

Downstream eligibility is categorical and metric-scoped: `eligible`, `limited`, or `excluded` for filtered speed, acceleration, jerk, yaw rate, heading-change rate, movement state, and corroborated vehicle motion. Missing or invalidated required evidence excludes only dependent metrics; degraded evidence limits their later score/event weight; healthy independent channels remain eligible. Corroborated vehicle motion additionally requires confirmed movement, all supporting channels, source agreement, device stability, and clock integrity. This confidence layer remains native, bounded-memory, local-only, and outside the Flutter bridge.

### M3.7 implemented replay-reduction baseline

Replay telemetry version 1 reduces synchronized M3.5/M3.6 frames onto an independently versioned 100 ms default display cadence. It emits the exact first source time, complete trailing cadence windows, and an exact partial terminal time when necessary. Cadence must be an integer multiple of the analysis interval, so the reducer never invents alignment or extrapolates beyond source coverage.

Each display frame retains the final source value and provenance plus source-window bounds/count. Scalar and per-axis vector extrema retain their exact source samples; available/missing counts, typed missing reasons, movement transitions, observed quality, confidence, and eligibility states remain explicit. Conservative summaries expose the most restrictive eligibility and most severe confidence seen in the window, so a brief invalid or missing interval cannot be hidden by a later healthy representative.

The reducer is repeatable and bounded-memory, holding only one active window with constant-size channel accumulators. It is display-only: it does not smooth through gaps, persist a second authority, cross the Flutter bridge, alter precise routes, or feed scoring/events/ML. Product replay clock and rendering are deferred to M5.

### M3.8 governed regression corpus

Telemetry regression corpus version 1 is generated entirely from deterministic synthetic evidence
at a non-real coordinate origin. It covers stationary, smooth-straight, acceleration, braking,
left/right corner, pothole, phone-move, GNSS-loss/recovery, and motorcycle-vibration scenarios. The
shared native harness passes every case through chunk encoding/decoding, 10 ms alignment, GNSS
sanity processing, stationary calibration, orientation and mount handling, M3.5 derived channels,
M3.6 confidence/eligibility, and M3.7 replay reduction.

Assertions use physically meaningful time windows and tolerances plus typed missingness,
confidence, eligibility, movement, device-invalidation, and gap-recovery evidence. Repeated fixture
generation must be byte-identical, and repeated timeline iteration must be value-identical. No
`.tripdebug` archive, real route, Tecno-specific constant, production dependency, or scoring/event
behavior is introduced. The motorcycle case establishes a deterministic vibration regression
boundary; it does not replace mounted physical tuning across vehicles and devices.

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
