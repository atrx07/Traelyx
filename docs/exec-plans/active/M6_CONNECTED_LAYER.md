# Execution Plan — M6 Connected / Social Layer

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M6
**Started:** 2026-09-25
**Last updated:** 2026-09-26

## Context budget / references

Read only the relevant portions of `docs/exec-plans/ROADMAP.md`,
`docs/technical/DATA_MODEL.md`, `AUTH_SPEC.md`, `SYNC_SPEC.md`,
`docs/product/PRIVACY_MODEL.md`, and the affected code/tests. Load later
social/Guardian references only when their substeps are authorized.

## Goal

Add an optional connected layer without making recording, history, scoring,
replay, or export depend on an account or cloud service.

## User-visible result

M6.1 provides a versioned cloud schema and tested access boundaries. M6.2
adds an optional account path with secure sessions while local use remains
available without sign-in. Summary sync is a later substep.

## In scope

- M6.1: Supabase project linkage, versioned initial migration, explicit grants
  and RLS, reproducible access tests, and deployment verification.
- M6.2: optional email magic-link auth UX, secure session persistence, session refresh
  and sign-out, accountless navigation, and hosted auth configuration.
- Later M6 substeps only after their individual authorization gates.

## Out of scope for M6.1

- Flutter auth/session UI, cloud sync, public profiles, friendships,
  leaderboards, Guardian relationships/alerts, and raw-route upload.

## M6.2 boundary

- Email magic links are the initial method; password, Google, and Apple sign-in
  are deferred. Password reset is unnecessary without passwords.
- No local-to-account migration or trip upload is started by sign-in.
- Production auth uses a publishable client key supplied at build time, never
  a service-role key or a committed credential.
- Secure session storage must fail closed; device behavior needs physical QA.

## Preconditions

- Supabase free-tier project `ksydjfcyzdtpbigskahm` (Singapore) identified in
  the maintainer's authenticated dashboard; no credential is stored in Git.
- Current `main` is clean and aligned with `origin/main`.

## Affected components

- `supabase/migrations/`, `supabase/tests/`, cloud schema reference,
  `.github/workflows/ci.yml`, roadmap/status documents.

## Data/privacy/security implications

- New cloud storage is opt-in only when later app integration is added.
- No precise route, raw sample, email, device ID, API key, or high-frequency
  evidence column is admitted to the initial cloud schema.
- All client-facing tables use explicit grants and owner-scoped RLS. Client
  trip summaries remain untrusted inputs for later leaderboard validation.

## Compatibility/migration implications

- Initial migration starts an empty connected database; it does not alter
  Drift schema version 1 or existing local records.
- Subsequent cloud schema changes require forward migrations and tests.

## Implementation steps

- [x] M6.1 Create and test initial Supabase schema/RLS; verify project deployment.
- [ ] M6.2 Auth UX (authorized; host implementation ready for physical QA).
- [ ] M6.3 Local-to-account migration.
- [ ] M6.4 Profiles/vehicles sync.
- [ ] M6.5 Friends/social.
- [ ] M6.6 Safe leaderboards.
- [ ] M6.7 Guardian pairing.
- [ ] M6.8 Guardian alerts.

## M6.1 tests / validation

- [x] Apply migration to a fresh local PGlite PostgreSQL database.
- [x] Exercise anonymous, owner, and cross-owner RLS paths with real SQL roles
  locally, including a firing event trigger after helper `EXECUTE` revocation;
  CI PostgreSQL 17 verification remains pending.
- [x] Verify both hosted migrations, RLS state, helper grants, enabled event
  trigger, and a refreshed security advisor with zero errors or warnings.
- [x] Run repository contract/secret validation and `git diff --check`.
- [x] Confirm the PostgreSQL 17 CI job and other relevant CI checks pass.
- [x] Inspect the exact diff and commit/push the bounded implementation unit.
- [x] Push this completion-state update and verify `HEAD` equals `origin/main`.

## M6.2 tests / validation

