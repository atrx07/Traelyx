# ANDROID_TRACKING.md — Native Recorder Requirements

## When to read

Read for foreground service, permissions, GNSS/IMU acquisition, Android lifecycle/background behavior, native bridge, wake/battery behavior, or recorder recovery.

## 1. Core requirement

A real trip must remain reliably recorded even if:

- screen locks;
- Flutter UI is backgrounded;
- network disappears;
- app activity is recreated;
- the user returns after a long trip.

Platform limitations/OEM behavior must be tested and disclosed.

## 2. Foreground service

Use the appropriate Android foreground-service type/notification and current platform permission requirements.

The user must be able to tell recording is active.

### M2.1 lifecycle baseline

Recorder lifecycle state contract version 1 uses explicit `idle`, `starting`, `recording`, `stopping`, `recovered`, and `error` states. `recovered` is an active but visibly non-fresh state; it must not be presented as an uninterrupted normal trip. Duplicate start requests preserve the existing trip identity rather than creating a second lifecycle.

Before foreground promotion, the native recorder atomically persists versioned active-trip recovery metadata under the app-private no-backup directory. The record contains only trip identity, start wall/monotonic timestamps, lifecycle state, recovery count, and an allowlisted failure code. Missing, partial, unknown-version, or otherwise invalid metadata fails closed.

The service is non-exported, survives activity task removal, uses the Android `location` foreground-service type, and requires coarse or fine location permission before foreground promotion. The M2.1 bridge can start, stop, and query this lifecycle for validation. M2.1 itself acquired no GNSS/IMU samples, held no wake lock, and performed no network access.

### M2.2 GNSS baseline

While an active or recovered recorder service owns the lifecycle, a dedicated native handler thread registers `LocationManager.GPS_PROVIDER` at a requested one-second minimum interval and zero minimum distance. Fine location permission is required for this precise GPS path. Listener registration, provider disablement, sample mapping, and teardown are explicit; acquisition stops on recorder stop, error, or service destruction.

Raw GNSS schema version 1 preserves Android `Location.elapsedRealtimeNanos` as the source monotonic timestamp and `Location.time` separately as source wall time. Trip elapsed nanoseconds are derived only when the persisted same-boot monotonic epoch and fix ordering are valid. Latitude/longitude use degrees; accuracy, altitude, and speed use SI units; source-dependent altitude, speed, bearing, and associated accuracy fields remain nullable rather than becoming fabricated zeros.

Mandatory coordinates, source timestamp, provider, and horizontal accuracy are validated before acceptance. Horizontal accuracy above 50 metres is retained with `GNSS_LOW_ACCURACY`; invalid/non-monotonic epoch evidence receives `CLOCK_DISCONTINUITY`; Android's mock-location signal receives `MOCK_LOCATION_SIGNAL`. The latter is evidence only, never a standalone integrity verdict.

M2.2 health snapshots contain acquisition state, provider, requested interval, counts, last source/trip timestamps, last accuracy, and optional-field presence, but never coordinates. Accepted fixes are now handed directly to the M2.4 native durable writer; they are not logged, bridged to Flutter, sent through diagnostics, or uploaded. `recordingAvailable` remains false pending M2.5/M2.6 integration and permission onboarding.

### M2.3 IMU baseline

An active or recovered recorder service registers calibrated hardware `Sensor.TYPE_ACCELEROMETER` and `Sensor.TYPE_GYROSCOPE` listeners on a dedicated native handler thread. Absence or registration failure of either mandatory stream fails conservatively. Both listeners stop on recorder stop, error, or service destruction and restart with explicit lifecycle recovery.

Raw IMU schema version 1 preserves `SensorEvent.timestamp`, whose per-sensor time base matches `SystemClock.elapsedRealtimeNanos()`. Trip elapsed nanoseconds are derived only for a valid same-boot monotonic epoch and strictly increasing per-sensor source order. Accelerometer vectors remain in Android's unchanged device frame, include gravity, and use m/s². Gyroscope vectors use the same device frame and rad/s. No filtering, gravity removal, fusion, orientation inference, screen-orientation axis swap, or vehicle-frame relabeling occurs during acquisition.

The baseline requests a 10,000 microsecond period (100 Hz), below Android's 200 Hz permission threshold, and up to 1,000,000 microseconds of hardware FIFO report latency. Effective period never requests faster than the sensor's advertised `minDelay`; effective latency is bounded by reported FIFO capacity and falls back to zero when batching is unavailable. No `HIGH_SAMPLING_RATE_SENSORS` permission or wake lock is added.

Invalid timestamps, non-finite axes, and unknown accuracy states are rejected and counted. Non-monotonic or invalid-epoch events carry `CLOCK_DISCONTINUITY`; gaps above five effective periods carry `IMU_DROPOUT`; Android accuracy status zero or below carries `SENSOR_UNRELIABLE`. These remain raw quality evidence, not filtered values or safety conclusions.

M2.3 health snapshots expose sensor configuration/capability, counts, source/trip timestamps, accuracy status, gaps, and registration state without raw vectors. Accepted samples are now handed directly to the M2.4 native durable writer; they are not logged, bridged to Flutter, sent through diagnostics, or uploaded. `recordingAvailable` remains false.

## 3. Acquisition

Recorder owns:

- GNSS/location updates;
- sensor listeners;
- source timestamps;
- batching/buffer flush;
- trip start/end state;
- persistent recovery metadata;
- health counters.

