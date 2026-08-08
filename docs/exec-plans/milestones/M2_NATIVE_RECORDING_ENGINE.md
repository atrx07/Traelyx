# M2 Playbook — Native Recording Engine

## Goal

Prove the one thing everything else depends on: trustworthy real-device recording while the UI is not actively babysitting it.

## Minimum references

`android/AGENTS.md`, `ANDROID_TRACKING.md`, timestamp/raw sections of `TELEMETRY_SPEC.md`, `STORAGE_SPEC.md`, `SAFETY_GOVERNANCE.md`.

## Work units

1. Define native trip state machine: idle → starting → recording → stopping/finalizing → recovered/error.
2. Implement foreground service and user-visible recording notification.
3. Implement GNSS acquisition with accuracy/source timestamps.
4. Implement accelerometer/gyro acquisition with original timestamps.
5. Define bounded buffers and durable chunk writer.
6. Protect chunk atomicity/checksum and unfinished-trip recovery.
7. Implement Flutter bridge commands/status without making Flutter lifetime authoritative.
8. Add contextual permission flow.
9. Add recorder health counters: sample counts, gaps, service restarts, last flush.
10. Test screen lock/background/activity recreation/network loss/GNSS loss.
11. Export first `.tripdebug` fixture.
12. Conduct a normal legal 30–60 minute physical drive and inspect gaps/timing.

## Acceptance

- screen can remain locked for a full real trip;
- no unexplained catastrophic gaps;
- Flutter can reopen and discover active/recovered recorder;
- raw GNSS/IMU timelines are preserved and exportable;
- a failure never masquerades as a perfect finalized trip.

## Stop-the-line failures

Do not move to ML/scoring if recorder randomly loses long segments, timestamps cannot be aligned, or chunk corruption is common.
