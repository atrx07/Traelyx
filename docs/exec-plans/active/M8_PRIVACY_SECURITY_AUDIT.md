# Execution Plan — M8.3 privacy/security audit

**Status:** Complete at the bounded audit scope below
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
- [x] Review private/public RLS and current Guardian participant/permission/revocation gates.
- [x] Repair confirmed findings with negative regression coverage; document residual risks.
- [x] Run affected format/analysis/tests/lint/build/contracts and source CI.
- [x] Synchronize report, plan/STATUS/NEXTSTEPS/README; commit/push and verify remote main.

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
  catalog checks cover 17 tables and nine negative probes. Local Docker engine
  is not running; execute SQL in isolated source CI, never hosted production.
- Ordinary debug/release builds, all 601 native tests and app lint pass. Actual
  packaged release policy passes with 10 permissions/three exports, bound backup
  exclusions and consent defaults. Artifact SHA-256 is in the aggregate report.
  Ignored local.properties was restored byte-for-byte. Source CI pending.
  No phone/account/provider operation performed; no schema/dependency change.
- Source checkpoint `c29bde9` is pushed; local HEAD/origin/main matched. Full
  [source CI 44244259697](https://github.com/atrx07/Traelyx/actions/runs/44244259697)
  is running, including actual PostgreSQL catalog/negative probes and packaged
  policy validation. Do not mark M8.3 complete until all required jobs pass.
- First CI's cloud-schema job correctly exposed an overbroad new audit assumption:
  bootstrap's platform-owned rls_auto_enable event-trigger stub has no pinned
  search path. Existing migration revokes client execution but does not define
  that hosted helper. The audit now enforces its event-trigger identity and closed
  client ACL, with an added negative grant probe, while keeping the empty-path
  rule for app-owned definers. Existing fixtures/authorization tests are unchanged;
  hosted helper internals remain unverified. Corrected source CI is required.
- Corrected source `711cb27` is pushed. Full
  [CI 44244638894](https://github.com/atrx07/Traelyx/actions/runs/44244638894)
  passes all four jobs, including PostgreSQL's 17-table catalog/nine injected
  regressions and existing behavioral fixtures, Guardian Edge tests, Flutter/
  native suites, profile lint/builds and ordinary release packaged policy.
  The CI-built ordinary release independently retains exactly 10 permissions,
  three protected/reviewed exports and all backup exclusions. Both local/CI APK
  hashes and sizes are in m8-privacy-security-v1-result.json.

## Completion

M8.3 is complete as a bounded source/packaged/fixture audit. Backup eligibility
and callback-authority repairs are in `c29bde9`; catalog scope correction/additional
negative coverage is in `711cb27`. All four source CI jobs 44244638894 and local
596 Flutter/601 native/nine Python privacy tests, analysis/lint/build/contracts
pass. Completion documents are committed/pushed with clean local/remote main
synchronization verified. No schema migration, dependency, permission addition,
hosted mutation, live provider send or ordinary phone installation.

Physical OEM backup/restore, newer cross-platform transfers, hosted helper
internals/natural expiry and live Guardian/provider operation remain unverified.
No historical backup transmission is established or recalled. A private security
reporting channel must be confirmed before release; recorder profiling and carried
M6.8/M7/distribution gates remain held. Stop before M8.4 pending explicit authorization.
