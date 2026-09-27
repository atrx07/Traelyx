# Execution Plan — Long-trip finalization crash recovery

**Status:** Complete
**Owner:** agent/maintainer
**Milestone:** M6 reliability interruption
**Started:** 2026-09-27
**Last updated:** 2026-09-27

## Goal

Restore app startup and recover the maintainer's approximately 48-minute trip,
preserving all original evidence. M6.8 feature work is paused for this repair.

## Scope and evidence

Crash logs show a 256 MiB Android heap exhaustion in full-record catalog scanning
from pendingFinalizations on the main thread. Startup retries the pending record.
The app has no running recorder service. Before edits, a Git-ignored private local
tar backup preserves recorder files and SQLite: 74,347,008 bytes, 11,859 files,
one pending finalization; SHA-256
`0f3e3aea005f416d1e8624259df9dd4eaa2a3d4fbba7301430392a067875d268`.

## References / boundaries

Root/android/app instructions; recorder chunk codec/catalog, finalization bridge,
Drive stop flow, storage and Android tracking specifications. No cloud upload,
data clearing, uninstallation, schema migration or score-version rewrite.
Preserve unfinished encrypted-outbox work from the interrupted M6.8 turn.

## Steps and gates

- [x] Preserve private raw files and database before app mutation.
- [x] Stream verified chunk metadata for finalization/recovery/export.
- [x] Move pending-finalization scans off the Android main thread.
- [x] Test long-trip memory behavior and existing corruption/order validation.
- [x] Build/update-install while preserving data; verify startup and reconciliation.
- [x] Verify recovered duration/chunk counts/hash preservation and responsive Stop UI.
- [x] Synchronize status, commit/push and report recovery honestly.

## Risks

Finalization must fully validate evidence even when discarding decoded samples.
The backup contains precise private telemetry and must stay ignored and local.
This recovery cannot manufacture usable scores from insufficient sensor evidence.

## Results

The data-preserving debug update reconciled the original pending finalization
into Drift. The saved recording is 2,727.075 seconds (45m27s), containing 4,290
ordered chunks, 2,725 GNSS, 547,659 accelerometer and 547,649 gyroscope samples.
Every raw chunk SHA-256 matches the pre-fix backup. The database reports
completed / recovery not needed, zero corruption/orphan/order counts and no
quality flags from finalization. The pending record was acknowledged normally.
Trips visibly shows the recovered recording; a second cold launch succeeds.

All 266 native tests, 28 targeted Flutter tests, static analysis and the configured
debug build pass. The lazy catalog regression decodes two million samples across
10,000 chunks under a 96 MiB Java heap. A slow-stop widget regression verifies the
confirmation closes while Saving remains visible and prevents a duplicate stop.
Private backups and verification database remain under ignored
`.dart_tool/trip_recovery/`; no user telemetry enters Git or cloud services.

Raw chunk v1, finalization logic v1 and the existing database schema are unchanged.
No dependency, permission, sampling, score or Guardian behavior was added.
A fresh long drive / physical End drive on the repaired build has not been tested;
the actual failed drive's reconciliation and subsequent startup were tested.
M6.8 remains in progress, with its prior work preserved in commit `96a9b79`.
