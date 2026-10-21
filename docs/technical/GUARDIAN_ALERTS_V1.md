# Guardian alert rules and delivery contract v1

## Status

M6.8 is in progress. The native evaluator and lifecycle are implemented as a
prerequisite. Bounded recorder sidecar integration passes local/inactive-device
checks and full source CI 38133415539 (`98f9a49`); production driver
activation and network sending remain disabled in ordinary builds. A separate
default-off debug sending review is implemented below. An idle desk activation/
Stop and bounded receiver delivery checks have passed; a correctly mounted
review, active native ingestion and physical recording/performance validation
remain required. The current acceptance matrix is at the end of this document;
the execution plan preserves dated implementation evidence. These are
experimental synthetic baselines, not field-validated crash
detection, emergency protection, or calibrated confidence probabilities.

## Local evaluation

`GuardianSafetyEvaluator` consumes the original version-1 IMU and GNSS samples
without modifying them. A separate single-consumer worker uses an offer-only
1,024-input queue and at most 1,024 reordered samples with a two-second horizon.
Overflow, late input, callback failure or 1.5 seconds without input after startup
disables that worker. It does not block or fail the independent raw recorder.
There are no new sensor subscriptions, rates, wake locks, network calls or SDKs.
Stopping discards unqualified evidence; it does not flush a late alert.

The M6.8 recorder sidecar offers unchanged samples only after the raw writer accepts
them. An immediate-close handle stops forwarding on trip stop/error; Guardian
shutdown and encrypted writes stay on the existing owner executor. Unknown owner
or missing/expired consent starts no evaluator or timer. Qualified callbacks recheck
the exact handle/lease and clocks before atomic cooldown/event insertion; they
never send anything. Worker/enqueue failure stops Guardian and attempts local
revocation without changing recorder success/failure. A clock-only one-second
watchdog exists only while evaluation is active; acquisition rates, permissions,
wake locks and raw storage remain unchanged. Performance/device gates are pending.

Live evaluation requires a two-stage activation committed in the current process.
An encrypted lease recovered after full process death does not itself restart
evaluation, even after owner binding; the driver must explicitly reactivate.
Same-process service restart recalibrates with persisted cooldowns. Lease presence
must not be shown as active monitoring. See
`../decisions/ADR-0029-guardian-recorder-sidecar.md` for isolation and restart limits.

The foreground `driverStatus` method accepts only the bound owner's ID and returns
only `state` plus nullable `expiresEpochMillis`; it exports no capability, account,
activation/event identity or telemetry. Native state distinguishes disabled,
reactivation required, waiting for a trip, calibrating, experimental monitoring
and unavailable evidence. Restored or expired consent overrides an observer's
monitoring claim. Flutter rejects unknown/extra fields and inconsistent/expired
or over-eight-hour expiry. Guardian's local status panel checks only on tap,
labels the observation/check time and clears on background/account change;
timeouts/late replies never restore it. There is no polling, activation, sender
or Auth/network call in this path. Only the inactive state is physically verified
so far; live states have synthetic tests. Full source CI 38135386431 passes for
`dae26e7`, closing only this bounded local-status unit.

The driver must first confirm a rigid mount and device-forward direction.
Missing confirmation is disabled. A stationary three-second window requires
GNSS speed at most 1 m/s, gyro magnitude at most 0.05 rad/s, accelerometer norm
within 0.75 m/s² of 9.80665, and maximum axis standard deviation 0.15 m/s².
Its mean estimates gravity and stationary bias. Device forward is projected
perpendicular to gravity; horizontal projection below 0.5 is rejected.

Eligibility requires Android IMU accuracy at least 2, no raw quality flags,
non-null trip elapsed times, strictly increasing per-channel source timestamps,
and IMU spacing/pair age at most 50 ms. GNSS must be non-mock, flag-free, have
horizontal accuracy at most 15 m and reported speed accuracy at most 1.5 m/s,
with fix age/spacing at most 1.5 seconds. Speed above 90 m/s or a fix-to-fix
change above 15 m/s² invalidates evidence rather than supporting an alert.

Gyro magnitude above 0.5 rad/s or cumulative non-yaw rotation above 10 degrees
invalidates calibration. This intentionally limits availability on slopes,
rough roads and moving mounts; it cannot identify every phone movement.
Free fall (acceleration norm below 4 m/s²) and predominantly vertical shocks
(absolute vertical delta above half the longitudinal delta magnitude plus
2 m/s²) clear pending evidence. Missing evidence is never labelled safe/normal.

### Severe-drive candidate

- Longitudinal acceleration at most −6 m/s² for at least one second.
- Three preceding usable GNSS fixes spanning at least 1.5 seconds, all at
  least 8 m/s and within a 3 m/s range; use their minimum as baseline.
- Two following fixes each at least 5 m/s below that baseline, before the
  candidate's four-second deadline.
- A five-minute cooldown; no repeated claim for the same sustained brake.

This denotes a corroborated strong braking pattern, not proof of reckless
driving, intent, injury, or a collision.

