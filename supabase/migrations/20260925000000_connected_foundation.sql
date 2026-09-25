-- M6.1 initial optional cloud schema. Local Drift remains the source of truth.
-- Apply through the Supabase migration mechanism as the project database owner.
-- No raw telemetry, route geometry, precise position, email, or credentials.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique
    check (username ~ '^[a-z][a-z0-9_]{2,29}$'),
  display_name text not null
    check (char_length(display_name) between 1 and 80),
  visibility text not null default 'private'
    check (visibility in ('private', 'public')),
  created_at timestamptz not null default now()
);

-- Vehicle metadata is deliberately limited to an opaque ID, display label,
-- and broad class. Registration identifiers and make/model are not stored.
create table public.vehicles (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  id uuid not null default gen_random_uuid(),
  display_name text not null
    check (char_length(display_name) between 1 and 80),
  vehicle_class text not null
    check (char_length(vehicle_class) between 1 and 40),
  created_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- Client-supplied summaries are private and untrusted for ranking. Later
-- server validation must create a separate publishable ranking projection.
create table public.trip_summaries (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  source_trip_id uuid not null,
  vehicle_id uuid,
  summary_version smallint not null default 1
    check (summary_version = 1),
  trip_day date,
  duration_seconds integer
    check (duration_seconds >= 0),
  distance_m numeric(12, 1)
    check (distance_m >= 0),
  score_overall numeric(5, 2)
    check (score_overall between 0 and 100),
  scoring_version text,
  event_count integer
    check (event_count >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, source_trip_id),
  foreign key (user_id, vehicle_id)
    references public.vehicles (user_id, id)
    on delete set null (vehicle_id),
  check ((score_overall is null) = (scoring_version is null)),
  check (scoring_version is null or char_length(scoring_version) between 1 and 40)
);

create index trip_summaries_user_day_idx
  on public.trip_summaries (user_id, trip_day desc);

-- Explicit grants are required in addition to RLS. Existing Supabase
-- projects can have broad default privileges on new public tables.
revoke all on public.profiles, public.vehicles, public.trip_summaries
  from public, anon, authenticated;
grant usage on schema public to authenticated;

grant select on public.profiles to authenticated;
grant insert (user_id, username, display_name, visibility)
  on public.profiles to authenticated;
grant update (username, display_name, visibility)
  on public.profiles to authenticated;

grant select, delete on public.vehicles to authenticated;
grant insert (user_id, id, display_name, vehicle_class)
  on public.vehicles to authenticated;
grant update (display_name, vehicle_class)
  on public.vehicles to authenticated;

grant select, delete on public.trip_summaries to authenticated;
grant insert (
  user_id, source_trip_id, vehicle_id, summary_version, trip_day,
  duration_seconds, distance_m, score_overall, scoring_version, event_count
) on public.trip_summaries to authenticated;
grant update (
  vehicle_id, trip_day, duration_seconds, distance_m, score_overall,
  scoring_version, event_count
) on public.trip_summaries to authenticated;

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.trip_summaries enable row level security;

create policy profiles_read_self on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy vehicles_read_self on public.vehicles
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy vehicles_insert_self on public.vehicles
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy vehicles_update_self on public.vehicles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy vehicles_delete_self on public.vehicles
  for delete to authenticated
  using (user_id = (select auth.uid()));

create policy summaries_read_self on public.trip_summaries
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy summaries_insert_self on public.trip_summaries
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy summaries_update_self on public.trip_summaries
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy summaries_delete_self on public.trip_summaries
  for delete to authenticated
  using (user_id = (select auth.uid()));
