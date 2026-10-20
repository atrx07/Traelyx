# Execution Plan — M6 Connected / Social Layer

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M6
**Started:** 2026-09-25
**Last updated:** 2026-10-17

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
- [x] Verify hosted/device behavior, full CI, and data preservation.
- [x] Synchronize completion, commit/push, stop before M6.6.

### M6.6 boundary (authorized 2026-09-26)

The maintainer explicitly approved completing the missing local analysis and
server-validation prerequisites within M6.6. Preserve scoring version 1 and
historical results. Local analysis is accountless, explicitly requested, and
separate from recording finalization. Missing calibration, mount orientation,
raw evidence, or full confidence must remain unavailable/ineligible.

Ranking submission requires a separate review and consent for a bounded,
sanitized validation dossier. Existing compact-summary consent is insufficient.
The server must recompute accepted metrics and enforce eligibility, versions,
ownership, deduplication, quotas, and withdrawal. Client integrity labels alone
are not validation. No coordinates, raw samples, exact dates, speed rankings,
extreme-G rewards, or new paid dependencies. Device-provided evidence cannot
prove driver identity or resist a fully compromised client; disclose that limit.

- [x] Persist immutable local scoring/integrity/event evidence from verified raw
  trips, with explicit mount input, bounded execution, failure recovery, and tests.
- [x] Define/version the minimized ranking dossier and safe aggregation policy;
  implement server validation/access controls and adversarial SQL tests.
- [x] Implement separate consent, account-safe submission/retry/withdrawal and
  truthful ranking/insufficient-evidence UI with regression coverage.
- [x] Validate full suites/builds; obtain exact migration approval; verify hosted
  synthetic transactions, device behavior, and preservation of personal data.
- [x] Review/commit/push, verify CI, synchronize completion, stop before M6.7.

M6.6 validation complete: all 260 Flutter tests, 222 native tests including
production analysis fixtures, static analysis, all local SQL
suites, exact atomic deployment-script checks, configured debug build and
release build (59.6 MB) pass. An 80-second synthetic trip passes the complete
raw-to-score adapter with full/verified eligibility; missing calibration and
corrupt evidence fail closed. Existing result/replay/accessibility tests remain
unchanged and pass after analysis controls were placed below recorded evidence.
The explicitly approved production migration and atomic hosted tests passed:
migration history, private RLS, guarded RPC grants and fixture rollback all
verified true. Physical synthetic analysis on Android 14 Tecno passed full/
verified scoring, transactional persistence in an isolated in-memory database,
immutable repeat refusal, minimized
payload and no-upload assertions (8,741 ms native analysis). The temporary
in-memory probe and 80 generated chunks were removed; the configured normal
app was restored. Explicit live comparison reload succeeds with no shared
results or eligible personal trips. All 7,546 original raw files / 59,570 KiB
remain. Consent/submission transitions use widget/SDK and hosted synthetic
tests; no personal trip or real friend's data was shared. CI run 36250004115
passed every gate for implementation commit `728254f`, including PostgreSQL 17,
generated/schema checks, Flutter/native tests, both APK builds and artifacts.

### M6.7 boundary (authorized 2026-09-27)

Implement authenticated short-lived random invite codes, recipient acceptance,
driver confirmation, explicit granular permission preferences, visible connection
history, revocation/disconnection and blocking. Invite secrets stay transient in
the app; the server stores only hashes. One directional Guardian relationship per
account pair is supported at a time; reciprocal roles require disconnect/re-pair.
Pairing shares reviewed username/display-name snapshots, never trip data. Keep
location, speed and history unsupported/off; label all alert/state delivery as
unavailable until M6.8. No new dependency, local schema or recorder change.

- [x] Implement private schema, account/revision guards, bounded invitations,
  single use/expiry, permissions, audit and adversarial SQL tests.
- [x] Implement provider-isolated account-safe UI and transient token handling;
  test consent, failures, stale responses and sign-out behavior.
- [x] Run relevant full suites/builds and hosted rollback-only validation after
  exact deployment approval; verify device behavior when a phone is available.
- [x] Commit/push, verify CI, synchronize completion and stop before M6.8.

### M6.8 boundary (authorized 2026-09-27; prerequisites included)

The maintainer authorized starting Guardian alerts. Inspection found that the
current native pipeline analyzes completed trips only; it has no live governed
safety-state evaluator or crash inference. Recorder acquisition currently only
persists samples, and no remote push provider is configured. Existing strong
maneuvers/road impacts must not be relabelled as crashes or severe risk.

The maintainer's subsequent continue authorizes both the live native evaluator
and background push prerequisites. Implement and validate them within M6.8;
synthetic rule validation alone must not be described as field crash accuracy.
The maintainer authorized creating Firebase under organization `atrx07`. Provider configuration, new
credentials and production access changes require their concrete deployment
review; do not collect secrets in chat.

Common delivery design to validate:

- A minimized, versioned event envelope contains an opaque event identity,
  event kind, governed rule version, occurrence time and explicit uncertainty.
  No coordinates, speed, route, raw samples, trip name or free-form message.
- Explicit driver activation and recipient notification opt-in are separate
  from pairing. Account changes/sign-out must disable old-account dispatch.
- Server authorization checks current active, unblocked directional consent
  on ingestion, dispatch and read. Permission changes must invalidate queued
  stale deliveries; re-pairing must not revive old events.
- Durable bounded retries use stable deduplication IDs, expiry, backoff and
  recipient-level delivery state. Backend acceptance is distinct from device
  receipt; no claim that a person saw an alert without acknowledgement.
- Generic push content avoids exposing driver identity or event details on a
  lock screen; opening details requires authenticated current permission.
- No automated emergency calling, guaranteed delivery claim, hidden location
  sharing, or changes to historical scoring rules.

Proposed provider: replaceable FCM Android adapter dispatched by a Supabase Edge
Function. Firebase documents Cloud Messaging as a no-cost product; high-priority
push attempts immediate delivery but can be delayed/deprioritized. Supabase
publishes an Edge Function push pattern. Server credentials stay in backend
secrets; no service-role or service-account key enters the mobile app.
Sources: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans,
https://firebase.google.com/docs/cloud-messaging/android-message-priority,
https://supabase.com/docs/guides/functions/examples/push-notifications.
Final package/version/license, transitive size, permission and battery review
must pass DEPENDENCY_POLICY before introducing a push SDK.

- [x] Inspect current safety/event, recorder, sync and pairing boundaries.
- [x] Resolve prerequisite scope: include live evaluation and background push. Firebase project and Android registration are ready; client configuration is staged locally.
- [x] Complete backend FCM credential installation after concrete deployment
  review (2026-10-03). The dedicated sender has only
  `cloudmessaging.messages.create`. An approved temporary project key-creation
  exception and organization policy administrator role allowed one replacement
  JSON key to be written directly to an ignored local file. The inherited
  policy was restored and verified enforced; the temporary role was removed
  and verified absent. The exact JSON was installed as Supabase Edge secret
  `GUARDIAN_FCM_SERVICE_ACCOUNT`; its hosted digest matched the local upload.
  The local JSON and transfer files were deleted. A 24-hour, project-scoped
  Supabase token with only Edge Function Secrets Read-write was used once and
  independently verified revoked; the older legacy token was untouched.
  Google IAM showed only the replacement sender key. Both Guardian functions
  remain disabled; no OAuth, FCM send, registration or alert occurred. Live
  authentication and delivery remain separate gates.
- [x] Implement an isolated Edge/FCM dispatch adapter with no runtime package:
  separate worker-secret authentication, bounded requests/responses, six claims
  with three concurrent sends, current target recheck, minimal data-only FCM
  payload, signed OAuth assertion and guarded completion. Eighteen synthetic
  Deno tests pass, including the combined HTTP adapter flow; formatting, lint
  and entry-point type checks pass. CI now includes a pinned Deno 2.9.6 gate.
  Repository secret scanning covers the new JS/TS and SQL/TOML source types.
  At this validation point no function deployment, sender key, scheduler,
  registration or send occurred.
  Concrete setup/review is in `docs/reference/GUARDIAN_DISPATCH_SETUP.md`.
- [x] Implement the separate capability ingestion/receipt Edge draft with exact
  request schemas, bounded bodies and deadlines, fixed service-role RPC routes,
  redacted errors and an explicit disabled flag. Eleven synthetic Deno tests,
  formatting, lint and entry-point type checks pass. Native integration and
  enabled hosted checks remain. See
  `docs/reference/GUARDIAN_CAPABILITY_SETUP.md`.
- [x] After full source CI run 36572524947 passed, deploy
  `guardian-capability` to production with processing disabled. The dashboard
  staging matched both committed source hashes. The function-specific legacy
  JWT gate was saved off and verified after reload. A direct unauthenticated
  synthetic POST returned HTTP 503 `capability_disabled` on 2026-09-29.
  No device registration, alert, scheduler or trip upload occurred.
- [x] After full source CI run 36336437458 passed, create the dedicated Google
  service account and grant only the custom `cloudmessaging.messages.create`
  role. Deploy `guardian-dispatch` with its own 256-bit worker secret and
  `GUARDIAN_DISPATCH_ENABLED=false`; disable the legacy JWT gate only for this
  function. Hosted empty-body calls returned 401 without the secret and 503
  `dispatch_disabled` with it. Google rejected JSON key creation under
  `iam.disableServiceAccountKeyCreation`; no key was downloaded or installed,
  the policy was not changed, and no scheduler, device registration or alert
  send occurred. Record this blocker before considering a new credential route.
- [x] Prepare service-only scheduled retry RPCs in
  `20260927020000_guardian_dispatch_worker.sql`, resolving the gap after native
  backend acceptance. All eight local SQL suites and the exact atomic hosted
  bundle pass. Claim replacement, revocation-before-send, expiry, Retry-After,
  exhausted attempts and stale/duplicate callback protections are tested.
  The hosted bundle is `.dart_tool/m6_8_worker_dashboard_deploy.sql`, SHA-256
  `0bbfa7642ba6eae1731baf7895e63a8f28e9bcf50c1bc30a37eaa90e58135611`.
  It requires an empty delivery queue under a transaction lock before running
  global-claim fixtures; existing production deliveries cause an atomic refusal.
- [x] Obtain exact worker migration approval, deploy and run rollback-only hosted
  checks (2026-09-27). Full CI run 36334866638 for `85ece8f` passed before
  deployment. Browser-staged SQL matched the reviewed bundle exactly; production
  returned true for `worker_migration_recorded`, `worker_service_only`,
  `private_rls_enabled` and `fixtures_rolled_back`, without test errors.
  Ignored proof: `.dart_tool/m6_8_worker_hosted.png`. No real alerts or device
  registrations were created. Edge Function, scheduler and sender credentials
  remain separate gates.
- [x] Specify the experimental version-1 safety rules, uncertainty and synthetic false-positive fixtures; do not claim field validation.
- [x] Implement isolated native rules/lifecycle prerequisite: 24 new tests, 246 total native tests pass; debug build and repository validation pass. Rules are not connected to recording or enabled in the app. See ADR-0025 and `GUARDIAN_ALERTS_V1.md`.
- [x] Verify native foundation CI run 36315748455 (`04a1836`) passes all gates.
- [x] Add optional Firebase Messaging 25.0.1 registration adapter with consent-race tests; configured/unconfigured builds, release build, 253 native tests and physical inert-startup proof pass. SDK review is in `FIREBASE_PUSH_SETUP.md`. Registration/delivery are not enabled.
- [x] Recheck the provider target contract before wiring recipient registration
  (2026-10-03). Current Firebase docs prefer FIDs, but the pinned 25.0.1 AAR
  exposes only the legacy token registration methods. The disabled worker and
  client still use the supported token path. A coordinated SDK/server migration
  to FIDs requires separate validation before production delivery; see
  `FIREBASE_PUSH_SETUP.md`.
- [ ] Implement minimized outbox, guarded cloud transitions, deduplication,
  expiry, revocation and explicit send/receipt states with adversarial tests.
- [x] Prepare private alert delivery migration and adversarial SQL tests; local
  full SQL suites pass. ADR-0026 defines scoped capabilities and bounded retention.
  Cancellation now ends before first network handoff; all 253 native tests pass.
- [x] Verify Firebase client CI run 36316643251 (`0171465`) passes all gates.
- [x] Deploy approved `20260927010000_guardian_alert_delivery.sql` after all
  CI gates passed in run 36317565469 (`decacb4`). Exact atomic hosted bundle
  passes: migration history, private RLS, guarded RPC grants and fixture rollback
  are all true. No real devices, personal telemetry or alerts were submitted.
- [x] Implement isolated Keystore-encrypted driver lease/outbox with bounded
  schema, atomic reservations/cooldowns, restart/cancellation and stale-callback
  guards. All 264 native tests, configured debug build and synthetic physical
  Keystore proof pass; existing raw files preserved. Runtime integration pending.
- [ ] Implement provider-isolated Android push, consent and alert UI; validate
  account switching, offline/recovery and background/locked-device behavior.
- [x] Add an explicit-load account-bound alert inbox with current-permission
  recheck on opening, separate provider/receipt/view states, expiry and
  background/account clearing. Twenty Guardian tests, analysis and configured
  debug build pass, including a 20-second request timeout and late-response
  rejection. Physical screen/hosted empty reload passes after the maintainer
  restored the phone's network. Push/driver activation and end-to-end delivery
  remain unavailable.
- [x] Implement isolated two-stage native activation coordinator: account/mount
  binding, two-minute single-use proposal, bounded server-confirmed lease and
  fail-closed teardown. All 275 native tests and configured debug build pass.
  Auth/consent/recorder integration is still pending; no activation enabled.
