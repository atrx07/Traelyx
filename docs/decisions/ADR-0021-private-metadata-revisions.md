# ADR-0021 — Cached metadata edits and sanitized public profiles

**Status:** Accepted 2026-09-26

## Context

M6.4 adds optional profile/vehicle sync. Local anonymous vehicles already own
trip and baseline history; sharing metadata must not reassign that evidence.
Two devices can edit the same account, and a request can commit without its
acknowledgement reaching the app. Public profile lookup must not expose the
private profile table, account identifiers, vehicles, or trips.

## Decision

Add an account-scoped `account_metadata_cache` in additive Drift schema 3.
Store allowlisted version-1 profile/vehicle records and their server revision.
Use the existing durable queue for explicitly reviewed edits, each with a
random mutation UUID and expected server revision. Pending drafts remain
separate from acknowledged cache fields. Sign-in/page-open performs no
metadata upload or automatic cloud fetch; Reload cloud is explicit.

Profile fields are username, display name, and visibility (private by default).
Vehicle fields are an opaque UUID, chosen display label, and one broad class:
unspecified, car, motorcycle, or other. Selected local vehicle metadata can
be copied after review; original IDs, namespaces, assignments, manufacturer,
model/year, calibration, baselines, trip summaries, and raw telemetry remain
unchanged. A local source association prevents accidental duplicate copies
within the account while that cache record remains.

Use RLS-enforced invoker RPCs for optimistic saves. Each request carries
its reviewed `expected_user_id`; the server compares it with `auth.uid()`
before reading or writing. This closes the gap between a client-side account
check and SDK session/header selection. Unguarded initial signatures are
revoked by forward migration `20260926020000`. A database trigger advances
the revision even for direct/older clients; clients cannot set revision values.
Repeating an acknowledged mutation with identical fields returns its existing
result. A stale revision/username collision blocks the draft; the user can
discard, reload, and review a new edit. The app never silently overwrites a
newer cloud revision. A profile's unresolved queue holds dependent vehicle
edits. Foreground batches are limited to 50, with persisted exponential retry
delays from 30 seconds to one hour. Account changes stop later requests.

The only public path is `lookup_public_profile_v1(exact_username)`, returning
username and display name for an explicitly public profile. Its SECURITY
DEFINER body uses a fixed empty search path, qualified table, exact equality,
and an explicit two-column projection. PUBLIC execution is revoked; anon and
authenticated are granted only this narrow lookup. Private base-table RLS
remains owner-only. No public vehicle, trip, social-search, or ranking path.

No dependency, native permission, sensor, or background-service change.
Account caches persist locally but are inaccessible through another account's
app flow. Cloud is authoritative for acknowledged metadata; local history
remains authoritative for trips. Cloud metadata does not configure recording.

## Recovery and limits

Do not downgrade schema-3 installations. Use forward repair. Discard removes
queued drafts, not remote data; an in-flight or unacknowledged request may have
committed. Reload after discarding. Visibility changes are not effective until
the cloud save succeeds. Public data already copied by others cannot be recalled.
No metadata deletion UI, account deletion, avatar upload, friendship, or
automatic trip association is added by M6.4.

Validate schema-1/2 upgrades, disk reopen, stale edits, lost acknowledgements,
account switching, queue cancellation, strict payloads, UI consent, and SDK
request shape. Hosted synthetic tests run inside a rollback-only transaction;
physical account details are created only by the maintainer's own UI choices.
