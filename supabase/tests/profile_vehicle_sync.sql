begin;
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select public.save_profile_v1('11111111-1111-4111-8111-111111111111', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'metadata_owner', 'Private driver', 'private');
select public.save_profile_v1('11111111-1111-4111-8111-111111111111', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'metadata_owner', 'Private driver', 'private');
do $$ begin
  if (select revision from public.profiles) <> 1 then raise exception 'retry changed revision'; end if;
  if exists(select 1 from public.lookup_public_profile_v1('metadata_owner')) then raise exception 'private profile leaked'; end if;
  begin
    perform public.save_profile_v1('11111111-1111-4111-8111-111111111111', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'metadata_owner', 'Stale', 'public');
    raise exception 'stale creation succeeded';
  exception when serialization_failure then null; end;
end $$;
select public.save_profile_v1('11111111-1111-4111-8111-111111111111', 1, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'metadata_owner', 'Public driver', 'public');
select public.save_vehicle_v1('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'Private car', 'car');
select public.save_vehicle_v1('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'Private car', 'car');
do $$ begin
  if (select revision from public.vehicles) <> 1 then raise exception 'vehicle retry changed revision'; end if;
  begin
    update public.profiles set revision = 200;
    raise exception 'client set revision';
  exception when insufficient_privilege then null; end;
end $$;
-- Direct/older clients still advance the revision; a stale RPC cannot overwrite.
update public.vehicles set display_name = 'Other device';
do $$ begin
  begin
    perform public.save_vehicle_v1('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 1, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'Stale', 'car');
    raise exception 'stale vehicle edit succeeded';
  exception when serialization_failure then null; end;
  if (select display_name from public.vehicles) <> 'Other device' then raise exception 'conflict overwrote data'; end if;
end $$;
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ begin
  if exists(select 1 from public.profiles) or exists(select 1 from public.vehicles) then raise exception 'cross-owner read'; end if;
  if (select count(*) from public.lookup_public_profile_v1('metadata_owner')) <> 1 then raise exception 'public projection missing'; end if;
  -- The payload was reviewed for A, but the transport now authenticates B.
  begin
    perform public.save_profile_v1('11111111-1111-4111-8111-111111111111', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7', 'switched_owner', 'Must not copy', 'private');
    raise exception 'switched profile request accepted';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_vehicle_v1('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8', 'Must not copy', 'car');
    raise exception 'switched vehicle request accepted';
  exception when insufficient_privilege then null; end;

  begin
    perform public.save_vehicle_v1('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 1, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'Forged', 'car');
    raise exception 'cross-owner update succeeded';
  exception when serialization_failure then null; end;
end $$;
reset role;
set role anon;
do $$ declare projected jsonb; begin
  select to_jsonb(p) into projected from public.lookup_public_profile_v1('metadata_owner') p;
  if projected <> '{"username":"metadata_owner","display_name":"Public driver"}'::jsonb then raise exception 'unsafe public projection'; end if;
  if exists(select 1 from public.lookup_public_profile_v1('%')) then raise exception 'wildcard enumeration'; end if;
  begin perform * from public.profiles; raise exception 'anonymous private profile read'; exception when insufficient_privilege then null; end;
  begin perform * from public.vehicles; raise exception 'anonymous vehicle read'; exception when insufficient_privilege then null; end;
  begin perform * from public.trip_summaries; raise exception 'anonymous trip read'; exception when insufficient_privilege then null; end;
  begin
    perform public.save_profile_v1('11111111-1111-4111-8111-111111111111', 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5', 'attacker', 'Attacker', 'public');
    raise exception 'anonymous mutation';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select public.save_profile_v1('11111111-1111-4111-8111-111111111111', 2, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6', 'metadata_owner', 'Private again', 'private');
reset role;
set role anon;
do $$ begin
  if exists(select 1 from public.lookup_public_profile_v1('metadata_owner')) then raise exception 'unpublished profile visible'; end if;
end $$;
reset role;
do $$ begin
  if has_function_privilege('anon', 'public.save_profile_v1(uuid,bigint,uuid,text,text,text)', 'execute') then raise exception 'anon save grant'; end if;
  if has_function_privilege('authenticated', 'public.save_profile_v1(bigint,uuid,text,text,text)', 'execute') or
     has_function_privilege('authenticated', 'public.save_vehicle_v1(uuid,bigint,uuid,text,text)', 'execute') then raise exception 'unguarded legacy mutation accessible'; end if;
  if has_function_privilege('authenticated', 'public.advance_metadata_revision()', 'execute') then raise exception 'trigger helper client grant'; end if;
end $$;
rollback;