- [x] Add a dormant foreground Android bridge for the activation coordinator.
  Three bridge tests cover exact request fields and redacted status/commit
  replies. The Android runtime uses a single process worker and a fail-closed
  boot-count clock; those platform properties still need physical QA. All
  native unit tests, Android lint and the debug APK build pass. Lint exposed
  an older API-31-only Drive DNA integer conversion despite minSdk 24; the
  equivalent API-compatible bounds check now has a boundary/overflow test.
  No scoring rule or version changed. No Flutter caller, recorder hook,
  provider registration or send is enabled.
- [x] Bind the native Guardian owner to optional Flutter Auth without delaying
  local startup. Serialized identity changes target the latest account;
  sign-out waits for local cleanup and refuses to complete if it fails. Three
  focused race/failure tests and all 284 Flutter tests pass; analysis and debug
  APK build pass. No activation request, server session, device registration,
  recorder hook or alert send is introduced. Physical account-change QA and
  explicit consent/server-confirmed activation remain.
- [x] Verify the configured account-binding APK on the physical Tecno LH8n
  without clearing app data. The 2026-09-29 update-install and the 2026-09-30
  cold launch both opened normally; Auth remained signed in, the recovered
  45m27s trip remained in local history, and Guardian still disclosed that
  alerts were unavailable. Android exposed a readable boot count; no app crash
  or Guardian exception appeared in the checked process log. Source CI run
  36583140285 passed. This does not exercise an account switch, native lease
  begin/commit, recording hook or push delivery. No personal trip, device
  registration or alert was sent by this check.
- [x] Repair a cloud-provider regression exposed by the account decorator:
  profile/vehicle metadata, summary sync, Social, rankings, Guardian pairing
  and Guardian alert inbox selected Supabase transport by checking the concrete
  account gateway type. The decorator hid that type. All six providers now
  obtain the optional client through a delegated source interface, with an
  accountless null path. A focused provider-graph regression, all 286 Flutter
  tests, analysis and a configured debug APK pass. A data-preserving physical
  update completed a read-only Guardian server reload; sign-in and local trip
  history remained intact. No alert activation or personal trip upload occurred.
  Source CI run 36743035626 passed; account-switch behavior still requires
  physical validation.
- [x] Add a dormant Flutter two-stage driver activation service. It checks the
  current Auth owner, requests a native single-use proposal only after the
  future explicit mount/axis consent, sends its transient capability to the
  guarded signed-in session RPC, validates exact confirmation fields and a
  bounded expiry, then commits the encrypted native lease. Failed/late or
  account-changed attempts remove local authority and try a matching server
  revoke; server TTL remains the fallback if a late request cannot be revoked.
  Six synthetic flow/wire tests, all 292 Flutter tests, analysis and an Android
  debug build pass. No UI caller, recorder hook, device registration, hosted
  activation or alert send exists. Full CI run 36747071540 passed. Physical
  production MethodChannel remains to be verified before any activation
  control is exposed.
- [x] Run an isolated physical Android activation proof on the Tecno LH8n.
  Instrumentation uses a random proof namespace and actual boot-count clock,
  checks `bindOwner`/`begin`/`commit`/`snapshot`/`disable`, confirms ciphertext
  contains no capability, and destroys the scoped test key/file. The test APK
  builds and the proof passes; app-private storage remains 187,943 KiB before
  and after; full CI run 36750081398 passed. This uses a synthetic
  confirmation, no production Auth/session, alert, Firebase initialization or
  trip change. MainActivity MethodChannel,
  real consent and hosted activation remain unverified.
- [x] Verify the production Flutter-to-Android MethodChannel on the physical
  phone with `tool/guardian_channel_probe.dart` as a temporary entrypoint. The
  normal Guardian vault was empty before the test. A random synthetic owner
  bound through `MainActivity`, began a single-use proposal, returned an
  inactive snapshot, aborted, and cleared its binding; the probe displayed
  PASS on 2026-09-30. The probe made no Supabase RPC, FCM registration/send,
  recorder hook, alert or user-consent call. The normal configured APK was restored
  with `adb install -r`: it opens, the account remains signed in, the recovered
  45m27s trip remains visible, recorder storage stays 94,251 KiB, and the
  Guardian vault is empty. This verifies proposal/abort wiring, not hosted
  activation, commit through this channel, or end-to-end delivery. Full CI run
  36858643612 passed.
- [x] Extend the physical production-channel proof on 2026-10-01 with a
  second synthetic proposal, a five-minute local commit, an active snapshot,
  disable and an inactive snapshot. It displayed PASS, left the Guardian vault
  empty and recorder storage at 94,251 KiB. The normal configured APK was
  restored without clearing data; Drive opens, Account is signed in, and the
  recovered trip remains visible. This synthetic confirmation did not create a
  hosted session, register a device, dispatch an alert or validate real consent.
  Full CI run 36859977077 passed.
- [x] Add a dormant explicit driver consent review component. It requires a
  selected Android device-forward axis and separate rigid-mount, uncertainty
  and limited-recipient-sharing acknowledgements; cancel returns no consent.
  The activation service now rejects an incomplete, future or over-two-minute
  review before any native proposal. A widget cancellation/gating regression,
  a service rejection regression, all 294 Flutter tests, full analysis and the
  configured debug APK pass. At this stage the dialog had no production route or caller; it
  does not activate a hosted/local session or register a device. Full CI run
  36861945539 passed.
- [x] Add a separate, dormant recipient notification review. It explains the
  experimental detection/delivery limits and Firebase registration disclosure;
  both acknowledgements are required, cancellation returns no consent, and a
  review expires after two minutes. Two focused tests, all 296 Flutter tests,
  analysis and a configured debug APK pass. No production caller, Firebase
  initialization, permission prompt, device registration or alert send exists.
- [x] Add the dormant account-guarded recipient device RPC gateway. It accepts
  only canonical device/account/generation IDs, a bounded printable routing
  token and a 256-bit lowercase-hex credential; rechecks the signed-in owner
  before and after the guarded `set_guardian_push_device_v1` call. Revocation
  sends no routing token or credential. Six adversarial gateway tests, all 302
  Flutter tests, analysis, a configured Android debug build and repository
  validation pass. It has no runtime caller; no Firebase registration, server
  device row, notification or alert was created. Integration with encrypted
  recipient state, consent orchestration, cleanup and receiver authority remain pending.
- [x] Add separate, dormant native recipient receipt storage. A bounded
  version-1 record binds owner/device/generation and a 256-bit capability to
  at most 30 days, in its own no-backup file, Keystore alias and AES-GCM domain.
  Seven new unit tests cover restoration, account/generation/expiry denial,
  tampering, schema rejection, uncertain writes and failed erasure. The native
  app suite and scoped physical Keystore proof pass; the existing driver-vault
  physical proof also passes after the shared cipher gained a domain argument.
  The proof used a random namespace, cleaned its key/file, and left private
  directory sizes unchanged. No runtime caller, registration or alert exists;
  consent orchestration, server/provider cleanup and receiver authority remain pending.
- [x] Bind the dormant native recipient vault to the current Auth owner. A
  serialized coordinator/foreground bridge retains only same-account unexpired
  state, clears it on account switch/sign-out and rejects stale or future local
  commits. Flutter's owner port now waits for recipient and driver cleanup,
  refusing sign-out success if either fails. Seven native coordinator/bridge tests,
  two Flutter channel tests, the full native and 304-test Flutter suites,
  analysis and configured debug build pass. A scoped physical Keystore bridge
  proof and production Flutter-to-Android synthetic owner-binding probe pass;
  the normal app was restored without clearing data, and no production
  recipient credential or server device row was created. Consent, FCM token
  acquisition/deletion, server registration/revocation, receiver and alert UI
  remain pending.
- [x] Add an isolated Android parser for the fixed data-only FCM envelope.
  It rejects notification content, schema drift, extra fields and malformed
  identifiers before any future authority check. The full native unit suite
  passes. No receiver service or runtime caller is connected; no registration,
  notification or receipt is enabled.
- [x] Add a durable, account-free no-backup cleanup marker around the dormant
  Firebase registration adapter. It precedes every token request, survives
  restart/interrupted writes, and clears only after explicit token and
  installation deletion succeeds. Focused and full native tests, lint,
  configured APK and scoped Android 14 proofs pass; the normal app opens with
  private storage sizes unchanged. The owner runtime still lacks provider
  cleanup and no registration caller exists, so no token was requested.
- [x] Connect marker-aware provider deletion to native recipient owner binding.
  A valid same-owner restart preserves receipt authority; sign-out, switching,
  expired or orphaned state erase local authority and wait for confirmed
  provider deletion before binding. Failure/timeout denies the new owner;
  absent marker remains Firebase-inert. Native tests, lint, configured APK,
  data-preserving first-phone startup and a guarded production-runtime inert
  owner-bind proof pass. Server revocation and unexpected
  Auth-loss reconciliation are still required before opt-in is exposed.
- [x] Guard explicit recipient sign-out with the existing signed-in server
  device revocation RPC. Native status exposes only device/generation IDs;
  server revocation completes before local provider deletion and Auth release.
  Offline/malformed/missing transport denies sign-out; a confirmed server
  revoke followed by local deletion failure can retry locally. Concurrent
  sign-out and account replacement cannot release the wrong owner. All 311 Flutter
  tests, analysis, configured debug APK and a data-preserving first-phone
  startup pass. No production recipient device exists, so hosted revoke and
  physical registered-device sign-out remain untested. Unexpected Auth loss,
  reviewed opt-in and delivery remain gates.
- [x] Add a dormant, ID-only native revoke journal for unexpected Auth loss.
  It keeps at most eight exact owner/device/generation tickets in a separate
  no-backup AES-GCM/Keystore domain until confirmed server revocation; capacity
  or corrupt/missing/uncertain state fails closed rather than discarding a ticket.
  Six focused tests, full native unit suite, Android lint, configured APK and a
  random-namespace first-phone Keystore proof pass. The proof removed its key
  and file; Firebase stayed inactive. The initial isolated unit had no runtime
  writes. Full CI run 37134160751 (`1b6bce6`) passed. Same-owner
  reconciliation remains required before registration.
- [x] Capture recipient revoke IDs before native owner-switch, sign-out,
  expiry, explicit disable or replacement erases the old receipt. Journal write
  failure blocks a new owner or replacement and retains the old receipt and
  provider cleanup marker for retry. The exact-ID ticket is idempotent. Focused
  coordinator/lifecycle tests, the full native unit suite, Android lint,
  repository validation and a configured debug APK pass. Scoped first-phone
  bridge and production inert-owner proofs pass; the production journal remains
  absent and normal app startup succeeds after a data-preserving update. Full
  CI run 37135490530 (`8a0ffde`) passed. The signed-in same-owner server
  retry/confirmation bridge was still pending in this unit; no real device registered.
- [x] Wire signed-in, same-owner revoke reconciliation. The native bridge
  exposes only the bound owner's bounded device/generation IDs. Flutter checks
  Auth before and after each guarded server revoke and confirms the exact
  local ticket only afterward. Offline, account changes, malformed responses
  and failed local confirmation leave the ticket for retry. Explicit sign-out
  now erases a server-confirmed local receipt without creating a redundant
  ticket. All 316 Flutter tests, analysis, the native unit suite, Android lint,
  repository validation and the configured debug APK pass. A scoped first-phone
  bridge proof verifies owner filtering and exact ticket confirmation; production
  inert binding and normal startup pass after a data-preserving update. The
  production journal is absent. Full CI run 37137200095 (`0eefc13`) passed. No production ticket,
  token or server device exists yet; hosted same-owner retry is untested.
- [x] Reserve an exact ID-only revoke ticket before any future recipient token
  acquisition or server registration. Native binding requires the currently
  bound owner and an empty local receipt. If a crash leaves that ticket beside a
  committed receipt, same-owner retry revokes the server row, erases the matching
  receipt and retries provider cleanup before confirming success. Failed server
  or receipt cleanup keeps the ticket; failed provider deletion keeps its marker.
  All 318 Flutter tests, analysis, native tests, Android lint, repository
  validation, configured APK and scoped first-phone proofs pass. No production
  caller, token or device row exists. Full CI run 37191422357 (`43c03e5`)
  passed.
  The registration transaction, hosted row retry and delivery remain gates.
- [x] Enforce that reservation at the native local receipt commit boundary.
  A commit now requires a matching pending owner/device/generation ticket and
  an empty local receipt. A replacement must first disable the old receipt,
  preserving its revoke ticket, then use a fresh device ID and reservation.
  Native tests and the scoped first-phone bridge proof pass. Full CI run
  37192530498 (`6302ee8`) passed. This is dormant:
  production has no registered recipient or caller; consented token acquisition
  and the guarded registration transaction remain pending.
- [x] Add a dormant recipient registration transaction behind explicit fresh
  consent and current-owner serialization. It reserves exact cleanup IDs before
  an injected provider token request, checks Auth around each await, calls the
  guarded server registration, writes the native encrypted receipt, then clears
  the reservation. Failure attempts guarded server revoke and local/provider
  cleanup; uncertain cleanup retains the ticket or marker for retry. Synthetic
  tests cover success, account switch, local failure, failed revoke, expiring
  consent and exact receipt-channel response. Provider acquisition and local
  receipt awaits have 25-second limits. A concurrent explicit sign-out is refused and can
  be retried after the transaction. No production provider adapter or UI caller is wired;
  no FCM token or server row was created. All 327 Flutter tests, analysis,
  repository validation, a configured APK, and the data-preserving first-phone
  inert startup check pass. Full CI run 37195623057 (`fb75553`) passed.
