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

This is M1's main acceptance criterion.
