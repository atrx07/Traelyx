# ADR-0026: Restrict background Guardian delivery with revocable capabilities

- Date: 2026-09-27
- Status: server contract implemented; local and approved hosted tests pass

## Context

Flutter owns Supabase Auth refresh. A native background sender must not compete
for the same rotating refresh token or receive a service-role credential. Pairing
alone does not authorize local monitoring or Firebase device registration.

## Decision

After explicit signed-in activation, the server stores only a SHA-256 digest of
a random 256-bit native capability, bound to an owner and activation UUID with an
eight-hour expiry. It authorizes only minimized alert ingestion/dispatch through
a trusted Edge Function. The app must keep the capability encrypted, clear it on
account change, and use a new activation UUID for a fresh session. Retries of the
same activation never extend its expiry. Activation replacement/disable revokes
all old deliveries. The Edge Function alone receives the backend service role.

Recipients separately opt into at most three device registrations per account.
Each registration binds an opaque device UUID, generation, FCM routing token,
digest of a receipt-only capability and 30-day expiry. Replacement invalidates
old delivery generations; opt-out deletes the row and its deliveries. The FCM
token is a routing address, not authorization to read event details. The native
adapter must delete token/installation registration after local opt-out.

The native provider boundary writes a no-backup cleanup marker before any token
request. It records no account or token. Owner binding preserves a valid
same-owner receipt across restart; sign-out, replacement, expiry or an orphaned
marker first erase local receipt authority, then require confirmed deletion of
the Messaging token and Firebase installation before another owner binds.
Deletion failure retains the marker and fails closed. The server row must also
be revoked while its owner is authenticated; local provider deletion alone is
not complete opt-out. Unexpected Auth loss needs a separate reconciliation path
before live device registration is exposed.

Explicit app sign-out now reads the native device identity and performs its
guarded server revoke while the old Auth owner is still signed in. Only then
does it clear native/provider authority and remove the local Auth session.
Offline server failure leaves that Auth owner and local binding available for
retry; a failure after confirmed server revoke retries local cleanup without
repeating the RPC. This does not reconcile unexpected account replacement.

Events carry no trip ID, coordinates, speed, raw samples, name, or arbitrary text.
They are explicitly **experimental client-reported signals**, not server-verified
crashes. The server validates the exact versioned envelope, at least 30 seconds
of cancellation age, ten-minute freshness, stable identity, quotas and consent.
It cannot establish physical truth from a minimized client report.

Delivery rows bind the exact connection revision and device generation. Current
active/unblocked directional permission, driver activation and device opt-in are
checked at claim, receipt and details read. Re-pairing never revives an old alert.
Delivery states distinguish backend acceptance, provider acceptance, device
receipt and the recipient's explicit authenticated view. No stage claims help
was contacted or a person acted on a notification.

Only signed-in owners may manage their activation/device and only entitled
participants may read minimized details. Ingest, dispatch claims, results and
receipt are service-role-only RPCs. Tables/helpers have no direct privileges for
PUBLIC, anonymous, signed-in or service-role callers; RLS stays enabled.

## Limits and retention

- At most ten events per driver in the preceding 24 hours, at most 30 device
  targets per event, and six dispatch attempts with bounded exponential delay.
- Severe alerts have a five-minute cooldown. Crash-like alerts have a 30-minute
  same-kind cooldown and may escalate a preceding severe alert.
- Event detail access expires after ten minutes. At most ten minimized event
  records and their bounded deliveries remain per driver; stale rows are pruned
  on subsequent ingestion or removed on account deletion. This is bounded
  retention, not a promise of immediate physical deletion at expiry.
- Driver activation is one row per account; devices are at most three rows per
  account. Expired devices are pruned on the next device registration.

## Remaining implementation boundary

### Scheduled retry follow-up (deployed 2026-09-27)

Backend acceptance ends the native ingestion retry lifecycle. Therefore a
trusted scheduled worker must retry accepted delivery rows independently of the
driver being online. Migration `20260927020000_guardian_dispatch_worker.sql`
adds a partial due-work index and three service-role-only RPCs: bounded batch
claim, current target authorization, and version-2 provider completion. PUBLIC,
anon and authenticated cannot execute them; direct table access stays revoked.

Claims use row locking / SKIP LOCKED, at most 30 rows and a 120-second reservation.
Only delivery/claim UUIDs leave the claim RPC. After OAuth setup, the worker must
recheck the current connection revision, opt-in device generation, activation,
block state and expiry before receiving the routing target. A new reservation
invalidates old callbacks. Completion consumes the claim and preserves earlier
receipt/view states. Transient failures respect a bounded provider Retry-After,
at least 60 seconds and the existing exponential delay; six attempts and the
ten-minute event expiry remain. Permanent failures are terminal.

Provider/network failure after a send but before its recorded result can still
produce duplicate generic pushes. The receiving app must deduplicate delivery
IDs. Revocation racing with an already in-flight provider call cannot retract
its generic notification; receipt and details still recheck permission.

Unexpected Auth loss cannot call the signed-in device revocation RPC. Preserve
only the owner, device and generation IDs needed for a later same-owner retry in
a separate encrypted, no-backup native journal. Keep the journal bounded and
never silently evict an unconfirmed row based on the local clock; refuse new
registration when capacity or journal integrity is uncertain. The journal is
now captures IDs before native local receipt erasure. Signed-in same-owner
server reconciliation remains a separate gate before device registration can be
exposed.

The migration does not install a scheduler, create credentials, register devices
or send messages. Edge dispatch, scheduler setup and receipt handling remain
integration gates. All eight local SQL suites pass. Following the maintainer's
exact approval and green CI run 36334866638 (`85ece8f`), the atomic production
deployment/rollback-fixture bundle passed all four verification checks.
The hosted fixture suite first locks and requires an empty delivery queue, so
global claims cannot touch real deliveries. Non-empty production queues require
an isolated test project instead; fixtures and migration roll back on failure.

The isolated `guardian-dispatch` Edge adapter is implemented and deployed with
dispatch explicitly disabled.
It uses built-in Web APIs, fixed RPC/provider destinations, a separate worker
secret, six claims per invocation and bounded three-way concurrency. OAuth
configuration is validated before claiming; target authorization immediately
precedes sending. Eighteen synthetic tests include signed assertions and the
combined HTTP flow. Hosted unauthorized and disabled checks pass. The dedicated
Google sender has only FCM send permission; organization policy blocked creation
of its JSON key, so provider authentication remains unresolved. Credential/IAM
review and subsequent integration gates are recorded in
`../reference/GUARDIAN_DISPATCH_SETUP.md`.

The separate `guardian-capability` Edge draft forwards only the exact minimized
ingestion and device-receipt shapes to the two guarded service-role RPCs. Its
body/deadline limits, disabled default and redacted errors pass eleven local Deno
tests. It has not been deployed or enabled. Hosted and native integration gates
are in `../reference/GUARDIAN_CAPABILITY_SETUP.md`.

The migration adds empty private tables/RPCs. It neither registers Firebase
devices nor sends alerts by itself. The isolated native encrypted lease/outbox
passes unit and physical Keystore tests. Consent UI, account teardown/runtime
attachment, provider authentication and background delivery QA remain M6.8
gates. No sender credential has been created. Distributed revocation cannot
erase a generic notification already displayed; details always require fresh
authorization and FCM payloads must contain no event or identity details.