- [x] Verify optional local navigation and account flows with unit/widget tests.
- [x] Verify session persistence, refresh, sign-out, and failure paths.
- [x] Run format, analysis, tests, repository validation, and Android builds.
- [x] Exercise the configured auth flow and secure storage on a physical phone;
  stop and ask the maintainer to connect it when host checks are ready.
- [ ] Inspect the exact diff, commit/push, verify green CI and Git alignment,
  then mark M6.2 complete and stop before M6.3.

## M6.1 acceptance criteria

- Fresh migration succeeds and is source-controlled.
- Anonymous clients cannot read or write private account tables.
- Authenticated clients can access only their own rows, including linked
  vehicles and summaries; owner columns cannot be reassigned.
- Cloud schema contains only the stated compact fields and creates no local
  account/cloud dependency.
- Hosted project state and test results are recorded before completion.

## Risks

- Hosted deployment needs a temporary CLI access token. Do not claim M6.1
  complete from local SQL inspection alone.
- RLS policies do not make client-provided scores trustworthy for ranking.

## Decisions made during execution

Use the accepted Supabase decision in `ADR-0003`. Future public/social access
requires its own narrowly scoped schema and policies.

## Progress log

- 2026-09-25: M6 authorized; M6.1 started. Existing project reference pending.
- 2026-09-25: Migration and SQL role/RLS tests passed under temporary PGlite
  0.5.8; repository contract/secret validation passed. No hosted deployment or
  CI result yet.
- 2026-09-25: Maintainer authenticated the dashboard. Confirmed Traelyx's free
  project in Singapore has no public tables or migration history. CLI 2.118.0
  installed temporarily; authored local config is source-controlled. Awaiting
  credential creation approval before linking and pushing the migration.
- 2026-09-25: Maintainer approved temporary CLI credential creation and
  deployment. Dry run listed only `20260925000000`; push succeeded, and remote
  migration history matches local. Dashboard shows three empty public tables,
  each with RLS and its owner-scoped policies. Per-table Data API exposure
  remains off (0 of 3); M6.3 must enable and verify only needed routes.
- 2026-09-25: Hosted security advisor reported two client-EXECUTE warnings on
  a pre-existing `public.rls_auto_enable()` helper. A conditional follow-up
  revoke migration passed local present/absent-helper tests and remote dry run.
  Automatic approval review rejected applying this new production migration
  because it was outside the earlier approval; explicit approval requested.
- 2026-09-25: Maintainer approved the follow-up after confirming `PUBLIC`,
  `anon`, and `authenticated` execution would be revoked while the event
  trigger remains effective. Hosted catalog showed both helper and enabled
  `ensure_rls` trigger owned by `postgres`; a local PostgreSQL event-trigger
  test fired after the revoke. Applied `20260925010000`; remote history now
  matches both local migrations. Hosted query confirms `postgres` can execute,
  `PUBLIC`/`anon`/`authenticated` cannot, and the trigger is enabled. Refreshed
  Security Advisor reports zero errors and zero warnings. Repository
  contract/secret validation and whitespace checks pass; CI remains pending.
