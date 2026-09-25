-- Run after bootstrap.sql and the M6.1 migration with ON_ERROR_STOP=1.
-- These assertions exercise actual grants, RLS, and cross-owner references.
begin;

do $$
declare
  table_name text;
  trigger_calls_before integer;
begin
  foreach table_name in array array['profiles', 'vehicles', 'trip_summaries'] loop
    if not exists (
      select 1 from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = table_name
        and c.relrowsecurity
    ) then
      raise exception 'RLS missing on %', table_name;
    end if;
    if has_table_privilege('anon', 'public.' || table_name, 'select')
       or has_table_privilege('anon', 'public.' || table_name, 'insert')
       or has_table_privilege('anon', 'public.' || table_name, 'update')
       or has_table_privilege('anon', 'public.' || table_name, 'delete') then
      raise exception 'anonymous table grant on %', table_name;
    end if;
  end loop;
  if has_table_privilege('authenticated', 'public.profiles', 'delete') then
    raise exception 'client profile delete grant is forbidden';
  end if;
  if has_function_privilege('anon', 'public.rls_auto_enable()', 'execute')
     or has_function_privilege(
       'authenticated', 'public.rls_auto_enable()', 'execute'
     ) then
    raise exception 'client can execute the RLS event helper';
  end if;
  if exists (
    select 1 from pg_proc p, lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) a
    where p.oid = 'public.rls_auto_enable()'::regprocedure
      and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ) then
    raise exception 'PUBLIC can execute the RLS event helper';
  end if;
  if not exists (
    select 1 from pg_proc p
    where p.oid = 'public.rls_auto_enable()'::regprocedure
      and has_function_privilege(p.proowner, p.oid, 'EXECUTE')
  ) then
    raise exception 'RLS event helper owner lost EXECUTE';
  end if;
  select count(*) into trigger_calls_before from public.event_trigger_fires;
  execute 'create table public.event_trigger_probe (id integer)';
  if (select count(*) from public.event_trigger_fires) <= trigger_calls_before then
    raise exception 'RLS event trigger did not fire after EXECUTE revoke';
  end if;
end $$;

set role anon;
do $$
begin
  begin
    perform count(*) from public.profiles;
    raise exception 'anonymous profile read unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

insert into public.profiles (user_id, username, display_name)
values ('11111111-1111-4111-8111-111111111111', 'driver_one', 'Driver One');
insert into public.vehicles (user_id, id, display_name, vehicle_class)
values (
  '11111111-1111-4111-8111-111111111111',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Bike', 'motorcycle'
);
insert into public.trip_summaries (
  user_id, source_trip_id, vehicle_id, summary_version,
  trip_day, duration_seconds, distance_m, score_overall, scoring_version
) values (
  '11111111-1111-4111-8111-111111111111',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  1, '2026-09-25', 600, 1200.0, 82.50, 'scoring-v1'
);

do $$
begin
  if (select count(*) from public.profiles) <> 1
     or (select count(*) from public.vehicles) <> 1
     or (select count(*) from public.trip_summaries) <> 1 then
    raise exception 'owner cannot read own cloud rows';
  end if;
  begin
    insert into public.profiles (user_id, username, display_name)
    values ('22222222-2222-4222-8222-222222222222', 'impostor', 'Impostor');
    raise exception 'cross-owner profile insert unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.trip_summaries (user_id, source_trip_id)
    values (
      '22222222-2222-4222-8222-222222222222',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
    );
    raise exception 'cross-owner summary insert unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles
      set user_id = '22222222-2222-4222-8222-222222222222';
    raise exception 'owner reassignment unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;

set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';

insert into public.profiles (user_id, username, display_name)
values ('22222222-2222-4222-8222-222222222222', 'driver_two', 'Driver Two');

do $$
declare
  affected integer;
begin
  if (select count(*) from public.profiles) <> 1
     or (select count(*) from public.vehicles) <> 0
     or (select count(*) from public.trip_summaries) <> 0 then
    raise exception 'cross-owner private rows are visible';
  end if;
  update public.profiles set display_name = 'Stolen'
    where user_id = '11111111-1111-4111-8111-111111111111';
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'cross-owner profile update changed a row';
  end if;
  delete from public.trip_summaries
    where user_id = '11111111-1111-4111-8111-111111111111';
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'cross-owner summary delete changed a row';
  end if;
  begin
    insert into public.trip_summaries (user_id, source_trip_id, vehicle_id)
    values (
      '22222222-2222-4222-8222-222222222222',
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    );
    raise exception 'cross-owner vehicle reference unexpectedly succeeded';
  exception when foreign_key_violation then null;
  end;
end $$;

set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
delete from public.vehicles
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
do $$
begin
  if (select count(*) from public.trip_summaries) <> 1
     or (select count(*) from public.trip_summaries where vehicle_id is null) <> 1 then
    raise exception 'vehicle deletion removed or retained an invalid trip summary';
  end if;
end $$;

reset role;
rollback;
