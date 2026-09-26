# Cloud schema version 1 — M6.1

## When to read

Read when changing Supabase migrations, RLS, or a connected data payload.
`supabase/migrations/` is the executable source of truth. This document lists
the initial foundation migration's permitted fields and trust boundary.

| Table | Fields | Client access |
|---|---|---|
| `profiles` | `user_id`, `username`, `display_name`, `visibility`, `created_at` | Signed-in owner reads/inserts/updates. No anonymous read or client delete. `visibility` does not yet publish a profile. |
| `vehicles` | `user_id`, `id`, `display_name`, `vehicle_class`, `created_at` | Signed-in owner reads/inserts/updates/deletes. Metadata is deliberately broad. |
| `trip_summaries` | `user_id`, `source_trip_id`, optional `vehicle_id`, `summary_version`, optional `trip_day`, `duration_seconds`, `distance_m`, `score_overall`, `scoring_version`, `event_count`, `created_at` | Signed-in owner reads/inserts/updates/deletes. Client data is never rank-authoritative. |

All rows belong to an `auth.users` identity. A local-only installation creates
none of them. `source_trip_id` preserves idempotent sync per owner; it does not
carry route geometry. Vehicle references are owner-scoped, and deleting a cloud
vehicle clears the optional reference without deleting trip summaries.

M6.1 recorded the dashboard's per-table Data API exposure indicators as off.
M6.3 verifies `trip_summaries` through real authenticated writes/readback,
denied anonymous reads, and denied forged-owner writes. SQL grants and RLS
establish the tested database boundary. No profile or vehicle sync flow is
introduced by M6.3.

The initial version-1 foundation introduced no public profile, social,
leaderboard, or Guardian read path. Later migrations are described below.
M6.1 did not alter local Drift schema version 1. M6.3 adds separate local
account associations in Drift schema 2, without rewriting existing evidence.

The M6.3 migration changes `trip_summaries.user_id` to reference `auth.users`
directly. Profiles are not required for private summary sync. The payload
version and existing RLS/column grants stay unchanged; M6.3 omits optional
`trip_day` and `vehicle_id` entirely. It inserts immutable snapshots and
verifies readback instead of overwriting existing summaries.

The second M6.1 migration revokes `EXECUTE` on an existing Supabase
`public.rls_auto_enable()` helper from `PUBLIC`, `anon`, and `authenticated`
where present. The `postgres` owner retains execution rights, and the
`ensure_rls` database event trigger remains enabled.

## M6.4 metadata revisions and public projection

Migration `20260926010000` adds server-maintained `revision` and nullable
`last_mutation_id` to profiles/vehicles. `save_profile_v1` and `save_vehicle_v1`
are authenticated-only SECURITY INVOKER RPCs: ownership comes from `auth.uid`,
RLS applies, and expected revisions prevent stale replacement. A revoked
client-EXECUTE trigger helper advances revisions for every update, including
direct writes. Existing profile/vehicle field grants and RLS remain intact.

`lookup_public_profile_v1(text)` is a deliberate SECURITY DEFINER projection
with a fixed empty search path and exact-username predicate. Only username
and display name of public profiles are returned; anon/authenticated can
execute it, PUBLIC cannot. It gives no base-table access, owner ID, private
profile, vehicle, or trip information. SQL tests verify publish/unpublish,
projection keys, denied base-table access, stale writes, and duplicate retries.

Forward migration `20260926020000` adds `expected_user_id` to both save RPCs
and requires it to match `auth.uid()` before any read/write. It revokes all
client execution on the initial unguarded signatures. Public lookup and stored
data are unchanged. A pre-guard development app must update before saving;
its existing queued metadata already contains the intended owner and remains
usable by the updated app. Tests simulate account A's payload arriving with
account B's session and require rejection before writing either account.

## M6.5 friendships

Migration `20260926030000` adds RLS-enabled `social_relationships` and
`social_request_limits` without direct PUBLIC/anon/authenticated table grants.
Authenticated-only `list_social_v1`, `request_friend_v1`, and `change_friend_v1`
use fixed empty search paths and explicit expected-account guards. The list
exposes only relationship ID/revision, peer name snapshots, and caller-relative
state; it never exposes the other account UUID or other people's relationships.
Existing profile/vehicle/summary grants and public projection remain unchanged.
See ADR-0022 and `supabase/tests/friendships.sql` for transitions and abuse limits.
