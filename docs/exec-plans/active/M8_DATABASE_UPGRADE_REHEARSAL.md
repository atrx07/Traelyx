# Execution Plan — M8.4 database upgrade rehearsal

**Status:** Complete — bounded host database rehearsal; signed/device limits retained
**Owner:** agent/maintainer
**Milestone:** M8.4
**Started / last updated:** 2026-11-18

## Goal / context

User authorized M8.4 after M8.3 at `de3c3af`. Rehearse supported SQLite database
upgrades and the previous-build same-schema reopen with populated, file-backed
synthetic history. Source routes: root/app/tests AGENTS, DATA_MODEL migration
section, STORAGE_SPEC section 8, TESTING_POLICY and existing migration tests/
frozen schema snapshots. No unrelated feature or historical execution-plan loading.

## Scope / compatibility

Frozen schemas 1/2/3 to current 4; previous-build schema4 to candidate schema4;
recognized settings-only development bootstrap. Verify every historical row,
settings, scoring/model provenance, queue/consent/cache/correction state, indexes,
foreign keys, integrity, repository readability, reopen idempotence and opaque
synthetic sidecar-byte preservation. Exercise failed-upgrade rollback/retry and
unsupported schemas without implicit reset. Fix confirmed migration defects only.

No new schema/version is planned. No real history, phone app replacement, signing,
account/provider sends, live Guardian, model activation, release or M8.5 work.
Actual signed APK install/upgrade remains M8.8/M8.9, separately approval-gated.
Recorder profiling/private reporting and carried acceptance/distribution holds remain.

## Gates

- [x] Inspect production migrations and existing frozen-schema tests.
- [x] Add deterministic, file-backed representative-history and rollback fixtures.
- [x] Execute all supported paths and verify exact preservation plus usable queries.
- [x] Validate any repair with full affected tests, analysis/build/contracts and source CI.
- [x] Publish aggregate report/protocol and synchronize status/roadmap for the completion commit.

Use owned temporary directories and synthetic data only. No destructive fallback,
silent score recomputation, privacy opt-in, credential material or network access.
Reports contain only aggregate counts/digests and explicit host/device limitations.

## Progress / risks

- Current DB schema is4; all app-schema upgrades since1 are additive. Existing
  coverage includes bootstrap recognition/Android metadata and small 1/2/3 fixtures.
- Rehearsal must distinguish frozen-schema fixture generation from an actual old
  signed APK. Initial interruption coverage was missing and is now implemented.
- Both initial interruption probes fail on the old implementation: middle DDL
  leaves partial tables, and failure after migration callback/before Drift's
  version publication leaves full new tables with old user_version. Existing
  rows remain but normal reopen is blocked. Repair now commits DDL and the target
  version stamp together. The focused 23-case matrix and all 619 Flutter tests
  pass; analysis has no issues. No destructive reset. Frozen schema snapshots and
  table definitions match de3c3af exactly. Ordinary debug/arm64 release builds,
  packaged Android privacy policy, formatting and repository contracts pass.
  Source checkpoint `d7d2e1882ab323ed51e2b70dce718aed5a470897` passes all four
  [source CI jobs 44267925802](https://github.com/atrx07/Traelyx/actions/runs/44267925802),
  attempt2, including Linux rehearsal/reference row-digest comparison, generated
  schemas, full Flutter/native tests, isolated QA builds, ordinary debug/release
  APKs and packaged privacy policy. Attempt1 stopped before app checks on an
  upstream SQLite asset HTTP403; unchanged checksum-verified retry passed.

## Completion

M8.4's database-component rehearsal is complete. Production schema remains4;
no new dependency, permission, phone installation, user history access or network
operation in the rehearsal. The source fix, ADR and incident record are linked
from the [protocol](../../reference/DATABASE_UPGRADE_REHEARSAL_V1.md).
Physical power/process-kill, hot-WAL and actual signed APK upgrades remain
unverified; M8.8/M8.9 retain their separate gates. Recorder profiling, private
reporting, M6.8/M7 acceptance and distribution holds remain.
Persist this docs-only closure to origin/main and verify clean synchronization.
Stop after M8.4; M8.5 requires explicit authorization and has not begun.
