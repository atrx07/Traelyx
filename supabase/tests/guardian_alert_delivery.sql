begin;
insert into auth.users(id) values('33333333-3333-4333-8333-333333333333');
insert into public.profiles(user_id,username,display_name,visibility) values
('11111111-1111-4111-8111-111111111111','alert_driver','Synthetic Driver','private'),
('22222222-2222-4222-8222-222222222222','alert_peer','Synthetic Peer','private'),
('33333333-3333-4333-8333-333333333333','alert_other','Synthetic Other','private');
insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
 driver_username,driver_display_name,guardian_username,guardian_display_name,status,permissions,expires_at)
values('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'alert_driver','Synthetic Driver','alert_peer','Synthetic Peer','active',
 '{"crash_alert":true,"severe_drive_alert":true,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}',now()+interval '1 day');
create function pg_temp.alert_check(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
create function pg_temp.alert_denied(query text) returns void language plpgsql as $$
begin begin execute query; exception when others then return; end; raise exception 'Expected denial: %',query; end $$;
create temp table alert_test_data(k text primary key,v jsonb);
grant all on alert_test_data to authenticated,service_role;
insert into alert_test_data values('event',jsonb_build_object('schema_version',1,'event_id','55555555-5555-4555-8555-555555555555',
 'kind','possible_crash','rule_version',1,'occurred_at_epoch_ms',floor(extract(epoch from now()-interval '40 seconds')*1000)::bigint,
 'uncertainty','experimental_not_confirmed'));

select pg_temp.alert_check(not has_function_privilege('anon','public.list_guardian_alerts_v1(uuid)','EXECUTE'),'anonymous read denied');
select pg_temp.alert_check(not has_function_privilege('authenticated','public.ingest_guardian_alert_v1(uuid,text,jsonb)','EXECUTE'),'mobile cannot call trusted ingestion');
select pg_temp.alert_check(not has_function_privilege('authenticated','public.guardian_delivery_allowed_v1(uuid)','EXECUTE'),'private helper denied');
select pg_temp.alert_check(not has_table_privilege('service_role','public.guardian_push_devices','SELECT'),'service uses guarded RPC only');
select pg_temp.alert_check((select bool_and(relrowsecurity) from pg_class where oid in
 ('public.guardian_driver_sessions'::regclass,'public.guardian_push_devices'::regclass,'public.guardian_alert_events'::regclass,'public.guardian_alert_deliveries'::regclass)),'all tables RLS');

set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222','66666666-6666-4666-8666-666666666666',
 '77777777-7777-4777-8777-777777777777','synthetic-fcm-routing-token',repeat('b',64));
select pg_temp.alert_denied($q$select public.set_guardian_push_device_v1('11111111-1111-4111-8111-111111111111',gen_random_uuid(),gen_random_uuid(),'synthetic-token-wrong',repeat('c',64))$q$);
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into alert_test_data values('activation',public.set_guardian_driver_session_v1('11111111-1111-4111-8111-111111111111',
 '88888888-8888-4888-8888-888888888888',repeat('a',64)));
select pg_temp.alert_check((select (v->>'enabled')::boolean from alert_test_data where k='activation'),'explicit driver activation');
select pg_temp.alert_check(public.set_guardian_driver_session_v1('11111111-1111-4111-8111-111111111111',
 '88888888-8888-4888-8888-888888888888',repeat('a',64))=(select v from alert_test_data where k='activation'),'activation retry fixed expiry');
select pg_temp.alert_denied($q$select public.set_guardian_driver_session_v1('11111111-1111-4111-8111-111111111111','88888888-8888-4888-8888-888888888888',repeat('c',64))$q$);
select pg_temp.alert_denied($q$select public.set_guardian_driver_session_v1('11111111-1111-4111-8111-111111111111',gen_random_uuid(),null)$q$);
select pg_temp.alert_denied($q$select * from public.guardian_alert_events$q$);
select pg_temp.alert_denied($q$select * from public.guardian_push_devices$q$);

