# ADR-0030: Fence delayed Guardian activation with an owner revision

- Date: 2026-10-14
- Status: server deployed; local, full CI and approved hosted checks pass; native/client integration implemented; live driver validation pending

## Context

An activation HTTP request can finish after its caller times out. The old exact
revoke deletes a matching session or succeeds when none exists; a delayed
activation can then recreate that session. An old revoke also conflicts with a
replacement, leaving cleanup tickets unable to settle. Persistent local proposal
IDs are necessary but cannot close this server ordering race by themselves.

## Decision

Keep one private `guardian_driver_controls` row per owner with a nonnegative
bigint revision. Its RLS is enabled and all direct client/worker privileges are
revoked. An explicit signed-in owner-only read returns the revision as decimal
text, without exposing sessions, credentials or another account's revision.

The v2 activation requires that reviewed revision to match under the same stable
`auth.users` row lock already used by ingestion/dispatch. A successful new
activation advances it. An exact retry with matching credential and an existing
session keeps its original expiry; it cannot recreate an absent session from a
stale revision. Every exact revoke advances the revision, including an absent or
superseded session, invalidating earlier activation requests. It deletes only a
matching session and revokes only deliveries belonging to that activation.
Cleanup of an old activation therefore settles without stopping a newer session.
Concurrent reviews may be rejected conservatively and require a fresh review.

The legacy v1 RPC becomes cleanup-only. Older dormant clients cannot bypass the
revision check; their exact cleanup remains usable. Existing session identities,
credential hashes and expiry timestamps are preserved by the migration. No
unbounded tombstone history, new dependency, event field, scheduler or processing
enable is introduced. Revision exhaustion rejects mutation without wrapping.

## Integration and validation

Local rollback-only SQL checks cover access denial, stale activation after
revoke, fixed retry expiry, replacement preservation, exact delivery cleanup,
replay denial and bigint boundaries. A disposable upgrade check applies and
rolls back the migration around a legacy session. All existing SQL suites remain
required. All 13 suites, upgrade checks and full source CI 38603573947 (`b301544`)
pass. The approved atomic deployment verifies migration history, private RLS,
owner-only RPC grants and synthetic rollback, all true. Both enable flags remain
false; no real activation or push was performed.

The native/client integration now reserves exact proposal IDs durably before
returning a capability. Stop erases local authority before retrying cleanup; the
client obtains a revision only after cleanup and checks consent/account state
after awaits. Commit retains its independent cleanup reservation throughout the
lease lifetime; only exact server cleanup after local Stop can confirm it.
Reviews serialize per bound account, while Stop/sign-out invalidate their callbacks. Exact abort cannot
erase a newer lease. The wire adapter uses validated decimal text across the full
bigint range. No revision read is added to startup/status. It uses fresh
activation UUIDs; this contract fences delayed requests, not deliberate
reuse of an old UUID with a freshly obtained revision by its signed-in owner.
Driver controls and sending remain dormant until their remaining gates pass.

## Cleanup retention through vault failure (2026-10-17)

A synthetic destructive-write regression showed that removing the proposal
reservation at commit could lose the only exact cleanup identity when a later
outbox write destroyed its key/file. Keep that ID-only reservation after commit,
independently encrypted from the capability/outbox. Before outbox mutation or
replacement, journal the affected lease IDs; journal uncertainty denies the
mutation before destructive IO. Owner binding adopts a readable older lease, and
recovery journals before a pruning write. Repeated retention does not rewrite a
present ticket. Active/proposed identities still cannot be confirmed as revoked.

No schema, provider, network field, automatic reconciliation or server grant
changes. Explicit Stop still erases local authority before retrying the guarded
server revoke. Journal failure and hosted failure remain visible uncertainty;
loss of both stores or a legacy identity already unreadable before adoption
cannot be repaired by this contract. Synthetic regression tests reopen both real
authenticated-encryption stores after failures. Physical fault injection and
hosted live Stop are unverified.

## Foreground result consumption (2026-10-17)

The default-off debug driver controls give each foreground activation a single-use
cancellation token. It remains cancellable until the controller synchronously
accepts the completed result. This closes the gap between durable native commit
and UI consumption: background/navigation/account loss can still start memoized
exact abort/revoke cleanup, while late success cannot appear. After acceptance,
ordinary backgrounding does not revoke completed consent. The same owner/exact
activation checks and journal handle failed cleanup; an old token cannot target a
newer review. This adds no provider, schema, server access grant or automatic send.