- [x] Add a dormant native provider token bridge for the transaction. The
  MethodChannel requires the exact bound owner/device/generation ticket before
  invoking the marked Firebase adapter, and rechecks that ticket after its
  callback. A late result after owner switch, malformed token or mismatched
  consent is denied. The production entry point has no UI caller. All 328
  Flutter tests, analysis, native tests, Android lint, repository validation,
  a configured APK and scoped first-phone denial/startup proof pass; full CI
  run 37197100176 (`850ba2b`) passed. No real token was requested; live
  consent, hosted row and delivery remain gates.
- [x] Wire foreground recipient phone status, the existing two-acknowledgement
  review, guarded registration and explicit server-first withdrawal. Normal
  builds keep the opt-in action paused until hosted synthetic row registration
  and withdrawal pass. Opening Guardian sends no registration request; the first
  phone showed local status, opened/cancelled review, and retained no production
  revoke ticket. A data-preserving default-off update opens normally and shows
  the paused state. Focused widget/transaction tests, all 332 Flutter tests,
  analysis, formatting, repository validation, a configured APK and full CI
  run 37215132816 (`0f5e3ab`) pass. No real token or recipient row exists.
- [x] Add a versioned rollback-only synthetic recipient fixture to cloud-schema
  CI. It checks private table grants, exact signed-in registration, same-owner
  retry, wrong-owner denial, withdrawal and post-rollback absence. The fixture
  adds no migration or real recipient. Full CI run 37216038800 (`47ab744`)
  passed before hosted execution.
- [x] Validate synthetic hosted registration, withdrawal and same-owner retry
  before exposing real recipient opt-in. The maintainer ran the versioned SQL
  text in the Traelyx Supabase SQL Editor and reported all three final checks
  true with no error. Browser control failed before attachment, so the result
  was not directly observed by Codex. The fixture rolled back synthetic rows.
- [x] Run a separately consented first-phone registration and withdrawal check
  from a deliberately configured debug pilot build. Normal builds stay paused;
  release builds cannot enable the pilot flag. All 332 Flutter tests, focused
  recipient tests, analysis, repository validation and the configured pilot APK
  build pass; full CI run 37217322365 (`89a5b91`) passed. The APK was
  update-installed without clearing first-phone data. The maintainer completed
  both acknowledgements; the phone reported registration and an encrypted
  receipt existed. The maintainer's read-only hosted count was 1 total/1
  unexpired row. After explicit withdrawal, the phone reported removal, the
  local receipt and provider cleanup marker were absent, and the maintainer's
  hosted count was 0/0. Browser control prevented direct SQL observation;
  no push, alert, trip upload or second-phone test occurred. Alert processing
  stays off.
- [x] Add a dormant native FCM preflight after the strict data-only envelope
  parser. It requires the provider cleanup marker and a readable, unexpired
  encrypted local receipt whose generation matches the envelope. Missing,
  revoked, expired, mismatched or corrupt state yields no receipt authority.
  A valid result is transient and redacted in diagnostics; it is not permission
  to notify without a current server check. Focused and full native tests,
  Android lint and a configured default-off APK build pass. The first phone was
  not updated for this dormant change; no message, receipt or notification ran.
- [x] Wire the Android data-message receiver to a bounded, no-redirect HTTPS
  receipt call. It accepts only the exact `received: true` capability response,
  rechecks the encrypted local registration after the server reply, and then
  posts generic lock-screen text without driver or trip details. The endpoint
  is a public build resource derived from the ignored Supabase URL; no receipt
  credential is embedded. Five focused and full native tests, Android lint,
  repository validation and a configured default-off APK build pass. A
  data-preserving first-phone update opens normally; the withdrawn recipient
  receipt and provider marker remain absent. Both Edge functions stay disabled,
  so actual FCM arrival, server receipt and notification display are untested.
  The sender uses data-only messages. Firebase may automatically display a
  notification-type payload while backgrounded before this callback can reject
  it, so sender access and payload contract remain security gates.
  Full CI run 37310628396 (`470779b`) passed every job. Browser control recovered;
  a directly observed read-only hosted count confirmed 0 device rows and 0
  unexpired rows after withdrawal. No routing token or row identity was read.
- [x] Route a generic notice tap through the fixed data-free
  `io.github.atrx07.traelyx://guardian-notice/` link to Guardian. Extra paths,
  query/fragment fields, user information and ports are rejected. Opening the
  screen performs no alert request or view acknowledgement; signed-out users
  see the existing sign-in gate, and details still require explicit current
  server authorization. Full delivery IDs tag notifications without integer
  hash collisions. Navigation regressions, all 334 Flutter tests, analysis,
  native unit tests, Android lint and the configured default-off APK pass.
  A data-preserving first-phone update passed cold and warm link launches;
  sign-in remained and the withdrawn receipt/provider marker stayed absent.
  These were link-ingress checks, not FCM or actual notification-tap tests.
  Full CI run 37313495995 (`b6effe3`) passed every job.
- [x] Complete the separately approved capability-only hosted denial-test
  window on 2026-10-05. Direct aggregate counts before and after were 0 driver
  sessions, devices, alert events and deliveries. The flag was saved true at
  13:15:08 UTC and restored false at 13:16:09 UTC; the hosted false digest was
  verified. Seven enabled checks passed: GET 405, wrong media type 415,
  missing/extra/oversized contracts 400, and unknown synthetic receipt/ingest
  capabilities 401. After closure every POST again returned 503. The probe
  used only synthetic IDs and an unusable zero credential; no accepted event,
  registration, FCM send or scheduler occurred. Both functions are disabled.
  Ignored proof: `.dart_tool/m6_8_capability_denial_closed.jpg`. Routine
  ingestion/dispatch, driver consent, recorder integration and positive
  delivery gates remain.
- [x] Persist recipient notice claims before display (ADR-0027). Plaintext v2
  reads v1 authority and retains at most 1,024 compact delivery IDs under the
  existing no-backup Keystore key; no eviction, extra network field or recorder
  change. Duplicate dismissal/restart cannot reset claims. Expiry, replacement,
  withdrawal, missing server replies and uncertain disk writes fail closed;
  uncertain claims preserve atomic old/new authority for restart/revocation.
  A crash or display failure after claim may suppress that notice. All 351
  native tests, including v1 upgrade/key preservation, concurrent claims,
  capacity, lost-response retry and receiver lifecycle regressions pass.
  Android lint, configured default-off APK and repository validation pass.
  The isolated first-phone Keystore proof rejects duplicate claims through
  separate vault instances and erases its synthetic file/key with Firebase
  inactive and no-backup storage size unchanged. Production receipt and provider
  marker variants remain absent; the normal configured app reopens on the
  signed-in Guardian screen after its data-preserving update. Actual FCM,
  notification dismissal/tap, cold-process delivery and two-phone checks remain unverified; both functions
  remain disabled.
- [x] Duplicate-claim full source CI passed in runs 37319268272 (`24e6cd7`)
  and 37319919712 (`92a0430`, independent v1 upgrade fixture). After a
  data-preserving review-pilot update, the maintainer freshly consented to
  first-phone registration. App withdrawal control and encrypted receipt/marker
  presence were observed. A read-only dashboard count directly showed 1 device,
  1 unexpired device and 0 sessions/events/deliveries; both enable digests are
  false. No token, receipt credential or real profile name was inspected.
  Proof: `.dart_tool/m6_8_notice_claim_recipient_ready.jpg`.
- [x] Prepare the isolated positive-receipt window described in
  `docs/reference/GUARDIAN_RECEIPT_CHECK.md`. The stage/cleanup scripts and
  disposable wrapper pass all ten SQL suites on network-isolated PostgreSQL 17;
  negative staging/cleanup guards and recipient preservation also pass. The
  dormant two-request native phone probe compiles; all 351 native tests, Android
  lint and repository validation pass. Staging, enabled hosted
  positive receipt, FCM and notices have not run; obtain concrete production
  approval before the window. Keep dispatch disabled throughout.
  Full source CI run 37331996250 (`fd139db`) passed every job. The prepared
  instrumentation runner is update-installed on the authorized first phone;
  its hosted receipt mode has not been run. Fresh read-only hosted counts
  remain 0 sessions, 1 device, 1 unexpired device, 0 events and 0 deliveries.
- [x] Attempt the approved isolated receipt window on 2026-10-06. Staging
  passed; the Android gateway failed at regex initialization before HTTPS.
  Receipt status remained false. Capability was enabled 14:20:07–14:20:41 UTC,
  restored to false and verified by digest/503 responses; dispatch stayed false.
  Synthetic cleanup passed, preserving the sole real device, with final
  counts 0/1/1/0/0. Explicitly escaping the closing brace repairs the Android
  ICU pattern; all 352 JVM tests, lint, configured review-pilot build and
  repository checks pass. After a data-preserving first-phone update, the
  independent network-free Android contract proof passes with Firebase
  inactive. Subsequent source CI and hosted retry results are below; see
  `docs/issues/2026-10-06_android-guardian-receipt-regex.md`.
- [x] Repair source CI run 37479031254 (`94eadff`) passed every job. Repeated
  the already approved isolated receipt window after fresh queue/phone checks.
  Staging passed; capability was enabled 14:39:43–14:40:21 UTC on 2026-10-06.
  Both native receipt calls passed with unchanged local authority and Firebase
  inactive; boolean hosted verification confirmed `device_received`. Restored
  false and verified its digest/disabled responses, then removed only synthetic
  records. Cleanup passed all absence checks, preserved the sole real device,
  and final counts were 0/1/1/0/0. Normal signed-in app reopening and encrypted
  receipt/marker presence pass. Dispatch stayed false; no FCM, notice or trip
  upload ran. Receipt-only gate passes; actual FCM/notice, cold-process,
  recorder and two-phone gates remain. Proof:
  `.dart_tool/m6_8_receipt_positive.jpg`, `.dart_tool/m6_8_receipt_closed.jpg`.
- [x] Prepare and validate the controlled single-phone FCM window in
  `docs/reference/GUARDIAN_PUSH_CHECK.md`. Standalone pending-fixture/cleanup
  SQL and a one-invocation, bounded, redacted worker probe are implemented.
  Four Node probe tests and 352 native tests pass; own-notification observation
  and readiness modes compile. The read-only readiness proof passes on the
  consented first phone after updating only the test runner. Eleven SQL suites
  including the new negative-stage, cleanup and receipt-race fixture pass
  CI's disposable PostgreSQL 17. Full source CI run 37484921020 (`76c02a7`)
  passed every job. Local Docker startup failed before any container and exited
  without configuration/data changes; SQL validation used CI. Production
  rotation, enablement, sending and cleanup were subsequently approved and
  executed as recorded below.
- [x] Execute the approved first-phone background FCM/notice/tap gate.
  First window: capability 15:33:01 UTC, dispatch 15:33:19, both closed
  15:34:15 on 2026-10-06. Exactly one provider acceptance, hosted one-attempt
  receipt and own-app generic/private notice observation pass. The process
  stayed alive after `am kill`; cold-process arrival remains unverified.
  The maintainer cleared the notice before tapping and explicitly requested
  one repeat. Fresh reserved IDs 701–705 preserved duplicate claims. Repeat
  window: capability 15:39:38, dispatch 15:40:05, both closed 15:41:09 UTC.
  Exactly one provider acceptance and receipt pass; actual system-tray tap
  opens unloaded Guardian with Reload alerts available. Post-tap delivery
  remains `device_received`, not viewed. Both temporary worker secrets were
  retired to fresh server-only values, digests verified, old keys rejected
  with 401 and local files removed. Both marker-checked cleanups pass,
  preserving the real device; final counts 0/1/1/0/0 and both flags false.
  Saved sign-in/registration pass. See `docs/reference/GUARDIAN_PUSH_CHECK.md`
  and ignored positive/closed screenshots. No runtime/schema update, real
  telemetry, scheduler or Google sender-key change. Second phone not needed.
- [x] Verify one approved cold-process delivery with synthetic IDs 711–715.
  Process absence and package `stopped=false` were checked immediately before
  the sole dispatch; no instrumentation or app opening preceded hosted receipt.
  Exactly one provider acceptance, receipt and generic notice pass; actual tap
  opens unloaded Guardian and leaves delivery `device_received`, not viewed.
  Capability enabled 16:05:25 UTC, dispatch 16:06:25, both closed 16:07:27 on
  2026-10-06. Disabled probes pass. Test worker retired at 16:09:10, digest
  verified/old value rejected with 401/local file erased. Cleanup passes with
  final 0/1/1/0/0, both flags false and real registration/sign-in intact. No
  runtime/schema update, personal telemetry, scheduler or Google key change.
  See `GUARDIAN_PUSH_CHECK.md` and ignored cold positive/closed proof images.
