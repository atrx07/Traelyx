-- Rollback-only synthetic contract checks. No real device/session/token is used.
begin;
insert into auth.users(id) values('30303030-3030-4030-8030-303030303030'),('31313131-3131-4131-8131-313131313131');
insert into public.profiles(user_id,username,display_name,visibility) values
 ('30303030-3030-4030-8030-303030303030','driver_revision_test','Synthetic Driver','private'),
 ('31313131-3131-4131-8131-313131313131','peer_revision_test','Synthetic Peer','private');
insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
 driver_username,driver_display_name,guardian_username,guardian_display_name,status,permissions,expires_at)
values('32323232-3232-4232-8232-323232323232','30303030-3030-4030-8030-303030303030','31313131-3131-4131-8131-313131313131',
 '30303030-3030-4030-8030-303030303030','31313131-3131-4131-8131-313131313131',
 'driver_revision_test','Synthetic Driver','peer_revision_test','Synthetic Peer','active',
 '{"crash_alert":true,"severe_drive_alert":false,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}',now()+interval '1 day');
create function pg_temp.driver_revision_check(value boolean,label text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
create function pg_temp.driver_revision_denied(query text,expected_code text) returns void language plpgsql as $$
begin
  begin execute query;
  exception when others then if sqlstate=expected_code then return; else raise; end if; end;
  raise exception 'Expected denial: %',expected_code;
end $$;
create temp table driver_revision_results(k text primary key,v jsonb);
grant select,insert on driver_revision_results to authenticated;

select pg_temp.driver_revision_check((select relrowsecurity from pg_class where oid='public.guardian_driver_controls'::regclass),'controls require RLS');
select pg_temp.driver_revision_check(not has_table_privilege('anon','public.guardian_driver_controls','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') and
 not has_table_privilege('authenticated','public.guardian_driver_controls','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') and
 not has_table_privilege('service_role','public.guardian_driver_controls','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),'controls have no client or worker table access');
select pg_temp.driver_revision_check(not exists(select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a
 where p.oid in ('public.get_guardian_driver_revision_v2(uuid)'::regprocedure,
 'public.set_guardian_driver_session_v2(uuid,uuid,text,bigint)'::regprocedure) and a.grantee=0 and a.privilege_type='EXECUTE'),'PUBLIC cannot execute');
select pg_temp.driver_revision_check(not has_function_privilege('anon','public.get_guardian_driver_revision_v2(uuid)','EXECUTE') and
 not has_function_privilege('anon','public.set_guardian_driver_session_v2(uuid,uuid,text,bigint)','EXECUTE') and
 not has_function_privilege('service_role','public.get_guardian_driver_revision_v2(uuid)','EXECUTE') and
 not has_function_privilege('service_role','public.set_guardian_driver_session_v2(uuid,uuid,text,bigint)','EXECUTE'),'anonymous/worker RPC access denied');
select pg_temp.driver_revision_check(has_function_privilege('authenticated','public.get_guardian_driver_revision_v2(uuid)','EXECUTE') and
 has_function_privilege('authenticated','public.set_guardian_driver_session_v2(uuid,uuid,text,bigint)','EXECUTE'),'signed-in RPC contract available');

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.driver_revision_denied($q$select public.get_guardian_driver_revision_v2('30303030-3030-4030-8030-303030303030')$q$,'42501');
select set_config('request.jwt.claim.sub','31313131-3131-4131-8131-313131313131',true);
select pg_temp.driver_revision_denied($q$select public.get_guardian_driver_revision_v2('30303030-3030-4030-8030-303030303030')$q$,'42501');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',null,null)$q$,'42501');
select set_config('request.jwt.claim.sub','30303030-3030-4030-8030-303030303030',true);
select pg_temp.driver_revision_check(public.get_guardian_driver_revision_v2('30303030-3030-4030-8030-303030303030')='{"revision":"0"}'::jsonb,'new owner reads zero as decimal text');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v1('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',repeat('a',64))$q$,'55000');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030',null,null,null)$q$,'22023');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',repeat('a',64),null)$q$,'22023');

