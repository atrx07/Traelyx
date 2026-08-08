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
