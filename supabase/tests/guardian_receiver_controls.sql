-- Disposable PostgreSQL only. Never run this wrapper in production.
create function pg_temp.receiver_assert(ok boolean, message text) returns void
language plpgsql as $$ begin
  if ok is distinct from true then raise exception '%',message; end if;
end $$;
create function pg_temp.receiver_accept() returns void language plpgsql as $$
declare claims jsonb; claim uuid; begin
  claims:=public.claim_guardian_dispatch_batch_v1(6);
  perform pg_temp.receiver_assert(jsonb_array_length(claims)=1,'Expected one synthetic claim');
  claim:=(claims->0->>'claim_id')::uuid;
  perform public.finish_guardian_dispatch_v2(
    '00000000-0000-4000-9000-000000000695',claim,true,false,60);
end $$;

insert into public.profiles(user_id,username,display_name,visibility)
  values('22222222-2222-4222-8222-222222222222','receiver_controls_peer','Synthetic receiver peer','private');
insert into public.guardian_push_devices values(
  '66666666-6666-4666-8666-666666666666','22222222-2222-4222-8222-222222222222',
  '77777777-7777-4777-8777-777777777777','synthetic-receiver-controls-routing',
  sha256(convert_to(repeat('b',64),'UTF8')),now()+interval '1 day');
\ir ../manual_tests/guardian_push_stage.sql

-- Refuse a requeue before the first receipt, with unchanged pending state.
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_requeue.sql
\set ON_ERROR_STOP on
select pg_temp.receiver_assert(exists(select 1 from public.guardian_alert_deliveries
  where status='pending' and attempts=0),'Unreceived requeue changed state');
select pg_temp.receiver_accept();
select pg_temp.receiver_assert(public.receive_guardian_delivery_v1(
  '66666666-6666-4666-8666-666666666666',repeat('b',64),
  '00000000-0000-4000-9000-000000000695'),'First receipt denied');

-- Never mutate a principal with a mismatching private fixture marker.
update public.profiles set display_name='Mismatched receiver marker'
  where user_id='00000000-0000-4000-9000-000000000691';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_requeue.sql
\set ON_ERROR_STOP on
select pg_temp.receiver_assert(exists(select 1 from public.guardian_alert_deliveries
  where status='device_received' and attempts=1),'Marker refusal changed delivery');
select pg_temp.receiver_assert(public.guardian_delivery_allowed_v1(
  '00000000-0000-4000-9000-000000000695'),'Marker refusal revoked authority');
update public.profiles set display_name='Synthetic push test driver'
  where user_id='00000000-0000-4000-9000-000000000691';
\ir ../manual_tests/guardian_push_requeue.sql
select pg_temp.receiver_assert(exists(select 1 from public.guardian_alert_deliveries
  where status='pending' and attempts=1),'Requeue erased attempt history');
select pg_temp.receiver_accept();
select pg_temp.receiver_assert(public.receive_guardian_delivery_v1(
  '66666666-6666-4666-8666-666666666666',repeat('b',64),
  '00000000-0000-4000-9000-000000000695'),'Duplicate receipt denied');
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_requeue.sql
\set ON_ERROR_STOP on
select pg_temp.receiver_assert(exists(select 1 from public.guardian_alert_deliveries
  where status='device_received' and attempts=2),'Third-send refusal changed state');
\ir ../manual_tests/guardian_push_cleanup.sql

\ir ../manual_tests/guardian_push_stage.sql
select pg_temp.receiver_accept();
update public.profiles set display_name='Mismatched receiver marker'
  where user_id='00000000-0000-4000-9000-000000000691';
\set ON_ERROR_STOP off
\ir ../manual_tests/guardian_push_expire.sql
\ir ../manual_tests/guardian_push_disconnect.sql
\set ON_ERROR_STOP on
select pg_temp.receiver_assert(public.guardian_delivery_allowed_v1(
  '00000000-0000-4000-9000-000000000695'),'Accepted marker refusal revoked authority');
select pg_temp.receiver_assert(not exists(select 1 from public.guardian_audit
  where connection_id='00000000-0000-4000-9000-000000000692'),'Marker refusal disconnected a principal');
update public.profiles set display_name='Synthetic push test driver'
  where user_id='00000000-0000-4000-9000-000000000691';
\ir ../manual_tests/guardian_push_expire.sql
select pg_temp.receiver_assert(not public.receive_guardian_delivery_v1(
  '66666666-6666-4666-8666-666666666666',repeat('b',64),
  '00000000-0000-4000-9000-000000000695'),'Expired delivery accepted a receipt');
select pg_temp.receiver_assert(exists(select 1 from public.guardian_alert_deliveries
  where status='provider_accepted' and attempts=1),'Expiry recorded a receipt');
\ir ../manual_tests/guardian_push_cleanup.sql

\ir ../manual_tests/guardian_push_stage.sql
select pg_temp.receiver_accept();
\ir ../manual_tests/guardian_push_disconnect.sql
select pg_temp.receiver_assert(not public.receive_guardian_delivery_v1(
  '66666666-6666-4666-8666-666666666666',repeat('b',64),
  '00000000-0000-4000-9000-000000000695'),'Disconnected delivery accepted a receipt');
select pg_temp.receiver_assert(exists(select 1 from public.guardian_audit
  where connection_id='00000000-0000-4000-9000-000000000692'
  and actor_role='driver' and action='disconnect'),'Disconnect audit absent');
\ir ../manual_tests/guardian_push_cleanup.sql
select pg_temp.receiver_assert(not exists(select 1 from public.guardian_audit
  where connection_id='00000000-0000-4000-9000-000000000692'),'Cleanup left synthetic audit');
select pg_temp.receiver_assert(not exists(select 1 from public.guardian_driver_sessions)
  and not exists(select 1 from public.guardian_alert_events)
  and not exists(select 1 from public.guardian_alert_deliveries)
  and (select count(*) from public.guardian_push_devices)=1,'Cleanup changed queue/device boundary');
select pg_temp.receiver_assert(exists(select 1 from public.guardian_push_devices
  where routing_token='synthetic-receiver-controls-routing'
  and credential_hash=sha256(convert_to(repeat('b',64),'UTF8'))
  and generation='77777777-7777-4777-8777-777777777777'
  and expires_at>now()+interval '23 hours'),'Controls changed recipient authority');
delete from public.guardian_push_devices where id='66666666-6666-4666-8666-666666666666';
delete from public.profiles where user_id='22222222-2222-4222-8222-222222222222';
select true as receiver_controls_marker_requeue_expiry_disconnect_passed;
