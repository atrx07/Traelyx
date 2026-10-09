# M6.8 duplicate, expiry and revocation receiver checks

**Status:** Actual duplicate suppression remains unverified: first fixture expired
after receipt/tap; replacement received once without an observed notice. Both
windows are disabled/cleaned with workers retired. Debug-only receiver tracing
passes local/device checks and full CI 37803704159 (`4aecd2e`), including twelve
SQL suites, Flutter/native tests, analysis and debug/release builds. The single
traced live message passes callback/receipt/claim/notice checks and is closed and
cleaned; earlier absence did not reproduce. Review a fresh actual duplicate pair.
**Owner:** agent/maintainer. **Updated:** 2026-10-08. M6.8 remains active.

## Goal and references

Validate a dismissed notice cannot reappear after an actual duplicate FCM message,
and queued messages cannot show a notice after server event expiry or disconnect.
Read only Guardian spec sections 3, 7, 8 and 10, the permission matrix, receipt /
preflight / durable claim implementation, existing dispatcher and manual fixtures.
Prior [locked/offline results](GUARDIAN_RECEIVER_CHECK.md) passed and are closed.

## Proposed review boundary

At most **four synthetic FCM messages** across three sequential fixtures:

| Case | Reserved IDs | Sends | Expected result |
|---|---|---|---|
| Duplicate after dismissal/restart | 741–745 | 2, same delivery/generation | Two receipts/attempts; second message does not recreate the dismissed notice |
| Server expiry after queuing | 751–755 | 1 | Shortened synthetic server expiry denies receipt/display after reconnection |
| Disconnect after queuing | 761–765 | 1 | Guarded driver disconnect increments revision/audits; queued receipt/display denied |

Review each case separately. The first hosted window is the duplicate pair only
(two sends). Expiry and disconnect require their own review and reliable callback
observability; they are not authorized by approval of the duplicate pair.

Use one explicitly reviewed temporary worker value, private ignored file and
fixed-endpoint probe; retire to a fresh server-only value, prove old-value 401 and
delete the local copy after closure. Briefly enable both functions only during
each phase, with current capability/worker authorization unchanged. No scheduler,
app update, driver activation, real-contact alert or personal trip upload.
Google receives the existing routing token and opaque delivery/generation IDs;
Supabase receives only normal receipt requests. Preserve real profile/device,
sign-in, trips, Google key and durable notice claims. Second phone is not needed.

This is a proposed production enable/send/network/fixture-control/cleanup scope.
It needs specific M6.8 review and action-time browser confirmation before execution.

## Concrete controls and validation

Source controls in `supabase/manual_tests/` are standalone SQL, not migrations:

- `guardian_push_requeue.sql`: exact private marker/IDs, received once, attempts=1,
  no claim, one delivery, current authority and over two minutes of event lifetime.
  Requeue once with the same IDs/generation; preserve attempts and native claims.
- `guardian_push_expire.sql`: only the exact accepted-once synthetic fixture.
  Shorten its server event expiry, preserving the already queued provider TTL.
  This exercises current server receipt authorization; it does not test natural
  FCM TTL exhaustion or prove that FCM always delivers a queued message.
- `guardian_push_disconnect.sql`: same accepted-once guards. Transaction-local
  synthetic Auth context calls the existing guarded disconnect API, preserving
  audit/revision semantics. No reusable credential or grant is created.
- Existing marker-checked stage/cleanup scripts are unchanged. Nine ignored
  `.dart_tool/m6_8_{duplicate,expiry,revocation}_{stage,control,cleanup}.sql` copies
  reverse-verify as UUID-only substitutions. Never run the test wrapper in production.
- `supabase/tests/guardian_receiver_controls.sql` runs in disposable PostgreSQL:
  wrong-state/marker refusals, one requeue with attempts preserved, third-send
  refusal, denied expired/disconnected receipts, disconnect audit/cascading cleanup,
  and unchanged receiver routing/generation/credential/lifetime. Added to CI.