-- Revoke arrives before a delayed activation. Its captured revision is now stale.
select pg_temp.driver_revision_check(public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',null,null)='{"enabled":false}'::jsonb,'absent exact revoke confirmed');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',repeat('a',64),0)$q$,'40001');
insert into driver_revision_results values('first',public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','35353535-3535-4535-8535-353535353535',repeat('b',64),1));
select pg_temp.driver_revision_check(public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','35353535-3535-4535-8535-353535353535',repeat('b',64),1)=(select v from driver_revision_results where k='first'),'exact activation retry keeps fixed expiry');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','35353535-3535-4535-8535-353535353535',repeat('c',64),1)$q$,'40001');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','36363636-3636-4636-8636-363636363636',repeat('c',64),1)$q$,'40001');
insert into driver_revision_results values('replacement',public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','36363636-3636-4636-8636-363636363636',repeat('c',64),2));
reset role;

-- Represent already queued old/new deliveries; old cleanup must leave new ones intact.
insert into public.guardian_push_devices values('37373737-3737-4737-8737-373737373737','31313131-3131-4131-8131-313131313131',
 '38383838-3838-4838-8838-383838383838','synthetic-revision-routing-token',sha256(convert_to(repeat('d',64),'UTF8')),now()+interval '1 day');
insert into public.guardian_alert_events(user_id,event_id,activation_id,kind,rule_version,occurred_at,expires_at) values
 ('30303030-3030-4030-8030-303030303030','39393939-3939-4939-8939-393939393939','35353535-3535-4535-8535-353535353535','possible_crash',1,now()-interval '40 seconds',now()+interval '10 minutes'),
 ('30303030-3030-4030-8030-303030303030','40404040-4040-4040-8040-404040404040','36363636-3636-4636-8636-363636363636','possible_crash',1,now()-interval '40 seconds',now()+interval '10 minutes');
insert into public.guardian_alert_deliveries(id,user_id,event_id,connection_id,connection_revision,device_id,device_generation) values
 ('41414141-4141-4141-8141-414141414141','30303030-3030-4030-8030-303030303030','39393939-3939-4939-8939-393939393939','32323232-3232-4232-8232-323232323232',1,'37373737-3737-4737-8737-373737373737','38383838-3838-4838-8838-383838383838'),
 ('42424242-4242-4242-8242-424242424242','30303030-3030-4030-8030-303030303030','40404040-4040-4040-8040-404040404040','32323232-3232-4232-8232-323232323232',1,'37373737-3737-4737-8737-373737373737','38383838-3838-4838-8838-383838383838');
set local role authenticated;
select pg_temp.driver_revision_check(public.set_guardian_driver_session_v1('30303030-3030-4030-8030-303030303030','35353535-3535-4535-8535-353535353535',null)='{"enabled":false}'::jsonb,'legacy superseded exact cleanup settles');
select pg_temp.driver_revision_check(public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','36363636-3636-4636-8636-363636363636',repeat('c',64),2)=(select v from driver_revision_results where k='replacement'),'unrelated cleanup cannot extend or change replacement');
reset role;
select pg_temp.driver_revision_check((select activation_id='36363636-3636-4636-8636-363636363636' from public.guardian_driver_sessions where user_id='30303030-3030-4030-8030-303030303030'),'newer session preserved');
select pg_temp.driver_revision_check((select status='revoked' from public.guardian_alert_deliveries where id='41414141-4141-4141-8141-414141414141') and
 (select status='pending' from public.guardian_alert_deliveries where id='42424242-4242-4242-8242-424242424242'),'only exact activation deliveries revoked');
select pg_temp.driver_revision_check((select count(*)=1 from public.guardian_driver_controls where user_id='30303030-3030-4030-8030-303030303030'),'constant-size owner control');
set local role authenticated;
select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','36363636-3636-4636-8636-363636363636',null,null);
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','36363636-3636-4636-8636-363636363636',repeat('c',64),2)$q$,'40001');
reset role;
select pg_temp.driver_revision_check(not exists(select 1 from public.guardian_driver_sessions where user_id='30303030-3030-4030-8030-303030303030'),'revoked activation cannot replay');
-- No local-clock eviction; bigint exhaustion must deny mutation without restoring authority.
update public.guardian_driver_controls set revision=9223372036854775807 where user_id='30303030-3030-4030-8030-303030303030';
set local role authenticated;
select pg_temp.driver_revision_check(public.get_guardian_driver_revision_v2('30303030-3030-4030-8030-303030303030')='{"revision":"9223372036854775807"}'::jsonb,'revision never loses JSON integer precision');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',null,null)$q$,'22003');
select pg_temp.driver_revision_denied($q$select public.set_guardian_driver_session_v2('30303030-3030-4030-8030-303030303030','34343434-3434-4434-8434-343434343434',repeat('a',64),9223372036854775807)$q$,'22003');
reset role;
rollback;
select not exists(select 1 from auth.users where id='30303030-3030-4030-8030-303030303030') as synthetic_user_absent,
 not exists(select 1 from public.guardian_driver_controls where user_id='30303030-3030-4030-8030-303030303030') as synthetic_control_absent,
 true as driver_revision_checks_passed;