- [x] Verify actual duplicate FCM suppression: 871–875 proof and closure below.
- [x] Verify server expiry after queuing: 881–885 proof and closure below.
- [x] Verify revocation FCM behavior: reviewed 901–905 proof and closure below.
- [ ] Complete recorder/driver activation integration
  and two-phone gates before calling M6.8 complete.
  First bounded implementation: connect a native offer-only recorder sidecar to
  the existing account-bound activation coordinator and encrypted outbox. Keep
  driver activation UI and network dispatch dormant. Reuse raw samples without
  changing acquisition/persistence, rates, permissions or wake behavior. Serialize
  authority and disk operations on the existing Guardian worker; acquisition must
  never wait on vault IO, evaluator shutdown or cloud access. Unknown owner,
  missing/expired lease, reboot and stale callbacks deny evaluation/enqueue;
  evidence/storage failure disables only Guardian until a new activation. Stop
  discards late evidence and never prevents trip finalization. Required gates:
  authority/failure/restart races with fake worker/storage, native suites/lint,
  configured build and data-preserving inactive startup; active physical recording
  and field sensitivity remain separate validation gates.
  - [x] Implement offer-only service hookup after raw-writer acceptance, immediate
    stop/error forwarding closure, serialized authority/outbox control and
    clock-only active watchdog. No disk work/shutdown on acquisition; no new
    subscriptions/rates/wake locks, activation UI or sender.
  - [x] Enforce fresh in-process activation for telemetry evaluation; restored
    lease/owner binding alone cannot resume it. Record ADR-0029 and update specs.
  - [x] Fourteen new integration regressions plus existing worker failure-report
    isolation pass; all 371 native tests have zero failures/errors/skips. Android
    lint and configured debug build pass; repository validation/diff checks pass.
    The documented temporary local.properties escaping remedy fixed the host
    lint representation error; exact original ignored bytes were restored.
  - [x] Data-preserving inactive physical update opens normally and You shows
    Signed in. All 11,857 recorder file hashes and encrypted recipient vault match
    the private pre-update manifests; driver vault remains absent. No recording,
    account change, activation, registration, alert or trip upload occurred.
    Initial Android launch output was inconclusive; subsequent top-instance
    Status: ok and visible app/sign-in checks pass. No startup-time claim.
  - [x] Exact diff inspected; source committed/pushed as `98f9a49`, with HEAD equal
    to origin/main. Full source CI 38133415539 passes all three jobs, including
    Flutter/native tests, debug/release builds and size/repository checks. This
    closes only the bounded native integration, not active-device or M6.8 gates.
  - [ ] Validate active recording/performance, process recovery UX, explicit
    activation/cancellation and sender integration before overall M6.8 completion.
  - [x] Add a dormant exact-revoke stop contract: native erases the local lease
    before returning only its activation UUID, and the account-bound Flutter
    service attempts the matching owner-checked server revoke. No capability,
    alert, account or trip data reaches UI or logs. Wrong-owner, malformed
    response, missing lease, vault-read failure and server-failure regressions
    pass. All 344 Flutter and 377 app native tests pass, analysis and configured
    debug build and app lint pass, and repository validation passes. No UI caller, hosted
    revoke, migration, sender or production enable change; active physical and
    two-device reliability checks remain open. Add a retryable server revoke
    before claiming user-facing cancellation complete; queued remote delivery
    may continue if the server revoke fails.
    Resume audit on 2026-10-13: Pixel_10 restarted with saved data; both devices
    remain paired and locally registered, neither has a recorder service, and
    the Tecno reconnects after restoring Wi-Fi from off. Both production enable
    secret digests still match `false`. No activation or alert send occurred.
  Next bounded unit: persist exact driver-stop revocation tickets in a separate
  encrypted, no-backup journal before erasing the local lease. A failed request
  keeps its ticket across process restart; only the same signed-in owner can
  enumerate/retry/confirm it. Reconcile outstanding stops before another driver
  activation, with no automatic network call from status or screen opening.
  Keep driver UI and sender dormant. Validate strict wire/owner guards,
  disk failure, capacity/corruption, restart, network retry and account races;
  require full Flutter/native suites, analysis/lint/build and exact-source CI.
  - [x] Implement durable explicit-stop retries: separate schema-1 AES-GCM
    no-backup journal stores only owner/activation IDs, capped at eight tickets
    and 4,096 bytes. Record before local erasure; confirm only after an exact
    same-owner server revoke. Pending stops and full/uncertain journal health
    deny new activation. No automatic status/startup request, schema migration,
    new dependency, monitoring UI or sender. Local Stop does not wait for
    recipient cleanup to reach the network. All 348 Flutter and 387 native tests,
    analysis, app lint, configured debug build and isolated proof compilation pass.
    The physical synthetic activation/stop proof reopens the Keystore journal,
    confirms its exact ticket and destroys only its proof key/file. All 11,857
    recorder file hashes and the real recipient vault are unchanged; driver
    authority remains absent. Pixel update preserves its recipient vault.
    Account-loss/activation-timeout teardown, replacement-conflict recovery,
    active recording and production UI/sender gates remain. Prior prerequisite
    commit `5dd2d5c` has full green source CI 38424057362.
  Next bounded unit: make account teardown clear driver authority even when
  recipient cleanup fails. Journal retained driver identities before owner-loss,
  expiry or reboot erasure; expose no IDs to a different owner. Explicit sign-out
  uses the existing exact driver-stop service while Auth is still available,
  retaining Auth on unconfirmed server cleanup. Keep driver activation UI and
  sending dormant. Require failure/account-race/expiry tests, full app suites,
  analysis/lint/build, isolated physical cleanup proof and inactive data preservation.
  - [x] Implement driver account teardown: retained lease IDs are journaled before
    owner-loss/change and invalid recovery erasure, including outbox background
    paths. Recipient cleanup failure still attempts driver teardown. Explicit
    sign-out stops/reconciles under the original Auth owner before recipient
    cleanup, retaining Auth on unconfirmed cleanup; account races cannot clear
    the new owner. Three new Flutter and seven native regressions, all 351 Flutter
    and 394 native tests, analysis, app lint, configured debug build and repository
    validation pass. Isolated physical proof verifies owner-loss capture, journal
    reopening and owner filtering before destroying only its synthetic key/file.
    All 11,857 recorder hashes and both receiver vaults remain unchanged, normal
    apps open with saved sign-ins and real driver authority is absent. No schema/provider/dependency,
    production enable or send change. Hosted driver revoke, uncommitted proposal
    teardown and replacement conflicts remain gates. Prior durable-stop commit
    `1647f3f` has full green source CI 38427561887.
  Next bounded prerequisite: add an owner-only driver revision contract so a
  revoke also invalidates delayed activation requests and old cleanup can settle
  without changing a newer session. Keep one private revision row per owner,
  preserve exact-session delivery revocation and fixed retry expiry, and make the
  legacy RPC cleanup-only. Prepare migration, access/race/upgrade SQL checks and
  atomic rollback-safe deployment bundle before requesting production approval.
  No activation or push window is part of this unit. Native proposal reservation
  and the v2 client remain a following integration unit after hosted verification.
  Prior account-teardown commit `0345e78` has full green source CI 38598534975.
  - [x] Validate and deploy the driver revision prerequisite.
    Local preparation passes all 13 SQL suites, legacy-session preservation and
    cleanup upgrade checks, repository validation and an atomic bundle with
    migration history plus rollback-only synthetic assertions. Source `b301544`
    has full green CI 38603573947. After exact Run/confirmation approval, the
    atomic production bundle passes migration history, private control RLS,
    owner-only RPC grants and synthetic-fixture rollback, all true. Fresh hosted
    enable digests remain SHA-256 of `false`; no mobile change, alert or trip upload.
    Legacy activation is now denied; durable proposal reservation and the v2
    client remain next. Approved deployment bundle SHA-256:
    `09b0ae2a27620ba4f7f20a3e18aa6bbd7587cbe4bbafb88db32d037d321744fb`.
  Next bounded unit: reserve exact proposal IDs in the existing encrypted driver
  journal before returning a native capability. Commit removes that reservation
  only after durable lease write; failures/abort/restart retain it for exact
  cleanup. Stale callbacks must not disable a newer activation. Serialize driver
  reviews, allow local Stop/sign-out to invalidate in-flight review, and attach
  the deployed v2 revision RPCs with owner/freshness checks after awaits. Keep
  activation controls and sender dormant; no hosted activation/send is approved
  by this unit. Require race/failure/restart/wire tests, full Flutter/native
  suites, analysis/lint/build, isolated physical proof and data-preserving updates.
  - [x] Implement and locally/device-validate durable proposals and the v2 client.
    The existing schema-1 encrypted journal reserves exact IDs before capability
    return. Durable lease commit clears the reservation; failed writes/confirmation,
    lost replies, abort and restart retain exact cleanup. Expiry does not evict it.
    Stale exact abort preserves newer authority. Account review serialization and
    a process-local invalidation generation reject Stop/sign-out/account races;
    consent freshness is checked after awaits. The v2 adapter preserves bigint as
    decimal text and guards owner before/after every request. Startup/status add
    no revision request. Four new native and eleven new Flutter cases (including
    one loopback SDK wire test) bring totals to 398 native/362 Flutter, all passing.
    Analysis, app lint, configured build, repository validation and the isolated
    physical Keystore proof pass, including reopen-before-commit, coordinator
    restart and original late-commit rejection after exact cleanup. Updated normal
    apps preserve saved sign-in/pairing, report driver monitoring off and retain
    all 11,857 Tecno recorder hashes plus both encrypted receiver vault hashes;
    Pixel has no recorder files. Stale Pixel ADB recovered via a non-wiping AVD
    restart and renewed USB authorization; Tecno network reconnect/ping and both
    hosted read-only pairing reloads pass. The disposable test APK/key/files are
    removed. Both hosted enable digests freshly match `false`. No new migration,
    provider/dependency, registration, real hosted driver session, send or trip
    upload. Reviewed source `a3bde81` is committed/pushed, with local HEAD verified
    equal to origin/main. Full exact-source CI 38926552436 passes all three jobs,
    including Android debug/release builds and artifact gates, closing this
    bounded unit. Reviewed UI/sender, live timeout/replacement cleanup and active
    physical reliability remain gates.
  Next bounded unit: add debug-only driver review/Stop controls behind a separate
  default-false pilot flag. Require a fresh explicit review and an idle-recorder
  preflight; Stop remains available during activation and does not stop recording.
  Background/navigation/account changes cancel only their own in-flight review,
  suppress late success and retain exact cleanup through the v2 service. Report
  saved consent separately from observed monitoring and explicitly disclose that
  sending is unavailable. No event-cancellation claim, sender, real activation,
  production enable, migration or new dependency belongs to this unit. Test
  default-off startup, consent cancellation, lifecycle/account races, Stop during
  activation, failure/redaction and accessible layouts; run the full Flutter,
  analysis/build/CI gates and default-off data-preserving device checks.
  - [x] Implement and locally/device-validate the gated driver review/Stop UI.
    A separate debug-only `TRAELYX_GUARDIAN_DRIVER_PILOT` defaults false;
    ordinary/release and installed builds hide the controls. Explicit review
    preflights recorder idle state before the dialog and again before activation.
    It discloses the temporary account session/local lease, bounded duration,
    restart requirements and unavailable sending. Stop stays usable during
    activation and changes only Guardian authority. Per-review single-use
    cancellation remains effective through native commit until synchronous
    foreground acceptance; memoized exact cleanup handles interruption without
    late success or cancellation of a newer review. After acceptance, ordinary
    backgrounding does not revoke completed consent. All 376 Flutter tests pass
    (14 new control/lifecycle/service cases), analysis is clean, and repository
    validation plus the explicitly pilot-off configured build pass. Existing
    consent assertions are retained with real scroll-to-visible interactions for
    the expanded disclosure. No Kotlin/sensor/acquisition code changed.
    Both default-off updates preserve saved sign-in, pairing and local receiver
    registration, report driver monitoring off and hide Review/Stop controls.
    All 11,857 Tecno recorder hashes and both receiver vault hashes remain exact;
    Pixel has no recorder files and both driver vaults are absent. Pixel boots
    without wiping saved data; both network pings pass. A recurring Android Fast
    Pair popup covered Tecno briefly; the maintainer cleared it and final checks
    passed. Supabase routine GitHub sign-in resumed without a new credential or
    grant; both hosted enable digests freshly match `false`. No live driver
    session, registration, send, trip upload, migration, dependency or permission
    change occurred. Source `14ce8af` is committed/pushed with HEAD verified
    equal to origin/main. Full exact-source CI 39012717528 passes all three jobs,
    including native suites, debug/release builds, server policies and artifacts,
    closing this bounded unit. Minimized sending, event-cancellation UI, live
    pilot activation/revoke and active physical reliability remain gates.
  Next bounded unit: implement the dormant minimized-ingest HTTPS adapter before
  runtime scheduling/cancellation notification integration. Accept only an existing
  reserved attempt, serialize exactly the current capability ingest allowlist and
  validate the fixed project HTTPS endpoint before constructing any request.
  Keep response parsing bounded, exact and duplicate-key rejecting; backend
  acceptance must name this event and cannot imply receipt/display. Treat
  authorization denial separately from retryable/unconfirmed results. Reuse the
  unchanged 128-byte bounded no-redirect transport;
  clear request bytes on every outcome. No runtime caller, scheduling, network
  request, event UI, migration, dependency or live activation belongs to this
  prerequisite. Validate malformed/mismatched authority, redaction, strict wire
  contracts, retries/denials, buffer cleanup and transport limits using synthetic
  native tests; require native suites/lint/build, repository checks and exact-source
  CI before connecting runtime dispatch. Physical network/lifecycle behavior
  remains an explicit later gate.
  - [x] Implement and locally validate the dormant ingest adapter: fixed HTTPS
    endpoint, exact owner/capability plus six-field envelope, reservation/binding/
    clock guards and strict 128-byte current-event acceptance parsing. Explicit
    duplicate replies follow both deployed response forms; 401/403 are separate
    denial, with failures/rate limits/other statuses unconfirmed. Mutable request
    bytes are zeroed on success, loss and exception. Eleven new synthetic native
    cases cover the wire allowlist, malformed/duplicate response fields, endpoint
    confusion, invalid authority/clocks, durable cancellation/write failure,
    reopened retries and stale acceptance after revoke/replacement. All 409 app
    native tests have zero failures/errors/skips; dependency suites, debug APK and
    app lint pass. The documented local.properties escaping/cache fix was used
    for lint and exact original ignored bytes restored. No runtime caller, timer,
    acquisition change, migration, dependency, device update, activation, enable
    change, production request, send or trip upload. Source `ba4df40` is committed/
    pushed with HEAD verified equal to origin/main. Full exact-source CI
    39014126703 passes all three jobs, including native suites, both APK builds,
    server policies and artifacts, closing this dormant prerequisite. Runtime
    scheduling/cancellation UI and live/physical gates stay open.
  Next bounded unit: implement a dormant serialized dispatch coordinator and
  bounded separate network worker. Reserve in the existing encrypted outbox
  before handoff, require current bound authority and an explicit cancellation-
  affordance gate, invalidate queued permits before Stop/account/activation
  changes, and marshal every completion back to the control worker. Permit only
  one unsettled network operation; a local deadline ignores late acceptance but
  retains the busy slot until actual worker completion, preventing retry/thread
  buildup if transport stalls. Preserve durable retry identity/backoff and exact
  pre-reservation cancellation without claiming retraction after reservation.
  Add no Android runtime caller, timer, recorder change, live network request,
  migration, dependency or permission. Test control/network separation, queued
  invalidation, callback races, deadlines, stuck workers, retry/cancel/replacement,
  failed persistence/submission and shutdown. Require native suites, app lint,
  debug build, repository validation and exact-source CI. Runtime notification/
  cancellation controls, scheduling, reviewed live activation and physical
  reliability remain later gates.
  - [x] Implement and locally validate dormant dispatch coordination: one
    unsettled operation, persisted reservation before separate network submission,
    exact cancellation before reservation, per-event handoff gate, one-use queued
    permit and control-worker completion marshalling. The local ten-second
    deadline rejects delayed handoff and ignores late acceptance, retaining the
    busy slot until actual transport completion. Existing retry identity/backoff
    and six-attempt cap remain unchanged. Twenty new synthetic coordinator/worker
    cases cover timing, owner/lease replacement, cancellation, stale/duplicate/
    inline callbacks, persistence/submit failure, shutdown and executor bounds.
    All 429 native app tests have zero failures/errors/skips; dependency suites,
    app lint and debug build pass. The documented temporary local.properties
    escaping fix was used for lint and exact original ignored bytes restored.
    ADR-0031 records worker isolation and the local-deadline limitation. Pixel_10
    restarted without wiping saved data; saved sign-in, read-only pairing reload
    and local recipient receipt remain present. Both devices pass ping and
    report local driver monitoring off with controls hidden. No app update,
    recorder/service hook, schema, permission, dependency, activation, enable
    change, ingest/dispatch request or trip upload. Source `3184303` is committed/
    pushed with HEAD verified equal to origin/main. Full exact-source CI
    39034069372 passes all three jobs, including both APKs, native/Flutter tests,
    server policies and artifacts, closing this bounded unit. Before Android
    attachment, validate exact cleanup-ID retention through destructive vault-write
    failures (repair and validation below); a dispatch failure flag does not prove hosted revocation. Android
    scheduling/cancellation UI, reviewed live activation and physical reliability
    remain separate gates.
  - [x] Reproduce and locally repair exact cleanup-ID loss through destructive
    vault writes. The authenticated-encryption regression fails before repair:
    commit cleared the reservation, then failed enqueue destroyed the sole lease
    identity. Commit now retains its independent ID-only reservation throughout
    the lease; outbox writes/replacement journal affected IDs before destructive
    mutation, and binding adopts readable legacy leases before exposing authority.
    Active tickets cannot be confirmed; explicit Stop/server-revoke confirmation
    alone clears them. Journal uncertainty/capacity denies mutation without
    discarding prior tickets/authority. Nine new native encrypted-store tests
    cover write/readback failure across enqueue/reservation/cancellation/recovery/
    completion/replacement, idempotence, legacy adoption, restart, exact-owner
    isolation and failed cleanup confirmation. A new foreground test verifies
    offline server-revoke retry after local vault authority loss. Existing tests
    now assert lifetime retention instead of removal at commit. All 438 native
    app and 377 Flutter tests, dependency suites, app lint and debug APK pass;
    the documented lint-only local.properties normalization restores exact ignored
    bytes. ADR-0030, the delivery contract and the new product issue record define
    guarantees and loss-of-both-stores/legacy-unreadable limitations. The configured
    pilot-off Tecno update and isolated physical Keystore proof pass: the lifetime
    ticket survives scoped capability key/file loss and reopening, active exact
    confirmation is refused, and synthetic Stop/confirmation clears only its
    ticket. All 11,857 recorder hashes and the recipient vault remain unchanged;
    ordinary app startup retains sign-in with controls hidden. Pixel remains
    connected/authorized; it was not updated in this unit. No recorder sample,
    permission, schema, dependency, hosted activation, enable change, production
    request or trip upload. Physical Keystore/disk-failure injection
    and hosted live Stop are unverified. Source `6e4b50d` is committed/pushed with
    HEAD verified equal to origin/main. Full exact-source CI 39036370579 passes
    all three jobs, including both APKs, native/Flutter checks, server policies
    and artifacts, closing this bounded unit. Next: cancellation controls/notification and
    eligibility proof, then Android runtime dispatch attachment.
  Next bounded unit: implement account/exact-event cancellation controls and a
  private generic Android cancellation notification without attaching ingest or
  dispatch. A fresh in-process driver lease must back every control. Require an
  observed active notification followed by a full 30-second monotonic and wall
  clock window before handoff eligibility; event age alone is insufficient.
  Keep eligibility ephemeral and bounded to the 16-event outbox: process restart
  restores no proof and cannot resume evaluation under ADR-0029. Failed/blocked
  notification, clock uncertainty, owner/Stop/replacement and terminal events
  deny eligibility. A non-exported immutable notification action and explicit
  pilot-only local UI check/cancel must recheck the exact owner/activation/event
  and persist cancellation before reporting success. Never claim retraction
  after reservation. Preserve raw acquisition, current permission flows and
  the default-off driver pilot; add no network request, backend enable, schema
  or dependency. Require synthetic native/bridge/Flutter/widget race/failure
  tests, lint/build/analysis, isolated physical notification-action proof and
  preservation checks, plus exact-source full CI before bounded closure.
  - [x] Implement and locally validate cancellation controls and observed offers:
    strict owner/exact-event foreground metadata and mutation, pilot-only check/
    cancel UI, review disclosure and a generic private local Android notification.
    Its immutable explicit action targets a non-exported receiver on the existing
    serialized worker. First reservation closes cancellation; persistence precedes
    success. Bounded in-memory proof starts after observing the exact notice and
    requires 30 seconds on both clocks; dismissal/permission loss during the
    unfinished window denies proof without reposting. A direct reservation cannot
    manufacture maturity; restart restores no proof. ADR-0032 records this contract
    and the older-Android stale-notice limitation. Nineteen new control tests and
    two bridge tests cover timing, authority, failed persistence/notification,
    cancellation/retry, restart/expiry/rollback, bounded state and wire isolation.
    Seven new Flutter tests cover strict parsing, explicit operations, lifecycle/
    owner races, denial/error wording and large text. All 459 native app and 384
    Flutter tests, analysis, app lint, configured debug/test builds and repository
    validation pass. The documented lint normalization restores exact ignored
    local.properties bytes. The isolated Tecno proof passes generic private notice,
    immutable/private action, unbound production-receiver denial, a real full
    30-second window, scoped durable cancellation and exact notice cleanup, with
    Firebase inactive and no hosted call. All 11,857 recorder hashes and the
    real receiver vault are unchanged; ordinary startup retains sign-in with
    pilot controls hidden. No schema, dependency, permission request, sampling/
    wake change, added polling timer, hosted activation, enable change, ingest/
    dispatch request or trip upload. Source `8d346aa` is committed/pushed with
    HEAD verified equal to origin/main. Full exact-source CI 39039569866 passes
    all three jobs, including both APKs, native/Flutter checks, server policies
    and artifacts, closing this bounded unit. Accepted action under a live driver lease, active recording
    and physical/two-account reliability remain separate gates. Next attach
    serialized dispatch scheduling using offer maturity and retry timing, with
    permit invalidation before owner/Stop and separate bounded network IO;
    renewed sending consent and reviewed live activation remain required.
  Completed bounded unit (2026-10-17): attach a serialized one-shot dispatch host
  to cancellation readiness, retry/deadline completion and pending-event expiry.
  Observe asynchronous notices for a bounded interval and continue the full
  cancellation window independently of the recorder watchdog after trip end.
  Invalidate permits before relevant authority changes; stale old aborts must
  preserve newer work. Keep one unsettled network job across authority changes.
  Sending remains unconditionally unavailable in the Android host: do not reuse
  the existing sending-unavailable consent as transmission authorization, create
  a network worker while disabled, activate a hosted lease or change enable flags.
  Validate timing, no-work idleness, failures, retries, lifecycle/authority races
  and default-disabled behavior with injected clocks/schedulers/ports; require
  native suites, lint/configured builds, inactive device preservation and full
  exact-source CI. No schema, dependency, permission or acquisition change.
  Renewed consent and reviewed live-device network/lifecycle gates remain open.
  - [x] Implement and locally validate the disabled Android scheduling host:
    one cancellable generation-fenced wake combines offer observation/maturity,
    retry/deadline and earliest dual-clock event/lease expiry after trip end.
    Asynchronous notice confirmation has three seconds of automatic checks;
    unfinished observed offers are checked at most once per second. Blocked or
    dismissed proof waits for expiry rather than polling. No idle timer, OS alarm,
    wake lock or acquisition change. Stop/account/current-activation mutations
    invalidate permits first; pure identity checks preserve newer authority on a
    stale abort. The process-scoped dispatcher retains one unsettled job across
    replacement and a local deadline. Network completion returns to the control
    worker and refreshes the schedule. The Android sending gate is fixed false,
    with no build-flag bypass or network worker/reservation while disabled.
    Eighteen new scheduler tests and one pure authority-identity test pass; all
    478 native app/384 Flutter tests, dependency tests, analysis, app lint,
    configured debug/test builds, format and repository validation pass. A local
    check-only formatting discrepancy was line-ending-only (no Git source diff)
    and the repeated full check passes. The isolated Tecno proof uses real Android
    notifications, clocks, a separate serialized scheduler and scoped encrypted
    storage: the full offer window completes with no recorder/watchdog, disabled
    mode constructs no runner, then one injected synthetic reservation/fake
    completion passes with exact scoped cleanup and Firebase inactive. No network
    transport or hosted credential is used. All 11,857 recorder hashes and the
    real receiver vault match the fresh pre-update snapshot; ordinary pilot-off
    startup retains sign-in, with no production driver vault. No dependency,
    schema, permission request, enable change, hosted activation or trip upload.
  - [x] Source `a343fae` passes full exact-source CI 39041962086, including all
    three jobs, both APKs, native/Flutter checks, server policies and artifacts.
    Resume audit (2026-10-18): Tecno and cold-booted Pixel are authorized, online,
    idle and retain saved sign-in. No data reset or account replacement. A pending
    executor cleanup remained uncommitted at interruption: use remove-on-cancel
    so repeated expiry-wake replacement cannot retain cancelled tasks until old
    deadlines. The new actual-worker queue regression fails with the former
    policy and detects retained entries; restore the fix before final checks.
  - [x] Final queue cleanup passes the actual-worker regression: 500 cancelled
    ten-minute wakes leave no queued entries. All 479 native app tests and
    dependency suites pass, with app lint and configured pilot-off debug/test
    builds. Format/repository validation pass. The final isolated Tecno scheduler
    proof passes again with a fake transport and no hosted activation/ingest;
    all 11,857 recorder hashes and the receiver vault match the new resume
    baseline, with no production driver vault. Existing Flutter source is
    unchanged from the base's 384 passing tests and full CI.
  - [x] Source `a23601f` passes full exact-source CI 39140377015: all three jobs,
    479 native app/384 Flutter tests, server-policy suites, debug/release APKs,
    repository/size checks and artifacts. This closes the bounded disabled
    scheduler integration and queue cleanup. No sending gate, production enable,
    account authority or wire contract changed during the final queue fix.
    Renewed sending consent and
    reviewed hosted activation/Stop, accepted live cancellation action, active
    recording and physical/two-account reliability remain separate gates.
  Completed bounded unit (2026-10-18): add a versioned, fresh, explicit sending
  acknowledgement behind a separate default-false debug pilot. Existing reviews
  remain evaluation-only. Bind new sending permission to the exact in-process
  proposal/committed activation; clear it on Stop, owner loss, replacement,
  failure or restart. Release builds must deny the sending bridge, and ordinary
  configured builds keep both driver/sending pilots false. Disclose providers,
  minimized sharing, the observed cancellation window, irreversible handoff and
  delivery limits. Preserve exact cleanup/revision fencing and lifecycle review
  cancellation. Require strict bridge/wire/version/freshness tests, old-review
  compatibility, failure/owner/Stop races, widget/large-text tests, native/Flutter
  checks, lint/configured build, inactive device preservation and exact-source CI.
  No live activation, backend enable, alert send, registration, migration,
  dependency or trip upload is authorized by this source unit. The later reviewed
  hosted window and user's actual on-device consent remain separate gates.
  - [x] Version-1 sending review adds a separate unchecked acknowledgement and
    provider/cancellation/handoff disclosure. Both debug pilot flags default
    false. The old version-0 review stays evaluation-only even when the sending
    pilot is available. Service/controller validation rejects unavailable,
    stale/future and inconsistent/unknown-version reviews before side effects.
    The strict `beginSending` native method requires the new acknowledgement
    and a debuggable package; old `begin` and all persistence/wire schemas stay
    unchanged. Permission binds only the exact proposal and successful fresh
    activation, with current lease validation. Stop, owner loss, restart,
    expiry/reboot, missing vault and failed commit deny sending. Five new native
    tests and six Flutter tests cover denial/compatibility, wire allowlisting,
    exact lifecycle cleanup and large-text unchecked review. An expiry regression
    caught a null/null comparison while recovery cleared IDs; capturing the
    non-null activation before recovery repairs it without weakening assertions.
    All 484 native app/390 Flutter tests, dependency suites, analysis, app lint,
    configured pilot-off debug/test builds, format and repository checks pass.
    ADR-0033 records the contract. No live activation or sending occurred.
  - [x] Isolated Tecno proof uses scoped encrypted stores and a synthetic owner:
    old/unavailable reviews deny sending, the new exact review grants in-memory
    permission only after commit, a reopened coordinator denies it, and Stop
    preserves exact cleanup while removing authority. No real hosted session,
    evaluator, scheduler, transport or Firebase initialization. All 11,857
    recorder hashes and the receiver vault match the fresh pre-update snapshot;
    production driver vault remains absent. Installed build keeps both pilots off.
    Normal startup retains saved sign-in and hides driver controls.
  - [x] Source `9835ad4` passes full exact-source CI 39147698943: all three jobs,
    debug/release APKs, 484 native app/390 Flutter tests, server policies,
    repository/size checks and artifacts. This closes the bounded default-off
    sending-review unit. Separately reviewed live activation/Stop and actual
    on-device consent remain required; no real driver session was created.
  Prepared live gate (approved and attempted 2026-10-18; mounted prerequisite
  remains unverified): source `9835ad4` has a
  compiled controlled debug APK with both pilots enabled, stored only in ignored
  local state; the ordinary pilot-off APK is preserved separately. Read-only
  hosted readiness on 2026-10-18 confirms both
  enable digests equal `false`, zero driver sessions/events/deliveries and two
  unexpired receiver registrations. The proposed test permits one real Tecno
  activation/Stop cycle while idle, using its existing signed-in account and
  fresh on-device review. A private driver session/capability lasts at most eight
  hours until exact Stop; revision-fence metadata remains after revocation.
  Verify aggregate sessions 0 → 1 → 0, local fresh authority then no lease/ticket,
  and unchanged zero events/deliveries and receiver registrations. Do not start a
  recording or change either backend flag. No ingest, FCM, notification or trip
  upload. On uncertainty, retry exact Stop from the retained journal before
  proceeding; do not assume revocation. Restore the ordinary APK without clearing
  app data and verify preserved sign-in/recorder/receiver state. Explicit M6.8
  production review and the user's actual new consent precede this live gate.
  - [x] After explicit production approval, update-installed the exact pilot
    without clearing data. All four acknowledgements alone left Confirm disabled
    until the user selected the required forward direction. The user confirmed;
    aggregate hosted counts changed from 0/0/0/2/2 to 1/0/0/2/2 (sessions,
    events, deliveries, devices, unexpired devices).
  - [x] The user then clarified that the phone was resting on a room table.
    The rigid vehicle-mount prerequisite was therefore not met. Immediately
    used the approved Stop path rather than recording or evaluating. The app
    reports Stop completed and explicit local check says monitoring off;
    hosted counts return to 0/0/0/2/2 and the driver lease vault is absent.
    The retained encrypted revoke journal is 37 bytes, matching the versioned
    empty journal encoding (8 plaintext bytes plus 29 cipher framing bytes).
    This is session creation/revocation evidence only; do not close mounted
    consent, calibration, cancellation, driving or delivery validation from it.
  - [x] Restored ordinary source `9835ad4` APK with both pilots off. Normal
    startup retains saved sign-in and hides driver controls. All 11,857 recorder
    hashes and the receiver vault match the pre-test baseline. No recording,
    backend enable change, event, dispatch/FCM, registration or trip upload.
    Source CI 39147698943 remains the validation for unchanged implementation;
    this record adds only live observations. A correctly mounted review and
    separately reviewed driving/reliability tests remain pending.
  User deferral (2026-10-19): defer the correctly mounted vehicle review and
  driving/performance checks until the maintainer is ready. Keep them open as
  acceptance gates; desk simulation cannot replace sensor or road validation.
  - [ ] Deferred maintainer task: while parked, rigidly mount the phone in the
    vehicle, choose its actual forward direction and complete a fresh review.
    Resume only when ready; do not acknowledge a vehicle mount on a table.
    Active driving/calibration/performance checks follow their own reviewed
    scope; do not perform dangerous maneuvers or physical impact tests.
  Completed bounded desk-safe unit: connect the existing versioned activation bridge,
  recording-session callback, cancellation controls and scheduler in a synthetic
  native integration harness. Inject only generated detections, in-memory
  persistence, virtual clocks/notices and a fake ingest runner. Verify old
  consent never constructs transport, fresh sending consent waits the full
  observed cancellation window, cancellation persists without reservation,
  Stop blocks queued handoff/late evidence, and restart cannot reuse sending
  permission or resume evaluation. No production code, phone/account state,
  backend enable, network request, raw recording, dependency or schema change.
  Require the targeted integration tests, all native suites, repository checks
  and exact-source CI. This does not close any deferred physical gate.
  - [x] Five integration tests join the production versioned bridge, fresh
    activation coordinator, recording-session callback, outbox, foreground
    cancellation and scheduler. Old reviews enqueue without transport or
    reservation; new review waits the full observed 30 seconds even after the
    recording handle ends. Cancellation persists with zero attempts. Stop
    rejects queued handoff, late detection and late acceptance. A reopened
    coordinator retains cleanup evidence but cannot evaluate, notify or send.
    All 489 native app tests and dependency suites pass with zero app failures,
    errors or skips; repository validation and whitespace checks pass. Only test
    and progress-document files changed. No phone or production operation.
  - [x] Source `cd00629` passes full exact-source CI 39293105212: all three jobs,
    Flutter/native tests, debug/release APKs, cloud SQL/RLS and Edge suites,
    repository/size checks and artifacts. This closes only synthetic integration
    coverage; the deferred mounted/vehicle and remaining M6.8 reliability gates
    remain open. No phone or production changes occurred during this unit.
  Completed bounded UI clarity unit (2026-10-19): address the observed disabled-Confirm
  confusion without relaxing consent. Show the next required choice beside the
  dialog actions, keep Cancel usable at large text, and explicitly distinguish
  a parked rigid vehicle mount from a phone on a desk. Keep status/pairing copy
  consistent with the default-off sending pilot, without inferring backend
  availability or successful delivery. No acknowledgement defaults, authority,
  wire/schema, permission, provider or backend change. Require regression of all
  acknowledgements selected with direction still missing, large-text navigation,
  pilot/default copy and no automatic status/network calls, Flutter suites,
  analysis, configured build, repository checks and exact-source CI. The deferred
  vehicle gate remains open; no live activation or phone review is needed here.
  - [x] Disabled Confirm now shows the next required choice with a live-region
    explanation beside the actions, including the observed all-boxes/no-direction
    case. Explicit copy says a table is not a rigid vehicle mount. Default and
    sending-pilot status/pairing wording stay distinct; neither a local check nor
    pairing claims backend readiness or delivery. No choice is waived or filled.
    Five new widget regressions and existing large-text/consent tests pass; all
    395 Flutter tests, analysis, configured pilot-off debug build and repository
    checks pass. No native contract, network behavior, migration, permission or
    dependency changes; no device update, live review or production operation.
  - [x] Source `37906dc` passes full exact-source CI 39296488417: all three jobs,
    395 Flutter tests, native suites, debug/release APKs, cloud SQL/RLS and Edge
    suites, repository/size checks and artifacts. This closes the bounded UI
    correction only. The build was not installed on either device; real-device
    rendering is unverified for this correction. Mounted vehicle and remaining
    M6.8 active-device/delivery gates remain open. No production change.
  Completed bounded preparation (2026-10-21): verify the existing Tecno/Pixel pair
  and prepare one synthetic backend delivery/inbox window without native driver
  activation or a drive. Keep the mounted/vehicle gate deferred. Reuse the sole
  existing active directional relationship and its current possible-crash-only
  permission; create no profile, account, connection or device. Prepare guarded
  admin SQL for only one eight-minute test session, generated event and delivery
  (fixture 1001–1003), using no usable retained driver credential. Select the
  single guardian device without exposing its routing/receipt token. Refuse
  nonempty queues, multiple pairs/devices, permission changes and ID collisions.
  Exact-lineage cleanup must preserve profiles, pairing, registrations, revision
  metadata and any newer replacement session. Verify these guards, one-claim
  dispatch, two authenticated inbox roles and recipient-only viewing in disposable
  PostgreSQL CI before requesting production review. Existing bounded worker and
  processing-window contracts remain unchanged. No hosted staging, enablement,
  worker credential or send is authorized by preparation.
  - [x] Pixel_10 restarted with saved data; both devices authorized, signed in,
    network validated and recorders inactive. Update-installed ordinary source
    `37906dc` without clearing data. All 11,857 Tecno recorder hashes, zero Pixel
    recorder files and both receiver vaults match fresh private baselines; both
    driver vaults are absent. Explicit read-only pairing reloads show Paired on
    both. Dashboard enable digests remain false; aggregate sessions/events/
    deliveries/devices/unexpired/pairs/ready-receiver-pairs are 0/0/0/2/2/1/1.
  - [x] Prepared fixture/cleanup, disposable SQL guard/inbox regressions and
    `GUARDIAN_TWO_ACCOUNT_CHECK.md`, with no production execution. Local Docker
    was not running; no service was started/repaired. Use existing disposable
    PostgreSQL 17 CI for executable SQL validation before production review.
    Initial CI 39481928913 caught a missing profile for the synthetic third
    account in the multiple-pair negative test. Add that required test profile
    and teardown; keep all rejection/preservation assertions. No production
    fixture or access setting was changed.
  - [x] Source `8ad6be0` passes full exact-source CI 39482359166: all three jobs,
    fourteen SQL suites plus revision upgrade, Flutter/native suites, debug/
    release APKs, repository/size checks and artifacts. The new suite proves
    refusal guards, one claim/guardian target, both authenticated inbox roles,
    recipient-only viewing and exact cleanup/preservation. Notification permission
    and provider markers are present on both devices; the read-only current-pair
    permission check returns true. No retained test worker file exists.
    Persist preparation, then request concrete production review. No hosted
    fixture, worker rotation, enablement, mobile activation or push occurred.
  - [x] Reviewed live two-account check and exact cleanup passed (2026-10-21).
    Saved Pixel restart/ADB reauthorization retained the guardian account and
    registration. Stage 1001–1003 returned ready/pending/two-devices true; fresh
    queue/window headroom exceeded 300 seconds. One invocation processed=1,
    provider_accepted=1, all other counters zero; Pixel received one generic
    notice and hosted attempts=1/device_received. Both flags closed at 01:19:05
    IST, about 30 seconds after provider acceptance, inside the six-minute
    server lease. Actual notice tap retained Guardian's scroll; after bringing
    the inbox into view it was unloaded. Explicit reads showed the Pixel's
    incoming/Open action and Tecno's outgoing-only row. Pixel Open displayed
    details; Tecno reload and hosted status became viewed, still attempts=1.
    Worker retirement digest, old-value 401, local deletion, disabled probes and
    approved lineage cleanup passed. Final counts 0/0/0/2/2/1/1; both inboxes
    empty after explicit reload. All 11,857 Tecno recorder hashes and its receiver
    vault match; Pixel has zero trip files, and both driver vaults are absent.
    The generic comparison flagged Pixel receiver ciphertext inequality:
    successful claimNotice intentionally persists noticeDeliveryIds in that
    encrypted file. Retain the original comparison, verify owner-bound local
    registration, and correct the check procedure rather than restoring old
    ciphertext or claiming byte equality. Existing vault preservation/restart
    tests cover this contract. No new runtime/schema/dependency, native mobile
    activation, registration, permission, recording or trip upload. This closes
    only the synthetic two-account delivery/inbox gate; mounted/native-active,
    performance and physical reliability validation remain deferred/open.
    See `GUARDIAN_TWO_ACCOUNT_CHECK.md`; no M6.8 completion or M7 activation.
  Next bounded unit: expose credential-free, account-checked local driver status
  through a new native method and an explicit foreground check. Distinguish
  restored consent requiring reactivation from waiting for a trip, calibration,
  experimental evaluation and unavailable evidence. Display the check time and
  clear status on background/account change; never infer delivery from a lease.
  Explain process-death reactivation in the dormant consent review. No activation
  control, sender, network request, timer, migration or permission change. Require
  strict wire/owner/restart/failure tests, Flutter/native checks, configured build,
  inactive physical screen proof and exact-source CI before bounded closure.
  - [x] New account-checked `driverStatus` bridge returns only state/expiry. The
    local-only foreground panel requires a tap, labels its last-check time and
    clears on background/account changes. No activation, polling, sender or Auth
    request is added. Dormant driver consent explains process-death reactivation.
  - [x] Six new Flutter status/wire/timeout/lifecycle checks and four native
    owner/restart/expiry/state checks pass. All 340 Flutter and 375 app native tests
    plus dependency suites pass; analysis, app lint and configured debug build
    pass. A pairing test now waits for scroll geometry to settle after preview
    removal, retaining every acceptance/confirmation assertion. Document the
    Java-21/all-native and app-target-lint host commands without new permissions
    or plugin/test suppression.
  - [x] First phone update opens; local check reports monitoring off plus check
    time. Home/resume clears that observation without an automatic recheck. You
    remains signed in; all 11,857 recorder hashes and recipient vault match, and
    driver vault stays absent. Private preservation/QA artifacts are ignored.
    No activation, recording, registration, network request or trip upload.
  - [x] Exact diff inspected, source committed/pushed as `dae26e7`; full
    exact-source CI 38135386431 passes all three jobs. Persist bounded closure;
    active-device and overall M6.8 gates remain open.
  Next bounded setup: the maintainer selected Tecno Pova 5 Pro plus the existing
  Pixel_10 emulator after Redmi Note 9 blocked USB installation/input behind
  Xiaomi account/SIM checks. Use the Google Play emulator for account/pairing
  setup; do not count it as physical-device reliability evidence. Install the
  configured normal app without data clearing and request email-link sign-in with
  a different account. Establish a private profile and reviewed two-sided Guardian
  pairing before driver activation. Keep both production functions disabled;
  recipient registration requires its own in-app consent, and no real alert is sent.
  - [x] Pixel_10 API-37 Google Play emulator boots, accepts ADB input and installs
    the tested configured recipient-pilot APK. Account opens normally; no
    recorder service or driver vault exists. Google OAuth is not implemented;
    the maintainer opened the new email link inside the emulator. Private
    UI observations emit only allowlisted labels, never email/link contents.
  - [x] Both Account screens signed in, and an in-memory comparison confirmed
    different account emails without outputting or storing either address. Pixel
    saved a private profile with zero queued changes; no vehicle or trip data was
    entered on the emulator.
  - [x] One single-use Guardian invite was accepted on Pixel and confirmed on
    Tecno. Both screens still show `Paired. Delivery not available yet.` after
    explicit reload. Possible-crash preference alone is on; location, speed and
    trip history remain off. Tecno sign-in and existing local trips were preserved;
    no recorder service was active during setup.
  - [x] Pixel's first recipient review failed with Android notification permission
    off. The Guardian flow now requests the existing OS permission after explicit
    review, stops before token acquisition on denial and offers app settings for
    a settings-required state. All 341 Flutter tests, analysis, repository
    validation, configured debug build and data-preserving Pixel update pass. The
    maintainer repeated both acknowledgements and allowed the Android prompt;
    Pixel shows local registration. Read-only hosted SQL reports two device rows,
    both unexpired. No token values were read; both production enable secret
    digests match SHA-256 of `false` after the power outage.
    This establishes emulator receiver setup, not physical push reliability.
  Preparation is concrete in `GUARDIAN_REJECTION_CHECK.md`: at most four sends
  across fresh 741–745/751–755/761–765 fixtures. Exact-marker requeue, expiry and
  guarded disconnect controls plus disposable SQL regression suite are wired
  into CI; corrected full run 37646111095 (`6734a3b`) passes every job and twelve
  SQL suites. Nine UUID-only copies reverse-verify; the bounded
  offline-hold/independent-restore helper parses without execution. The reviewed
  duplicate first phase passed one acceptance/receipt and actual notice tap to
  unloaded Guardian, attempts=1/device_received (not viewed). Its event expired
  before requeue; no second send or lifetime extension occurred. Both functions
  closed at 16:07:27 UTC, worker retired at 16:20:13 with digest/401/local-file
  proof, and approved cleanup passes with final counts 0/1/1/0/0. Network 1/0/0,
  no recorder, unchanged encrypted vault hash and zero notice records pass.
  Actual duplicate suppression remains unverified. Review fresh IDs and a
  contiguous two-send window within the existing event lifetime, preserving
  durable claims; expiry/disconnect remain gated on review/callback evidence.
