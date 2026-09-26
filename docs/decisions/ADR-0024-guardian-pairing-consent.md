# ADR-0024 — Guardian pairing and permission preferences

Date: 2026-09-27

Status: Accepted for M6.7 implementation; hosted validation passed; device/CI validation pending.

## Decision

Guardian is separate from friendship and ranking consent. Use a manually shared
64-character random code, avoiding a camera/QR dependency. Two PostgreSQL v4
UUIDs provide 244 random bits; store only SHA-256 of the code. Codes expire in
10 minutes, are single use and returned once. Explicit recreation replaces the
driver's previous code. App codes are transient and clear on leaving,
backgrounding, reload or expiry. Explicit copy uses the system clipboard with
a disclosure to clear it; no code is logged or stored in the local database.

A code holder may review the driver's consented name snapshot and permission
preferences. Authenticated acceptance discloses the recipient's reviewed name
snapshot. The driver must confirm that identity within 24 hours. Both profiles
may remain private. Support one directional relationship per pair; reversing
roles requires disconnect/re-pair. Either participant may disconnect or block.
Unblocking never reactivates access. Guardian blocks are independent of Social
friendship blocks; the UI states their scope.

Preserve matrix defaults: possible-crash preference on, severe-drive/coarse
state off. Location, speed and history remain unsupported and server-rejected
if true. All delivery is explicitly unavailable until M6.8. No telemetry read
API or alert producer is added. Future delivery must recheck the private
`guardian_allows_v1` predicate at dispatch/read time, never trust cached consent.

No direct client table access. Authenticated RPCs bind writes to expected account
and reviewed revision/profile. Driver alone may change preferences. Lost
responses require explicit reload/review. Limit each anchored 24 hours to
10 code creations, 10 acceptances, 60 previews and 30 permission expansions.
Invalid previews return null so the attempt count commits. Reductions and
disconnection are never quota-limited. Retain at most 100 account pairs per
account and the latest 100 audit events per pair; expose the latest 20 only to
participants. Audit includes action, actor role, permission snapshot and time,
never invite secrets or telemetry. Expired pending relationships are inactive.

## Consequences

No new package, paid service, local schema, Android permission, recorder change
or background worker. A lost create response cannot recover a code; explicitly
cancel/recreate. Validate server transitions with rollback-only synthetic users.
Pairing alone must never imply emergency protection or delivery reliability.
