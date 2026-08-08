# PRIVACY_POLICY_ENGINEERING.md — Engineering Privacy Checklist

## When to read

Read when adding storage/network/social/export/analytics/provider functionality or reviewing a release.

## Data minimization questions

Before collecting/transmitting a field:

1. Which user-visible feature needs it?
2. Can the feature work with a derived/coarser value?
3. Can it stay local?
4. How long must it persist?
5. Who can read it?
6. Can the user delete/export it?
7. Is it included in logs/backups/crash reports?

If there is no clear answer to #1, do not collect it.

## Location

- Precise routes private by default.
- Public ranking rows do not contain route geometry.
- Cloud commentary does not need precise location.
- Debug exports warn/anonymize.
- Map-provider requests are acknowledged as a privacy surface.

## Guardian

- Explicit permission matrix.
- Revocation server-side.
- No hidden tracking.
- Live location off by default.

## Credentials

- Provider keys in secure storage.
- Signing secrets outside repo.
- Auth handled by trusted auth provider.
- Logs redact tokens.

## User contribution to ML

Account consent ≠ training consent. Contribution is separate and explicit.

## Release checklist

Before release, review:

- Android permissions diff;
- network endpoints/providers;
- cloud schema/RLS;
- new logs/diagnostics;
- exported data;
- new public profile/ranking fields;
- retention defaults;
- deletion flow.