The ignored `m6_8_receiver_negative_once.ps1` with `-Case expiry` or
`-Case revocation` requires the
same Wi-Fi-on/data-off/airplane-off baseline, inactive recorder, absent process and
non-stopped package. It waits at most 15 seconds for no active default network,
dispatches exactly once, then holds offline for at most 90 seconds awaiting a
fixed local signal. Create that signal only after the appropriate hosted control
query verifies denial. Independent `finally` restoration runs on success/failure;
abrupt host termination can bypass it, requiring immediate baseline restoration.
No credential or private payload is logged. Syntax is checked without execution.

## Execution and acceptance after approval

1. Recheck changed phone/hosted state, no recording, notification permission,
   exact network baseline, retained native registration, empty queues/one ready
   device, both false digests and no scheduler. Abort if any precondition differs.
2. Duplicate: stage fresh 741–745, establish process absence, enable reviewed
   flags and send once. Require normal receipt/notice, then disable. Tap the
   actual notice to dismiss it; verify unloaded Guardian/not viewed, zero active
   records for this delivery and snapshot only the encrypted vault's hash.
   Re-establish process absence. Run the guarded one-time requeue, reopen the
   reviewed window and dispatch once. Require hosted attempts=2/device_received,
   absent recreated notice and unchanged encrypted vault hash. Do not erase claims.
3. Close both flags and remove only the marker-checked fixture before the next case.
4. Expiry then disconnect: stage each fresh fixture while disabled. Establish
   process absence and enable reviewed flags. Run the negative helper once; after
   provider acceptance/process-absence proof, run its control SQL while the phone
   remains offline. Require all denial/audit booleans true, then create its exact
   local signal. Verify radio restoration and normal callback process start,
   unchanged vault hash, no notification for the synthetic delivery, hosted
   denial and provider_accepted/attempts=1 without receipt/view. Do not open or
   instrument Traelyx before callback observation. Close flags within 90 seconds
   of reconnection or failure, then cleanup before the next case.
5. Provider acceptance with no callback evidence is inconclusive, not a receiver
   rejection pass. Process start alone does not prove `onMessageReceived`; require
   scoped Firebase service/callback evidence and report inference or missing
   observability explicitly. Never resend after an uncertain response or timeout. Cleanup
   still runs; record any late-message observations honestly.
6. Verify final false digests/disabled probes, retired worker 401/local deletion,
   three fixture absence checks and final 0/1/1/0/0. Verify retained sign-in/device
   and network baseline. Save ignored proof, synchronize status, commit/push.

## Pending gates

- [x] Guarded SQL controls and isolated regression wrapper prepared.
- [x] Ignored fixture copies reverse-verified; bounded helper syntax parsed.
- [x] Isolated SQL CI and remaining affected checks pass (37646111095).
- [ ] Obtain concrete hosted review and execute bounded cases.
- [ ] Record observed results/limits and complete cleanup/persistence.

Initial isolated CI run 37645710237 caught an incorrect receipt API name in the
new wrapper. Corrected to the existing `receive_guardian_alert_v1`; no runtime or
hosted change. Corrected full CI 37646111095 passed every job. Repository validation
and diff checks pass. The first requested hosted review covers only the duplicate
pair; expiry/disconnect remain separately gated.

## Duplicate execution checkpoint — 2026-10-07

The maintainer approved the two-message duplicate scope. Fresh phone checks pass:
ADB authorized, no recorder, Wi-Fi on/mobile data off, notification permission
granted and process absent without force-stop after Settings/Home/app-specific
kill. The approved temporary worker was installed at 16:01:04 UTC with matching
digest; its ignored 64-byte local file has inheritance disabled and only the
current Windows user/SYSTEM access. The authenticated disabled dispatch probe passes.
Fixture 741–745 staged with fixture_ready/one_pending_delivery/one_device all true.
Both functions were enabled after action-time approval at 16:05:27 UTC. Immediate
process-absence/non-stopped checks preceded the sole dispatch. The probe returned
processed=1/provider_accepted=1 and zero skipped/failed/deferred. Hosted receipt
was device_received/attempts=1 before manual app opening. Both flags returned to
false at 16:07:27 UTC.