### Possible-crash candidate

- A longitudinal impact at most −25 m/s² lasting 40–400 ms, with integrated
  negative impulse at least 2 m/s, followed by release below the threshold.
- The same three-fix moving baseline as above.
- Speed falls by at least 6 m/s to at most 1.5 m/s within three seconds of
  impact, then remains stopped through usable fixes for at least five seconds.
- The evidence must complete within 12 seconds; pending impact takes priority
  over severe-braking notification. A 30-minute crash cooldown also starts the
  five-minute severe cooldown.

All thresholds belong to **Guardian safety rules version 1**. They are governed
heuristics, not population-calibrated limits. They miss events and can produce
false positives. They are independent of M4 scoring, event taxonomies, ML and
LLM commentary. Any classification-changing tuning needs a new rule version.

## Local alert lifecycle

`GuardianPendingAlert` defines a 30-second cancellation window, stable random
event UUID, account/consent generation binding, and ten-minute expiry. Both
monotonic and wall clocks bound expiry. Reboot, clock rollback, account change
or consent replacement prevents old dispatch. An attempt reservation must be
persisted before network IO. Six attempts use 5/10/20/40/80/120-second backoff;
late callbacks cannot resurrect cancellation or revocation.
Cancellation is available only before the first network-attempt reservation.
After handoff, the UI must not claim it can retract an in-flight request;
account/consent revocation still invalidates subsequent server access.

The network envelope allowlist is schema version, event UUID, kind, rule version,
occurrence time and `experimental_not_confirmed` uncertainty. No trip ID,
coordinates, speed, raw evidence, mount direction, name or free-form text.
Backend acceptance is its own state; it never means recipient receipt or view.
Persistence and dispatch integration must enforce these transitions and remain
disabled until separate consent, authorization and delivery tests pass.

### Local cancellation controls and offer proof

The default-off driver pilot exposes explicit local pending-alert check/cancel
controls. Foreground replies contain only exact activation/event UUIDs, kind,
local state, cancellability and optional remaining offer time (0–30,000 ms), with
at most 16 unique events. They contain no capability, trip ID or raw evidence.
No automatic Flutter read/polling or server request is added. Account/background
changes clear observations; native authority is checked again before mutation.
Durable cancellation precedes success; reserved attempts cannot be retracted.

`GuardianCancellationControls` observes a generic private Android cancellation
notice before starting a full 30-second dual-clock window. Its bounded in-memory
proof binds the exact lease and immutable event metadata. A delayed notification
cannot borrow event age; blocked/unobserved posting, clock uncertainty, authority
loss, expiry or restart denies eligibility. Submitting a notice is not observation
or proof a person saw it. The separate channel uses an immutable explicit action
and non-exported receiver; only exact owner/activation/event UUIDs enter that
action. It cannot reconstruct driver authority after process death. A notice
dismissed before observation is not repeatedly reposted. Android 26+ timeout is
bounded by remaining event/lease life; older Android may leave a stale generic
notice after process death, with no restored authority or send permission.

Runtime offer handling reuses the serialized worker with one cancellable
one-shot alert wake, independently of the recorder watchdog. Raw acquisition
and permissions are unchanged. ADR-0032 defines the proof and physical
limitations. The host combines offer checks, retry/deadline timing and expiry;
it invalidates permits before relevant Stop/account/activation changes. Pilot
controls state sending is unavailable in ordinary builds. The separate debug
sending pilot requires a new version-1 acknowledgement and exact fresh native
activation, with a native debuggable-package guard. A build flag, old review,
retained lease or receiver registration alone grants no transmission consent.

## Dormant minimized-ingest adapter

`GuardianCapabilityIngestGateway` accepts the native reserved-attempt shape,
checks owner/activation/boot binding, reservation state, the completed 30-second
cancellation window, server-safe timestamp range and current lease/event expiry,
and serializes only the capability ingest authorization plus the six
approved envelope fields above. The URL must be the fixed project HTTPS
`guardian-capability` endpoint, with no port, credentials, suffix or query.
It uses the existing transport interface; the bounded HTTPS implementation has
no redirects, 3-second connect/read timeouts and a 128-byte response limit.

Only HTTP 200 with an exact current-event `backend_accepted` reply is accepted.
The reply must have a Boolean duplicate flag and an integer recipient-device
count from 0 through 30; only an explicit duplicate may omit that count, matching
the deployed RPC. Unknown/duplicate fields, malformed JSON, trailing content,
wrong event IDs and oversized replies are unconfirmed. HTTP 401/403 are a separate
authorization-denied result; rate limits, other statuses, exceptions and missing
replies remain unconfirmed. No backend reply means receipt, display or assistance.
Mutable request bytes are zeroed on every transport outcome; no request/reply
body or credential is logged. Retry reservations and late callback protection
remain owned by the encrypted outbox, not by this adapter.