## 4. Flutter bridge

Flutter commands:

- start trip;
- stop trip;
- query current recorder state;
- stream/retrieve live summary/health;
- recover existing active trip state;
- retrieve pending finalized-trip metadata and verified chunk indexes;
- acknowledge a pending finalization only after its local database transaction commits.

Do not require Flutter to remain alive to preserve raw acquisition.

## 5. Crash-safe buffering

### M2.4 durable chunk baseline

Accepted GNSS, accelerometer, and gyroscope samples enter a non-blocking native ingress queue bounded to 1,024 samples. A dedicated writer thread maintains a separately bounded 1,024-sample reorder heap, releases evidence after a two-second horizon, and completes a chunk at 256 samples or a one-second elapsed-time span. Queue/reorder overflow, invalid trip time, a sample behind the committed boundary, sequence exhaustion, or a write failure transitions the recorder to an explicit error rather than silently discarding evidence.

Chunk encoding version 1 is self-describing and declares telemetry schema version 1, trip UUID, sequence, elapsed-time bounds, per-channel counts, compression, stored payload length, SHA-256 over the stored compressed payload, and an explicit completion marker. Record encoding preserves the raw source timestamps, SI units, device-frame vectors, optional GNSS fields, provider/mock evidence, accuracy status, and quality flags. Platform DEFLATE uses best-speed mode, and decode independently enforces a decompressed-size bound.

Completed chunks are atomically replaced with Android `AtomicFile` under `noBackupFilesDir/recorder/trips/<trip-id>/chunks/<sequence>.tlxc`. Recovery scans and verifies self-describing files to continue after the highest observed sequence and last valid committed elapsed boundary. Corrupt, truncated, unknown-version, misnamed, out-of-order, and orphaned writes are isolated from the valid catalog and are never overwritten as recovered evidence.

Buffer health is internal and privacy-safe: it exposes state, bounded depths/capacities, counts, byte totals, sequence/boundary presence, isolated-file counts, and allowlisted errors, but no raw values, precise coordinates, vectors, timestamps, paths, or device identifiers. M2.7 finalization now reconciles the complete verified catalog into the existing Drift schema version 1 without changing the chunk encoding.

### M2.7 finalization and recovery baseline

Stop flushes acquisition and writes a versioned app-private pending-finalization record before active recovery metadata can be cleared. If process death interrupts Stop after that handoff, recovery completes finalization without restarting acquisition; without a handoff, the active trip remains explicitly recoverable.

The bridge exposes lifecycle metadata, aggregate recovery/corruption evidence, and verified per-chunk index metadata with stable relative references under `recorder/trips/<trip-id>/chunks/`. It never exposes coordinates, vectors, raw sample timestamps, absolute paths, chunk contents, device identifiers, or exception text.

Flutter reconciles each trip and its complete chunk catalog into Drift schema version 1 in one idempotent transaction, using a stable accountless placeholder vehicle until vehicle onboarding exists. Native pending metadata is acknowledged only after commit. Recovered, incomplete, corrupt, orphaned, misordered, and recorder-error outcomes remain explicit rather than appearing as an uninterrupted perfect trip.

### M2.8 local export baseline

After finalization and Drift reconciliation, the user may explicitly export a versioned `.tripdebug` archive through Android's system document picker. Native Kotlin remains the raw-chunk authority: it refuses active, empty, corrupt, orphaned, misordered, sequence-gapped, unreadable, changed, or mixed-version catalogs; writes the original verified chunks with a minimal `precise_private` manifest; then reopens and fully inspects the archive before reporting success. The bridge returns aggregate counts/gaps only and never transfers chunk bytes, coordinates, vectors, source timestamps, absolute paths, device identity, or exception text.

Maximum per-channel gaps include leading acquisition time and trailing loss relative to the complete trip bounds, not only intervals between samples. While the recorder is active, Flutter polls this aggregate health and must continue to show GPS acquisition or missing-motion status until samples from each required channel are observed; it must not claim that location and motion are being stored merely because the service started.

Export does not change acquisition, sampling, batching, wake behavior, raw encoding, database schema, retention, or network behavior. The version 1 contract and independent host inspector are defined in `docs/reference/TRIPDEBUG_FORMAT.md`.

## 6. Permissions

Request contextually and explain:

- location;
- background location if required by architecture/platform;
- notifications/foreground service visibility;
- sensors if platform requires special permission.

Do not request contacts, SMS, microphone, camera, etc. without feature need.

## 7. Battery

Do not hold unnecessary wake locks or maximum-frequency sensors permanently without evidence.

Measure:

- CPU;
- battery drain/hour;
- sample drop rate;
- GNSS update behavior;
- temperature where practical.

## 8. OEM/Android testing matrix

At minimum prioritize supported Android versions on real devices/emulators. Add OEM-specific notes only from evidence, not assumptions.

## 9. Recovery

On app reopen:

- detect active/recovered trip;
- show recorder state;
- avoid starting duplicate service/recording;
- discover and transactionally reconcile pending finalizations;
- finalize recovered trip with appropriate quality flags if needed;
- acknowledge native pending metadata only after the verified local index commits.

## 10. Initial proof-of-concept gate

Before building rich UI/ML, prove:

1. record 30–60 min physical trip;
2. lock screen;
3. background app;
4. preserve synchronized GNSS/IMU;
5. reopen and finalize;
6. export/replay raw timeline;
7. no unexplained large gaps.

This is M2's main acceptance criterion.