- 2026-09-25: Committed and pushed implementation as `c4b9c33`. GitHub Actions
  [run 36167160163](https://github.com/atrx07/Traelyx/actions/runs/36167160163)
  passed both jobs: PostgreSQL 17 cloud schema/RLS tests and the existing
  generated-source, schema snapshot, format, analysis, Flutter/Kotlin test,
  repository-validation, debug/release build, size, and artifact gates. The
  temporary local Supabase CLI credential was removed and a subsequent
  authenticated CLI request correctly required login. M6.1 is complete;
  M6.2 remains unauthorized.
- 2026-09-26: Maintainer authorized continuing with M6.2 and noted the phone
  is disconnected. Implementation and host validation may proceed; pause for
  physical auth QA when the code and CI checks are ready.
- 2026-09-26: Implemented optional email-link UX, build-time publishable-key
  configuration, Android callback registration, encrypted session and PKCE
  storage, and backup exclusion. Accountless operation remains available and
  sign-in triggers no trip upload. Focused Flutter tests and debug/release APK
  builds passed. Dart format, Flutter analysis, all 187 Flutter tests, repository
  contract/secret validation, and whitespace checks passed. Hosted callback
  configuration and physical session QA remain.
- 2026-09-26: Traelyx's `:app:testDebugUnitTest` passed with Android Studio's
  Java 21. The broader all-module Gradle task was inconclusive because a
  transitive `shared_preferences_android` Robolectric test needed an Android
  artifact whose download was aborted by the host network. No app test failed.
- 2026-09-26: Updated CI's Java runtime from 17 to 21 because the new
  transitive Android SDK 36 Robolectric test requires Java 21. Generated
  sources, Drift schema snapshots, and trip-debug inspector tests match the
  committed contracts. The physical phone is still absent from ADB; hosted
  auth redirect and session QA are still pending.
- 2026-09-26: Committed and pushed the in-progress M6.2 implementation as
  `fb03bc4`. GitHub Actions [run 36205833119](https://github.com/atrx07/Traelyx/actions/runs/36205833119)
  passed cloud PostgreSQL 17/RLS and all validation, Flutter, native Kotlin,
  debug/release build, and artifact gates. The maintainer connected the
  Android 14 Tecno, set the hosted auth redirect, and supplied an ignored
  local publishable-key build config. The auth-enabled APK updated the
  existing installation in place. Physical email-link callback signed in,
  encrypted session restore survived a cold app restart, local sign-out
  returned to the signed-out screen, and retained local trip history remained
  nonempty. Cold-start callback and post-expiry refresh remain to verify.
- 2026-09-26: The cold-start callback signed in but landed on Drive, requiring
  manual navigation to Account. The maintainer reported this UX gap. Added
  explicit dedicated-link routing for warm and cold callbacks while ordinary
  launches still enter Drive; focused route tests pass. Physical landing QA
  and full regression/CI validation remain.
- 2026-09-26: The auth-enabled phone build opens Account for a token-free cold
  callback while ordinary app launch still opens Drive. Added an explicit
  refresh action with visible success/failure and a widget regression path.
  The real Supabase session refreshed successfully and survived cold restart.
  With Wi-Fi briefly disabled (mobile data already off), refresh showed a
  connection failure without signing out; Wi-Fi was restored and a retry
  succeeded. Existing local trip history remained nonempty.
- 2026-09-26: The final link request displayed the generic connection error
  after the interrupted QA run. Phone Wi-Fi was on, airplane mode off,
  Internet ping passed 3/3, and project DNS resolved with 2/3 then 4/5 ping
  responses. No persistent offline flag exists in the auth flow. Fixed the
  misleading catch-all message by mapping provider errors to safe categories
  (transport, rate limit, service, rejection, unknown), with successful-retry
  regression coverage. The original failure category is not recoverable from
  the old UI/logs; one retry on a restarted updated build is still required.
- 2026-09-26: Updated the retained phone installation with the safe error
  categories and restarted only Traelyx. The maintainer requested one fresh
  link and confirmed Account shows Signed in; a privacy-safe UI check agreed.
  The current flow is healthy, while the original transient failure cannot
  be attributed conclusively to stale process state, transport, or the
  provider. The phone remains signed in and Wi-Fi enabled. All 199 Flutter
  tests, static analysis, and repository contract/secret validation pass;
  the configured debug APK builds and installs, and the unconfigured release
  APK builds (57.6 MB). Final CI validation and completion persistence remain.

## Completion summary

M6.1 provides three empty, private, owner-scoped cloud tables, versioned
migrations, and reproducible SQL access tests. Both migrations are installed
on the Traelyx free-tier Singapore project. No app sign-in, upload, local
schema change, route storage, or new production dependency was introduced.
Hosted RLS/privileges and the zero-warning security advisor were verified;
the cloud Data API table exposure remains off pending a later authorized sync
step. No new physical-device behavior was involved.