Android had exactly one generic notice for delivery 745. Tapping its actual title
opened unloaded Guardian; the active record count became zero. Only the encrypted
recipient vault hash was saved, without reading contents. A later hosted query
confirmed device_received/attempts=1 (not viewed) and event expiry. The eight-minute
fixture lifetime elapsed during phase transition/resumption; no requeue or second
send occurred, and no event/session lifetime was extended. This is incomplete
duplicate validation, not evidence of a receiver defect or duplicate suppression.

Disabled dispatch/capability probes pass. The worker was replaced with a fresh
server-only value at 16:20:13 UTC, its digest verified, the old value rejected with
401 and the exact local temporary file deleted; credential strings were cleared.
After separate action-time cleanup approval, marker-checked deletion returned all
three fixture absence checks true and device_rows=1; final readiness counts are
0 sessions/1 device/1 unexpired device/0 events/0 deliveries. Fresh phone checks confirm
ADB authorization, network settings 1/0/0, inactive recorder, unchanged encrypted
vault hash and zero active notice records for 745. Ignored proof images:
`m6_8_duplicate_first_expired.jpg`, `m6_8_duplicate_cleanup_review.jpg`,
`m6_8_duplicate_closed.jpg`.

A repeat must use fresh synthetic IDs because durable notice claims for 745 were
preserved. Review a contiguous two-send enable window so dismissal/restart/requeue
can finish within the existing eight-minute event lifetime. Do not extend an
already staged event or erase notice claims to make the check pass. Expiry and
disconnect remain separately gated on approval and callback evidence.

## Fresh duplicate repeat — closed, first notice unverified

Reserved fixture IDs 771–775 avoid the retained claim for 745. Three ignored
`m6_8_duplicate_repeat_{stage,control,cleanup}.sql` copies reverse-verify as
UUID-only substitutions of the CI-validated scripts; their existing eight-minute
event/ten-minute session lifetimes and all guards remain unchanged.

The maintainer approved at most two sends in one contiguous enable window, capped at six minutes:
first normal receipt/notice, actual tap and hash baseline, Settings/Home/background
kill without force-stop, guarded one-time requeue, then one duplicate dispatch.
Keep both functions active only for this bounded reviewed pair; close immediately
after the second receipt or any failure/deadline. Recheck remaining event lifetime
and absent/non-stopped process before each dispatch. Never extend a staged event,
erase claims or retry an uncertain invocation. No network toggling, app update,
scheduler, recorder or real-contact event. The temporary worker and synthetic
fixture require the same verified retirement/cleanup as the first window.

The temporary worker was installed at 16:29:27 UTC on 2026-10-07 and its digest /
authenticated disabled probe verified. Exact staging guards and a fresh six-minute
remaining lifetime check passed. Both flags became true at 16:31:55 after separate
action-time approval. Immediate process absence/non-stopped checks preceded the
sole dispatch: processed=1/provider_accepted=1, with zero other counters. Hosted
attempts=1/device_received passed before app opening. Two scoped Android checks
found zero active package notices; no generic title was visible. The receiver vault
hash was unchanged from the earlier baseline. Notification permission was granted,
there was no explicit app-op denial, and the Guardian channel had high importance.

The duplicate phase was aborted: no tap, requeue, second send, network toggle or
claim erasure. Both flags returned false at 16:34:52, within the six-minute cap.
Disabled probes passed. Worker rotation was submitted at 16:43:25. Automatic
approval review then became unavailable due to the account usage limit; its digest
and old-value 401 were verified on resumption on 2026-10-08, and the exact local
worker file and credential strings were removed. After action-time deletion
approval, all three fixture absence checks and retained device_rows=1 passed.
Final hosted counts are 0/1/1/0/0; both flags remain false. Proof images are ignored:
`m6_8_duplicate_repeat_receipt.jpg`, `m6_8_duplicate_repeat_cleanup_review.jpg`,
`m6_8_duplicate_repeat_closed.jpg`.

