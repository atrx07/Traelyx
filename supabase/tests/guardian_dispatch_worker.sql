begin;
-- Global claim tests require an empty delivery queue and exclusive fixture window.
lock table public.guardian_alert_deliveries in share row exclusive mode;
do $$ begin if exists(select 1 from public.guardian_alert_deliveries) then
 raise exception 'Worker fixture tests require an empty delivery queue'; end if; end $$;
create function pg_temp.worker_check(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
create function pg_temp.worker_denied(query text) returns void language plpgsql as $$
begin begin execute query; exception when others then return; end; raise exception 'Expected denial: %',query; end $$;
select pg_temp.worker_check(not has_function_privilege('anon','public.claim_guardian_dispatch_batch_v1(integer)','EXECUTE'),'anonymous cannot claim');
select pg_temp.worker_check(not has_function_privilege('authenticated','public.claim_guardian_dispatch_batch_v1(integer)','EXECUTE'),'signed-in cannot claim');
select pg_temp.worker_check(not has_function_privilege('authenticated','public.guardian_dispatch_target_v1(uuid,uuid)','EXECUTE'),'routing target private');
select pg_temp.worker_check(not has_function_privilege('anon','public.finish_guardian_dispatch_v2(uuid,uuid,boolean,boolean,integer)','EXECUTE'),'anonymous result denied');
select pg_temp.worker_check(not has_function_privilege('authenticated','public.finish_guardian_dispatch_v2(uuid,uuid,boolean,boolean,integer)','EXECUTE'),'signed-in result denied');
select pg_temp.worker_check(not has_table_privilege('service_role','public.guardian_push_devices','SELECT'),'worker retains RPC-only access');

insert into public.profiles(user_id,username,display_name,visibility) values
 ('11111111-1111-4111-8111-111111111111','worker_driver','Synthetic Driver','private'),
 ('22222222-2222-4222-8222-222222222222','worker_peer','Synthetic Peer','private');
insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
 driver_username,driver_display_name,guardian_username,guardian_display_name,status,permissions,expires_at)
values('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'worker_driver','Synthetic Driver','worker_peer','Synthetic Peer','active',
 '{"crash_alert":true,"severe_drive_alert":true,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}',now()+interval '1 day');
insert into public.guardian_driver_sessions values('11111111-1111-4111-8111-111111111111',
 '88888888-8888-4888-8888-888888888888',sha256(convert_to(repeat('a',64),'UTF8')),now()+interval '8 hours');
insert into public.guardian_push_devices values('66666666-6666-4666-8666-666666666666',
 '22222222-2222-4222-8222-222222222222','77777777-7777-4777-8777-777777777777',
 'synthetic-worker-routing-token',sha256(convert_to(repeat('b',64),'UTF8')),now()+interval '30 days');
insert into public.guardian_alert_events values('11111111-1111-4111-8111-111111111111',
 '55555555-5555-4555-8555-555555555555','88888888-8888-4888-8888-888888888888',
 'possible_crash',1,now()-interval '40 seconds',now(),now()+interval '9 minutes');
insert into public.guardian_alert_deliveries(id,user_id,event_id,connection_id,connection_revision,device_id,device_generation)
select '99999999-9999-4999-8999-999999999999','11111111-1111-4111-8111-111111111111',
 '55555555-5555-4555-8555-555555555555',c.id,c.revision,'66666666-6666-4666-8666-666666666666',
 '77777777-7777-4777-8777-777777777777' from public.guardian_connections c where c.id='44444444-4444-4444-8444-444444444444';
