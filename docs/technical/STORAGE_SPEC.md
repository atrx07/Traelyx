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

## 4. Compression

Favor fast, deterministic, mobile-friendly compression/delta encoding. Measure CPU/battery tradeoff.

## 5. Retention

User-configurable policy candidates:

- keep full raw telemetry 7 days;
- 30 days default candidate;
- forever;
- keep summaries forever but prune raw data;
- manual archive/export.

Do not hardcode final default until storage measurements are available.

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

Actions:

- clear map cache;
- prune raw telemetry by policy;
- remove local model;
- export/archive;
- delete selected trips.

## 8. Database migration

Every migration requires upgrade tests with existing fixture DB. Never let a release migration destroy local trip history without explicit user-controlled recovery path.

## 9. Corruption

A corrupt chunk should not make all history unreadable. Isolate affected trip/chunk and expose diagnostic status.
