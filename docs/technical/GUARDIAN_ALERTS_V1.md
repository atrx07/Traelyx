# Guardian alert rules and delivery contract v1

## Status

M6.8 is in progress. The native evaluator and lifecycle are implemented as an
isolated prerequisite. They are **not connected to RecorderService or enabled
in the application**. Hosted delivery, consent UI and physical validation remain
required. These are experimental synthetic baselines, not field-validated crash
detection, emergency protection, or calibrated confidence probabilities.

## Local evaluation

`GuardianSafetyEvaluator` consumes the original version-1 IMU and GNSS samples
without modifying them. A separate single-consumer worker uses an offer-only
1,024-input queue and at most 1,024 reordered samples with a two-second horizon.
Overflow, late input, callback failure or 1.5 seconds without input after startup
disables that worker. It does not block or fail the independent raw recorder.
There are no new sensor subscriptions, rates, wake locks, network calls or SDKs.
Stopping discards unqualified evidence; it does not flush a late alert.

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
remain intact. This is not yet integrated with app consent, recorder or dispatch;
actual process-kill/offline/locked delivery validation remains required.

Primary platform references:
- https://developer.android.com/privacy-and-security/keystore
- https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec

## Required remaining integration gates

### Two-stage activation prerequisite

`GuardianActivationCoordinator` now binds foreground account identity, explicit
rigid-mount confirmation and forward axis to a single-use activation proposal.
Its random capability stays in memory until the caller confirms the server lease;
only then is the encrypted local lease committed. Proposals expire after two
minutes on both clocks. Local duration is capped at eight hours from preparation,
so network delay cannot extend consent. Replacement first removes old local
authority. Account changes, sign-out, cancellation, reboot, clock rollback and
failed cleanup invalidate pending activation; a late response cannot restore it.
Failures to erase leave the coordinator unbound. Status never means monitoring
or delivery is running. Nine unit regressions cover these boundaries. The
foreground Android method bridge now serializes coordinator and encrypted-vault
calls on one process worker, including across Activity recreation. It accepts
exact request fields, returns the credential only from `begin`, and keeps
status/commit replies redacted. Its clock uses wall time, elapsed time including
sleep, and Android's boot count; missing boot count fails closed. The bridge is
bound to Flutter Auth identity changes but `begin` remains dormant until an
explicit consent flow exists. Startup binding runs asynchronously so local
trip startup does not wait for the vault. Sign-out first waits for local
Guardian cleanup; if cleanup fails, sign-out is cancelled and account binding
stays fail closed for that process. Server confirmation must be validated by
the future caller before `commit`; the bridge does not verify a server response
itself. RecorderService, push and consent UI integration remain required before
activation is available. Its startup owner binding passed a data-preserving
physical update and cold launch; `begin` and `commit` passed only in an isolated
physical test namespace. The account decorator delegates optional Supabase client
access so existing cloud features remain reachable after wrapping Auth.

The dormant Flutter `GuardianDriverActivationService` now coordinates the
foreground two-stage call. It requires the current Auth owner and native owner
binding, accepts only a reviewed forward axis, validates the exact native
proposal and signed-in server response, and commits locally only after a
matching, bounded server lease. Failure removes local authority and attempts
an activation-matched server revoke. If a request finishes after account
change or revocation cannot reach the server, the server session may remain
until its eight-hour expiry, but the native capability is unavailable. The
service has no UI caller yet; mount confirmation, recorder use, recipient push
and full end-to-end validation remain required. Six synthetic flow/bridge tests
cover ordering, response shape and account races. A separate physical Android
instrumentation proof exercises the native bridge and encrypted vault with a
random test namespace and synthetic confirmation, then destroys its key and
ciphertext. A later physical Flutter alternate entrypoint exercises the
production `MainActivity` MethodChannel with a random synthetic owner,
proposal/abort, synthetic local commit, active snapshot and disable; the normal
app and sign-in were restored without changing recorder storage. Neither proof
exercises a hosted session, real user consent or alert delivery.

The dormant Flutter review component collects a phone-forward axis and separate
rigid-mount, false-alarm/missed-event and limited-recipient-sharing
acknowledgements. Its result is ephemeral. The activation service rejects a
review older than two minutes, from the future or missing any acknowledgement
before asking native code for a proposal. Cancelling returns no review. The
component is not reachable from the production Guardian screen until delivery
gates pass; it has no hosted activation or device-registration side effect.

The separate recipient review is also dormant. It requires explicit
acknowledgement of experimental detection/delivery limits and of Firebase
installation/device metadata transfer plus private routing-token registration.
It returns a foreground-only, account-labelled result valid for less than two
minutes; cancellation returns none. It does not initialize Firebase, request
Android notification permission, register a token or mutate server state.

The recipient device RPC gateway is also dormant. It validates canonical
account/device/generation identities and bounded credentials, checks the current
Auth owner before and after each guarded registration or revocation call, and
never logs its routing token or credential. No UI or native caller is connected;
recipient credential persistence and account-change cleanup are still required.

### Integration still required

- Connect the tested native encrypted outbox to consent, cancellation notification
  and account-change teardown; no duplicated Supabase refresh-token ownership.
- Current server permission and connection-generation checks at ingest,
  dispatch, receipt and detail reads, with quotas and bounded retention.
- The capability Edge function provides exact bounded ingestion/receipt requests
  to those guarded SQL transitions. It is deployed with processing disabled;
  an unauthenticated synthetic POST returned `503 capability_disabled`.
  Enabled hosted authorization and native integration still need validation.
- Replaceable push provider, opt-in device registration, generic lock-screen
  copy and authenticated details; distinct send/receipt/view semantics.
  The dormant Android envelope parser now accepts only data-only FCM messages
  with exactly `schema_version=1`, a canonical delivery UUID and a canonical
  device-generation UUID. It rejects notification payloads, extra fields and
  malformed IDs before any future local-authority or server check. No receiver
  service, notification, registration or receipt is wired to it yet.
- False-positive fixtures, lifecycle/retry/revocation tests, and background,
  screen-lock, offline/recovery and performance checks on a physical phone.
- Synthetic end-to-end delivery without dangerous driving or real-contact
  alerts. Synthetic success does not validate field sensitivity/specificity.
