# ADR-0031: Isolate Guardian ingest IO from authority and vault control

- Date: 2026-10-17
- Status: dormant implementation; live runtime integration and physical validation pending

## Context

Guardian authority, exact Stop, encrypted outbox transitions and recorder-sidecar
control share one serialized native worker. Blocking that worker on HTTPS would
delay revocation and evidence handling. Releasing a timed-out operation's busy
slot while its transport remains blocked could instead accumulate requests,
threads or queued retries.

## Decision

Keep reservation, cancellation and result persistence on the control worker.
Require a bound, current authority snapshot and an explicit per-event handoff
gate from the future cancellation-affordance integration. Persist the attempt
before submission; reservation remains the cancellation boundary even if a
subsequent gate or executor rejection prevents IO.

Use one separate network executor with one transient queued slot. The dispatch
coordinator permits one unsettled operation, including after a local timeout.
The queued slot only covers the old executor frame unwinding after posting its
completion; it does not authorize parallel requests. No Auth refresh token,
vault access or recorder operation belongs on the network worker.

Each job has a one-use atomic permit. Its clock check rejects a delayed handoff
after the ten-second local deadline, reboot, rollback or clock failure. The host
must invalidate queued permits **before** owner, activation, Stop or local sending
gate changes. A request already begun cannot be retracted by this permit;
server revocation/expiry remains independent enforcement.

Marshal callbacks onto the control worker. Compare the exact lease and reserved
alert before persisting the result. A ten-second local deadline records an
unconfirmed result, denies queued handoff and ignores later acceptance. Keep the
busy slot until transport completion is reported; if transport never returns, dispatch
stays unavailable for further work rather than growing resources. This is a
local accounting deadline, not a promise that a remote request is cancelled.
Control/storage failures fail dispatch closed without throwing into recording.

The coordinator returns a monotonic wake time instead of creating a polling
timer. A future host must pump after relevant control events/completions and
schedule the returned wake, with no timer when there is no pending work.
Actual Android runtime scheduling, cancellation UI/notification, reviewed
activation and live network/device tests remain separate gates. These new
classes have no Android runtime caller in this unit.

## Consequences

- Existing encrypted schema, retry identity/backoff and six-attempt limit stay intact.
- Synthetic tests can control both executors and exercise late/duplicate callbacks.
- A stuck request can reduce Guardian availability until it drains or the process
  restarts. It cannot delay the raw recorder through this control boundary.
- Process death retains the durable attempt reservation. Future recovery still
  needs current owner/lease/clock checks and cancellation-affordance validation.
- Backend acceptance never means recipient receipt, display or assistance.
- No new dependency, permission, scheduler or production enable is introduced.