create temp table worker_claim(v jsonb);
grant all on worker_claim to service_role;
savepoint initial_delivery;
set local role service_role;
select pg_temp.worker_denied('select public.claim_guardian_dispatch_batch_v1(0)');
select pg_temp.worker_denied('select public.claim_guardian_dispatch_batch_v1(31)');
insert into worker_claim select public.claim_guardian_dispatch_batch_v1(1);
select pg_temp.worker_check((select jsonb_array_length(v)=1 from worker_claim),'one due claim');
select pg_temp.worker_check(public.claim_guardian_dispatch_batch_v1()='[]'::jsonb,'lease prevents duplicate claim');
select pg_temp.worker_check(public.guardian_dispatch_target_v1('99999999-9999-4999-8999-999999999999',gen_random_uuid()) is null,'wrong claim cannot obtain routing');
select pg_temp.worker_check((public.guardian_dispatch_target_v1('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim))->>'routing_token')='synthetic-worker-routing-token','worker gets allowed target');
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),false,false,180);
reset role;
select pg_temp.worker_check((select status='pending' and attempts=1 and next_attempt_at=now()+interval '180 seconds' and claim_id is null
 from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'retry-after retained and old claim consumed');
set local role service_role;
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),true,false);
reset role;
select pg_temp.worker_check((select status='pending' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'stale result ignored');
update public.guardian_alert_deliveries set next_attempt_at=now()-interval '1 second' where id='99999999-9999-4999-8999-999999999999';
set local role service_role;
update worker_claim set v=public.claim_guardian_dispatch_batch_v1();
reset role;
update public.guardian_connections set revision=revision+1 where id='44444444-4444-4444-8444-444444444444';
set local role service_role;
select pg_temp.worker_check(public.guardian_dispatch_target_v1('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim)) is null,'permission changed between claim and send');
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),true,false);
reset role;
select pg_temp.worker_check((select status='revoked' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'late provider result cannot restore permission');
rollback to initial_delivery;

-- A killed worker's claim is replaced, and its late completion cannot affect the retry.
set local role service_role;
insert into worker_claim select public.claim_guardian_dispatch_batch_v1();
reset role;
update public.guardian_alert_deliveries set next_attempt_at=now()-interval '1 second' where id='99999999-9999-4999-8999-999999999999';
set local role service_role;
select pg_temp.worker_check(jsonb_array_length(public.claim_guardian_dispatch_batch_v1())=1,'interrupted worker reclaimed');
select pg_temp.worker_check(public.guardian_dispatch_target_v1('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim)) is null,'old reservation invalid after reclaim');
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),true,false);
reset role;
select pg_temp.worker_check((select attempts=2 and status='pending' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'old completion ignored after reclaim');
rollback to initial_delivery;

update public.guardian_alert_deliveries set attempts=6 where id='99999999-9999-4999-8999-999999999999';
set local role service_role;
select pg_temp.worker_check(public.claim_guardian_dispatch_batch_v1()='[]'::jsonb,'killed final attempt not retried');
reset role;
select pg_temp.worker_check((select status='failed' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'exhausted attempt terminal');
rollback to initial_delivery;
set local role service_role;
insert into worker_claim select public.claim_guardian_dispatch_batch_v1();
select pg_temp.worker_check(public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
 '99999999-9999-4999-8999-999999999999'),'receipt may beat provider callback');
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),false,true);
reset role;
select pg_temp.worker_check((select status='device_received' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'callback cannot downgrade receipt');
rollback to initial_delivery;
set local role service_role;
insert into worker_claim select public.claim_guardian_dispatch_batch_v1();
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),true,false);
select public.finish_guardian_dispatch_v2('99999999-9999-4999-8999-999999999999',
 (select (v->0->>'claim_id')::uuid from worker_claim),false,true);
select pg_temp.worker_denied($q$select public.finish_guardian_dispatch_v2(gen_random_uuid(),gen_random_uuid(),true,true)$q$);
reset role;
select pg_temp.worker_check((select status='provider_accepted' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'duplicate callback cannot downgrade provider acceptance');
rollback to initial_delivery;
update public.guardian_alert_events set expires_at=now()-interval '1 second' where user_id='11111111-1111-4111-8111-111111111111' and event_id='55555555-5555-4555-8555-555555555555';
set local role service_role;
select pg_temp.worker_check(public.claim_guardian_dispatch_batch_v1()='[]'::jsonb,'expired event never sent');
reset role;
select pg_temp.worker_check((select status='revoked' from public.guardian_alert_deliveries where id='99999999-9999-4999-8999-999999999999'),'expired delivery terminal');
rollback;
