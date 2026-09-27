# ADR-0026: Restrict background Guardian delivery with revocable capabilities

- Date: 2026-09-27
- Status: implemented and locally tested; hosted deployment pending approval

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

The migration adds empty private tables/RPCs. It neither registers Firebase
devices nor sends alerts by itself. Native encrypted storage, consent UI,
recorder attachment, HTTP v1 provider/Edge Function and background delivery QA
remain M6.8 gates. No sender credential has been created. Distributed revocation
cannot erase a generic notification already displayed; details always require
fresh authorization and FCM payloads must contain no event or identity details.
