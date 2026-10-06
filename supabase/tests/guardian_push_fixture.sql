-- Disposable PostgreSQL only. Never run this wrapper in production.
create function pg_temp.assert_no_push_fixture() returns void language plpgsql as $$ begin
  if exists(select 1 from auth.users where id='00000000-0000-4000-9000-000000000691')
    or exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries) then
    raise exception 'Denied staging left a synthetic fixture';
  end if;
end $$;
-- Expected stage errors are isolated; following assertions and the positive
-- stage run with ON_ERROR_STOP on, so unrelated failures cannot make this pass.
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_stage.sql
\set ON_ERROR_STOP on
select pg_temp.assert_no_push_fixture();
begin;
insert into public.profiles(user_id,username,display_name,visibility)
  values('22222222-2222-4222-8222-222222222222','push_test_peer','Synthetic push peer','private');
insert into public.guardian_push_devices values(
  '66666666-6666-4666-8666-666666666666','22222222-2222-4222-8222-222222222222',
  '77777777-7777-4777-8777-777777777777','synthetic-push-routing-token',
  sha256(convert_to(repeat('b',64),'UTF8')),now()+interval '1 day');
commit;
insert into public.guardian_push_devices values(
  '88888888-8888-4888-8888-888888888888','11111111-1111-4111-8111-111111111111',
  '99999999-9999-4999-8999-999999999999','synthetic-other-routing-token',
  sha256(convert_to(repeat('c',64),'UTF8')),now()+interval '1 day');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_stage.sql
\set ON_ERROR_STOP on
select pg_temp.assert_no_push_fixture();
do $$ begin
  if (select count(*) from public.guardian_push_devices)<>2 then raise exception 'Multiple-device refusal changed registrations'; end if;
end $$;
delete from public.guardian_push_devices where id='88888888-8888-4888-8888-888888888888';
update public.guardian_push_devices set expires_at=now()+interval '1 minute';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_stage.sql
\set ON_ERROR_STOP on
select pg_temp.assert_no_push_fixture();
update public.guardian_push_devices set expires_at=now()+interval '1 day';
insert into public.profiles(user_id,username,display_name,visibility)
  values('11111111-1111-4111-8111-111111111111','traelyx_push_fixture','Unrelated collision profile','private');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_stage.sql
\set ON_ERROR_STOP on
select pg_temp.assert_no_push_fixture();
do $$ begin
  if not exists(select 1 from public.profiles where user_id='11111111-1111-4111-8111-111111111111'
    and display_name='Unrelated collision profile') then raise exception 'Collision profile changed'; end if;
end $$;
delete from public.profiles where user_id='11111111-1111-4111-8111-111111111111';
\ir ../manual_tests/guardian_push_stage.sql
update public.profiles set display_name='Mismatched fixture marker' where user_id='00000000-0000-4000-9000-000000000691';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_cleanup.sql
\set ON_ERROR_STOP on
do $$ begin
  if not exists(select 1 from auth.users where id='00000000-0000-4000-9000-000000000691')
    or not exists(select 1 from public.profiles where user_id='00000000-0000-4000-9000-000000000691'
      and display_name='Mismatched fixture marker') then raise exception 'Cleanup deleted a mismatched principal'; end if;
end $$;
update public.profiles set display_name='Synthetic push test driver' where user_id='00000000-0000-4000-9000-000000000691';
begin;
set local role service_role;
do $$ declare claims jsonb; target jsonb; claim uuid; begin
  claims:=public.claim_guardian_dispatch_batch_v1(6);
  if jsonb_array_length(claims) is distinct from 1 or claims->0->>'delivery_id' is distinct from '00000000-0000-4000-9000-000000000695' then
    raise exception 'Push fixture did not yield exactly one reviewed claim';
  end if;
  claim:=(claims->0->>'claim_id')::uuid;
  target:=public.guardian_dispatch_target_v1('00000000-0000-4000-9000-000000000695',claim);
  if target is null or target->>'routing_token' is distinct from 'synthetic-push-routing-token'
    or target->>'device_id' is distinct from '66666666-6666-4666-8666-666666666666'
    or target->>'device_generation' is distinct from '77777777-7777-4777-8777-777777777777'
    or coalesce((target->>'ttl_seconds')::integer not between 1 and 480,true)
    or jsonb_array_length(public.claim_guardian_dispatch_batch_v1(6)) is distinct from 0 then
    raise exception 'Push target or reservation bounds failed';
  end if;
  -- An actual receiver can race the provider's completion response.
  if not public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
    '00000000-0000-4000-9000-000000000695') then raise exception 'Early device receipt denied'; end if;
  perform public.finish_guardian_dispatch_v2('00000000-0000-4000-9000-000000000695',claim,true,false,60);
end $$;
reset role;
do $$ begin
  if not exists(select 1 from public.guardian_alert_deliveries
    where id='00000000-0000-4000-9000-000000000695' and status='device_received'
    and attempts=1 and claim_id is null) then raise exception 'Completion lost receipt or attempt state'; end if;
end $$;
rollback;
\ir ../manual_tests/guardian_push_cleanup.sql
\ir ../manual_tests/guardian_push_cleanup.sql
begin;
do $$ begin
  if exists(select 1 from auth.users where id='00000000-0000-4000-9000-000000000691')
    or exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries)
    or (select count(*) from public.guardian_push_devices)<>1
    or not exists(select 1 from public.profiles where user_id='22222222-2222-4222-8222-222222222222'
      and username='push_test_peer' and display_name='Synthetic push peer' and visibility='private')
    or not exists(select 1 from public.guardian_push_devices where id='66666666-6666-4666-8666-666666666666'
      and user_id='22222222-2222-4222-8222-222222222222'
      and generation='77777777-7777-4777-8777-777777777777'
      and routing_token='synthetic-push-routing-token'
      and credential_hash=sha256(convert_to(repeat('b',64),'UTF8'))
      and expires_at>now()+interval '23 hours') then
    raise exception 'Push cleanup changed recipient or left synthetic state';
  end if;
end $$;
delete from public.guardian_push_devices where id='66666666-6666-4666-8666-666666666666';
delete from public.profiles where user_id='22222222-2222-4222-8222-222222222222';
commit;
select true as push_fixture_claim_receipt_cleanup_passed;
