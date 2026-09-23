# STORAGE_SPEC.md — Local Storage, Retention & Telemetry Chunks

## When to read

Read when changing SQLite schema, raw telemetry encoding, retention, cache, export, migration, or app-storage UI.

## 1. Problem

APK size is not the primary long-term storage threat; accumulated raw telemetry and map cache are.

The app should remain transparent about storage growth.

## 2. Structured vs high-rate data

Use Drift/SQLite for:

- trip metadata;
- vehicles;
- events;
- scores;
- baselines;
- sync state;
- chunk index.

Store high-rate telemetry in compact chunks/blobs/files chosen through benchmarks rather than millions of expensive logical records if that proves inefficient.

## 3. Chunk properties

Each chunk needs:

- encoding version;
- trip ID;
- sequence;
- start/end elapsed time;
- channel/sample counts;
- compression info;
- checksum;
- write completion marker/atomic strategy.

### M2.4 implemented baseline

Chunk encoding version 1 carries telemetry schema version 1 and deterministic GNSS/accelerometer/gyroscope records inside a self-describing binary envelope. It uses platform DEFLATE in best-speed mode, SHA-256 over the stored compressed payload, an explicit completion marker, and Android `AtomicFile` replacement. Files live only under app-private no-backup storage at `recorder/trips/<trip-id>/chunks/<sequence>.tlxc`; path components contain a trip UUID and sequence only.

The native catalog verifies complete chunks independently and isolates corrupt, truncated, unknown-version, misnamed, out-of-order, and orphaned writes. Recovery advances beyond the highest observed filename and the last verified elapsed-time boundary so existing evidence is not overwritten. M2.7 now rescans and reconciles the complete verified catalog into the existing Drift `trips` and `trip_chunks` tables in one idempotent transaction, then acknowledges the app-private pending-finalization record. Schema version 1 and raw chunk encoding version 1 are unchanged; corrupt or incomplete evidence remains explicit and is never indexed as a perfect trip.

M2.8 adds explicit user-directed `.tripdebug` export without changing the storage authority or retention default. Android creates a temporary deterministic archive in app cache, self-inspects it, copies it only to the user-selected document destination, and removes the temporary copy. The export remains precise-private and does not delete or replace the authoritative app-private chunks.

## 4. Compression

Favor fast, deterministic, mobile-friendly compression/delta encoding. Measure CPU/battery tradeoff.

The M2.4 deterministic synthetic baseline (one 1 Hz GNSS sample plus two 100 Hz IMU streams) encoded at 4,244 bytes/second, approximately 14.57 MiB/hour. This is a provisional codec/storage-growth measurement, not a physical-drive battery result, a retention promise, or evidence that all devices will produce the same rate.

## 5. Retention

User-configurable policy candidates:

- keep full raw telemetry 7 days;
- 30 days default candidate;
- forever;
- keep summaries forever but prune raw data;
- manual archive/export.

Do not hardcode final default until storage measurements are available.

### M5.9 implemented baseline

The default remains `manual`. The user may save `manual`, `7 days`, `30 days`, or `forever` as a local non-secret preference. A time-based policy only creates a preview: M5.9 never runs raw cleanup in the background. The preview includes the exact finalized-trip candidate count and indexed raw bytes, and execution requires a separate confirmation that explains the loss of route replay and future recomputation.

Raw-only cleanup asks native storage to remove one exact UUID trip directory before deleting that trip's chunk-index rows. Whole-trip deletion uses the same native guard before deleting the selected schema-v1 trip and its cascaded event/score/chunk rows. Both operations refuse active trips and pending finalization, fail closed on unsafe paths or native errors, and do not claim success after a partial failure. No database migration or raw-format change is involved.

## 6. Downsampling/archive

A future archive may retain lower-rate replay channels after full raw streams expire. If implemented, explain which analysis can no longer be recomputed.

## 7. Storage manager UX

Show breakdown:

```text
App
Trip summaries
Raw telemetry
Map cache
Downloaded local AI models
Total
```

The M5.4 local-canvas provider stores no tiles, reports map cache as unavailable at `0 B`, and implements clear as a visible safe no-op. Any future tile-backed provider must report real bytes and implement deletion through the same provider-neutral control before it can be enabled.

Actions:

- clear map cache;
- prune raw telemetry by policy;
- remove local model;
- export/archive;
- delete selected trips.

M5.9 implements these controls under **You → Data & Export**. Raw telemetry bytes are measured from the app-private recorder authority, while database, app, map-cache, and model categories retain their existing aggregate contracts. The current offline-canvas map provider continues to report an unavailable `0 B` cache and a safe no-op clear action. No local model deletion control is enabled while no downloaded-model provider exists.

The existing `.tripdebug` path remains version 1 `precise_private`. M5.9 adds a separate JSON `redacted_trip_summary` format version 1 for user-directed local export. It contains only bounded duration, distance, evidence states, telemetry schema version, event count, and an all-or-none score/provenance group. It excludes route geometry, raw samples, trip/account/device/vehicle identifiers, storage metadata, and wall-clock time. Redaction is not an anonymity guarantee. See `docs/reference/REDACTED_TRIP_SUMMARY_FORMAT.md`.

## 8. Database migration

Every migration requires upgrade tests with existing fixture DB. Never let a release migration destroy local trip history without explicit user-controlled recovery path.

## 9. Corruption

A corrupt chunk should not make all history unreadable. Isolate affected trip/chunk and expose diagnostic status.
