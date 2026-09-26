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
Signing in, opening the review screen, and keeping trips local make no data
requests. Account links prevent another signed-in account from claiming the
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
