-- M6.3: private summary sync does not require a public/profile identity.
-- Preserve existing rows and owner-only RLS; do not enable profile/vehicle sync.
alter table public.trip_summaries
  drop constraint trip_summaries_user_id_fkey;
alter table public.trip_summaries
  add constraint trip_summaries_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;

comment on table public.trip_summaries is
  'Private, client-supplied compact snapshots; never authoritative for ranking. M6.3 allows auth owners without profiles.';

notify pgrst, 'reload schema';
