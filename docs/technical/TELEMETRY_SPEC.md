# TELEMETRY_SPEC.md — Canonical Telemetry Contract

## When to read

Read the relevant sections when changing acquisition, storage encoding, sensor units, timestamps, coordinate frames, derived channels, replay data, scoring inputs, or ML features.

Do not read the whole file for unrelated UI/auth work.

## 1. Purpose

This document defines what telemetry fields **mean**. Implementation is free to optimize representation but must preserve semantics and version compatibility.

The most dangerous failures in this project are silent unit/frame/timestamp disagreements. Therefore:

- every physical value has a defined unit;
- every vector has a defined coordinate frame;
- every timestamp has a defined clock/source;
- quality/uncertainty travels with data;
- raw and derived channels are not conflated.

## 2. Schema version

Every persisted trip/raw chunk must declare a telemetry schema version, initially `1` once implementation stabilizes.

Breaking semantic changes require a new version and migration/decoder compatibility strategy.

### M2.4 persisted encoding baseline

Native telemetry chunk encoding version 1 persists telemetry schema version 1 without changing the field semantics below. Every record retains `trip_elapsed_ns` and the original platform `source_timestamp_ns`; GNSS also retains source wall time, provider/mock evidence, all available accuracy fields, optionality, and quality flags, while IMU retains sensor type, Android device-frame axes, accuracy status, and quality flags.

The chunk envelope declares trip UUID, monotonically increasing sequence, elapsed-time bounds, per-channel counts, compression algorithm, stored payload length, SHA-256 over stored payload bytes, and a completion marker. Decode independently bounds decompressed output, must reproduce global record order, and rejects unknown versions, checksum/length/count mismatches, invalid completion, or non-monotonic bounds rather than reinterpret them. The golden fixture under the native unit-test resources pins this compatibility contract.

## 3. Time model

Use a monotonic clock for ordering/alignment of local sensor events where available, plus wall-clock UTC metadata for user-facing time.

Canonical conceptual fields:

- `trip_elapsed_ns` — monotonic elapsed time from trip epoch, nanoseconds or another explicitly declared integer unit.
- `source_timestamp_ns` — original platform sensor/GNSS source timestamp where available.
- `wall_time_utc` — optional UTC instant for events that need human/calendar meaning.

Rules:

- never align IMU and GNSS solely by formatted wall-clock strings;
- preserve original timestamps before resampling;
- record clock discontinuities/restarts;
- do not fabricate samples across long gaps without marking interpolation.

## 4. Raw GNSS/location sample

Conceptual fields:

```text
trip_elapsed_ns
latitude_deg
longitude_deg
horizontal_accuracy_m
altitude_m?                 optional/source-dependent
vertical_accuracy_m?        optional
speed_mps?                  source estimate if available
speed_accuracy_mps?         if available
bearing_deg?                [0,360)
bearing_accuracy_deg?       if available
provider/source
is_mock_flag?               platform signal, not sole cheat verdict
quality_flags
```

Latitude/longitude storage is required locally for route replay. Cloud sync policy is separate.

Do not infer "true" speed from a single noisy location jump if better source/filtered estimates are available.

### M3.2 processed GNSS contract

Processed GNSS version 1 preserves the complete raw sample and adds an auditable per-fix/segment decision, evidence flags, prior anchor time, elapsed time, geodesic displacement, combined horizontal-accuracy envelope, apparent/minimum-plausible speed, distance increment, and cumulative distance split into resolved and source-motion-supported components. Missing segment metrics remain null rather than zero; a zero distance increment means the decision explicitly excluded or reset that segment.

Input time must be strictly increasing. Empty GNSS input is a valid explicit zero-distance result. Low accuracy, clock discontinuity, long gaps, accuracy-adjusted impossible jumps, stationary jitter, and unresolved movement inside the accuracy envelope are distinct outcomes. Precise coordinates and this processed evidence remain local-native in M3.2 and are not added to diagnostics, logs, network payloads, or the Flutter bridge.

## 5. Raw IMU sample

Minimum candidates:

```text
trip_elapsed_ns
sensor_type
x
y
z
accuracy/status
source_timestamp_ns
```

Accelerometer unit: **m/s²** unless explicitly named `*_g`.

Gyroscope unit: **rad/s** unless explicitly named otherwise.

Raw axes use the Android/device coordinate frame exactly as documented by platform APIs; do not relabel them as vehicle longitudinal/lateral axes.

### M3.3 stationary calibration contract

Stationary calibration version 1 consumes the M3.1 aligned device-frame accelerometer and gyroscope values at their monotonic analysis cadence. Its configuration snapshot declares standard gravity, minimum duration, instantaneous gravity/angular-rate gates, and per-axis stability gates. Missing or discontinuous evidence is never converted to zero, and raw vectors, timestamps, status, flags, and interpolation provenance remain unchanged.

A successful result records the selected trip-time bounds and sample count; device-frame accelerometer mean and standard deviation; measured gravity direction; the observable accelerometer radial bias parallel to gravity; device-frame zero-rate gyroscope bias and standard deviation; conservative minimum Android accuracy statuses; raw quality flags; and interpolation counts. `calibrated_degraded` is distinct from `calibrated` when the selected source carries unreliable sensor status. Insufficient evidence carries explicit diagnostic reasons and no fabricated calibration.

One stationary orientation cannot identify a general three-axis accelerometer bias independently of gravity and phone orientation. The version-1 result must not be interpreted as a full accelerometer correction, a vehicle-frame transform, or proof that the phone remained fixed after the selected window.

## 6. Coordinate frames

