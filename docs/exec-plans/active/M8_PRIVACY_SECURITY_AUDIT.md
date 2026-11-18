# Execution Plan — M8.3 privacy/security audit

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M8.3
**Started / last updated:** 2026-11-18

## Context / goal

User authorized M8.3 after M8.2 and the deferred pre-release profiling decision
at `f138d2e`. Audit permissions/components, local storage/backups, logs/diagnostics,
exports, optional provider payloads, RLS and Guardian authorization. Produce a
reproducible evidence matrix, repair confirmed defects and preserve explicit
unverified limits. Read root/app/Android/tests AGENTS, SECURITY, privacy policies,
permissions matrix and only relevant auth/sync/storage/provider/Guardian sections.

## Scope / boundaries

Source and ordinary APK review, synthetic/mocked negative tests, local/CI RLS and
Edge-function tests. No private routes/log dumps, real credentials, hosted account
mutation, live Guardian, provider sends, key creation, publication or ordinary
phone app replacement. No M8.4 work. Recorder profiling remains a separate
required pre-release follow-up. No new dependency or schema change planned.

## Steps / acceptance

- [x] Inventory source/merged APK permissions, exported components, backups and credential stores.
- [x] Trace diagnostics/logs, export minimization and consent-bound provider/network payloads.
- [ ] Review private/public RLS and current Guardian participant/permission/revocation gates.
- [x] Repair confirmed findings with negative regression coverage; document residual risks.
- [ ] Run affected format/analysis/tests/lint/build/contracts and source CI.
- [ ] Synchronize report, plan/STATUS/NEXTSTEPS/README; commit/push and verify remote main.

Evidence must distinguish inspected source, executed software/fixture tests and
physical/hosted behavior not exercised. A security audit is not a penetration-test
certification. Never turn an unknown or carried acceptance gate into a pass.

## Findings / progress

- Confirmed private database OS-backup eligibility in the actual ordinary APK;
  actual past transmission unverified. Policy v1 now excludes all domains and
  disables implicit backup. ADR-0045/issue record preserve compatibility limits.
- Noncanonical callback user information/ports reproduced and rejected; SDK PKCE
  unchanged. Cleartext denial is explicit, not a claimed plaintext leak repair.
- Flutter analysis and all 596 tests pass. Nine Python privacy-policy mutation
  tests pass; old packaged artifact fails exactly the intended new policy gates.
- Source review covers all matrix rows in PRIVACY_SECURITY_AUDIT_V1. New SQL
  catalog checks cover 17 tables and eight negative probes. Local Docker engine
  is not running; execute SQL in isolated source CI, never hosted production.
- Ordinary debug/release builds, all 601 native tests and app lint pass. Actual
  packaged release policy passes with 10 permissions/three exports, bound backup
  exclusions and consent defaults. Artifact SHA-256 is in the aggregate report.
  Ignored local.properties was restored byte-for-byte. Source CI pending.
  No phone/account/provider operation performed; no schema/dependency change.

## Completion

Pending. Distribution/M6.8/M7 and recorder-efficiency gates remain held. Stop
after M8.3; M8.4 requires separate authorization.