The notice absence does not establish a root cause. The existing native transport
has three-second connect/read bounds; a server-committed receipt with an unconfirmed
client response is one hypothesis, not a measured timeout. No claim-file change
was observed. Read-only invocation metadata later showed HTTP 200 at 16:33:02 UTC
with execution_time_ms=1537; server execution does not establish client response
arrival or total network duration. Do not label this a duplicate pass or increase timeouts without
evidence. Before another reviewed send, use the data-free debug receiver stages
described below to identify the stopping gate. Expiry/disconnect remain separately
gated; the second phone is not needed.

## Receiver observability — 2026-10-08

Debuggable builds now emit only fixed `GuardianReceiveStage` enum names under
`TraelyxGuardianReceive`: callback, permission/configuration/preflight rejection,
unconfirmed transport or rejected response, confirmed receipt, current-authority
rejection, claim outcome and attempted/failed post. The sink accepts no dynamic
data or exception, makes no extra request, writes no app file and is inert in
non-debuggable builds. Observer failures cannot alter receiver decisions.
`NOTICE_POST_ATTEMPTED` is not proof of display. Existing authorization, durable
claims, request bounds and no-retry behavior are preserved. All 357 native tests,
Android lint, configured debug build and repository/diff checks pass. The known
local-properties escaping failure required the documented one-time forced lint
rerun; the ignored file was restored exactly. A data-preserving physical update
opens signed-in Guardian with details unloaded, no fatal exception or receiver
trace at inert startup, and unchanged encrypted registration hash. Phone network
is 1/0/0 and recording inactive. Full source CI 37803704159 (`4aecd2e`) passes
every job, including twelve SQL suites, Flutter/native checks and debug/release
builds. The installed build is debuggable and the encrypted registration hash
still matches after startup. The reviewed single live callback subsequently passed
as recorded below; this is observability, not a confirmed fix for the prior absence.

### Reviewed single-message diagnostic boundary — completed

The approved boundary before another duplicate pair was one data-only message using fresh
synthetic fixture 781–785. Its ignored stage/cleanup copies reverse-verify as
UUID-only substitutions of the existing scripts. Stage only while both functions
are false, recheck the inactive recorder / notification permission / retained
registration / network baseline, and establish process absence without force-stop.
Capture the phone's timestamp before the sole send, then read only fixed enum
codes from the `TraelyxGuardianReceive` tag after that timestamp. Preserve Android
logs, registration and durable claims; do not clear logcat or read raw message data.
Require source CI first and fresh scoped plus action-time enable approval.

Use a temporary worker under the same private custody, bounded invocation and
verified retirement/cleanup contract. Close both functions within 90 seconds of
provider acceptance, or immediately on failure; never resend an uncertain call.
Compare stage codes with hosted receipt and scoped active-notice counts before
app opening. A server receipt or post-attempt code alone is not display evidence.
Record the stopping gate without claiming a measured timeout or changing safety /
authorization / claim policy. No network toggle, recorder activation, scheduler,
trip upload or real-contact alert. After closure, no fixture or temporary worker
remains and both functions are false.
The second phone is not needed.

### Diagnostic execution checkpoint — 2026-10-08

