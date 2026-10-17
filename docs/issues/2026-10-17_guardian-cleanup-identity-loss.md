# Guardian cleanup identity lost after destructive vault failure

- Status: durable source repair; local and CI evidence tracked in the active M6 plan.
- Discovery: synthetic prerequisite check during M6.8, not a reported field incident.
- Fix commit: the atomic `Retain Guardian cleanup IDs through vault failure` change
  introducing this record; exact source hash/CI recorded in the active execution plan.

## Confirmed cause and evidence

Successful native activation removed its proposal cleanup reservation after
persisting the driver lease. A later encrypted outbox write failure intentionally
destroyed the vault key/file to prevent uncertain authority from being reused.
That also removed the only remaining owner/activation identity needed for an
exact server revoke. The separate journal was empty. Local monitoring failure did
not prove that the hosted session or queued delivery was revoked.

`GuardianCleanupRetentionTest` reproduced this with synthetic identities and real
authenticated encryption: activate, fail event insertion, reopen both stores.
Before repair, the driver vault was absent and the expected cleanup ticket was
missing. The regression failed before the implementation change and passes after it.

## Repair and recovery

Retain the independent, encrypted ID-only proposal reservation throughout the
committed lease. Journal affected lease IDs before outbox mutation/replacement;
deny mutation if journal persistence is uncertain. Binding adopts readable older
leases, including journaling before a recovery pruning write. Stop removes local
authority first; the signed-in owner then retries an exact guarded server revoke.
Only confirmed server cleanup after local Stop removes the ticket. Active tickets
cannot be confirmed, and exact cleanup preserves other owners' tickets.

This is a code repair, not a temporary workaround. No real session/data was
created, revoked or recovered during the reproduction. An identity already lost
by an older build cannot be reconstructed locally; independent server expiry
still applies. Never report local off/failure as successful hosted cleanup.

## Regression coverage and limits

Nine new native tests cover destructive write/readback failures during enqueue,
reservation, cancellation, recovery, completion and replacement; idempotent active
retention; readable legacy adoption; journal failure/capacity; restart and exact
confirmation isolation. A foreground regression covers failed server cleanup and
retry after local authority is lost. Existing tests now assert the stronger
lifetime-reservation contract, including denied confirmation while active.

The isolated Tecno Android Keystore proof also passes retained cleanup after
deleting only its disposable capability key/file and reopening the journal.
This models the destructive outcome; it does not inject a real disk failure.
The configured pilot-off update opens with saved sign-in. All 11,857 recorder
file hashes and the real recipient vault remain unchanged.

No schema migration, dependency, network field, recorder sample/permission change
or automatic server request. The journal still contains at most eight ID-only
tickets under its separate key/domain. It cannot guarantee recovery after both
stores are corrupted/lost, app data is cleared, or a legacy lease is unreadable
before adoption. Physical disk/Keystore-failure injection and reviewed hosted Stop
remain untested. See [ADR-0030](../decisions/ADR-0030-guardian-driver-revision-fencing.md)
and [Guardian delivery contract](../technical/GUARDIAN_ALERTS_V1.md).
