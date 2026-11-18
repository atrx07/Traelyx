# M8.4 database upgrade rehearsal v1

**Status:** Active — local validation passes; source CI pending
**Date:** 2026-11-18
**Previous source baseline:** de3c3af
**Candidate target:** schema4, local database upgrade policy1

See the [aggregate result](m8-database-upgrade-v1-result.json) for exact case
outcomes, row counts/digests, input snapshot hashes and platform qualification.

This rehearses the database component of previous-source/candidate upgrades using
frozen schema writers and current production migration code. It does not install
an old APK, name a signed RC or replace M8.8/M8.9. The previous baseline and
candidate have identical schema4 snapshots/table definitions; this step adds no
schema5. No ordinary phone database, raw route or credentials are used.

## Matrix / acceptance

| Cases | Workload / assertions |
| --- | --- |
| 8 populated upgrades/reopens | Frozen schemas1/2/3→4 and4→4 in cleanly closed DELETE and WAL modes; 1,000 trips per fixture |
| 12 interruption/retry cases | Schemas1/2/3 in both journal modes; exception before later DDL or after callback/before framework version publication; atomic old/current image, exact old rows and successful retry |
| 1 development bootstrap | Historical settings-only writer→4; exact settings and complete target schema |
| 2 refusal cases | Unknown v1 table shape and future version5; version/schema/rows/sidecars unchanged, no implicit reset |

Every populated fixture includes three vehicles and three baseline records,
3,000 chunk metadata rows, 2,000 events, 2,000 historical score rows across two
synthetic scoring versions, and 250 queued snapshots with retry/attempt state.
Schema2+ retains 250 account-consent links; schema3+ retains two opaque synthetic
metadata cache payloads; schema4 retains two valid correction notes, one default
off and one explicitly opted in. Null values, incomplete/recovered history,
low-confidence evidence, JSON whitespace/Unicode and inactive model references
exercise preservation rather than recalculation or promotion.

The fixture compares canonical encodings of every row/column in every historical
table, preserving JSON string contents exactly. The aggregate report records row
counts/digests and frozen snapshot byte hashes. It does not claim binary equality
of the SQLite database file, whose layout/journals may change. New tables are
empty, so upgrades cannot manufacture consent. Target schema validation covers
constraints/indexes; PRAGMA integrity_check, foreign_key_check and foreign_keys
are checked. Production history/detail queries must read representative trips,
their latest recorded score/version and evidence counts. Two further reopen
cycles preserve the complete image; no upload/sync service is instantiated.

Nine small opaque sidecar sentinels are created below the owned fixture no_backup
tree and compared byte-for-byte by digest. They are not encoded GNSS/IMU chunks;
the test does not present them as raw codec, route/replay or sensor-quality proof.
Other chunk entries are metadata-only, as in the existing database benchmark.
WAL cases exercise a cleanly closed database configured in WAL mode, not a hot-WAL
crash/power-cut experiment. Existing migration tests separately retain the Android
locale-metadata recognition case.

## Repair / provenance

The rehearsal found non-atomic upgrade DDL/version publication. The old probes
leave mixed old-version/new-table images and fail. Upgrade policy1 now commits
DDL and the target user_version together; see [ADR-0046](../decisions/ADR-0046-atomic-local-database-upgrades.md)
and [the incident](../issues/2026-11-18_interrupted-database-upgrade.md).
An early failure rolls back; a transaction committed before a later callback
failure remains a complete current image and can reopen. Existing already-mixed
files are refused pending reviewed recovery, not silently reset.

## Reproduction / outputs

```powershell
flutter test test/core/database/migrations/upgrade_rehearsal_test.dart
flutter test test/core/database/migrations
flutter analyze
```

The first command writes build/reports/database-upgrade-rehearsal-v1.json, including
platform, target/policy versions, all23 case dispositions, counts/digests and
limits. Only a fully completed matrix sets passed=true. CI's full Flutter suite
runs it, compares populated-table row digests to the public synthetic reference
and retains the aggregate artifact. Snapshot byte hashes are provenance only;
line endings can differ across hosts. Local analysis, all619 Flutter tests,
ordinary debug/arm64 release builds, packaged Android privacy policy and
repository contracts pass. Test-owned temporary directories stay
under ignored .dart_tool/m8-upgrade-fixtures; cleanup checks their canonical parent
before recursive deletion. Failed-image inspection explicitly disables migration
so the observer cannot repair/rewrite the state being checked.

No new dependency, permission, cloud operation, raw/schema/model/scoring revision
or actual phone install. SQLite schema remains4. The [execution plan](../exec-plans/active/M8_DATABASE_UPGRADE_REHEARSAL.md)
records full validation, source CI and commits. Physical storage/power-failure,
platform SQLite variants and signed install/upgrade behavior remain unverified.
Recorder efficiency, private reporting, M6.8/M7 acceptance and distribution holds
remain. Stop after M8.4; M8.5 needs authorization.