The maintainer approved the single-message 781–785 scope. Phone was awakened and
unlocked using the authorized password-free swipe; signed-in unloaded Guardian
was verified. Fresh permission/debuggable/network 1/0/0/no-recorder checks pass.
Process absence and non-stopped package were established without force-stop.
Hosted baseline 0/1/1/0/0 passed. Temporary worker installed at 16:08:31 UTC,
digest/private ignored file/authenticated disabled probe verified. All three
fixture staging guards and a fresh three-minute remaining lifetime check passed.
Both flags were enabled at 16:11:35 UTC after action-time approval. An immediate
process-absence/non-stopped check and fresh device timestamp preceded the sole
dispatch. Its probe returned processed=1/provider_accepted=1, zero other counters.
After that timestamp, the data-free trace contained exactly:
`CALLBACK, RECEIPT_CONFIRMED, NOTICE_CLAIMED, NOTICE_POST_ATTEMPTED`.
Android's scoped active section contained one notice for delivery 785; the
encrypted vault hash changed, consistent with its new durable claim. Hosted
attempts=1/device_received (not viewed) passed before app opening.

Both flags returned false at 16:13:10 UTC, 56.07 seconds after the probe's confirmed
provider-acceptance return. Disabled dispatch/capability probes pass. The actual
generic notice title was tapped; an initial transient UI snapshot failure was
resolved by a fresh observation confirming signed-in Guardian and zero notice
records. No alert reload/view acknowledgement was performed. The temporary worker
was retired to a fresh server-only value at 16:20:07, digest verified, old value
rejected with 401, exact local file deleted and credential strings cleared.
After action-time deletion approval, marker-checked cleanup returned all three
fixture absence checks true and device_rows=1. Final readiness counts are
0 sessions/1 device/1 unexpired device/0 events/0 deliveries. Fresh phone checks retain
encrypted registration/provider consent marker, network 1/0/0 and inactive recorder.

The earlier missing-notice symptom did not reproduce. These stages confirm a
successful callback path and provide future stopping-gate evidence; they do not
establish the prior failure's cause or prove a permanent notice fix. No retry,
second message, network toggle, trip upload, schema or backend change occurred.
Actual duplicate suppression, expiry/disconnect, recorder and two-phone gates
remain pending. Ignored proof: `m6_8_diagnostic_positive.jpg`,
`m6_8_diagnostic_cleanup_review.jpg` and `m6_8_diagnostic_closed.jpg`.

The only app change is debug-only stage tracing; no backend runtime, schema,
dependency, sampling, recorder lifecycle or permission contract change.

### Traced duplicate pair — closed after first phase

The maintainer approved a fresh 791–795 pair: at most two sends / one guarded
requeue in one contiguous enable window capped at six minutes. Three ignored
`m6_8_traced_duplicate_{stage,control,cleanup}.sql` copies reverse-verify as UUID-only
substitutions. Fresh phone permission/network 1/0/0/no-recorder/process-absence/
non-stopped checks passed. Worker installed at 16:41:14 UTC, private ignored file
and digest verified; authenticated disabled dispatch probe passed. Staging guards
all true. Both flags became true at 16:43:57 after action-time approval. Only the
first message was sent: provider acceptance, fixed CALLBACK/RECEIPT_CONFIRMED/
NOTICE_CLAIMED/NOTICE_POST_ATTEMPTED stages, one scoped Android notice and hosted
attempts=1/device_received passed. Actual notice tap opened unloaded Guardian;
an initial transient null-root snapshot resolved on fresh observation. Its notice
disappeared, the encrypted vault hash was saved and the process was background
killed without force-stop. The exact guarded requeue refused: event expiry was
16:49:49.398678 UTC and the required remaining two-minute buffer had elapsed.
No requeue, second send, claim erasure or lifetime extension occurred.

Both flags returned false at 16:49:18 (5m21s active, within the six-minute cap).
Disabled probes passed. Worker rotation was saved at 16:57:02; verification was
interrupted by the usage limit. On 2026-10-09, the hosted digest differs from the
temporary file, the old credential returned 401, and that exact local file was
deleted. After action-time deletion approval, marker-checked cleanup returned
fixture_user_absent/fixture_connection_absent/fixture_delivery_absent all true,
device_rows=1. Final hosted counts are 0 sessions/1 device/1 unexpired device/
0 events/0 deliveries. Phone ADB authorization, notification permission,
registration/consent marker, network 1/0/0 and inactive recorder pass. Ignored
proof: `m6_8_traced_duplicate_cleanup_pass.jpg`, `m6_8_traced_duplicate_closed.jpg`.
This is an incomplete operator window, not duplicate-suppression evidence or a
confirmed receiver defect. No app/server behavior or security limit was changed.

