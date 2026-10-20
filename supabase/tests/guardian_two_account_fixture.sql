-- Disposable PostgreSQL only. Never run this wrapper in production.
create function pg_temp.two_check(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Two-account fixture check failed: %',label; end if; end $$;
create function pg_temp.two_clean() returns void language plpgsql as $$ begin
  if exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries) then
    raise exception 'Denied stage or cleanup left a test queue';
  end if;
end $$;
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_clean();
begin;
insert into auth.users(id) values('33333333-3333-4333-8333-333333333333');
insert into public.profiles(user_id,username,display_name,visibility) values
 ('11111111-1111-4111-8111-111111111111','two_driver','Synthetic Driver','private'),
 ('22222222-2222-4222-8222-222222222222','two_peer','Synthetic Receiver','private'),
 ('33333333-3333-4333-8333-333333333333','two_other','Synthetic Other','private');
insert into public.guardian_driver_controls values('11111111-1111-4111-8111-111111111111',9);
insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
 driver_username,driver_display_name,guardian_username,guardian_display_name,status,permissions,expires_at)
 values('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','two_driver','Synthetic Driver','two_peer','Synthetic Receiver','active',
 '{"crash_alert":true,"severe_drive_alert":false,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}',now()+interval '1 day');
insert into public.guardian_push_devices values
 ('66666666-6666-4666-8666-666666666666','11111111-1111-4111-8111-111111111111',
 '77777777-7777-4777-8777-777777777777','synthetic-two-driver-routing',sha256(convert_to(repeat('a',64),'UTF8')),now()+interval '1 day'),
 ('88888888-8888-4888-8888-888888888888','22222222-2222-4222-8222-222222222222',
 '99999999-9999-4999-8999-999999999999','synthetic-two-peer-routing',sha256(convert_to(repeat('b',64),'UTF8')),now()+interval '1 day');
commit;
update public.guardian_connections set permissions=jsonb_set(permissions,'{current_safety_state}','true');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_clean();
update public.guardian_connections set permissions=jsonb_set(permissions,'{current_safety_state}','false');
update public.guardian_push_devices set expires_at=now()+interval '1 minute'
 where user_id='22222222-2222-4222-8222-222222222222';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_clean();
update public.guardian_push_devices set expires_at=now()+interval '1 day';
insert into public.guardian_push_devices values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'synthetic-two-extra-routing',sha256(convert_to(repeat('c',64),'UTF8')),now()+interval '1 day');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_clean();
delete from public.guardian_push_devices where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
 driver_username,driver_display_name,guardian_username,guardian_display_name,status,permissions,expires_at)
 select '55555555-5555-4555-8555-555555555555','22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333','33333333-3333-4333-8333-333333333333',
 guardian_id,'two_other','Synthetic Other',guardian_username,guardian_display_name,status,permissions,expires_at
 from public.guardian_connections where id='44444444-4444-4444-8444-444444444444';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_clean();
delete from public.guardian_connections where id='55555555-5555-4555-8555-555555555555';
insert into public.guardian_driver_sessions values('11111111-1111-4111-8111-111111111111',
 '00000000-0000-4000-9000-000000001009',sha256(convert_to(repeat('d',64),'UTF8')),now()+interval '1 hour');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_stage.sql
\set ON_ERROR_STOP on
select pg_temp.two_check((select count(*)=1 and bool_and(activation_id='00000000-0000-4000-9000-000000001009')
 from public.guardian_driver_sessions),'existing session preserved');
delete from public.guardian_driver_sessions where activation_id='00000000-0000-4000-9000-000000001009';
insert into public.guardian_alert_events values('11111111-1111-4111-8111-111111111111',
 '00000000-0000-4000-9000-000000001002','00000000-0000-4000-9000-000000001009','possible_crash',1,
 now()-interval '40 seconds',now(),now()+interval '8 minutes');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_cleanup.sql
\set ON_ERROR_STOP on
select pg_temp.two_check((select count(*)=1 from public.guardian_alert_events),'collision cleanup refused');
delete from public.guardian_alert_events where event_id='00000000-0000-4000-9000-000000001002';
create function pg_temp.two_snapshot() returns jsonb language sql as $$ select jsonb_build_object(
 'users',(select jsonb_agg(to_jsonb(t) order by id) from auth.users t),
 'profiles',(select jsonb_agg(to_jsonb(t) order by user_id) from public.profiles t),
 'pairs',(select jsonb_agg(to_jsonb(t) order by id) from public.guardian_connections t),
 'devices',(select jsonb_agg(to_jsonb(t) order by id) from public.guardian_push_devices t),
 'controls',(select jsonb_agg(to_jsonb(t) order by user_id) from public.guardian_driver_controls t)) $$;
