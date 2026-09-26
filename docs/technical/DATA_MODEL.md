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

### `trip_account_links` — Drift schema 2
- `trip_id`: primary key and cascading reference to the original local trip;
- `user_id`: immutable authenticated account association through the app;
- `consented_at_micros`: local consent timestamp, never uploaded;
- `summary_version`: currently 1.

The additive v1→v2 upgrade leaves existing trip, vehicle, raw-chunk, score,
baseline, settings, and queue rows intact. No existing trip is linked by
migration or sign-in. Explicit review creates links and upload snapshots in
one transaction. The trip's anonymous vehicle owner namespace is not changed.

### `settings`
Non-secret app settings. Secrets live in secure storage.

### `account_metadata_cache` — Drift schema 3
- composite primary key: `user_id`, `entity_type` (profile/vehicle), `entity_id`;
- strict version-1 `payload_json`, server `revision` (0 only for unsaved creation);
- optional `source_local_vehicle_id`, local-only provenance for a reviewed copy.

An additive schema-1/2→3 upgrade creates this cache without rewriting existing
trip evidence, account links, or queues. Draft operations use `sync_queue`
entity type `account_metadata_v1`, mutation UUID idempotency, and expected
revision. Profile/vehicle cloud rows gain server-maintained `revision` and
`last_mutation_id`; no new raw/private telemetry fields are introduced.

## 2. Cloud database — compact connected layer

M6.1 begins with private `profiles`, sanitized `vehicles`, and compact
`trip_summaries`. Their exact version-1 fields and access rules are listed in
[`CLOUD_SCHEMA_V1.md`](../reference/CLOUD_SCHEMA_V1.md); the migration is the
executable source. Later entities below remain candidates for their own
authorized substeps and migrations.

M6.3 changes only the private summary owner foreign key from `profiles` to
`auth.users`; profiles and vehicles retain their existing contracts. This
allows compact private snapshots before profile/vehicle sync in M6.4.

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

## M6.5 private relationships

`social_relationships` stores one canonical profile pair, participant-only name
snapshots, requester, pending/accepted/closed state, owner-specific block flags,
revision, request mutation UUID, and request/close timestamps.
`social_request_limits` stores one account quota/window. Both have RLS enabled
and no direct client privileges. Only guarded RPC projections return peer
username/display name, relationship ID, revision, and caller-relative state.
Closed pairs retain minimal abuse/cooldown history; account/profile deletion
cascades relationship rows. Local Drift remains schema 3. See ADR-0022.