- [x] Prepare and validate data-free debug receiver observability after the 771–775 repeat.
  That reviewed window enabled both flags at 16:31:55 UTC on 2026-10-07 and
  closed them at 16:34:52. One provider acceptance/hosted receipt passed, but two
  Android checks found zero notices and the encrypted vault hash was unchanged.
  Notification permission/channel checks did not show a block. No requeue or
  second send occurred; notice absence has no confirmed cause. Worker rotation
  at 16:43:25 was verified after the usage-limit interruption on 2026-10-08:
  digest/old-value 401/local deletion and approved fixture cleanup pass, final
  0/1/1/0/0. Fixed enum-only debug tracing identifies callback and stopping gates
  without IDs/credentials/payloads/exceptions, extra requests or app persistence.
  It is inert in non-debuggable builds and sink failure cannot change decisions.
  All 357 native tests, Android lint and configured debug build pass. Physical
  data-preserving startup keeps signed-in Guardian, encrypted registration hash,
  unloaded details and no crash/receiver trace; phone network 1/0/0, no recorder.
  Full source CI 37803704159 (`4aecd2e`) passes every job, including twelve SQL
  suites, Flutter/native checks and debug/release builds. The installed build is
  debuggable; encrypted registration still matches after startup. Live callback
  diagnosis was separately reviewed below; no timeout
  or claim policy is changed without evidence. See `GUARDIAN_REJECTION_CHECK.md`.