create temp table two_baseline as select pg_temp.two_snapshot() as value;
\ir ../manual_tests/guardian_two_account_stage.sql
select pg_temp.two_check(pg_temp.two_snapshot()=(select value from two_baseline),'stage preserves existing accounts/pair/devices/revision');
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select pg_temp.two_check(public.list_guardian_alerts_v1('11111111-1111-4111-8111-111111111111')->0->>'own_event'='true','driver sees outgoing');
select pg_temp.two_check(not public.view_guardian_alert_v1('11111111-1111-4111-8111-111111111111',
 '00000000-0000-4000-9000-000000001003'),'driver cannot acknowledge guardian opening');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select pg_temp.two_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')->0->>'own_event'='false','guardian sees incoming');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select pg_temp.two_check(public.list_guardian_alerts_v1('33333333-3333-4333-8333-333333333333')='[]','other account list empty');
select pg_temp.two_check(not public.view_guardian_alert_v1('33333333-3333-4333-8333-333333333333',
 '00000000-0000-4000-9000-000000001003'),'other account opening denied');
set local role service_role;
do $$ declare claims jsonb; claim uuid; begin
 claims:=public.claim_guardian_dispatch_batch_v1(6);
 perform pg_temp.two_check(jsonb_array_length(claims)=1 and claims->0->>'delivery_id'='00000000-0000-4000-9000-000000001003','sole dispatch claim');
 claim:=(claims->0->>'claim_id')::uuid;
 perform pg_temp.two_check(public.guardian_dispatch_target_v1('00000000-0000-4000-9000-000000001003',claim)->>'device_id'=
  '88888888-8888-4888-8888-888888888888','guardian device only');
 perform pg_temp.two_check(public.claim_guardian_dispatch_batch_v1(6)='[]','no second reservation');
 perform public.finish_guardian_dispatch_v2('00000000-0000-4000-9000-000000001003',claim,true,false,60);
 perform pg_temp.two_check(public.receive_guardian_alert_v1('88888888-8888-4888-8888-888888888888',repeat('b',64),
  '00000000-0000-4000-9000-000000001003'),'synthetic server receipt');
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select pg_temp.two_check(public.view_guardian_alert_v1('22222222-2222-4222-8222-222222222222',
 '00000000-0000-4000-9000-000000001003'),'guardian opening accepted');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select pg_temp.two_check(public.list_guardian_alerts_v1('11111111-1111-4111-8111-111111111111')->0->>'status'='viewed','driver sees opened state');
commit;
update public.guardian_alert_events set kind='severe_drive' where event_id='00000000-0000-4000-9000-000000001002';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_two_account_cleanup.sql
\set ON_ERROR_STOP on
select pg_temp.two_check((select count(*)=1 from public.guardian_alert_deliveries),'mismatched lineage cleanup refused');
update public.guardian_alert_events set kind='possible_crash' where event_id='00000000-0000-4000-9000-000000001002';
update public.guardian_driver_sessions set activation_id='00000000-0000-4000-9000-000000001009';
\ir ../manual_tests/guardian_two_account_cleanup.sql
select pg_temp.two_check((select count(*)=1 and bool_and(activation_id='00000000-0000-4000-9000-000000001009')
 from public.guardian_driver_sessions),'newer session preserved');
select pg_temp.two_check(pg_temp.two_snapshot()=(select value from two_baseline),'cleanup preserves existing state');
delete from public.guardian_driver_sessions where activation_id='00000000-0000-4000-9000-000000001009';
\ir ../manual_tests/guardian_two_account_cleanup.sql
select pg_temp.two_clean();
\ir ../manual_tests/guardian_two_account_stage.sql
delete from public.guardian_alert_deliveries where id='00000000-0000-4000-9000-000000001003';
\ir ../manual_tests/guardian_two_account_cleanup.sql
select pg_temp.two_clean();
select pg_temp.two_check(pg_temp.two_snapshot()=(select value from two_baseline),'missing-delivery cleanup preserves existing state');
begin;
delete from public.guardian_push_devices where id in ('66666666-6666-4666-8666-666666666666','88888888-8888-4888-8888-888888888888');
delete from public.guardian_connections where id='44444444-4444-4444-8444-444444444444';
delete from public.guardian_driver_controls where user_id='11111111-1111-4111-8111-111111111111';
delete from public.profiles where user_id in ('11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333');
delete from auth.users where id='33333333-3333-4333-8333-333333333333';
commit;
select true as two_account_fixture_guards_inbox_cleanup_passed;
