# Guardian test window remained enabled after operator interruption

- Status: Production disabled and synthetic fixture removed; expiry repair passes
  full CI, is deployed and passes hosted automatic-expiry proof.
- Affected path: M6.8 production capability/dispatch test enablement.

## Evidence and confirmed cause

The reviewed 831–835 fixture was staged on 2026-10-09. Both enable settings were
saved at 16:50:19 UTC. The subsequent dispatch launch was rejected before process
creation because the approval service hit the account usage limit. The operator
job directory and send sentinels are absent. No retry or requeue occurred.

On 2026-10-10, both settings were still true. They were restored to false at
13:44:13 UTC: 20h53m54s enabled, exceeding the reviewed six-minute window.
The existing entrypoints used persistent boolean settings, with no server-side
processing deadline. The operator plan relied on the chat remaining able to
perform shutdown. Fixture expiry limited its authority but did not disable the
HTTP processing path. This is a confirmed control gap, not a passing timed test.

Hosted audit before cleanup confirms the exact private synthetic marker, pending
delivery, zero attempts, no claim and expired event. This fixture sent no message.
This is not a claim that arbitrary external requests were impossible. Existing
worker/capability authorization and SQL permission/expiry checks remained in place.

## Recovery

Both flags are verified false. The worker was rotated to a fresh server-only value
at 13:45:55 UTC; its digest matched, the old value returned 401 and its restricted
local file was deleted. No backend Google key was changed. Action-time-approved
marker cleanup returned all three absence checks true and device_rows=1.
Final counts: zero driver sessions/events/deliveries, one unexpired recipient
device. The phone USB wake setting remains 0; the app job never ran. Real profile,
registration and trips are retained. A credential-free capability POST returns
503 `capability_disabled`.

Private operational proof remains ignored under `.dart_tool/`:
`m6_8_deferred_duplicate_{enabled,resume_disabled,resume_zero_attempts,cleanup_pass,closed}.jpg`.
No credential, real account identifier or raw device log is recorded here.

## Source repair and verification

Both production entrypoints now require a versioned, finite processing window in
addition to their enable flag. The shared gate evaluates the clock on every
request; the guarded fetch adapter rechecks before SQL, OAuth and FCM operations.
Missing/invalid/expired windows deny processing. Warm instances close at expiry
and cannot reopen through a clock rollback. See
[ADR-0028](../decisions/ADR-0028-guardian-processing-windows.md).

Local Node and pinned Deno suites pass all 35 function tests (six new expiry
regressions), lint and type checks. Two network-free deployment-bundle tests pass:
both actual entrypoints deny missing leases and expire while warm with flags still
true. Twelve operator tests and 23 PowerShell gate checks pass. Source repair
[09089ac](https://github.com/atrx07/Traelyx/commit/09089acb16b03c72d794c05422c118b83a00b439)
and full [CI 38058389131](https://github.com/atrx07/Traelyx/actions/runs/38058389131)
pass all jobs, including twelve SQL suites, app/native checks and both APK builds.
No migration, dependency, app update, client payload or permission grant changed.

Reviewed deployment of both tested single-file bundles completed on 2026-10-10,
verified by 14:26:52 UTC. Deployed editor contents match the tested bundles after
line-ending normalization. Legacy JWT settings remain off; both enable flags are
false and processing-window config is absent. Credential-free empty POSTs return
capability 503 `capability_disabled` and dispatch 401 `unauthorized`. No send,
registration, fixture or credential was created during deployment.

The reviewed no-send hosted proof used a finite three-minute window from
14:53:21.191 to 14:56:21.191 UTC. Both endpoints received only `{"probe":true}`,
which is invalid for both APIs and never invokes their SQL/provider path. Active
requests returned 400 `invalid_request` at 14:54:16/17 UTC. Requests after the
deadline returned capability 503 `capability_disabled` and worker-authenticated
dispatch 503 `dispatch_disabled` at 14:56:42/43 UTC, while both flags were still
true. Flags were then restored false, the temporary worker was retired with a
verified digest/old-credential 401, and its restricted ignored file was deleted.
The retained processing-window config is expired. No fixture or send occurred.
Final read-only hosted counts are sessions=0, devices=1, unexpired_devices=1,
events=0 and deliveries=0; the real phone registration remains intact.
Hosted instance reuse is not proven; warm-instance expiry is tested locally in
the source and actual entrypoint bundles. Ignored closure proof is
`m6_8_window_expiry_closed.jpg`; sanitized response evidence is
`m6_8_window_expiry_results.jsonl` under `.dart_tool/`.

## Remaining limits

The original shutdown was recovery; the durable repair is now deployed and its
hosted automatic-expiry proof passes. Keep production disabled except for new
explicitly reviewed finite windows. This closes the missing-deadline defect;
actual duplicate FCM and the remaining M6.8 gates are not complete.
The guard stops new processing/outbound operations, not an HTTPS operation already
in flight; existing transport deadlines still bound those. It does not edit the
dashboard flag or delete fixtures/credentials automatically. Manual restoration,
worker retirement and marker cleanup remain required. Continuous production
monitoring is not authorized by this test-window design. Actual duplicate FCM,
recorder integration and two-phone validation remain pending.
