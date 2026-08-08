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

## 10. Export

Exports intended for personal use may contain precise data. Debug/community exports should provide anonymization controls and warn when precise route is included.

## 11. Logging

Production logs should avoid precise coordinates unless a diagnostic mode is explicitly enabled. Diagnostic bundles should allow redaction/anonymization before sharing.