- [x] Run the reviewed single-message receiver diagnostic 781–785.
  On 2026-10-08, after fresh phone/lifetime/process guards, the sole dispatch passed
  processed=1/provider_accepted=1. Scoped debug stages confirmed callback/receipt/
  claim/post attempt; Android showed one notice, encrypted vault changed, hosted
  attempts=1/device_received (not viewed) passed before manual app opening. Both
  flags enabled 16:11:35 UTC and closed 16:13:10, 56.07 seconds after the confirmed
  probe return. Actual notice tap opens signed-in Guardian and removes the notice.
  Disabled probes pass; worker retired 16:20:07 with matching digest/old-value 401/
  local deletion, and approved synthetic cleanup passes with the real device
  retained and final counts 0/1/1/0/0. Registration/consent marker/network 1/0/0/
  no-recorder checks pass.
  Prior absence did not reproduce; root cause/permanent fix remain unconfirmed.
  No second message, network toggle, upload, runtime or schema change in this test.
  Actual duplicate/expiry/disconnect, recorder and two-phone gates remain pending.
- [x] Close the incomplete traced duplicate window 791–795 and validate a bounded operator transition.
  On 2026-10-08 the first callback/receipt/claim/post, one Android notice and actual
  tap to unloaded Guardian passed. The unchanged requeue guard refused because
  the remaining event lifetime fell below its two-minute buffer; no second send,
  requeue or lifetime extension occurred. Both flags closed 16:49:18 UTC (5m21s).
  Worker rotation at 16:57:02 was verified after resumption on 2026-10-09 by changed
  digest/old-value 401/local deletion. Action-time-approved marker cleanup passes
  and hosted counts are 0/1/1/0/0. `tool/guardian_duplicate_phone.mjs` batches the
  first transition, retries only transient UI observation (three reads maximum),
  and separately checks duplicate refusal/no notice/unchanged vault. Twelve
  operator tests, syntax and physical read-only preflight pass. It performs no
  send or cloud mutation and changes no app contract. Live helper phases remain
  unverified; require source CI and a fresh reviewed pair. Keep actual duplicate
  acceptance unchecked and preserve all lifetime/claim/security limits.
  Full source CI 37944918981 (`16cf9a5`) passes every job, including twelve SQL
  suites, app/native tests and debug/release builds. Fresh ignored 801–805 copies
  reverse-verify as UUID-only changes. This was the pre-window checkpoint;
  the subsequently approved pair's incomplete outcome is recorded below.
