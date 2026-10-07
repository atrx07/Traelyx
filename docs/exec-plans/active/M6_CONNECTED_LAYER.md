# Execution Plan — M6 Connected / Social Layer

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M6
**Started:** 2026-09-25
**Last updated:** 2026-09-27

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
- [ ] Verify expiry/revocation and actual duplicate
  FCM behavior under separately reviewed windows; complete recorder integration
  and two-phone gates before calling M6.8 complete.
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