### Bounded phone transition — operator helper

`tool/guardian_duplicate_phone.mjs` reduces model/tool round trips during the next
reviewed pair. It never sends, requeues, changes flags/network, force-stops, clears
logs or deletes claims. Outputs are fixed booleans; subprocess failures are
redacted. Only a hash of the encrypted vault is stored in ignored `.dart_tool`.
The CLI phase deadline is 75 seconds, individual ADB calls at most 15 seconds.
After provider acceptance, fixed trace/notice observations wait at most forty
reads spaced 500 ms apart for asynchronous receipt (also inside that deadline).
Denial/unexpected stages abort immediately; no request or tap is repeated.
Missing notification sections, ambiguous titles, active recorder, wrong current
Android user state and unexpected trace sequences fail closed. A transient UI
root is observed at most three times without repeating a tap. The physical
read-only `preflight` passes; twelve operator tests and syntax pass. First and
duplicate live phases have not yet been exercised through this helper.
The app also opens Guardian with details unloaded; its explicit read-only phone
check shows the retained registration and the Stop notices control. No registration,
withdrawal or alert reload was performed during the resumed check.
Full source CI 37944918981 (`16cf9a5`) passes every job: Guardian functions,
twelve SQL suites, operator/app/native tests, analysis and debug/release builds.
Fresh ignored `m6_8_batched_duplicate_{stage,control,cleanup}.sql` copies reserve
801–805 and reverse-verify as UUID-only substitutions. This was the pre-window
checkpoint; the subsequent approved attempt is recorded below.

For a fresh, separately reviewed pair (fresh IDs required):

1. While both flags are false, complete source CI, unlock/wake the phone and use
   `preflight <adb-path> <serial>`. Establish absent/non-stopped process, network
   and fresh fixture lifetime before action-time enable confirmation. Recheck
   lifetime/process immediately afterward; do not dispatch if the buffer is gone.
2. Capture a fresh device timestamp, invoke the existing single-send probe once,
   then immediately run `first <adb-path> <serial> <delivery-uuid> <timestamp>`.
   It verifies fixed positive stages and exactly one active record, taps the
   observed generic title, requires unloaded Guardian/no notice, stores the vault
   hash and backgrounds/kills without force-stop in one invocation.
3. Verify the first hosted receipt and perform the unchanged marker-checked
   guarded requeue while its existing two-minute buffer remains. Confirm true,
   absent/non-stopped process and fresh lifetime; capture a new device timestamp
   and invoke the single-send probe once. Never retry an uncertain invocation.
4. Run `duplicate <adb-path> <serial> <same-delivery-uuid> <new-timestamp>`.
   Require CALLBACK/RECEIPT_CONFIRMED/CLAIM_UNAVAILABLE, zero active notices and
   unchanged vault; separately verify hosted attempts=2/device_received. Close
   both flags immediately afterward or on any failure/deadline. The existing
   six-minute enable cap and eight-minute fixture lifetime remain unchanged.
5. Verify closure, retire worker with digest/401/local deletion, and obtain the
   action-time fixture cleanup confirmation. Preserve real registration and all
   durable claims. Do not stage a new event or extend a lifetime inside the window.

### Batched pair 801–805 — aborted and cleaned

After fresh authorized phone/recorder/network/process and lifetime guards, the
temporary worker was installed at 14:47:05 UTC on 2026-10-09, digest/private file/
authenticated disabled probe verified. All staging guards passed. Both flags
enabled at 14:50:48 after action-time approval. The sole dispatch acceptance
returned at 14:51:59.1884188 UTC (processed=1/provider_accepted=1, zero others).
The phone helper aborted before its UI snapshot/tap/hash baseline. Immediate
closure returned both flags false at 14:52:35 (1m47s active); no guarded requeue,
second send, network change or lifetime extension occurred.

