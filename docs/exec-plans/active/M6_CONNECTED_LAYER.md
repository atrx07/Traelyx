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
available without sign-in. M6.3 adds explicit compact-summary review and consent.

## In scope

- M6.1: Supabase project linkage, versioned initial migration, explicit grants
  and RLS, reproducible access tests, and deployment verification.
- M6.2: optional email magic-link auth UX, secure session persistence, session refresh
  and sign-out, accountless navigation, and hosted auth configuration.
- M6.3: explicit review/consent for existing compact trip summaries, immutable
  per-trip account association, durable upload queue and bounded retry,
  owner-only cloud writes and authenticated hosted verification.
- Later M6 substeps only after their individual authorization gates.

### M6.4 boundary (authorized 2026-09-26)

Add account-scoped cached profile/vehicle metadata and explicit foreground
save/reload/retry. Profiles default private; an explicit publication choice
exposes only username/display name through an exact-username lookup. Vehicles
remain private and contain only an opaque ID, chosen label, and broad class.
Copying selected local metadata never reassigns local vehicles or trips.
Server revisions detect concurrent edits; persisted mutation IDs make lost
acknowledgements retryable. Conflicts require discard/reload/review. No new
dependency, recorder behavior, social relationship, or trip upload consent.

- [x] Add versioned cloud revision/mutation APIs and sanitized public lookup;
  prove owner/cross-owner/anonymous boundaries and stale-write rejection.
- [x] Add additive local schema-3 metadata cache and account-scoped queue;
  preserve schema-1/2 trip evidence and existing summary consent/operations.
- [x] Implement profile/vehicle review/edit UI, explicit publication consent,
  selected metadata copy, offline cache, retries, and conflict feedback.
- [x] Validate domain/repository/SDK/widget/navigation/upgrade paths, full
  tests, generated files, analysis, repository checks, and Android builds.
- [x] Deploy and verify hosted migration; use synthetic metadata for network
  QA and preserve personal profile/trips. Verify physical upgrade/consent UI.
- [x] Review, commit/push, verify CI and Git alignment, synchronize completion
  documents, and stop before M6.5.

### M6.5 boundary (authorized 2026-09-26)

Mutual friendship requests use exact public usernames. Sending a request and
accepting one explicitly share username/display name with that participant,
including when the sender's profile is private. No trip, vehicle, score, route,
Guardian permission, email, or account ID is shared. Relationships are private
to participants through guarded RPC projections, with no direct client table
access. Implement accept/decline/cancel/remove/block/unblock, bounded request
rates, expiry and repeat-request cooldown. Block removes the relationship and
prevents new requests in either direction without revealing who blocked whom.
Social actions are online and explicit; uncertain responses require reload.
No notifications, contacts import, messaging, ranking, or new dependency.

- [x] Implement forward schema, guarded transitions/projections, and SQL tests.
- [x] Implement replaceable gateway, account-safe state, Social UI and tests.
- [x] Validate local suites/builds and prepare reviewed hosted deployment.
- [ ] Verify hosted/device behavior, full CI, and data preservation.
- [ ] Synchronize completion, commit/push, stop before M6.6.

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
- [x] M6.2 Auth UX (physical auth QA and CI passed).
- [x] M6.3 Local-to-account migration (hosted/device/CI validation passed).
- [x] M6.4 Profiles/vehicles sync (hosted/device/CI validation passed).
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
- [x] Inspect the exact diff, commit/push, verify green CI and Git alignment,
  then mark M6.2 complete and stop before M6.3.

## M6.3 implementation and validation

- [x] Add a non-destructive Drift v1→v2 upgrade for per-trip account links;
  preserve anonymous vehicle/baseline namespaces, trip IDs, and raw evidence.
- [x] Add an allowlisted version-1 compact payload, explicit preview/consent,
  atomic linking/queueing, account-switch protection, and foreground retries
  with persisted backoff. New trips require a new review; sign-in never opts in.
- [x] Decouple private cloud summary ownership from profile creation using a
  forward migration; retain RLS and verify the needed hosted client route.
- [x] Test payload minimization, duplicate/restart recovery, partial network
  failure, account switching, cancellation/deletion, and v1 upgrade preservation.
- [x] Run formatting, analysis, generated/schema checks, full Flutter/native/SQL
  tests, repository validation, and debug/release builds.
- [x] Verify the physical upgrade and consent UI; require maintainer consent
  before sending their summaries. Verify authenticated hosted idempotency/RLS.
- [x] Review/commit/push the bounded unit, verify CI and Git alignment, record
  completion, and stop before M6.4.

