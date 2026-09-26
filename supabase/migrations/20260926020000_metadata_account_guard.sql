-- M6.4 review: bind each mutation to its explicitly reviewed account.
-- No stored data or public lookup grants change.
create function public.save_profile_v1(
  expected_user_id uuid,
  expected_revision bigint, mutation_id uuid,
  profile_username text, profile_display_name text, profile_visibility text
) returns public.profiles
language plpgsql security invoker set search_path = '' as $$
declare result public.profiles;
begin
  if expected_user_id is null or auth.uid() is null or auth.uid() <> expected_user_id then
    raise insufficient_privilege;
  end if;
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
  expected_user_id uuid,
  vehicle_id uuid, expected_revision bigint, mutation_id uuid,
  vehicle_display_name text, vehicle_class_name text
) returns public.vehicles
language plpgsql security invoker set search_path = '' as $$
declare result public.vehicles;
begin
  if expected_user_id is null or auth.uid() is null or auth.uid() <> expected_user_id then
    raise insufficient_privilege;
  end if;
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

-- Disable the pre-guard signatures: a switched SDK session must never
-- reinterpret an already-reviewed payload as another account's metadata.
revoke all on function public.save_profile_v1(bigint, uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.save_vehicle_v1(uuid, bigint, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.save_profile_v1(uuid, bigint, uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.save_vehicle_v1(uuid, uuid, bigint, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.save_profile_v1(uuid, bigint, uuid, text, text, text) to authenticated;
grant execute on function public.save_vehicle_v1(uuid, uuid, bigint, uuid, text, text) to authenticated;
notify pgrst, 'reload schema';
