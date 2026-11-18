# Execution Plan — M8.4 database upgrade rehearsal

**Status:** Active
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
- [ ] Validate any repair with full affected tests, analysis/build/contracts and source CI.
- [ ] Publish aggregate report/protocol; synchronize status/roadmap and commit/push.

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
  Source CI is pending; the source checkpoint is not substep completion.

## Completion

Pending. Stop after M8.4; M8.5 requires explicit authorization.
