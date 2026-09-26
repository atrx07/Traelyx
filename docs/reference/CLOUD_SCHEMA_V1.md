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

## M6.6 safe comparisons

Migration `20260926040000` adds `ranking_members`, `ranking_entries` and
`ranking_limits`. All have RLS, no direct PUBLIC/anon/authenticated table access,
and no client sequence grants. The private pure validator has no client EXECUTE.
Only authenticated callers can execute `submit_ranking_v1`, `read_rankings_v1`
and `withdraw_rankings_v1`, each with an expected-account guard and empty search
path. Submission validates current profile snapshots and a saved vehicle class.
One owner's retained history uses one class; changing it requires withdrawal.

The exact dossier keys are `versions`, `source_digest`, `vehicle_class`,
`duration_ms`, `moving_ms`, `calibration`, `integrity_counts`, `dimensions`, and
`events`. Every version in the validator's named registry must equal 1. Three
calibration checks must all pass; eleven ordered integrity exclusion counts
must all be zero. These are client-supplied evidence claims, not attestation.
Four dimension tuples contain opportunity/usable/fully-eligible milliseconds
in smoothness/braking/acceleration/cornering order. Full evidence must cover
at least 80% of each opportunity; minimum control opportunity is 500 ms, minimum
moving evidence 60 seconds, maximum duration two hours. Durations are integral.

At most 1,000 ordered event tuples contain category ordinal, clamped activation
severity in permille (1,000–2,000) and supported confidence weight (1,000).
Categories 0–8 follow strong/abrupt acceleration, strong/abrupt braking,
left/right high-load cornering, abrupt corner entry/exit and road impact.
Server scoring v1 independently reconstructs penalties; road impact earns
neither penalty nor reward. A maximum 64 KiB exact shape rejects extra fields.
No client score or rank is accepted. Trip IDs and digests deduplicate immutable
submissions; quotas are 30 new entries per 24-hour window and 1,000 retained.

Read returns the caller's current profile, eligible saved classes, own submitted
trip IDs, and sanitized comparison rows for self/accepted unblocked friends.
Rows expose name snapshots, broad class, capped sample count, self marker and
three aggregate metrics. No peer account ID, dossier or trip ID is projected.
Ten submissions are required; metrics use latest/preceding five by server
acceptance order. Withdrawal removes the owner's member/entries; rate-limit
counters remain. Account deletion cascades all three tables. See ADR-0023 and
`supabase/tests/safe_rankings.sql`. The approved production migration and atomic
synthetic tests passed on 2026-09-26; RLS, guarded grants, migration history and
rollback of every synthetic fixture were verified.
