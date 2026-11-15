# ADR-0041 — Separate user reports from detector evidence

**Status:** Accepted for M7.9
**Date:** 2026-11-15

## Decision

Store post-drive user reports in a separate additive local table bound to exact
event snapshots. They never replace score/event evidence or affect safety/ranking.
Use revisions, fresh parked/recorder checks, no automatic prompts and default-off
per-report export permission. Source changes become stale, not silently rebound.
Deletion remains user-controlled and cascades with the trip.

Revisions order annotation changes; local wall-clock metadata may move backward.
Do not block consent withdrawal because the device clock was adjusted.

Contributions use a separately reviewed, user-selected local JSON file, without a
mandatory backend. Restrict exports to categorical reports and source versions.
Exclude routes, raw sensors, measurements, identifiers and all timestamps. Serialize
correction actions across export completion so consent review cannot race an app
edit. Reauthorize current source/consent after the document picker returns,
including changes from other database writers; fail closed without a fresh response.
Do not hold a database write lock across the picker. Exported copies cannot be recalled through local consent withdrawal.

The receiver imports only to private quarantine with explicit declared-consent
acknowledgment. Missing grouping/features and unverified reports block training.
No cloud identity, public dataset, paid API, new dependency or automatic learning
is introduced. A future feature-bearing contribution/transport needs separate
governance; do not expand this payload silently.

See [the versioned contract](../reference/EVENT_CORRECTION_V1.md).
