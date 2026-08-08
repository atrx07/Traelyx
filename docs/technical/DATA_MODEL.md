# DATA_MODEL.md — Local & Cloud Domain Model

## When to read

Read when creating/migrating database tables, changing ownership relations, cloud sync payloads, Guardian/friend/ranking data, or trip persistence.

## 1. Local database — source of truth for full trip history

Candidate entities:

### `vehicles`
- id
- owner namespace/user association
- display name
- vehicle type/class
- optional manufacturer/model/year
- created/updated
- calibration/baseline metadata references

### `trips`
- id
- vehicle_id
- start/end time
- duration/distance summaries
- completion/recovery state
- telemetry schema version
- scoring version
- event-engine version
- ML model refs
- integrity status
- telemetry confidence summary
- cloud sync state

### `trip_chunks`
- trip_id
- sequence
- storage path/blob reference
- encoding version
- start/end elapsed time
- checksum
- sample counts

### `trip_events`
- event ID/type/time range
- severity/confidence
- audit/evidence compact data
- model/rule versions

### `trip_scores`
- dimensions
- overall synthesis
- confidence
- scoring version
- audit contributions

### `driver_baselines`
- vehicle/profile scope
- dimension statistics
- schema/version
- valid history window metadata

### `sync_queue`
- operation ID
- entity/version
- state/retry metadata

### `settings`
Non-secret app settings. Secrets live in secure storage.

## 2. Cloud database — compact connected layer

Candidate Supabase entities:

- `profiles`;
- `vehicles` (sanitized metadata if synced);
- `trip_summaries`;
- `leaderboard_entries`;
- `friendships` / follows as product decides;
- `guardian_connections`;
- `guardian_events` / notification delivery records where needed;
- `achievements` later;
- moderation/report tables if social features require them.

## 3. What not to put in public tables

- raw route geometry;
- complete high-frequency sensor streams;
- provider API keys;
- signing material;
- private email unless auth service internally manages it;
- unnecessary vehicle registration identifiers.

## 4. Ownership IDs

Use stable UUIDs or equivalent non-sequential identifiers. Distinguish local anonymous owner/device namespace from authenticated cloud user ID.

## 5. Migrations

Every schema change:

- migration file;
- upgrade test from supported previous version;
- rollback/recovery consideration;
- default/backfill behavior explicit;
- no destructive migration without backup/export path or explicit release note.

## 6. Denormalization

Leaderboards may use purpose-built denormalized rows/materialized views for performance/privacy. Do not expose private trip table merely because it is convenient.

## 7. Generated schema doc

Once implementation begins, generate a DB schema reference under a generated docs area if feasible. Generated artifacts do not replace migration source files.