Scoped PowerShell observations confirmed CALLBACK/RECEIPT_CONFIRMED/NOTICE_CLAIMED/
NOTICE_POST_ATTEMPTED, one active Android record and hosted attempts=1/
device_received (not viewed). A direct Node parser check rejected the raw header;
the actual header is CRLF, whereas its LF-only expression required LF immediately
after the colon. Normalization and CRLF positive/empty fixtures fix this confirmed
operator defect. The corrected parser reads the existing notice. A later full
helper attempt remained unverified; subsequent trace reads contained no stages.
That does not establish another stopping cause or a live helper pass. Static
operator failure codes now identify failed gates without raw output/exceptions.
Twelve operator tests, syntax and physical parser checks pass. Full repair source
CI 37949413443 (`77dd2c1`) passes every job, including app/native checks and both
APK builds. A fresh local `TraelyxGuardianOperatorProbe` tag (separate from the app
trace) confirms Node/ADB timestamp observation. This is tooling evidence, not an
app callback or receipt. No app/server receiver, authorization, timeout or claim
policy changed.

Worker retirement at 14:55:42 has matching digest, old-value 401 and exact local
deletion. Credential strings were cleared; the backend sender key is unchanged.
The event expired at 14:56:29.950133 UTC. After shutdown, a manual tap of the sole
existing generic notice opens Guardian with details unloaded; no reload/view
acknowledgement was performed. After action-time confirmation, marker-checked
cleanup returned all three fixture absence checks true and device_rows=1.
Final hosted counts are 0 sessions/1 device/1 unexpired device/0 events/0 deliveries;
the corrected physical parser confirms zero notices for 805 and no recorder.
Real registration/profile/trips are retained. Actual duplicate suppression
remains unverified. Ignored proof:
`m6_8_batched_duplicate_{enable_review,enabled,disabled,cleanup_review}.jpg` and
`m6_8_batched_duplicate_first_codes.json`. Do not reuse 805 or erase durable claims.
Closure proof: `m6_8_batched_duplicate_cleanup_pass.jpg`,
`m6_8_batched_duplicate_closed.jpg`.

### Corrected pair 811–815 closed (2026-10-09)

The reviewed UUID-only fixture passed staging/lifetime guards and the first full
operator phase. Enable at 15:33:25 UTC; sole acceptance at 15:34:35.3880541 UTC.
The helper confirms callback/receipt/claim/post, taps the actual notice to
unloaded Guardian, preserves the encrypted-vault hash and restarts the background
process without force-stop. The temporary USB awake setting was restored to 0.
The guarded requeue returned true, but the next preflight refused before dispatch
because operator latency exhausted the existing event/window buffers. Hosted
attempts remained one with no claimed worker; the second sentinel is absent.
No duplicate send or lifetime extension occurred. This proves the first helper
phase live, not the duplicate phase.

Both flags closed at 15:38:30 UTC (5m05s active). Worker retired at 15:46:58 with
matching digest, old-value 401 and exact local deletion. After action-time
approval, marker-checked cleanup returned three absence checks true/device_rows=1.
Final hosted counts are 0 sessions/1 device/1 unexpired device/0 events/0 deliveries.
Physical read-only preflight passes and recorder is inactive. Real registration,
profile/trips and backend Google key remain intact. Preserve the local claim/hash;
do not reuse 815. Ignored proof: `m6_8_corrected_duplicate_first_codes.json`,
`m6_8_corrected_duplicate_{enabled,disabled,requeued_unsent,cleanup_pass,closed}.jpg`.

### Bounded pair operator bridge (live validation pending)