- [x] Finish the aborted batched duplicate pair 801–805 closure and operator repair gates.
  Sole provider acceptance/positive native stages/one notice/hosted one-attempt
  receipt pass on 2026-10-09. Both flags enabled 14:50:48 UTC and closed 14:52:35
  after the operator phase failed; no requeue or second send. Worker retired at
  14:55:42, digest/401/local deletion verified. Windows CRLF output breaks the
  helper's LF-only notification header parser; normalization, CRLF regressions
  and fixed failure codes pass twelve operator tests/syntax. Actual parser reads
  the phone notice; later full-helper trace observations unavailable, so no live
  helper pass claimed. Manual existing notice tap after closure opens unloaded
  Guardian. Action-time-approved marker cleanup passes, final hosted counts
  0/1/1/0/0 and zero synthetic notices. Full repair source CI 37949413443
  (`77dd2c1`) passes all jobs. A fresh separate local operator-tag probe verifies
  Node/ADB timestamp observation. The subsequently approved 811–815 closure is
  recorded below.
  App/server behavior and security/lifetime limits are unchanged.
- [x] Close the corrected 811–815 pair and preserve its first live helper proof.
  On 2026-10-09, first callback/receipt/claim/post, actual tap to unloaded Guardian,
  durable vault baseline and non-force-stop background restart pass. Guarded
  requeue passes; second invocation refused because operator latency exhausted
  existing buffers. Hosted attempts remain one. Both flags closed at 15:38:30 UTC
  after enabling at 15:33:25. Worker retired at 15:46:58, digest/401/local deletion
  verified. Approved marker cleanup passes, final hosted counts 0/1/1/0/0.
  USB wake setting restored to 0 and physical read-only preflight passes.
- [x] Add a bounded operator-only pair bridge to remove model turnaround between
  requeue confirmation and second dispatch. Default Plan mode sends nothing;
  Run allows at most two non-retried invocations, a 45-second exact job gate and
  unchanged event/requeue/enable guards with a 45-second browser shutdown margin.
  Twenty-three local gate/quoting/Plan checks and twelve existing operator tests pass.
  No app/server/schema/dependency changes; live bridge remains unverified.
- [x] Verify bridge source CI before a fresh reviewed pair. Full run 37956582373
  (`223cc48`) passes all jobs: Edge functions, twelve SQL suites, operator checks,
  app/native tests and both APK builds. Fresh local 821–825 copies reverse-verify
  as UUID-only substitutions; no fixture/worker/enable window is active.
  Keep actual duplicate suppression pending until the second callback, refused claim, unchanged vault
  and zero recreated notices pass together. Fresh scope and action-time browser
  confirmations remain required.
- [x] Close unused bridge fixture 821–825 after approval-time expiry on 2026-10-09.
  Hosted pending/attempts=0/unclaimed/expired checks pass; no enable, requeue,
  send or bridge Run occurred. Worker retired 16:37:37 UTC, digest/401/local
  deletion verified. Approved marker cleanup returns three absence checks true
  and device_rows=1; final hosted counts 0/1/1/0/0. USB wake setting remains 0.
  Actual duplicate suppression remains pending. Prepare fresh scope/exact-enable
  review before starting the timed fixture; after approval, stage with both flags
  false, check hosted lifetime and apply the approved enable without another
  preparation gap. All existing lifetime and action-time approval gates remain.
- [x] Recover the interrupted 831–835 window on 2026-10-10. Both flags remained
  true after an approval-service usage rejection prevented dispatch launch; the
  six-minute limit was missed (20h53m54s). Close at 13:44:13 UTC; hosted zero
  attempts/unclaimed/expired proof, worker retirement 13:45:55 (digest/401/local
  deletion), approved cleanup and final counts 0/1/1/0/0 pass. USB wake remains 0.
  Real registration/profile/trips retained; no dispatch or requeue occurred.
- [x] Implement mandatory finite-window processing in both entrypoints and shared
  outbound transport gate (ADR-0028). All 35 local Node/Deno function tests,
  lint/type checks, two deployment-bundle tests, twelve operator tests and
  23 PowerShell checks pass. No
  migration, dependency, client payload, credential or permission grant added.
- [x] Verify expiry-repair source CI 38058389131 (`09089ac`): all jobs pass,
  including SQL/operator/app/native checks and both APK builds. Two dashboard
  drafts match their tested single-file bundles (line endings normalized).
- [x] Reviewed inert deployment completed on 2026-10-10 (verified by 14:26:52 UTC):
  both hosted single-file bundles match tested source, legacy JWT settings stay
  off, both flags remain false and processing-window config is absent. Empty
  credential-free checks return capability 503/dispatch 401. No send or app change.
- [x] Hosted expiry proof on 2026-10-10: window 14:53:21.191–14:56:21.191 UTC.
  Fixed invalid probes return 400 at 14:54:16/17, then capability/dispatch 503 at
  14:56:42/43 while both flags remain true. Flags restored false, test worker
  retired (digest/old 401/local deletion); expired window retained. No fixture,
  send, registration or phone change; final counts 0/1/1/0/0. Hosted instance
  reuse is not established; warm-instance behavior is covered by source/bundle
  regressions.
- [x] Close pair 841–845 on 2026-10-10: operator stopped before job directory or
  send sentinel creation; hosted pending/attempts=0/unclaimed/private marker pass.
  Both flags false, worker retired (digest/old 401/local deletion), USB wake 0,
  approved synthetic cleanup returns true/true/true/1; final counts 0/1/1/0/0.
  No send or requeue.
- [x] Repair operator UTC context parsing: `-ContextPath` preserves already parsed
  UTC dates and precision, validates exact context fields and rejects ambiguous
  dates. The real failed context now passes its original preflight budget in
  regression. 37 PowerShell gates and twelve phone/probe tests pass.
