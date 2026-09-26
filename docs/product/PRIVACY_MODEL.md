# Traelyx — User Privacy Model

## When to read

Read for any feature that stores, transmits, displays, exports, shares, ranks, or deletes user/trip data.

## 1. Principle

Location history is sensitive. The default is local/private. Cloud and social features are additive and permissioned.

## 2. Local-only mode

Without account:

- trip recording works;
- raw telemetry stays local;
- history works;
- scoring/Drive DNA works;
- replay works;
- procedural commentary works;
- user can delete/export data.

The app should not create a shadow cloud identity merely because the user opened it.

## 3. Cloud account mode

Account may unlock:

- profile;
- cloud summary sync;
- leaderboards;
- friends/social;
- Guardian Connect;
- online backup if implemented;
- cloud commentary if user separately provides a key.

Account creation must show what begins syncing.

M6.3 starts no trip sync at sign-in. A separate Account review identifies the
private destination and data categories before the user confirms existing
compact summaries. Dates, vehicle labels, precise routes, and raw sensors are
excluded. Future trips require another review. Cancelling the queue does not
remove already uploaded copies; deleting a local trip does not delete its
cloud copy. An upload already in progress may finish. See `SYNC_SPEC.md`.

## 4. Data minimization

### Keep local by default

- precise route;
- raw high-frequency IMU;
- high-frequency GNSS trace;
- detailed replay channel data.

### Suitable for optional cloud summary

- trip ID/user ownership;
- start/end coarse times as needed;
- duration/distance;
- Drive DNA/scoring summaries;
- integrity/rank eligibility;
- aggregate event counts;
- vehicle-class reference;
- social/ranking fields explicitly selected.

Exact final fields are defined in `DATA_MODEL.md` and schemas.

## 5. Public profile separation

Public profile/rank query paths must not grant raw trip access.

A leaderboard should read from a purpose-built sanitized table/view rather than querying private trip geometry.

M6.4 profiles default private. The reviewed publication checkbox and explicit
Save public profile action expose only username/display name to anyone who
knows the exact username. Vehicles remain owner-only. The underlying private
profile/vehicle/trip tables remain inaccessible to anonymous callers.
Unpublishing takes effect when saved successfully; previously copied public
details cannot be recalled. Queued/discarded edits do not imply a changed
cloud visibility. Vehicle copies include only the label and broad class that
the user reviews, leaving original local vehicles and trips untouched.

## 6. Guardian privacy

Guardian permissions are explicit. A safety relationship does not imply route history/live location.

## 7. AI privacy

BYO cloud commentary sends only the sanitized event dossier required to generate text by default. The app should present a clear "sent / not sent" explanation.

## 8. ML contribution

If users opt in to improve detection:

- obtain explicit consent;
- strip account identity from training artifact where feasible;
- remove/transform precise location unless location is necessary for the specific research question;
- allow contribution to be disabled;
- document retention and dataset versioning;
- do not assume account signup equals training consent.

## 9. Deletion

Support:

- delete trip locally;
- delete local raw telemetry while optionally retaining summary where user chooses;
- clear map cache;
- remove cloud commentary credentials;
- disconnect Guardian;
- delete cloud account/data when implemented.

Deletion UX must state what is deleted and what cannot be recovered.

M5.9 deletion is local, user-directed, and confirmation-gated. Retention settings only produce a preview and never trigger background deletion. Raw-only deletion preserves the trip summary, events, and score but can remove route replay and recomputation evidence. Whole-trip deletion has separate consequence copy. Native recorder/finalization guards and exact UUID path checks fail closed before authoritative raw data is removed.

## 10. Export

Exports intended for personal use may contain precise data. Debug/community exports should provide anonymization controls and warn when precise route is included.

M5.9 keeps `.tripdebug` explicitly `precise_private` and not anonymized. Its separate `redacted_trip_summary` version 1 omits precise route, raw telemetry, identifiers, vehicle/account/device identity, storage metadata, and wall-clock time. The app describes it as redacted, not anonymous, and neither export path uploads data.

## 11. Logging

Production logs should avoid precise coordinates unless a diagnostic mode is explicitly enabled. Diagnostic bundles should allow redaction/anonymization before sharing.
