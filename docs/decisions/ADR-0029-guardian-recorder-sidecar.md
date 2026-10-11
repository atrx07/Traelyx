# ADR-0029 — Isolate Guardian evaluation from recorder acquisition

- Date: 2026-10-11
- Status: Accepted for the M6.8 integration; active device validation pending

## Decision

RecorderService offers unchanged GNSS/IMU samples to an optional native sidecar
only after its independent raw writer accepts them. Acquisition does not wait
for Guardian disk IO, worker shutdown, Auth or network access. Guardian's existing
bounded evaluator owns its own queue/reorder buffer; no new sensor subscriptions,
sampling changes, wake locks or raw upload are introduced. Core recording remains
accountless. Trip stop/error closes forwarding immediately and discards late
evidence; it never waits for Guardian before flushing/finalizing raw recording.

The existing single Guardian owner executor serializes activation controls,
authority validation and encrypted outbox insertion. A detection callback posts
owner work rather than writing on the acquisition/evaluator thread. Before enqueue,
recheck the exact lease, current recording handle, clocks and worker availability.
Persist detection identity and cooldown together using the existing outbox.
There is no network sender or activation UI in this bounded integration.

Live evaluation requires a local two-stage activation committed in this process.
Restored encrypted leases remain status/outbox evidence, but owner binding alone
cannot restart evaluation after full process death. A fresh explicit driver
activation is required. This conservatively avoids replaying authority after an
interrupted or failed local cleanup. A service restart within the same process
may recalibrate under its still-valid committed lease and persisted cooldowns.
Driver UI must distinguish lease presence from actual monitoring and explain
the restart requirement before exposing activation.

Worker/evidence/enqueue failure stops only Guardian, blocks that lease in this
process and attempts local authority revocation. Failed erasure is not reported
as successful; existing coordinator unbinding and fresh-commit gating remain
fail closed. A one-second owner watchdog checks only clocks for a live run and
stops a quiet expired/reboot-invalid session. It performs no periodic vault IO
while valid and is absent when evaluation is inactive. It adds no wake lock and
cannot promise execution while the OS suspends the process; callbacks still
recheck authority before persistence.

## Validation and limits

Synthetic tests cover owner/commit gating, restored-lease refusal, unchanged
samples/no acquisition disk work, persisted cooldowns, stale detections/failures,
stop/replacement races, clock expiry/reboot/rollback, storage/cleanup/offer/factory
failures and failure-report isolation. Native suites, lint, configured build and
inactive physical startup are required before completing this bounded change.
Active physical recording, performance/battery, process recovery UX, cancellation,
dispatch and two-phone delivery remain M6.8 gates. Synthetic rules are not field
crash accuracy or emergency protection. Schema, envelope, scoring and rule version
remain unchanged; no new dependency or permission.