This adapter has synthetic wire/outbox tests. Its Android factory is attached
behind the default-off reviewed sending gate: ordinary app operation does not
construct its network worker or reserve a send. The serialized host uses fresh
in-process authority, cancellation proof and separate bounded IO, with completion
marshalled back onto the vault worker. Actual fresh on-device consent and reviewed
physical network/lifecycle validation remain gates. No production request or
additional activation is performed by this integration.

## Dispatch coordination and disabled Android host

`GuardianOutboxDispatchCoordinator` serializes reservation, exact cancellation
and result persistence through its serialized control-worker host. Its explicit
per-event handoff gate must represent validated cancellation-affordance readiness,
including the cancellation window; it must not be inferred from pairing or
lease presence. One unsettled operation is allowed. Queued work owns a one-use
atomic permit, invalidated before account/activation/Stop changes. The permit
also rejects delayed handoff after the local ten-second deadline, reboot,
rollback or clock failure. Network work uses `GuardianIngestWorker`, a separate
single-thread executor with one bounded transient queued slot and no vault/Auth
access. Results marshal back to the control worker and match the exact persisted
lease/attempt before changing state.

A local deadline records an unconfirmed result and ignores late acceptance;
it does not claim to cancel a remote request. The busy slot remains until actual
worker completion, so a stuck transport cannot accumulate retries or threads.
Only the returned monotonic wake is needed; no polling timer is created here.
Control/storage errors fail dispatch closed. Existing six-attempt limits, stable
IDs, backoff and encrypted schema remain unchanged. See
`../decisions/ADR-0031-guardian-dispatch-worker-isolation.md`.

`GuardianDispatchSchedule` owns one cancellable scheduled wake on that same
worker. Cancelled futures are removed from the executor queue immediately;
generation checks reject already-dequeued cancelled wakes. Enqueue,
explicit cancellation/checks, authority changes and network completion refresh
the schedule. No active event means no timer; cancellation timing continues after
the recording handle ends. The default-off reviewed Android sending gate avoids
constructing the network runner or reserving attempts without fresh permission.
Tests inject a separate synthetic gate.
The existing review saying sending is unavailable cannot authorize live ingest.

Unobserved notification submission receives at most three seconds of automatic
one-second confirmation checks. The dispatcher's initial event-age wake may also
trigger a check; later explicit controls can retry observation. An observed,
unfinished offer is checked at most once per second until both clocks complete
30 seconds or proof is withdrawn. Blocked/dismissed offers otherwise wait for
event/lease expiry, not a continuing poll. Mature offers retain exact retry proof;
completion removes the now-reserved notice. Each pending event also contributes
its earliest wall/monotonic expiry. No alarm, wake lock, foreground-service,
sampling, permission or process-restart activation is added. Android may delay
in-process timers during sleep; late wakes recheck authority/clocks and cannot
promise background delivery or real-time notification expiry.

The dispatcher and runner stay process-scoped across invalidation, retaining one
unsettled operation even if a new activation replaces the old one. A stale abort
for another activation does not invalidate a newer job; the host checks in-memory
owner/activation identity before changing permits. Schedule/clock failures deny
further scheduling. Reviewed live activation/Stop and actual on-device consent plus
physical network, active-recording and two-account reliability remain open.

## Encrypted outbox prerequisite (implemented; not activated)

`AndroidGuardianVault` persists a bounded version-1 binary snapshot under app-private
credential-encrypted `no_backup/guardian/primary.vault`. Android Keystore generates
a non-exportable AES-256 key; AES-GCM uses provider-generated random 96-bit IVs,
128-bit authentication tags and format-specific associated data. The native key
does not require a biometric prompt per use because explicit background consent
must survive screen lock after first unlock. No Supabase Auth refresh token,
service-role key, route, raw samples or trip identifier enters this store.

A driver lease binds account, activation UUID, restricted capability, both clock
origins, boot identity and confirmed forward axis. Recovery rejects another
account, reboot, clock rollback or expiry. The lease lasts at most eight hours.
At most 16 minimal alerts and their evaluator cooldowns share one atomic encrypted
snapshot, capped at 32 KiB plaintext. Cooldown/event insertion and attempt
reservation must persist before dispatch authority is returned. Cancellation and
bounded retries survive reopen; callbacks from older attempts or activations are
ignored. Expired alerts are pruned on recovery, including terminal records.

Unknown schemas, excess/trailing bytes, tampering and lost keys fail visibly.
Writes use AtomicFile, explicit file-descriptor sync and readback verification.
An uncertain write disables the live store and attempts both key destruction and
ciphertext removal. Revocation destroys the key before deleting ciphertext; no
plaintext fallback exists. If storage and Keystore both refuse cleanup, revocation
must be reported unavailable rather than claimed successful; backend expiry and
server revocation remain independent safeguards. One process-wide coordinator
serializes transitions on a worker, never the recorder acquisition thread.

