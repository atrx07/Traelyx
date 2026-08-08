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

## 2. Calibration

A calibration procedure may use stationary periods and/or stable-motion segments to estimate bias/orientation.

Requirements:

- calibration state is visible;
- poor calibration reduces confidence;
- phone movement during a trip can invalidate/restart orientation assumptions;
- do not require one perfect fixed mount for all users, but classify unsupported/unreliable states honestly.

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
