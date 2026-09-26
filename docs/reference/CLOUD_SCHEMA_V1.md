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

No public profile, social, leaderboard, or Guardian read path exists in version
1. Later M6 substeps must add those paths with migrations and access tests.
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