set local role service_role;
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('c',64),(select v from alert_test_data where k='event'))$q$);
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v||'{"latitude":1}' from alert_test_data where k='event'))$q$);
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v||jsonb_build_object('occurred_at_epoch_ms',floor(extract(epoch from now())*1000)::bigint) from alert_test_data where k='event'))$q$);
insert into alert_test_data values('accepted',public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v from alert_test_data where k='event')));
select pg_temp.alert_check((select v->>'recipient_devices'='1' and v->>'state'='backend_accepted' from alert_test_data where k='accepted'),'one opted-in recipient');
select pg_temp.alert_check((public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v from alert_test_data where k='event'))->>'duplicate')::boolean,'idempotent retry');
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v||'{"kind":"severe_drive"}' from alert_test_data where k='event'))$q$);
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v||jsonb_build_object('event_id',gen_random_uuid()) from alert_test_data where k='event'))$q$);
insert into alert_test_data values('claim',public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555'));
select pg_temp.alert_check((select jsonb_array_length(v)=1 and v->0->>'routing_token'='synthetic-fcm-routing-token' from alert_test_data where k='claim'),'server-only dispatch target');
select pg_temp.alert_check(public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555')='[]'::jsonb,'concurrent claim cannot repeat');
select public.finish_guardian_dispatch_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim'),
 (select (v->0->>'claim_id')::uuid from alert_test_data where k='claim'),true,false);
select pg_temp.alert_denied($q$select public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('c',64),(select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim'))$q$);
select pg_temp.alert_check(public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
 (select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'device receipt separate from provider acceptance');

set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select pg_temp.alert_check(public.list_guardian_alerts_v1('33333333-3333-4333-8333-333333333333')='[]'::jsonb,'unrelated account cannot read');
select pg_temp.alert_check(not public.view_guardian_alert_v1('33333333-3333-4333-8333-333333333333',(select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'unrelated view denied');
select pg_temp.alert_denied($q$select public.set_guardian_push_device_v1('33333333-3333-4333-8333-333333333333','66666666-6666-4666-8666-666666666666',gen_random_uuid(),'synthetic-other-token',repeat('c',64))$q$);
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select pg_temp.alert_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')->0->>'status'='device_received','receipt visible to entitled recipient');
select pg_temp.alert_check(public.view_guardian_alert_v1('22222222-2222-4222-8222-222222222222',(select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'recipient explicit view');
select pg_temp.alert_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')->0->>'status'='viewed','view distinct from receipt');

reset role;
savepoint permitted_baseline;
update public.guardian_connections set permissions=permissions||'{"crash_alert":false}' where id='44444444-4444-4444-8444-444444444444';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'actual permission downgrade independently enforced');
rollback to permitted_baseline;
update public.guardian_connections set status='closed',low_blocked=true where id='44444444-4444-4444-8444-444444444444';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'block immediately denies access');
rollback to permitted_baseline;
update public.guardian_alert_events set expires_at=now()-interval '1 second';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'expired events inaccessible');
rollback to permitted_baseline;
update public.guardian_driver_sessions set expires_at=now()-interval '1 second';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'expired driver capability inaccessible');
rollback to permitted_baseline;
update public.guardian_push_devices set expires_at=now()-interval '1 second';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'expired recipient opt-in inaccessible');
rollback to permitted_baseline;
set local role authenticated;
select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222','66666666-6666-4666-8666-666666666666',gen_random_uuid(),'synthetic-replacement-token',repeat('c',64));
select pg_temp.alert_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')='[]'::jsonb,'device replacement never inherits old deliveries');
reset role;
rollback to permitted_baseline;
set local role authenticated;
select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222','66666666-6666-4666-8666-666666666666',null,null,null);
select pg_temp.alert_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')='[]'::jsonb,'recipient opt-out removes old deliveries');
reset role;
rollback to permitted_baseline;
update public.guardian_alert_deliveries set status='pending',attempts=0;
set local role service_role;
select pg_temp.alert_check(not public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
 (select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'cannot acknowledge a never-dispatched alert');
reset role;
rollback to permitted_baseline;
update public.guardian_alert_deliveries set status='pending',attempts=5,next_attempt_at=now()-interval '1 second';
set local role service_role;
update alert_test_data set v=public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555') where k='claim';
select public.finish_guardian_dispatch_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim'),
 (select (v->0->>'claim_id')::uuid from alert_test_data where k='claim'),false,false);
select pg_temp.alert_check(public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555')='[]'::jsonb,'six attempts bound retries');
reset role;
select pg_temp.alert_check((select bool_and(status='failed' and attempts=6) from public.guardian_alert_deliveries),'retry exhaustion explicit');
rollback to permitted_baseline;
set local role authenticated;
select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222',gen_random_uuid(),gen_random_uuid(),'synthetic-token-device-2',repeat('c',64));
select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222',gen_random_uuid(),gen_random_uuid(),'synthetic-token-device-3',repeat('c',64));
select pg_temp.alert_denied($q$select public.set_guardian_push_device_v1('22222222-2222-4222-8222-222222222222',gen_random_uuid(),gen_random_uuid(),'synthetic-token-device-4',repeat('c',64))$q$);
reset role;
rollback to permitted_baseline;
release permitted_baseline;

savepoint recovery_baseline;
update public.guardian_alert_deliveries set status='pending',attempts=6,next_attempt_at=now()-interval '1 second';
set local role service_role;
select pg_temp.alert_check(public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555')='[]'::jsonb,'interrupted final attempt cannot be resent');
reset role;
select pg_temp.alert_check((select bool_and(status='failed') from public.guardian_alert_deliveries),'interrupted final attempt eventually fails explicitly');
rollback to recovery_baseline;
delete from public.guardian_alert_events;
update public.guardian_connections set permissions=permissions||'{"severe_drive_alert":false}';
set local role service_role;
select pg_temp.alert_check(public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),
 (select v||'{"kind":"severe_drive"}' from alert_test_data where k='event'))->>'recipient_devices'='0','severe event without permission has no recipients');
reset role;
rollback to recovery_baseline;
insert into public.guardian_alert_events(user_id,event_id,activation_id,kind,rule_version,occurred_at,received_at,expires_at)
 select '11111111-1111-4111-8111-111111111111',gen_random_uuid(),'88888888-8888-4888-8888-888888888888','severe_drive',1,
 now()-interval '2 hours',now()-interval '2 hours',now()-interval '110 minutes' from generate_series(1,9);
update public.guardian_alert_events set received_at=now()-interval '2 hours';
set local role service_role;
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v||jsonb_build_object('event_id',gen_random_uuid(),'kind','severe_drive') from alert_test_data where k='event'))$q$);
reset role;
update public.guardian_alert_events set received_at=now()-interval '25 hours';
set local role service_role;
select pg_temp.alert_check(public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),
 (select v||jsonb_build_object('event_id',gen_random_uuid(),'kind','severe_drive') from alert_test_data where k='event'))->>'recipient_devices'='1','old quota entries pruned on ingestion');
