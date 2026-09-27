# Long-trip finalization and startup crash

## When to read

Read for End drive/save hangs, Android heap exhaustion during chunk catalog
verification, or startup crashes while reconciling a pending trip. Also consult
before changing recorder recovery, finalization or export memory behavior.

**Reported:** 2026-09-27, during M6.8 development.

**Status:** Confirmed root cause repaired; original trip recovered.

**Fix:** [`691bb5750e92a2038ce364cc35f559c3451d6fe8`](https://github.com/atrx07/Traelyx/commit/691bb5750e92a2038ce364cc35f559c3451d6fe8).

**Affected device:** Tecno LH8n, Android 14; observed Java heap limit 256 MiB.

## Symptoms and impact

The maintainer reported an approximately 48-minute drive. After End drive,
the confirmation remained visible while the underlying action showed Saving.
After roughly a minute the app crashed, and subsequent launches crashed too.
Verified recording duration was 45m27.075s; the report's estimate is not the
stored duration. The trip had not yet been indexed into local history.

## Confirmed cause

The Android crash trace reported `java.lang.OutOfMemoryError` with a
268,435,456-byte heap growth limit. The failing path was:

```text
MainActivity method-channel dispatch
  -> RecorderBridgeDispatcher.dispatch
  -> AndroidRecorderBridgeGateway.pendingFinalizations
  -> AtomicFileTelemetryChunkStore.scan
  -> TelemetryChunkCatalog.inspect
  -> TelemetryChunkCodec.decode / decodeRecords / readImu / decodeImuFlags
```

Catalog scanning retained encoded chunk bytes and decoded sample objects for
the whole trip. With over a million motion samples, that object graph exhausted
the heap. Pending-finalization verification also ran on the Android main thread,
blocking UI progress; this explains the confirmation remaining visible during
saving. Startup retried the same durable pending finalization and exhausted the
heap again. The original raw chunks and pending record remained intact.

## Durable code repair

- Added lazy, sequence-ordered metadata catalog verification. Each chunk still
  receives full checksum, sample, identity and ordering validation; decoded
  samples are discarded after its metadata is collected.
- Switched finalization, recorder recovery and export's catalog verification to
  this metadata path. Grouping filenames by sequence also removes repeated
  whole-directory searches for each chunk.
- Moved pending-finalization verification to a dedicated native worker, with
  method-channel results returned on the UI thread.
- Preserved the existing Drift transaction/acknowledgement boundary, validation
  flags, raw encoding v1 and finalization logic v1. No schema migration,
  sampling change, dependency, permission or upload was introduced.

This is a durable repair of the identified algorithm/threading defect. It
does not rely on a larger heap, reduced recording fidelity, deleted evidence,
or suppressing the crash. The one-time backup and trip reconciliation were
recovery actions, separate from the code fix installed on the phone.

## Data-preserving recovery and evidence

1. Before modifying the app, preserved recorder files and SQLite in a private,
   Git-ignored local backup (74,347,008 bytes; 11,859 files; one pending record).
2. Independently decoded the affected trip and verified sequence/order/hashes.
3. Update-installed the configured debug APK without clearing data or uninstalling.
4. Allowed normal reconciliation to commit the trip/chunk index and acknowledge
   the pending record. Verified the resulting database and visible Trips entry.
5. Verified another cold launch and compared all original chunk hashes.

Recovered evidence: 4,290 chunks; 2,725 GNSS samples; 547,659 accelerometer and
547,649 gyroscope samples. Every raw chunk SHA-256 matches the pre-fix backup.
The database reports Completed, recovery not needed, and zero corruption,
orphaned-write or ordering counts. Those are finalization checks, not a claim
of perfect sensor quality or scoring eligibility. No personal telemetry was
uploaded. Private artifacts remain under ignored `.dart_tool/trip_recovery/`.

## Validation

| Check | Observed result |
|---|---|
| Full native Kotlin suite | 266 passed, zero failures/errors/skips |
| Relevant Flutter suites | 28 passed: Stop UI, recorder providers, finalization repository |
| Large synthetic catalog | 10,000 chunks / 2,000,000 samples passed with a 96 MiB test JVM heap |
| Corrupt/duplicate/orphan/ordering and wrong-trip checks | Metadata regression passed |
| Slow Stop UI | Confirmation closes while Saving remains; duplicate Stop disabled |
| Static analysis, repository validation, configured debug build | Passed |
| Actual device recovery and subsequent cold start | Passed; recovered trip visible as 45m27s, Completed |

The 96 MiB test exercises the catalog algorithm, not the whole Android app.
GitHub [repair CI run 36331984650](https://github.com/atrx07/Traelyx/actions/runs/36331984650)
was still in progress when this incident record was written; no CI success is
claimed here.

## Longer trips: remaining limits and follow-up

The specific whole-trip decoded-sample accumulation is removed from the repaired
paths. Longer recordings should therefore avoid this same finalization failure.
This is not evidence that arbitrary trip durations cannot crash:

- Filenames, verified metadata, finalization bridge payloads and database index
  work still grow with chunk count. Verification time still grows with data size.
  This is bounded sample decoding, not constant total memory for an unlimited trip.
- Export's initial catalog scan is repaired, but archive preparation still keeps
  compressed chunk bytes in memory. Its existing 10,000-chunk export limit is
  not a verified recording-duration limit or a memory-safety guarantee.
- This repair does not establish memory bounds for every analysis/replay/export
  operation, concurrent workload, device model, storage-full condition or OS kill.
- No fresh multi-hour physical drive and End drive on the repaired build was
  performed. The actual failed drive's recovery and later cold startup were tested.

Before claiming multi-hour reliability, validate progressively larger synthetic
catalogs through the full bridge/database path and measure peak heap, latency and
UI responsiveness on the target phone. Separately stress export/analysis, and
perform a fresh long-drive save/relaunch check. If metadata or archive memory
becomes limiting, add batching/streaming at that boundary with preservation and
failure-path tests. These are follow-up validation/hardening needs, not work
claimed complete by this fix and not authorization for a new roadmap step.

## Related sources

- [Recovery execution record](../exec-plans/completed/M6_TRIP_FINALIZATION_RECOVERY.md)
- [Storage specification](../technical/STORAGE_SPEC.md)
- [Android tracking specification](../technical/ANDROID_TRACKING.md)