`tool/guardian_duplicate_pair.ps1` defaults to Plan mode: no ADB, cloud requests
or sends. Run mode requires explicit reviewed scope, fresh fixture/worker/lifetime
checks and action-time enable approval. Prepare the command and requeue SQL
before enabling; launch the prewritten command immediately afterward. Pass the
fresh synthetic delivery UUID, hosted event expiry and six-minute window deadline
as UTC `DateTimeOffset` values. No function/SQL mutation is performed by the script.

The bridge allows at most two one-shot dispatch invocations. It rechecks lifetime,
default network, absent/non-stopped app process and recipient preflight; captures
a fresh device timestamp; writes a create-only sentinel before each invocation;
then runs the existing first/duplicate helper. Any uncertain acceptance fails
without retry. A second immediate budget check accounts for preflight latency.
It requires first-event lifetime >180 seconds, duplicate lifetime >120 seconds
and remaining enable time >165 seconds (45s dispatch +75s phone observation
+45s browser shutdown margin). Existing SQL guards remain unchanged.
ADB subprocesses are limited to 15 seconds and emit no raw errors. The adapter
passes physical read-only network/USB-wake checks; the new bridge Run mode has
not yet been exercised live.

After first-phase success, it restores the USB awake setting and writes a local
`.dart_tool/guardian-pair-<suffix>/waiting.json` with delivery, fresh correlation
nonce and `phase=waiting_for_guarded_requeue`. The browser operator must check
that file and `first-passed.json`, execute the already prepared guarded requeue
through the visible SQL Editor, and observe the new successful result. Only then
write a create-only `requeue-confirmed.json` in the same ignored directory with
exactly `delivery`, `nonce` and boolean `guarded_requeue_confirmed=true`, matching
the waiting file. Never signal a stale, failed or unobserved SQL result. The nonce
is a local correlation value, not an access credential. The bridge waits at most
45 seconds and refuses missing/extra fields, wrong delivery/nonce or non-boolean
confirmation; after a valid gate it starts the duplicate phase immediately.

The operator must disable both functions immediately on success/failure/timeout
and always within six minutes, then retire the worker and obtain action-time
cleanup confirmation. Keep the shutdown UI ready while the job runs. Script
output explicitly requests closure but does not close cloud flags itself. Source
syntax, twenty-three local budget/correlation/quoting/Plan checks and twelve existing operator
tests pass. Full source CI 37956582373 (`223cc48`) passes all jobs, including
Edge functions, twelve SQL suites, app/native tests and both APK builds. An
actual paired live run remains pending. No
runtime, schema, dependency, receiver authorization or claim-policy change.
Fresh pair scope and action-time enable/cleanup confirmations remain required.
Actual duplicate suppression is still unverified; no fresh fixture is staged.
The UUID-only 821–825 pair was reviewed and staged, but expired at
16:30:36.990944 UTC while awaiting action-time enable approval. At resume,
hosted pending/attempts=0/unclaimed/expired checks pass. No enable, requeue,
send or bridge Run occurred. Both flags remain false. Worker retirement at
16:37:37 UTC passes digest/old-value 401/exact local deletion; credential strings
were cleared. Approved marker cleanup returns three absence checks true and
device_rows=1; final counts 0/1/1/0/0 and USB wake setting 0 pass. Real registration,
profile/trips and Google key remain intact. Ignored proof:
`m6_8_bridge_duplicate_{expired_unsent,disabled,cleanup_review,cleanup_pass,closed}.jpg`.
No fixture, temporary local worker or enable window is active.

For the next fresh reviewed pair, prepare the exact enable form, local SQL and
launch/browser handoff before requesting approval. Start the eight-minute fixture
only after approval arrives, with both functions still disabled. Observe staging
guards and fresh hosted lifetime, then immediately apply the exact approved enable
change. This avoids consuming fixture lifetime while awaiting user response; it
does not extend lifetime or waive action-time confirmation. A changed action or
approval rejection still requires renewed review. Never use an expired fixture.

These checks do not prove natural Doze, long outages, reboot/direct boot, recorder
integration, two-phone delivery or emergency reliability. Complete those remaining
M6.8 gates independently; M7 is not authorized.