reset role;
select pg_temp.alert_check((select count(*)=1 from public.guardian_alert_events),'bounded retention prunes stale rows');
rollback to recovery_baseline;
release recovery_baseline;

reset role;
update public.guardian_connections set revision=revision+1 where id='44444444-4444-4444-8444-444444444444';
set local role authenticated;
select pg_temp.alert_check(public.list_guardian_alerts_v1('22222222-2222-4222-8222-222222222222')='[]'::jsonb,'permission revision invalidates old details');
set local role service_role;
select pg_temp.alert_check(not public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
 (select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'permission change invalidates queued push receipt');
reset role;
update public.guardian_connections set status='closed',revision=revision+1 where id='44444444-4444-4444-8444-444444444444';
update public.guardian_connections set status='active',revision=revision+1 where id='44444444-4444-4444-8444-444444444444';
select pg_temp.alert_check(not public.guardian_delivery_allowed_v1((select (v->0->>'delivery_id')::uuid from alert_test_data where k='claim')),'re-pair never revives old alert');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.set_guardian_driver_session_v1('11111111-1111-4111-8111-111111111111','88888888-8888-4888-8888-888888888888',null);
set local role service_role;
select pg_temp.alert_denied($q$select public.ingest_guardian_alert_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),(select v from alert_test_data where k='event'))$q$);
select pg_temp.alert_denied($q$select public.claim_guardian_deliveries_v1('11111111-1111-4111-8111-111111111111',repeat('a',64),'55555555-5555-4555-8555-555555555555')$q$);
reset role;
select pg_temp.alert_check((select count(*)=1 from public.guardian_alert_events),'duplicates never created additional events');
select pg_temp.alert_check((select bool_and(status='revoked') from public.guardian_alert_deliveries),'driver disable permanently revokes old deliveries');
rollback;