- [x] Verify full UTC-context repair CI 38065895016 (`17d7fb7`): all jobs pass,
  including twelve SQL suites, operator/app/native checks and both APK builds.
  Fresh pair 851–855 is prepared locally only; review scope and exact enable next.
- [x] Close pair 851–855 on 2026-10-10: first callback/receipt/claim/post,
  tap to unloaded Guardian, preserved vault baseline and background-only restart
  pass. One guarded requeue passed, but local confirmation arrived about 68
  seconds after waiting began, beyond the 45-second gate. Attempts remain one;
  no duplicate-send sentinel exists. Both flags false, retired worker
  digest/401/local deletion, USB wake 0, approved marker cleanup and final counts
  0/1/1/0/0 pass. Real profile/registration/trips remain intact.
- [x] Bound configurable handoff allowance: default 45 seconds, explicit maximum
  90, cut short by event expiry minus 120 seconds or server-window deadline minus
  165 seconds. Equality refuses the gate/send. Existing fresh preflight,
  immediate send-budget checks, two one-shot limits and six-minute server expiry
  remain unchanged. All 51 local PowerShell and twelve phone/probe checks pass.
- [x] Verify full handoff-repair CI 38068318083 (`ee81423`): all jobs pass,
  including twelve SQL suites, operator/app/native checks and both APK builds.
  Atomic non-overwriting gate publication was verified locally. Actual duplicate
  suppression still requires second callback/receipt, refused claim, unchanged
  vault and no recreated notice together. No fixture/window is active.
- [x] Close 861–865 (2026-10-11 local). The six-minute lease was
  19:27:37.667–19:33:37.667 UTC on October 10. A 90-second automatic approval
  review timeout interrupted verification after enable. Fresh recovery verified
  the save and lifetime; first phone phase passed. At waiting (19:30:49.871636 UTC)
  only 167.795364 seconds remained, so the unchanged 165-second reserve cut the
  gate to about three seconds. No requeue/gate publication/duplicate send occurred.
  Hosted device_received/attempts=1/unclaimed/private marker and one unexpired
  registration pass. Both flags false, worker retired (digest/old 401/local
  deletion), USB wake 0, approved marker cleanup and counts 0/1/1/0/0 pass.
- [x] Review a replacement with a two-minute future start using the existing
  tested window contract, then launch only after start with >300 seconds remaining
  in both event and window. Do not refresh/extend a live window to recover tooling
  latency. If readiness or timing fails, close without sending. At most two sends,
  one guarded requeue and existing exact enable/cleanup gates remain mandatory.
- [x] Complete 871–875 (2026-10-11 local), with lease
  19:43:07.391–19:49:07.391 UTC on October 10 and fresh >300-second event/window
  headroom. First provider acceptance 19:43:15.5326577 UTC; first callback,
  receipt, durable claim, notice, tap to unloaded Guardian, vault baseline and
  background-only restart pass. Guarded requeue and matching atomic local gate
  pass. Second provider acceptance 19:44:28.9620267 UTC; callback/receipt pass,
  claim refused, vault unchanged and notice_count=0. Hosted status device_received,
  attempts=2/unclaimed/private marker and one unexpired real registration pass.
  Both flags false, worker retired (digest/old 401/local deletion), USB wake 0,
  approved marker cleanup and final counts 0/1/1/0/0 pass. No app/server/schema,
  dependency, personal telemetry or Google key change. Expiry/disconnect still
  require separate review and denial/callback evidence; second phone not needed.
- [x] Prepare separately gated expiry case 881–885 locally only: UUID-only
  stage/lifetime/control/cleanup reverse checks and offline/future-launch syntax
  pass. Read-only denial observer requires callback then response rejection,
  unchanged encrypted vault and zero notices; ten parser regressions pass.
  No fixture, worker or window is active. Runtime source CI remains 38068318083;
  this manual observation preparation introduces no app/server change.
- [x] Complete separately reviewed 881–885 expiry-after-queue proof (2026-10-11
  local), lease 20:01:06.344–20:07:06.344 UTC on October 10. One provider acceptance
  while offline; guarded event expiry denies receipt and leaves it unrecorded.
  Reconnection yields CALLBACK then RECEIPT_RESPONSE_REJECTED, zero notices and
  unchanged encrypted vault. Hosted provider_accepted/attempts=1, event expired,
  receipt denied and exact private marker pass. Both flags false, worker retired
  (digest/old 401/local deletion), independent network restoration 1/0/0, approved
  marker cleanup and final counts 0/1/1/0/0 pass. No app/server/schema/dependency,
  personal telemetry or Google key change. Source CI 38068318083 remains green.
  This establishes server expiry rejection after queuing, not natural provider
  TTL exhaustion, long outages or Doze. Disconnect requires its own reviewed
  window; recorder/two-phone gates remain, and the second phone is not needed yet.
- [x] Prepare fresh disconnect-after-queue case 891–895 locally only. Four SQL
  copies reverse-verify as UUID-only changes; disconnect control uses the existing
  guarded synthetic-driver API and checks denial/audit/unrecorded receipt. Two
  PowerShell helpers and Node observer syntax pass; ten denial-parser regressions
  pass without device/network calls. The first-phone read-only preflight confirms
  inactive recorder, existing receipt/provider state and active network at 1/0/0.
  No fixture, worker or window staged. Review one send, bounded offline hold,
  synthetic disconnect and exact finite enable before execution; cleanup retains
  its action-time gate. No app/server/schema/dependency change.
- [x] Close unused 891–895 after reviewed staging (2026-10-11 local). Setup
  left about six minutes of event lifetime, insufficient for the reviewed
  two-minute future start plus >300-second launch headroom. No enable or send,
  network change, claim or disconnect control occurred; hosted pending/attempts=0.
  Both flags remained false, worker retired (digest/old 401/local deletion),
  approved marker cleanup and final counts 0/1/1/0/0 pass. Replacement 901–905
  reverse-verifies all seven SQL/helper artifacts as ID/path-only changes; helper
  syntax passes. Verify the worker before staging the replacement so credential
  setup does not consume event lifetime. Keep all timing/send limits unchanged;
  replacement scope/exact enable and cleanup remain separately reviewed.
- [x] Complete reviewed 901–905 disconnect-after-queue proof (2026-10-11 local).
  Worker verified before staging; lease 20:39:10.786–20:45:10.786 UTC on October
  10, with >300-second event/window launch headroom. Exactly one offline provider
  acceptance; guarded synthetic driver disconnect returns denial/audit/unrecorded
  receipt true. After network restoration, CALLBACK then RECEIPT_RESPONSE_REJECTED,
  zero notices and unchanged encrypted vault pass. Hosted provider_accepted,
  attempts=1, closed connection/revision 2, receipt denied and one unexpired real
  registration pass. Both functions disabled, worker retired (digest/old 401/local
  deletion), independently restored network 1/0/0, approved marker cleanup and
  final counts 0/1/1/0/0 pass. No app/server/schema/dependency, personal telemetry
  or Google key change. Runtime source CI remains 38068318083. This completes the
  receiver duplicate/expiry/disconnect gate; recorder/activation, two-phone and
  reliability/completion gates remain. Second phone is not needed for inspection.
- [x] Finish reviewed locked/offline pair closure in `GUARDIAN_RECEIVER_CHECK.md`.
  Both physical cases passed on 2026-10-07: one send each, normal one-attempt
  receipt, generic notice tap to unloaded Guardian and no viewed acknowledgement.
  Lock copy was hidden until unlock. Initial offline preflight aborted without
  dispatch and restored settings; the bounded-disconnect helper then passed with
  a fresh fixture after reviewed replacement. Network baseline restored to 1/0/0.
  Both functions closed at 09:59:17 UTC. Worker retired at 10:03:38 with matching
  digest/old-value 401/local-file deletion. Both marker-checked cleanups pass;
  final hosted counts 0/1/1/0/0, both flags false. Fresh changed-phone checks
  confirm authorized/unlocked, retained sign-in/native registration, network
  settings 1/0/0 and no recorder. Repository validation/diff checks pass and
  result documents are synchronized. No runtime, schema, personal telemetry or
  Google key change; second phone not needed yet.
- [ ] Validate all affected suites, schema upgrades, builds and performance;
  obtain exact deployment approval and verify synthetic hosted delivery.
- [ ] Synchronize M6 completion only after every M6.8 gate passes; commit/push
  and stop before M7. No dangerous-road testing or real-contact alerts.

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
- [x] M6.5 Friends/social (hosted/device/CI validation passed).
- [x] M6.6 Safe leaderboards (hosted/device/CI validation passed).
- [x] M6.7 Guardian pairing.
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

- 2026-09-26: Implementation committed and pushed as `d79c5ae`; local HEAD
  matched `origin/main`. GitHub Actions [run 36244993247](https://github.com/atrx07/Traelyx/actions/runs/36244993247)
  passed both jobs, including PostgreSQL 17 migration/access tests, generated
  sources/schema snapshots, format/analysis, all 244 Flutter tests, native
  Kotlin, inspector/contracts, debug/release builds, size reporting, and artifact
  publication. M6.5 is complete. This completion update changes documentation
  only; M6.6 remains unauthorized.

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


M6.5 provides mutual requests, acceptance/decline/cancel/removal, and blocking
with explicit username/display-name disclosure. Participant-only projections,
expected-account/revision guards, 30-request quotas, seven-day expiry/cooldown,
and bounded relationship history enforce the documented privacy/abuse contract.
The hosted migration and synthetic rollback tests pass; fixture cleanup was
verified. Physical reload/no-match/layout checks on one Tecno and all 244 Flutter
plus full CI gates pass. Two physical accounts and real-person request flows
were not exercised; those transitions have synthetic SQL/SDK/widget coverage.
The phone remains signed in; all retained raw telemetry is preserved. No new
package, permission, local schema, background upload, notification, ranking,
or Guardian capability was introduced. M6.6 requires separate authorization.

M6.6 is complete. Explicit foreground local analysis runs unchanged native v1
pipelines with a recorded mount choice and persists immutable audits/events.
Separate consent submits an allowlisted dossier; guarded server APIs validate
eligibility and arithmetic, isolate accepted unblocked friends by broad vehicle
class, and support withdrawal. The production migration and synthetic tests
passed with no retained fixtures. All 260 Flutter / 222 native tests and GitHub
CI run 36250004115 pass for implementation commit `728254f`.
Physical synthetic bridge/persistence checks and live empty comparison reload
passed on the Tecno; its normal app/session and original raw data were preserved.
Real driving calibration and simultaneous physical-account sharing remain
unverified. No personal trip upload, new dependency, local schema change or
recorder sampling change was introduced. Stop before M6.7 Guardian pairing.


M6.7 is complete (2026-09-27). All 273 Flutter tests, static analysis,
repository contracts/secrets, local SQL suites and debug/release builds pass
(release 60.2 MB). The exact approved deployment bundle passed locally and on
production: migration history, private RLS, guarded RPC grants and fixture
rollback are all true. No personal telemetry or real invitations were sent.

GitHub CI run 36265444147 passed every gate for implementation `d8b3823`:
PostgreSQL 17 migration/access tests, generated sources/schema snapshots,
formatting, analysis, Flutter/native Kotlin tests, repository checks,
debug/release APK builds, size reporting and artifacts.

The final configured debug APK update-installed on the Tecno LH8n. After the
maintainer unlocked it, physical checks passed: initial unloaded Guardian
screen, live reload, crash preference on and severe/coarse state off, unsupported
location/speed/history off, explicit name-sharing/expiry/delivery disclosure,
and Keep unchanged cancelling invitation review. A subsequent live reload
still showed no invitation; the connection list was empty. The existing session
and all 7,546 raw files / 59,570 KiB are preserved. Temporary QA XML was removed.

Full pairing transitions use rollback-only synthetic users and SDK/widget
fixtures; two real physical accounts were not paired. No new dependency,
local schema, native permission, recorder change or alert delivery was added.
Stop before M6.8 Guardian alerts; explicit authorization remains required.


M6.8 Firebase setup (2026-09-27): project `traelyx-e28ff` was created under the
maintainer-selected `atrx07` organization on Spark. Gemini and Google Analytics
were disabled in the creation wizard. Android package `io.github.atrx07.traelyx`
is registered as `Traelyx Android`, app ID
`1:931662794452:android:577b8e092b305bea1b3541`; sender/project number
`931662794452`. FCM HTTP v1 is enabled; legacy messaging is disabled.
No billing upgrade, service-account key generation, SDK installation or alert
sending was performed. The maintainer supplied the downloaded Android client config. Project ID,
sender number, package and app ID were verified. The unchanged client config is
staged at `.dart_tool/firebase/google-services.json`, Git-ignored and outside
the repository scanner. An initial copy under `android/app` was moved there
because the scanner correctly rejected the embedded Google client API key;
the validator remains unchanged. SDK/build integration is still pending.
The earlier prerequisite-scope choice remains unanswered.


### Long-trip reliability interruption — 2026-09-27

M6.8 implementation paused for a reported End drive / cold-start crash. The
repair streams verified catalog metadata and moves finalization verification
off the main thread. The actual 45m27s trip is recovered into local history;
all 4,290 raw chunk hashes match the private pre-fix backup, and a second cold
launch passes. No cloud upload, schema migration or sampling change occurred.
See the completed long-trip recovery plan for evidence and limitations. M6.8
remains in progress; consent/recorder/dispatch integration remains pending.
