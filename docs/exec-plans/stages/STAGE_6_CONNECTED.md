# Stage 6 Playbook — Auth, Social & Guardian

## Goal

Add online capabilities without turning the local-first app into a cloud hostage.

## Minimum references

`AUTH_SPEC.md`, `DATA_MODEL.md`, `SYNC_SPEC.md`, `PRIVACY_MODEL.md`, `SOCIAL_RANKING_SPEC.md`, `GUARDIAN_SPEC.md`.

## Work units

1. Provision Supabase free-tier project/config.
2. Create cloud schema and RLS tests.
3. Implement optional auth flow and secure session handling.
4. Implement local→account summary association/migration.
5. Build sanitized profiles and vehicle metadata sync.
6. Build friend relationship/block primitives.
7. Build purpose-specific leaderboard rows/queries.
8. Enforce scoring/integrity/rank eligibility.
9. Implement Guardian short-lived invite and acceptance.
10. Implement granular permission changes/revocation.
11. Implement alert deduplication/delivery state.
12. Test malicious cross-user data access attempts.
13. Add account/cloud data deletion path.

## Acceptance

- local recorder works with Supabase unreachable;
- users cannot read another user's private trip summary/routes via API manipulation;
- leaderboard contains no precise route data;
- Guardian live location remains off by default;
- revocation is enforced server-side.