M6.3 cloud payloads omit dates, vehicle labels, route geometry, raw samples,
email, and unbounded JSON. Known duration, distance, score/version, aggregate
event count, opaque trip ID, and authenticated owner are the only fields.
Unknown analysis stays null. Local trips remain authoritative. A request
already in flight may finish when signing out or deleting local data; local
deletion and cloud deletion are separate actions and must be explained.

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
  was recorded as off (0 of 3); M6.3 must verify needed client routes.
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
- 2026-09-26: Committed and pushed callback/refresh/error-feedback fixes as
  `236201d`; local HEAD matched `origin/main` and the worktree was clean.
  GitHub Actions [run 36221304374](https://github.com/atrx07/Traelyx/actions/runs/36221304374)
  passed PostgreSQL 17/RLS, generated-source/schema checks, formatting,
  analysis, Flutter tests, inspector and repository checks, debug/release
  builds, native Kotlin tests, and artifact publication. M6.2 is complete;
  this completion-state update is documentation-only. M6.3 remains gated.

- 2026-09-26: Maintainer authorized M6.3. Implemented ADR-0020 compact snapshots,
  explicit review/consent, atomic account links/queue, persisted foreground
  backoff, cancellation/deletion handling, and account-switch protection.
  Drift schema 2 preserves existing local evidence and anonymous namespaces.
  Active-version event counting and stale in-flight acknowledgement handling
  have regression coverage. No new dependency or native permission was added.
- 2026-09-26: Browser control failed before connecting even after reauthentication.
  The maintainer applied the reviewed cloud migration in the SQL Editor and
  confirmed migration history, auth-owner foreign key, and RLS checks all true.
  A phone-only harness verified real owner insert/readback, duplicate handling,
  snapshot-conflict rejection, forged-owner denial, anonymous denial, and
  cleanup of its one disposable synthetic summary. No local trip data was read
  or uploaded by the harness. The ordinary app was restored afterward.
- 2026-09-26: The physical schema upgrade and Keep local flow passed on the
  Android 14 Tecno: four available summaries, zero queued, zero synced, with
  7,546 raw telemetry files / 59,570 KiB preserved. The initial shell-wrapped
  file count included other app files; a direct scoped count matches the
  recorded pre-M6 baseline. All 216 Flutter tests, static analysis,
  formatting, generated/schema reproducibility, repository contract/secret
  validation, and local PGlite migration/RLS suites pass. CI schema generation
  uses `--no-test` to avoid a duplicate empty template; substantive upgrade
  and data-preservation tests remain under `test/core/database/migrations`.
  Final configured debug was update-installed and remains signed in. The
  release-validation APK builds (58.6 MB), and all three inspector tests pass.
  CI gates and completion persistence remain.

- 2026-09-26: Committed and pushed implementation as `a228da9`; local HEAD
  matched `origin/main`. GitHub Actions [run 36224500242](https://github.com/atrx07/Traelyx/actions/runs/36224500242)
  passed both jobs, including PostgreSQL 17/RLS, generated/schema checks,
  formatting, analysis, all Flutter/native tests, inspector/contract checks,
  debug/release builds, size reporting, and artifact publication. The prior
  M6.2 documentation-only run failed resolving Kotlin artifacts from the
  Gradle plugin repository; that failure did not recur in this full run.
  M6.3 is complete. This completion update changes documentation only;
  M6.4 remains unauthorized.

- 2026-09-26: Maintainer authorized M6.4. Automatic approval review rejected
  writing the proposed public lookup grants; the maintainer then explicitly
  approved the complete M6.4 migration and access contract. Implemented
  ADR-0021 account-scoped metadata cache (Drift schema 3), reviewed profile/
  vehicle forms, explicit publication choice, durable idempotent edits,
  optimistic conflict detection, manual reload/discard, and bounded retries.
- 2026-09-26: All local PGlite migration/RLS suites passed. Browser control
  still crashed before connecting. The maintainer ran the reviewed SQL script
  and confirmed migration history, private RLS, and safe lookup grants all
  true with no test error. Hosted synthetic fixtures were rolled back.
  Tests cover denied anonymous/private access, two-field exact public lookup,
  unpublishing, stale revisions, duplicate mutations, and cross-owner denial.
- 2026-09-26: All 235 Flutter tests and static analysis pass, including strict
  SDK request shapes, account switching, disk reopen, profile-dependent retries,
  stale acknowledgements, schema-1/2 upgrades, and consent/navigation tests.
  Generated/schema output is reproducible; repository validation and local
  debug/release builds pass (release-validation APK 59.2 MB). The Tecno
  upgraded in place, defaulted to private, and successfully reloaded cloud
  metadata. The maintainer saved a chosen private profile and vehicle and
  reported both saves succeeded with zero queued changes. Cold restart
  restored both private cached records and zero queue; all 7,546 raw telemetry
  files / 59,570 KiB remain. No personal trip upload or public publication
  was performed. Final CI validation and completion persistence remain.

- 2026-09-26: Final review identified an SDK session-switch race: metadata RPCs
  inferred the owner only from the session. Added forward migration
  `20260926020000` to bind each request to its reviewed owner and revoke the
  unguarded signatures. Updated exact SDK payload assertions and SQL tests
  proving account-A payloads authenticated as B fail before writes. All local
  migration/RLS tests pass. The maintainer deployed the forward guard and
  confirmed all three checks true with no test error. Both final guarded
  profile and vehicle saves, with existing private fields unchanged, showed
  cloud confirmation and zero queue on the phone. The matching release APK
  builds successfully; final CI and completion persistence remain. Anonymous HTTP lookup returned 200 with no rolled-back
  fixture present; all three private tables returned `42501` / HTTP 401.

- 2026-09-26: Implementation committed and pushed as `56083b3`, with local
  HEAD matching `origin/main`. GitHub Actions [run 36228279521](https://github.com/atrx07/Traelyx/actions/runs/36228279521)
  passed both jobs: PostgreSQL 17 migrations/access tests, generated/schema
  reproducibility, formatting, analysis, 235 Flutter tests, native Kotlin,
  inspector/contract checks, debug/release builds, size reporting, and artifact
  publication. M6.4 is complete; this completion update is documentation only.
  M6.5 remains unauthorized.

- 2026-09-26: Maintainer authorized M6.5 and subsequently approved the exact
  migration/hosted tests. Implemented ADR-0022 participant-only mutual requests,
  guarded state transitions, name snapshots, request limits, expiry/cooldown,
  blocking, explicit disclosure/confirmation, and a replaceable online gateway.
  All 244 Flutter tests, static analysis, SQL suites, repository/format checks,
  and configured debug/release builds pass (release-validation APK 60.6 MB).
- 2026-09-26: Browser control recovered using keyboard activation; pointer clicks
  missed their targets. Applied migration `20260926030000` through SQL Editor.
  Hosted regression fixtures rolled back; migration history, RLS, participant
  RPC-only grants, and fixture cleanup all verified true. The phone update
  preserved the signed-in account. Social opening was inert; explicit reload
  returned an empty list and the rolled-back public username returned no match.
  A first observation ran before the network response; the completed response
  passed. Visual QA passed and all 7,546 raw files / 59,570 KiB remain.
  No real friend request or personal trip upload occurred. CI/persistence remain.

## Completion summary

M6.1 provides three empty, private, owner-scoped cloud tables, versioned
migrations, and reproducible SQL access tests. Both migrations are installed
on the Traelyx free-tier Singapore project. No app sign-in, upload, local
schema change, route storage, or new production dependency was introduced.
Hosted RLS/privileges and the zero-warning security advisor were verified;
the dashboard exposure indicators were recorded as off at that stage.
M6.3 subsequently verifies authenticated summary access. No new
physical-device behavior was involved in M6.1.

M6.2 adds optional Supabase email-link sign-in, encrypted session/PKCE
storage with backup exclusions, Account callback landing, explicit refresh,
and local sign-out through a replaceable gateway. The Android 14 Tecno
validated real links, cold session restore, refresh success and offline
failure/recovery, sign-out, retained local history, and callback routing.
The initial cold real link exposed the landing bug; token-free cold routing
and a fresh real link on the corrected build verified the fix. Provider
failure classification and retry are regression-tested; the earlier
transient send failure's root cause remains unknown. The phone is left
signed in. No trip upload or local database migration was added, and
accountless driving remains available. Dependencies are documented in
ADR-0019. M6.3 was subsequently authorized on 2026-09-26.

M6.3 adds optional, explicitly consented compact-summary snapshots, immutable
local account links, durable retries with backoff, conflict protection, and
cancellation. Local Drift schema 2 is additive; the cloud summary owner now
references `auth.users` directly while RLS/grants remain intact. The physical
upgrade and Keep local flow preserved four local trips and 7,546 raw files;
real hosted validation used only a synthetic row whose cleanup was verified.
The final ordinary debug app remains installed and signed in. All 216 Flutter
tests and the full CI gates pass. No personal trip upload, new package,
permission, background sync, future-trip opt-in, restore flow, or remote
deletion UI was introduced. Sign-out/cancellation cannot recall an already
in-flight request. M6.4 requires separate authorization.


M6.4 adds reviewed private profile/vehicle saves, an account-scoped schema-3
cache, durable foreground retries, mutation idempotency, and revision conflicts.
Both approved hosted migrations are installed; the forward guard rejects a
session that differs from the intended account and disables legacy unguarded
RPCs. Explicit publication exposes only exact username/display name. The
maintainer's real profile remains private; no personal trips were uploaded.
Physical saves, reload, cache restore, and data preservation passed on one
Android 14 Tecno. Account-switch races, conflicts, lost acknowledgements, and
public/private transitions were tested through automated SDK/repository/SQL
fixtures, not simultaneous physical devices or real-profile publication.
All 235 Flutter tests and full CI gates pass. No new dependency, permission,
background sync, recorder behavior, or local vehicle reassignment was added.
The additive local schema must not be downgraded. M6.5 requires authorization.
