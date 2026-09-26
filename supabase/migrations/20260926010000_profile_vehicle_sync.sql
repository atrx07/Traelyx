-- M6.4: private metadata revisions and an explicitly sanitized public lookup.
alter table public.profiles
  add column revision bigint not null default 1 check (revision > 0),
  add column last_mutation_id uuid;
alter table public.vehicles
  add column revision bigint not null default 1 check (revision > 0),
  add column last_mutation_id uuid;

create function public.advance_metadata_revision() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.revision := old.revision + 1;
  return new;
end $$;
revoke all on function public.advance_metadata_revision() from public, anon, authenticated;
create trigger profiles_revision before update on public.profiles
for each row execute function public.advance_metadata_revision();
create trigger vehicles_revision before update on public.vehicles
for each row execute function public.advance_metadata_revision();

-- Invoker functions preserve RLS and column-grant enforcement. Clients
-- cannot set revisions; the trigger also covers older/direct clients.
grant insert (last_mutation_id), update (last_mutation_id)
  on public.profiles, public.vehicles to authenticated;

create function public.save_profile_v1(
  expected_revision bigint, mutation_id uuid,
  profile_username text, profile_display_name text, profile_visibility text
) returns public.profiles
language plpgsql security invoker set search_path = '' as $$
declare result public.profiles;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if expected_revision is null or expected_revision < 0 or mutation_id is null then
    raise exception 'Invalid mutation' using errcode = '22023';
  end if;
  select * into result from public.profiles where user_id = auth.uid();
  if result.last_mutation_id = mutation_id and
     result.username = profile_username and result.display_name = profile_display_name and
     result.visibility = profile_visibility then return result; end if;
  if expected_revision = 0 then
    insert into public.profiles (user_id, username, display_name, visibility, last_mutation_id)
    values (auth.uid(), profile_username, profile_display_name, profile_visibility, mutation_id)
    on conflict (user_id) do nothing returning * into result;
  else
    update public.profiles set username = profile_username, display_name = profile_display_name,
      visibility = profile_visibility, last_mutation_id = mutation_id
    where user_id = auth.uid() and revision = expected_revision returning * into result;
  end if;
  if result.user_id is not null then return result; end if;
  select * into result from public.profiles where user_id = auth.uid();
  if result.last_mutation_id = mutation_id and
     result.username = profile_username and result.display_name = profile_display_name and
     result.visibility = profile_visibility then return result; end if;
  raise exception 'Metadata conflict' using errcode = '40001';
end $$;

create function public.save_vehicle_v1(
  vehicle_id uuid, expected_revision bigint, mutation_id uuid,
  vehicle_display_name text, vehicle_class_name text
) returns public.vehicles
language plpgsql security invoker set search_path = '' as $$
declare result public.vehicles;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if vehicle_id is null or expected_revision is null or expected_revision < 0 or mutation_id is null then
    raise exception 'Invalid mutation' using errcode = '22023';
  end if;
  select * into result from public.vehicles where user_id = auth.uid() and id = vehicle_id;
  if result.last_mutation_id = mutation_id and result.display_name = vehicle_display_name and
     result.vehicle_class = vehicle_class_name then return result; end if;
  if expected_revision = 0 then
    insert into public.vehicles (user_id, id, display_name, vehicle_class, last_mutation_id)
    values (auth.uid(), vehicle_id, vehicle_display_name, vehicle_class_name, mutation_id)
    on conflict (user_id, id) do nothing returning * into result;
  else
    update public.vehicles set display_name = vehicle_display_name, vehicle_class = vehicle_class_name,
      last_mutation_id = mutation_id
    where user_id = auth.uid() and id = vehicle_id and revision = expected_revision returning * into result;
  end if;
  if result.user_id is not null then return result; end if;
  select * into result from public.vehicles where user_id = auth.uid() and id = vehicle_id;
  if result.last_mutation_id = mutation_id and result.display_name = vehicle_display_name and
     result.vehicle_class = vehicle_class_name then return result; end if;
  raise exception 'Metadata conflict' using errcode = '40001';
end $$;

revoke all on function public.save_profile_v1(bigint, uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.save_vehicle_v1(uuid, bigint, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.save_profile_v1(bigint, uuid, text, text, text) to authenticated;
grant execute on function public.save_vehicle_v1(uuid, bigint, uuid, text, text) to authenticated;

-- Fixed search path, exact username, and two explicit fields. This deliberate
-- public projection exposes no owner ID, vehicle, trip, or private profile.
create function public.lookup_public_profile_v1(profile_username text)
returns table (username text, display_name text)
language sql stable security definer set search_path = '' as $$
  select p.username, p.display_name from public.profiles p
  where p.visibility = 'public' and p.username = profile_username
    and profile_username ~ '^[a-z][a-z0-9_]{2,29}$'
  limit 1
$$;
revoke all on function public.lookup_public_profile_v1(text) from public, anon, authenticated;
grant usage on schema public to anon;
grant execute on function public.lookup_public_profile_v1(text) to anon, authenticated;
notify pgrst, 'reload schema';