Eleven new native tests cover authenticated encryption, restoration, malformed
state, failure injection, cancellation and stale callbacks. All 264 native tests
pass. A separate synthetic Android 14 Keystore proof verifies actual encryption,
reopen, attempt persistence, tamper rejection, invalidation of retained ciphertext
after key destruction and scoped cleanup. All 7,546 existing raw files / 59,570 KiB
remained intact during that isolated proof. Consent, recorder and dispatch
integration have since passed synthetic checks; physical receiver process-kill,
offline and locked delivery checks also passed. Active driver/outbox lifecycle
and recording validation remain open, as distinguished in the acceptance matrix.

Primary platform references:
- https://developer.android.com/privacy-and-security/keystore
- https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec

## Activation and recipient authority

### Two-stage activation prerequisite

`GuardianActivationCoordinator` now binds foreground account identity, explicit
rigid-mount confirmation and forward axis to a single-use activation proposal.
Its random capability stays in memory until the caller confirms the server lease;
only then is the encrypted local lease committed. Before returning the proposal,
native code durably reserves its exact owner/activation IDs in the encrypted
revoke journal; no credential or axis enters that journal. Proposals expire after two
minutes on both clocks. Local duration is capped at eight hours from preparation,
so network delay cannot extend consent. Replacement first removes old local
authority and confirms its exact server cleanup. An expired or interrupted
proposal still requires cleanup; time alone never discards its reservation.
Account changes, sign-out, cancellation, reboot, clock rollback and
failed cleanup invalidate pending activation; a late response cannot restore it.
Failures to erase leave the coordinator unbound. Status never means monitoring
or delivery is running. Native regressions cover these boundaries. The
foreground Android method bridge now serializes coordinator and encrypted-vault
calls on one process worker, including across Activity recreation. It accepts
exact request fields, returns the credential only from `begin`, and keeps
status/commit replies redacted. Its clock uses wall time, elapsed time including
sleep, and Android's boot count; missing boot count fails closed. The bridge is
bound to Flutter Auth identity changes; activation is available only through
the explicitly configured debug review pilot. Startup binding runs asynchronously so local
trip startup does not wait for the vault. Sign-out first waits for local
Guardian cleanup; if cleanup fails, sign-out is cancelled and account binding
stays fail closed for that process. Server confirmation must be validated by
the activation service before `commit`; the bridge does not verify a server response
itself. The recorder sidecar and gated consent UI are attached; active-device
validation remains required. Its startup owner binding passed a data-preserving
physical update and cold launch. Initial `begin`/`commit` proof used an isolated
physical namespace; the later idle hosted activation/Stop did not establish
vehicle-mount correctness. The account decorator delegates optional Supabase client
access so existing cloud features remain reachable after wrapping Auth.

The gated Flutter `GuardianDriverActivationService` coordinates the
foreground two-stage call. It requires the current Auth owner and native owner
binding, accepts only a reviewed forward axis, validates the exact native
proposal and signed-in server response, and commits locally only after a
matching, bounded server lease. Failure removes local authority and attempts
an activation-matched v2 server revoke. A bound-account transaction serializes
reviews across service instances and excludes recipient registration. Explicit
Stop/sign-out or an account change invalidates every later stage, including a
review waiting for a revision or activation response. Consent freshness is checked
after each asynchronous stage; failed cleanup uses exact abort rather than a
generic disable, so stale callbacks cannot erase a newer proposal or lease.
If a request finishes after account
change or revocation cannot reach the server, the server session may remain
until its eight-hour expiry, but the native capability is unavailable. The
service has a default-off review/Stop UI caller. Correct vehicle-mount confirmation,
active recorder use and the complete native-to-server flow remain unverified;
the separately tested administrative receiver fixtures do not cover them.
Synthetic flow/bridge/SDK tests
cover ordering, wire shapes, bigint precision, expiry, Stop/sign-out, concurrent
reviews, account races and retryable failed cleanup. A separate physical Android
instrumentation proof exercises the native bridge and encrypted vault with a
random test namespace and synthetic confirmation, then destroys its key and
ciphertext. A later physical Flutter alternate entrypoint exercises the
production `MainActivity` MethodChannel with a random synthetic owner,
proposal/abort, synthetic local commit, active snapshot and disable; the normal
app and sign-in were restored without changing recorder storage. Neither proof
exercises a hosted session, real user consent or alert delivery.

The dormant explicit stop path writes the exact owner/activation identity into
a separate encrypted no-backup journal, then erases the local driver lease before
returning. Neither the capability nor telemetry enters this journal or its
foreground replies. Journal schema 1 permits at most eight tickets and 4,096
plaintext bytes, with no eviction based on local clocks. A full or unhealthy
journal refuses new activation. Successful commit retains the proposal reservation
for the entire lease lifetime; only a subsequent exact server revoke can clear
it after local authority is stopped. Valid-lease outbox writes and replacement
retain cleanup IDs before any destructive vault operation. Binding adopts a
readable older lease into the journal before exposing authority; recovery writes
also journal before pruning. A failed vault write/readback may destroy its key
and file but cannot erase the independent, already durable cleanup reservation.
After process death, a restored lease cannot resume evaluation (ADR-0029); its
reservation remains available for explicit cleanup. Revoke confirmation is refused
while that exact proposal or lease is still locally active. Native status and
account binding perform no
server request. A subsequent explicit Stop or reviewed activation retries
outstanding stops under the same signed-in owner; only a confirmed exact server
revoke removes a ticket. Account changes or server conflicts leave it pending
and cannot revoke a replacement session. A read/write failure still attempts
local lease erasure and reports uncertainty rather than successful cancellation.
Already queued remote delivery may continue while server revocation is
unconfirmed, and an in-flight generic push cannot be retracted.