At minimum distinguish:

### Device frame
Axes fixed to Android's natural/default device orientation: +X right, +Y device-top, and +Z out of the screen. Display rotation never remaps stored raw sensor axes.

### World/navigation frame
Version 1 uses right-handed ENU: +X east, +Y true north, and +Z up. GNSS bearing is degrees east of true north and describes horizontal travel course, not device orientation.

### Vehicle-relative frame
Version 1 uses right-handed forward-left-up:

- +X longitudinal — forward;
- +Y lateral — left;
- +Z vertical — up.

Transform quality depends on orientation/mount/heading confidence and must produce uncertainty flags.

### M3.4 frame-transform contract

Frame-transform version 1 consumes M3.3 calibration and M3.2 GNSS decisions without rewriting either source. Tilt resolution records its calibration bounds, measured device-frame up direction, exact horizontal-reference choice, orthonormal device-to-leveled matrix, and degraded/unavailable evidence. A later stationary gravity-direction change above 10 degrees invalidates the prior tilt assumption; yaw-only change remains unobservable.

Vehicle transformation requires explicit mount-forward evidence. World ENU transformation additionally requires an accepted GNSS course at or before the target monotonic trip time, no more than 2 seconds old, at speed at least 3 m/s, and with bearing accuracy at most 30 degrees. Results retain target/source/calibration times, fixed frame conventions, source decisions/evidence, and resolved/degraded/unavailable state. Matrices rotate vectors only; gravity removal, signal filtering, and derived longitudinal/lateral/vertical channels remain M3.5 work.

## 7. Derived channels

Possible replay/analysis channels:

- filtered speed (`m/s`);
- longitudinal acceleration (`m/s²` and optionally derived display `g`);
- lateral acceleration;
- vertical acceleration;
- jerk (`m/s³`);
- yaw rate (`rad/s` or deg/s with explicit naming);
- heading change rate;
- distance accumulation (`m`);
- moving/stopped state;
- sensor quality/confidence;
- orientation confidence;
- GNSS confidence;
- event probabilities/evidence.

Derived channels must reference algorithm/version when persisted as authoritative audit data.

## 8. Missingness

Missing is not zero.

Represent:

- unavailable source;
- invalid source;
- filtered-out outlier;
- interpolated sample;
- gap;

explicitly. Scoring should reduce evidence rather than assume zeros.

## 9. Quality flags

Candidate flags:

- GNSS_LOW_ACCURACY;
- GNSS_GAP;
- IMU_DROPOUT;
- DEVICE_MOVED;
- ORIENTATION_UNCERTAIN;
- CLOCK_DISCONTINUITY;
- MOCK_LOCATION_SIGNAL;
- IMPOSSIBLE_JUMP;
- SENSOR_SATURATION;
- INTERPOLATED;
- LOW_SAMPLE_RATE;
- BACKGROUND_SERVICE_RECOVERY.

Machine-readable definitions belong in schemas/enums once implementation begins.

## 10. Trip boundaries

A trip record includes:

- trip ID;
- local creation time;
- monotonic epoch/boundary metadata;
- selected vehicle profile ID;
- start/end wall time;
- schema versions;
- acquisition configuration snapshot;
- recorder/device capability summary;
- chunk index;
- completion state (recording/finalized/recovered/corrupt).

Crashes/restarts must not turn an unfinished trip into an apparently normal finalized trip.

## 11. Resampling

Raw sensors may have different rates. Preserve raw/native timestamps, then construct analysis windows through a documented resampling/alignment procedure.

Do not make UI replay sampling identical to ML sampling by accident. It is acceptable to have:

- raw acquisition stream;
- analysis stream;
- reduced replay/display stream.

Each should have clear version/derivation.

### M3.1 analysis timeline baseline

Analysis timeline version 1 is a local native-Kotlin contract over verified raw chunk encoding/schema version 1. Its configuration snapshot declares the target interval and maximum IMU interpolation gap. The default interval is 10 ms and the default maximum interpolation gap is 50 ms; changing either value changes the configuration snapshot even when the algorithm version is unchanged.

Frames are anchored to `trip_elapsed_ns`, never wall time. Original GNSS records are assigned once to their monotonic time bucket and are not coordinate-interpolated before M3.2 sanity filtering. Accelerometer and gyroscope axes may be linearly interpolated only between bracketing samples whose elapsed gap is within the configured bound and has no raw dropout/clock-discontinuity evidence. The aligned value retains both bracketing trip/source timestamps, the conservative lower accuracy status, the union of raw quality flags, and an exact/interpolated state.

Missing IMU output remains explicit as channel unavailable, outside source coverage, source discontinuity, or interpolation gap too large. The resampler never extrapolates, never rewrites raw evidence, and exposes repeatable lazy frame iteration so a long trip need not be eagerly duplicated in memory.

## 12. Unit conventions

Internal canonical units should prefer SI:

- distance m;
- speed m/s;
- acceleration m/s²;
- angular velocity rad/s;
- time seconds/nanoseconds as appropriate;
- angles rad internally where math benefits, degrees only when explicitly named/displayed.

UI may display km, km/h, g, degrees, etc. Conversion belongs at boundaries.

## 13. Privacy

Precise coordinates/raw streams are local-private by default. See `PRIVACY_MODEL.md` and `SYNC_SPEC.md` before adding network serialization.

## 14. Golden fixture requirement

Every schema/decoder version should have at least one tiny deterministic test fixture proving:

- timestamps decode correctly;
- units remain correct;
- chunk boundaries do not reorder samples;
- old supported schemas remain readable.
