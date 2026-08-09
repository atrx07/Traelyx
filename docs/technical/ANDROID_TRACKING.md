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

M2.2 health snapshots contain acquisition state, provider, requested interval, counts, last source/trip timestamps, last accuracy, and optional-field presence, but never coordinates. Raw fixes remain process-local and ephemeral until M2.4 defines the durable versioned chunk format. They are not logged, bridged to Flutter, sent through diagnostics, or uploaded. `recordingAvailable` remains false pending M2.5/M2.6 integration and permission onboarding.

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
- recover existing active trip state.

Do not require Flutter to remain alive to preserve raw acquisition.

## 5. Crash-safe buffering

Use bounded in-memory buffers plus frequent durable chunk flushes. A process/device crash may lose the latest small window but should not lose an entire hour.

Chunk writes should have checksum/atomicity strategy.

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
- finalize recovered trip with appropriate quality flags if needed.

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