The journal retains IDs only, not a second capability or outbox. Repeated records
are idempotent without rewriting the journal. Journal uncertainty blocks a new
outbox state write or replacement before it starts; Stop/invalid-authority cleanup
still attempts local erasure. A failed server-cleanup confirmation retains the
ticket for explicit retry. This does not guarantee cleanup after loss/corruption
of both independent stores, app-data removal, or an older lease already unreadable
before adoption. Local failure/off status is never proof of hosted revocation.
Synthetic authenticated-encryption tests cover these storage boundaries; physical
Keystore/disk-failure injection remains unverified. Idle hosted activation/Stop
passed, without establishing mounted or active-recording behavior.

Owner loss/change and expiry, reboot or clock rollback recovery now capture
retained lease IDs in the same journal before erasure. A different owner cannot
enumerate or confirm those tickets. Journal/read failure still attempts lease
erasure and reports failure; successful cleanup cannot be claimed if persistence
is uncertain. Recipient cleanup failure also attempts driver owner teardown.
Explicit sign-out stops the driver before recipient cleanup and before removing
Auth, and retains Auth if an exact server revoke cannot be confirmed. Unexpected
Auth loss has no signed-in server authority; a later same-owner explicit retry
or reviewed activation reconciles the ticket. No network request is added to
native status/account binding.

The physical synthetic proof verifies Keystore storage, journal reopening,
owner-loss capture and exact confirmation in a random disposable namespace;
it preserves the normal recipient vault and recorder data. It also reopens a
proposal reservation before commit and after a simulated coordinator restart,
then confirms cleanup and rejects the original delayed commit. The default-off
UI and idle hosted revoke have since passed bounded checks. Hosted timeout/
replacement recovery and active physical recording remain integration gates.

### Driver revision contract (deployed 2026-10-14)

Migration `20261014000000_guardian_driver_revisions.sql` passed all 13 local SQL
suites, legacy-session upgrade checks and full CI 38603573947 before its approved
atomic hosted deployment. All four hosted verification checks pass and synthetic
state is rolled back. `get_guardian_driver_revision_v2(expected_user_id)` returns only
the current owner's bigint revision as decimal text. A new activation through
`set_guardian_driver_session_v2(expected_user_id, activation, credential,
expected_revision)` requires that reviewed revision under the stable owner row
lock. Success advances it; an exact existing-session retry preserves expiry.
With `credential = null`, the RPC advances revision even when that activation is
absent, deletes only a matching session and revokes only its event deliveries.
Old cleanup can settle without erasing a newer session. A delayed activation with
an earlier revision cannot recreate a revoked session. Conflicting concurrent
reviews fail conservatively and must obtain a new review/revision.

The private RLS-enabled control table contains one revision row per owner, with
no direct client or worker grants. Both v2 RPCs are signed-in owner-only. The
legacy v1 RPC becomes cleanup-only; activation from older dormant builds is
denied. Existing session rows are preserved. This adds no telemetry, recipient
access, startup request or processing enable. Both Guardian enable digests remain
`false`. The dormant client now reads the revision only after explicit local
Stop/cleanup and transmits it as strictly validated decimal text, preserving the
full signed bigint range. Revoke sends null credential/revision and an exact
activation ID. The adapter checks the Auth owner before and after every request;
startup/status add no revision read. Proposal journaling and v2 client attachment
are implemented. Idle hosted activation/revoke passed; active-device validation
remains required. See ADR-0030 and the current acceptance matrix.

The Flutter review component collects a phone-forward axis and separate
rigid-mount, false-alarm/missed-event and limited-recipient-sharing
acknowledgements. Its result is ephemeral. The activation service rejects a
review older than two minutes, from the future or missing any acknowledgement
before asking native code for a proposal. Cancelling returns no review. The
component alone returns ephemeral consent, with no hosted activation or device
registration side effect. A separate `TRAELYX_GUARDIAN_DRIVER_PILOT` gate requires
a deliberately configured debug build before the Guardian screen exposes driver
Review/Stop controls. It defaults false independently of the recipient pilot;
release builds cannot expose it. Installed validation builds keep it false.

The gated controller reads recorder status only for explicit review preflights,
never at startup or on a timer. It repeats that check after review, rechecks the
owner/freshness and invokes the v2 service. The review discloses the temporary
account session and private local lease, bounded to eight hours. UI state says
consent saved, not monitoring or delivery; ordinary builds keep sending unavailable. Stop
remains usable during activation and invokes the exact local-first stop service
without stopping raw recording. Failure is reported as uncertain confirmation,
not a promise that a previously handed-off message was retracted.

