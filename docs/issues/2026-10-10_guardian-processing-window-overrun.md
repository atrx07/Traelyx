# Guardian test window remained enabled after operator interruption

- Status: Production disabled and synthetic fixture removed; source expiry repair
  passes local checks, deployment and hosted expiry proof pending.
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
true. Twelve operator tests and 23 PowerShell gate checks pass. Source commit/CI
evidence will be recorded after persistence.
No migration, dependency, app update, client payload or permission grant changed.

## Remaining limits

The shutdown above is recovery. The durable repair is not deployed yet; production
must stay disabled until reviewed deployment and hosted expiry checks pass.
The guard stops new processing/outbound operations, not an HTTPS operation already
in flight; existing transport deadlines still bound those. It does not edit the
dashboard flag or delete fixtures/credentials automatically. Manual restoration,
worker retirement and marker cleanup remain required. Continuous production
monitoring is not authorized by this test-window design. Actual duplicate FCM,
recorder integration and two-phone validation remain pending.
