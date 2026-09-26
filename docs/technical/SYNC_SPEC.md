# SYNC_SPEC.md — Local/Cloud Synchronization

## When to read

Read when implementing cloud backup/summary sync, conflict resolution, account migration, social publication, or offline queue behavior.

## 1. Principle

The app functions locally first. Sync is eventual and non-destructive.

## 2. Default sync scope

When an account is enabled, sync compact data necessary for connected features:

- profile;
- selected vehicle metadata;
- trip summary;
- score/Drive DNA summary;
- integrity/rank eligibility;
- social/ranking state;
- Guardian relationships/events.

Do not upload raw sensor streams/precise routes by default.

## 3. Offline queue

Network operations should be represented as idempotent queued actions with retry/backoff.

Avoid a UI that blocks trip finalization on cloud response.

## 4. Conflict policy

Define authority by entity:

- raw trip: local authoritative;
- profile/social: cloud may be authoritative with cached local copy;
- user-editable trip label/name: resolve via version/timestamp with explicit rules;
- scoring: local deterministic result plus version; server may validate rank eligibility but should not silently rewrite local history.

## 5. Idempotency

Every upload/update should be safely retryable. Use stable IDs and server uniqueness constraints.

## 6. Privacy

Before adding a field to sync payload, ask whether connected feature actually needs it. If not, keep it local.

## 7. Account deletion / sign-out

Sign-out must not necessarily erase local trip data. Cloud deletion and local deletion are distinct user actions.

## 8. M6.3 implemented boundary

Account → Private summary sync reviews currently completed eligible UUID
trips. Only explicit confirmation links those trips to the displayed account
and atomically queues version-1 snapshots. New trips require another review.
Signing in, opening the review screen, and keeping trips local make no trip
upload requests. Account links prevent another signed-in account from claiming the
same local trip. Original anonymous vehicle/baseline ownership is retained.

The allowlist is `user_id`, `source_trip_id`, `summary_version`,
`duration_seconds`, `distance_m`, `score_overall`, `scoring_version`, and
`event_count`. Missing evidence is null; dates, vehicle identity/labels,
precise routes, raw samples, and arbitrary JSON never enter this queue.
Event count uses the trip's recorded active event-engine version. Score and
its version travel together; private client input remains rank-untrusted.

Uploads run only after confirmation or a foreground retry, at most 50 per
request batch. Retry delay persists (30 seconds, exponential to one hour).
The app inserts a snapshot without overwriting an existing cloud row, then
checks exact allowlisted readback. A conflict or malformed local payload is
blocked for review; connection/access failures retain the queue. Cancellation
removes pending payloads but retains account links and existing cloud copies.
Local whole-trip deletion removes the linked queue; an in-flight request may
still complete. No background worker, automatic future-trip opt-in, cloud
download/restore, or remote deletion UI is introduced in M6.3.

`trip_account_links` plus `sync_queue` are authoritative local sync records.
`trips.cloud_sync_state` mirrors `summary_pending`, `summary_synced`, or
`summary_linked` (cancelled queue, cloud existence may be unknown). Recorder
finalization replay preserves this field. See ADR-0020.

## 9. M6.4 profile/vehicle boundary

Account → Profile & vehicles opens an account-scoped local cache. Saving a
reviewed form queues its exact fields and attempts foreground sync; new
profiles default private. Reload cloud explicitly reads the current owner's
profile/vehicles and replaces acknowledged cache only when no draft is pending.
Cloud metadata remains separate from local recording vehicle configuration.

Version-1 edits use a random mutation UUID, expected server revision, and
explicit reviewed account ID. The server rejects an authenticated account
that differs from that ID, even if the SDK session changed during dispatch.
Idempotent lost-acknowledgement retries preserve the request; stale revisions
or username collisions require discard/reload/review instead of last-write-wins.
Retry delay persists from 30 seconds to one hour, with at most 50 edits per
batch. Pending profile edits hold vehicles until the profile is acknowledged.
Account changes stop later requests and prevent another account using the queue.

The public projection contains only exact username/display name for explicitly
published profiles. Private vehicles contain only account/opaque ID, chosen
label, and broad class. No vehicle registration, make/model/year, calibration,
baseline, route, trip, email, or credential is copied by these operations.
An explicit local metadata copy preserves local IDs/ownership/assignments.

Discard removes drafts, not remote data; already-sent requests may complete.
Visibility changes are effective only after cloud acknowledgement. Cache and
queued metadata stay on-device across restart/sign-out, scoped to the account.
No metadata deletion UI, auto-fetch, background sync, public vehicle lookup,
or social relationship is added here. See ADR-0021.

## 10. M6.5 relationships

Social has no persistent cache or outbox. Explicit Reload, exact public-name
lookup, and confirmed relationship actions use account-guarded foreground
RPCs. Pending requests expire after seven days; closed pairs have a seven-day
cooldown, accounts can send 30 new requests per 24-hour quota window, and each
account retains at most 1,000 pairs. Writes are revision-checked and uncertain
responses require reload. Sending shares only the sender's saved username and
display name with the target; acceptance grants no trip/vehicle/Guardian access.
See ADR-0022 for server state and block semantics.

## 11. M6.6 ranking consent

Explicit local analysis is accountless and produces an immutable original
score/event/integrity audit. Ranking eligibility does not cause an upload.
Social → Safe comparisons requires explicit reload, per-trip vehicle-class
review, and a separate confirmation naming the fields and friend audience.
Summary-sync consent never authorizes ranking evidence or score publication.

Ranking calls are foreground-only with no automatic outbox. Before sending,
validate the reviewed immutable audit and persist the existing per-trip account
association (`trip_account_links`, version 1). This association does not create
a summary queue or imply summary consent. An uncertain response requires an
explicit reload and review/retry; the server recognizes an identical trip/dossier
without charging quota again. Account guards apply before and after network
operations, and submission/withdrawal are serialized in both app and server.
Sign-out/local deletion does not recall an in-flight request or delete cloud
ranking evidence. Explicit Withdraw all comparisons does; local association
remains to prevent moving the same trip into a different account.