Each pending foreground operation owns a single-use cancellation token. On
background, route disposal or owner change, cancellation starts memoized exact
abort/revoke cleanup once the proposal ID is known, with the existing journal
retaining unsuccessful cleanup. It also covers a local commit whose asynchronous
result has not yet been consumed by the foreground controller. Only synchronous
foreground result acceptance releases that cancellation hook; subsequent ordinary
backgrounding does not revoke completed consent. Old tokens cannot invalidate
new reviews. Late success is suppressed; native/server owner and exact-activation
checks remain authoritative. The native MethodChannel and owner worker serialize
commit/abort; the fake models durable commit before its bridge reply. That
Review/Stop unit introduced no sender, automatic registration, migration or new
dependency. Local event cancellation is implemented in the separate section above.
Idle pilot activation/revoke passed; mounted consent and active recording remain
separate gates.

### Separate sending review v1 (default-off debug pilot)

`TRAELYX_GUARDIAN_SENDING_PILOT` additionally requires the existing debug driver
pilot and defaults false. Ordinary installed builds explicitly keep both false.
The new review variant adds a separate unchecked sending acknowledgement,
provider/minimized-data disclosure and at least 30 seconds after an observed
cancellation notice before handoff. It explains false alarms, missed events,
unreliable delivery and that handed-off requests cannot be retracted. The old
review remains evaluation-only version 0. Unknown versions, future/stale reviews
and mismatched acknowledgement/version fields deny activation before side effects.

The native `beginSending` bridge requires exactly the existing proposal fields
plus `sendingAcknowledged=true` and integer `sendingReviewVersion=1`. It is denied
unless the installed Android package is debuggable. The unchanged `begin` method
cannot acquire sending permission. Permission binds the exact proposal, then its
successfully committed fresh in-process activation; it is not persisted. The
scheduler requires that permission and a currently valid bound lease. Recovery
compares against a captured non-null activation to avoid matching two cleared IDs.
Stop/owner loss, expiry/reboot, failed commit or missing authority deny sending;
process reopening cannot resume it. Existing exact cleanup/revision fencing and
foreground lifecycle cancellation are preserved. No backend wire/schema change.
See `../decisions/ADR-0033-guardian-versioned-sending-review.md`.

The separate recipient review is available only in its debug pilot. It requires explicit
acknowledgement of experimental detection/delivery limits and of Firebase
installation/device metadata transfer plus private routing-token registration.
It returns a foreground-only, account-labelled result valid for less than two
minutes; cancellation returns none. It does not initialize Firebase, request
Android notification permission, register a token or mutate server state.

The recipient device RPC gateway validates canonical
account/device/generation identities and bounded credentials, checks the current
Auth owner before and after each guarded registration or revocation call, and
never logs its routing token or credential. Explicit sign-out invokes its
revocation method when local recipient status exists. The foreground
registration caller is disabled in normal/release builds. Consented pilot
registration/withdrawal and Pixel explicit sign-out/same-account recovery passed;
live unexpected account-loss reconciliation and failure recovery remain required.

Recipient receipt authority now has an isolated native storage boundary: a
bounded AES-GCM record in `no_backup/guardian/recipient-primary.vault`,
with its own Android Keystore alias and encryption domain, separate from the
driver lease/outbox. It binds the account, opaque device and generation to a
lowercase 256-bit capability and a maximum 30-day local lifetime. Reads return
no authority for a different account/generation, before registration time or
at expiry; corruption, missing keys and uncertain writes fail closed. The
record contains no routing token or Auth credential. Recipient plaintext v2
also retains at most 1,024 compact delivery IDs, encrypted under the same key.
It reads v1 authority with an empty history and upgrades on write. After a
positive server receipt and current local checks, it durably claims an ID
before a generic notice attempt; dismissal/restart never clear a claim. No
eviction is permitted during registration, and full history denies new notices
until withdrawal and fresh registration. Erasing authority also erases history.
Uncertain claim writes preserve atomic old/new authority for recovery but deny
display. Process death or notification failure after claim can suppress that
notice; this does not guarantee delivery. ADR-0027 defines the format, bounds,
downgrade behavior and tradeoffs. A synthetic physical
Keystore proof uses a random namespace and erases its key/file afterward.
Live server-confirmed registration, receipt and notification passed bounded
checks. Unexpected account-loss reconciliation remains unverified live.

The native recipient coordinator now binds the Auth owner and validates local
commit timing. A foreground caller must confirm guarded server
registration before invoking that commit. It preserves an unexpired record only for
that owner, erases on sign-out/account switch or expiry, rejects stale/future
commit timestamps, and exposes only opaque device/generation IDs plus expiry
in status. A separate foreground MethodChannel serializes its operations on a
single process worker. Flutter Auth binding calls recipient cleanup before
driver binding and waits for both on sign-out; a failure prevents sign-out from
reporting success. The foreground registration caller remains paused in normal
builds; marker-free binding does not initialize Firebase.

