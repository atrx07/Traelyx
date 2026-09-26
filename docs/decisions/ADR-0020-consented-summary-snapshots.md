# ADR-0020 — Consented private summary snapshots

**Status:** Accepted 2026-09-26

## Context

M6.3 permits optional compact summary sync while retaining local trips and
raw evidence as authoritative. Account creation is not upload consent.
The existing shared anonymous vehicle cannot safely be reassigned whenever
a different person signs in on the same installation.

## Decision

Add `trip_account_links` in local Drift schema 2. Its trip primary key makes
the account association immutable through the application. Preserve original
trip/vehicle/baseline identifiers and namespaces. Link only the completed
UUID trips included in an explicit review; compare their current summaries
with the reviewed snapshots inside the consent transaction. The transaction
records links and versioned `sync_queue` operations together.

The payload is an exact allowlist: authenticated owner, opaque source trip
ID, summary version, nullable duration seconds, distance metres, overall
score with its scoring version, and active-version aggregate event count.
Exclude dates, vehicle metadata, routes, raw telemetry, email, and arbitrary
JSON. Preserve absent evidence as null. Private client summaries do not
establish ranking eligibility.

Upload immutable snapshots using `ON CONFLICT DO NOTHING`, then compare
allowlisted readback with the queued payload. Lost acknowledgements can be
retried; conflicting cloud snapshots are blocked rather than overwritten.
Revisions/merge behavior require a future explicit versioned contract.

Use a foreground user-requested batch of at most 50 operations. Persist
retry count and exponential delay (30 seconds to one hour); do not run a
background timer, automatically opt in new trips, or block finalization.
Recheck the current account before every request. Requests already in flight
may finish after sign-out or cancellation. Queue cancellation retains local
account links; local trip deletion removes the link and queue but does not
delete a cloud copy. Raw-only cleanup preserves summary state. Finalization
replay preserves the existing summary-sync state.

The cloud foreign key for `trip_summaries.user_id` now references `auth.users`
directly, allowing private sync without inventing a username/profile ahead
of M6.4. RLS, column grants, and composite vehicle ownership remain intact.
No new package, provider, native permission, or recorder sampling change.

## Validation and recovery

Test v1 full/settings-only upgrades, preservation of evidence and queue rows,
account switching, consent cancellation, malformed payloads, partial failures,
backoff, disk reopen, SDK HTTP request shape, and duplicate/conflict handling.
Verify real authenticated writes/readback and anonymous/forged-owner denial
with one disposable synthetic cloud row, then verify its cleanup. Physical
user-trip upload requires the maintainer's own in-app consent.

Schema 2 is additive. Do not downgrade an installation to schema-1 code;
use a forward repair if needed. No raw evidence is rewritten or moved.