The dormant push adapter now writes an account-free, no-backup provider cleanup
marker before any explicit Firebase token request. Marker presence blocks another
request until deletion of both the Firebase Messaging token and installation
completes; deletion failure or an interrupted marker write retains cleanup intent.
An explicit cleanup can initialize Firebase after a process restart even though
automatic initialization stays disabled. Construction and marker-free owner
binding do not initialize Firebase. A scoped Android 14 proof verified marker persistence,
interrupted-write detection and erasure without requesting a token; the normal
app opened afterward with private storage sizes unchanged. No production caller
can request a token yet.

The native owner bridge now invokes that explicit provider deletion when its
marker exists and the next owner is absent, different, expired or has no matching
local receipt record. It erases local receipt authority before waiting up to 25
seconds for deletion and refuses the new owner if deletion fails or times out.
A same-owner restart with a valid local receipt preserves the provider token;
an unmarked receipt is discarded. With no marker, owner binding and sign-out
remain Firebase-inert. Unexpected account-loss recovery and opt-out orchestration
are implemented with guarded server-first cleanup and the revoke journal below;
live unexpected-loss recovery remains unverified. A guarded
Android 14 proof ran the production owner runtime with an empty marker/vault:
it completed a null-owner bind without initializing Firebase or requesting a
token, then the normal app reopened with private storage sizes unchanged.

For explicit sign-out, Flutter first reads the native account-bound status. If
it reports a device, the signed-in owner invokes the guarded server revocation
RPC and waits for confirmation before native provider deletion and Auth sign-out.
Offline or rejected revocation cancels sign-out without clearing the local
registration, so the same owner can retry. If server revocation succeeded but
local deletion fails, a retry resumes local cleanup without repeating the
server call. Missing server transport or malformed native status fails closed.
Concurrent sign-out is serialized, and an account replacement during the
server request cannot sign out the replacement account.
Production recipient devices now exist. Explicit server-first withdrawal, push
and Pixel registered sign-out/same-account recovery have passed. The latter
removed the old receiver, preserved pairing without automatic registration after
sign-in, then required fresh consent. It cannot replace physical-device sign-out,
unexpected Auth-loss or failed-network evidence.

A separate native revoke journal can persist up to eight exact
owner/device/generation ID triples in a no-backup Keystore-encrypted file. It
stores no routing token or credential. It does not drop pending IDs based only
on local time: the server row can remain live for 30 days and local clock or
refresh timing can differ. Exact confirmed revocation removes a ticket; full,
corrupt, missing-keyed-file or uncertain storage denies further journal mutations. An isolated
Android 14 proof verified restart, tamper/loss rejection and proof-only cleanup,
without touching the production namespace. Account-change capture and signed-in
same-owner server reconciliation now runs when the account is bound. Native
owner changes, expiry, explicit disable and receipt replacement record the
prior exact server-row IDs before erasure; failed journal writes deny the
transition and retain the receipt for retry. The native bridge returns only
the bound owner's device/generation IDs. Flutter checks the signed-in owner
before and after the guarded revoke RPC and clears an exact journal ticket
only after confirmation. Offline or owner-change failures leave the ticket for
later same-owner sign-in. Explicit sign-out erases a server-confirmed local
receipt without journaling a redundant revoke. Production devices exist, but no
live unexpected-loss journal/reconciliation proof has run; server expiry
is still the fallback if that owner never signs in again.

Before a future token request or guarded server registration, the client must
reserve the exact owner/device/generation revoke ticket in this journal. A
same-owner retry may find both the ticket and a local receipt if the process
stopped between receipt commit and ticket confirmation. In that case it revokes
the server row, erases that matching receipt and runs marker-aware provider
cleanup. Failed server or receipt cleanup preserves the ticket; failed provider
deletion preserves its separate marker for another retry.
This reservation bridge is used by the separately reviewed pilot registration
transaction; ordinary startup does not create a token or production device row.
The native receipt commit rejects a missing or mismatched reservation and
rejects overwriting an existing receipt. Replacing a device requires cleanup
of the old receipt and a distinct new reservation before server registration.
The dormant foreground transaction validates fresh explicit recipient consent,
serializes same-owner rebinding, reserves IDs, obtains a provider token through
an injected adapter, registers the guarded server row, commits the encrypted
local receipt and only then clears the reservation. It rechecks consent before
reservation and Auth after each await. Token and local receipt waits are bounded
to 25 seconds. Failure attempts signed-in server revocation before local receipt and
provider cleanup; uncertain cleanup leaves the exact ticket or provider marker
for retry. Explicit sign-out is refused while the transaction is in flight, so
it cannot release Auth before a late server registration finishes.
The Android provider adapter now has a dormant MethodChannel entry that checks
the exact pending ticket before and after Firebase's token callback. Its
account-free cleanup marker still precedes any token request. Late callbacks
after owner switch, mismatched consent, malformed tokens and unreserved calls
cannot return a routing token to Flutter. Foreground Guardian UI now exposes
an explicit local status check, the two-acknowledgement review and server-first
withdrawal. The opt-in action stays disabled in normal and release builds; only
an explicitly configured debug pilot build can expose it after hosted synthetic
registration and withdrawal checks. Opening Guardian and cancelling review
still create no token, recipient row or revoke ticket. There is no automatic
startup registration path.

### Current integration acceptance — 2026-10-21

- The minimized sender is attached behind the default-off sending pilot to
  consent, cancellation-offer and account teardown, with serialized scheduling
  and queued-permit invalidation. Synthetic cross-component tests pass; fresh
  mounted consent, active native ingestion/cancellation and recording remain open.
- Current permission/generation checks, quotas, deduplication and retention are
  implemented and covered by adversarial SQL/upgrade suites. They are not an
  authorization to leave production processing enabled.
- The capability Edge function provides exact bounded ingestion/receipt requests
  to those guarded SQL transitions. It is deployed with processing disabled;
  an unauthenticated synthetic POST returned `503 capability_disabled`.
  Reviewed denial/positive-receipt windows and independent server expiry passed.
  Actual driver telemetry ingestion remains a separate unverified gate.
- The opt-in first-phone provider registration/withdrawal path has passed a
  consented pilot check. Receiver handling, generic lock-screen copy, authenticated
  details and distinct send/receipt/view semantics have since passed bounded
  checks linked below. Both endpoints remain disabled between reviewed windows.
  The Android envelope parser accepts only data-only FCM messages
  with exactly `schema_version=1`, a canonical delivery UUID and a canonical
  device-generation UUID. It rejects notification payloads, extra fields and
  malformed IDs. A native preflight then requires a provider cleanup
  marker and an unexpired encrypted local receipt with matching generation;
  missing or corrupt state yields no transient receipt request. A server check
  is still required before notification. The Android FCM service now runs that
  preflight, sends a bounded HTTPS receipt to the configured capability
  endpoint, accepts only an exact positive reply, rechecks local authority,
  and posts generic private notification text. A missing local receipt,
  permission denial, network error or disabled capability endpoint shows no
  notice. The registered Tecno and Pixel have passed actual callback, positive
  receipt and generic notification checks. The dispatch sender's data-only
  contract is essential: Android
  Firebase can display notification-type messages in the background without
  calling the app's receiver, so the callback's payload rejection alone cannot
  contain a compromised sender. Neither Guardian Edge function is enabled.
  The generic notice's immutable tap intent uses only the fixed
  `io.github.atrx07.traelyx://guardian-notice/` URI. Configured app startup and
  warm-link handling route it to Guardian without passing an alert identity or
  acknowledging a view. Links with extra path, query, fragment, user information
  or port are ignored. Signed-out users see the existing sign-in gate; signed-in
  users must explicitly reload and open an authorized inbox row. Actual notice
  taps and cold/warm ingress passed; notifications use the full opaque delivery
  ID as their tag. No detail read or view acknowledgement is implicit in a tap.

| Acceptance area | Verified evidence | Remaining limit/gate |
|---|---|---|
| Background/cold receiver, locked/offline delivery | Physical Tecno checks in [push](../reference/GUARDIAN_PUSH_CHECK.md) and [receiver](../reference/GUARDIAN_RECEIVER_CHECK.md) reports | No general delivery or OEM reliability guarantee |
| Duplicate, queued expiry and disconnect | Actual FCM rejection/durable-claim checks in [rejection report](../reference/GUARDIAN_REJECTION_CHECK.md) | These cases do not validate active driver detection |
| Two-account receipt/details | One synthetic backend event to Pixel; explicit Open and Tecno viewed status; exact cleanup in [two-account report](../reference/GUARDIAN_TWO_ACCOUNT_CHECK.md) | Pixel is an emulator; no native detector/ingestion proof |
| Registered receiver sign-out/recovery | Ordering/failure/owner-race regressions plus reviewed Pixel explicit sign-out, same-account recovery and fresh consent in the [lifecycle report](../reference/GUARDIAN_RECIPIENT_LIFECYCLE_CHECK.md) | Unexpected Auth-loss/journal reconciliation, live failure recovery and physical-device reliability remain separate |
| Reviewed driver/outbox/scheduler integration | Governed fixtures, synthetic cross-component tests and isolated native proofs; idle hosted activation/Stop | Correct mount review, active cancellation/ingestion, process/network recovery and recording/performance remain open |
| Vehicle and physical reliability | No field accuracy claim | Maintainer deferred mounted review and driving/performance on 2026-10-19; retain separate physical-device and calibration gates |

M6.8 remains incomplete. Source CI and synthetic/backend fixture success do not
establish field sensitivity/specificity or authorize dangerous maneuvers, impact
tests, ordinary alert enablement or the next milestone.
