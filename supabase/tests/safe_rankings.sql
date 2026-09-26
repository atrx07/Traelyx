begin;
insert into auth.users(id) values('33333333-3333-4333-8333-333333333333');
insert into public.profiles(user_id,username,display_name,visibility) values
 ('11111111-1111-4111-8111-111111111111','rank_alice','Alice','private'),
 ('22222222-2222-4222-8222-222222222222','rank_bob','Bob','public'),
 ('33333333-3333-4333-8333-333333333333','rank_eve','Eve','public');
insert into public.vehicles(user_id,id,display_name,vehicle_class) values
 ('11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','Synthetic','car'),
 ('22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','Synthetic','car');
create function pg_temp.dossier(n integer) returns jsonb language sql as $$
 select jsonb_build_object('source_digest',lpad(to_hex(n),64,'0'),'vehicle_class','car',
 'versions','{"analysis":1,"raw":1,"encoding":1,"schema":1,"timeline":1,"gnss":1,"calibration":1,"orientation":1,"derived":1,"confidence":1,"taxonomy":1,"merge":1,"integrity":1,"scoring":1,"validation":1}'::jsonb,
 'calibration','[1,1,1]'::jsonb,'duration_ms',120000,'moving_ms',90000,
 'integrity_counts','[0,0,0,0,0,0,0,0,0,0,0]'::jsonb,
 'dimensions','[[90000,90000,90000],[2000,2000,2000],[2000,2000,2000],[2000,2000,2000]]'::jsonb,
 'events','[]'::jsonb)
$$;
do $$ declare d jsonb; bad jsonb; begin
 d:=pg_temp.dossier(1);
 if public.validate_ranking_dossier_v1(d)<>100000 then raise exception 'base scoring'; end if;
 if public.validate_ranking_dossier_v1(jsonb_set(d,'{events}','[[1,1500,1000],[3,1000,1000],[6,2000,1000],[7,1000,1000]]'))<>70000 then raise exception 'penalty recomputation'; end if;
 foreach bad in array array[
   '{}'::jsonb, d||'{"latitude":1}'::jsonb,d-'calibration',jsonb_set(d,'{versions,scoring}','2'),
   jsonb_set(d,'{vehicle_class}','"unspecified"'), jsonb_set(d,'{vehicle_class}','null'),
   jsonb_set(d,'{integrity_counts,1}','1'),jsonb_set(d,'{duration_ms}','-1'),
   jsonb_set(d,'{moving_ms}','59999'),jsonb_set(d,'{moving_ms}','120001'),
   jsonb_set(d,'{dimensions,0,2}','71999'),jsonb_set(d,'{dimensions,1,0}','0'),
   jsonb_set(d,'{dimensions,1,1}','2001'),jsonb_set(d,'{calibration}','[1,0,1]'),
   jsonb_set(d,'{events}','[[9,1000,1000]]'),jsonb_set(d,'{events}','[[1,2001,1000]]'),
   jsonb_set(d,'{events}','[[1,1000,500]]'),jsonb_set(d,'{moving_ms}','"90000"'),
   jsonb_set(d,'{events}',(select jsonb_agg('[1,1000,1000]'::jsonb) from generate_series(1,1001)))
 ] loop
   begin perform public.validate_ranking_dossier_v1(bad); raise exception 'accepted invalid evidence';
   exception when invalid_parameter_value then null; end;
 end loop;
end $$;
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
do $$ declare i integer; d jsonb; begin
 for i in 1..10 loop
   d:=pg_temp.dossier(i);
   if i<=5 then d:=jsonb_set(d,'{events}','[[1,2000,1000]]'); end if;
   if i=10 then d:=jsonb_set(d,'{events}','[[6,2000,1000]]'); end if;
   perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',('aaaaaaaa-aaaa-4aaa-8aaa-'||lpad(i::text,12,'0'))::uuid,d);
   perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',('aaaaaaaa-aaaa-4aaa-8aaa-'||lpad(i::text,12,'0'))::uuid,d);
 end loop;
 if (public.read_rankings_v1(auth.uid())->'rows'->0->>'smoothness')::numeric<>98 or
    (public.read_rankings_v1(auth.uid())->'rows'->0->>'improvement')::numeric<>10 or
    (public.read_rankings_v1(auth.uid())->'rows'->0->>'consistency')::numeric<>96.8 then raise exception 'aggregates'; end if;
 begin perform public.read_rankings_v1('22222222-2222-4222-8222-222222222222'); raise exception 'cross account read'; exception when insufficient_privilege then null; end;
 begin perform public.withdraw_rankings_v1('22222222-2222-4222-8222-222222222222'); raise exception 'cross account withdraw'; exception when insufficient_privilege then null; end;
 begin perform public.submit_ranking_v1('22222222-2222-4222-8222-222222222222','rank_bob','Bob',gen_random_uuid(),pg_temp.dossier(50)); raise exception 'cross account write'; exception when insufficient_privilege then null; end;
 begin perform * from public.ranking_entries; raise exception 'raw dossier disclosure'; exception when insufficient_privilege then null; end;
 begin insert into public.ranking_members values(auth.uid(),'forged','Forged'); raise exception 'direct write'; exception when insufficient_privilege then null; end;
 begin perform public.validate_ranking_dossier_v1(pg_temp.dossier(50)); raise exception 'validator exposed'; exception when insufficient_privilege then null; end;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_alice','Changed',gen_random_uuid(),pg_temp.dossier(50)); raise exception 'stale profile accepted'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_profile_changed' then raise; end if; end;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',gen_random_uuid(),jsonb_set(pg_temp.dossier(50),'{vehicle_class}','"motorcycle"')); raise exception 'unowned class accepted'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_vehicle_class_invalid' then raise; end if; end;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice','aaaaaaaa-aaaa-4aaa-8aaa-000000000001',pg_temp.dossier(50)); raise exception 'snapshot overwrite'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_snapshot_conflict' then raise; end if; end;
end $$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$ begin
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'rows')<>0 then raise exception 'stranger disclosure'; end if;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_bob','Bob',gen_random_uuid(),pg_temp.dossier(1)); raise exception 'cross-account duplicate digest'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_snapshot_conflict' then raise; end if; end;
end $$;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
select public.request_friend_v1(auth.uid(),'rank_bob','Bob','aaaaaaaa-aaaa-4aaa-8aaa-ffffffffffff');
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'rows')<>0 then raise exception 'pending friend disclosure'; end if;
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'accept');
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'rows')<>1 then raise exception 'friend projection missing'; end if;
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'submitted_trip_ids')<>0 then raise exception 'friend trip ids leaked'; end if;
 if (select count(*) from jsonb_object_keys(public.read_rankings_v1(auth.uid())->'rows'->0))<>8 then raise exception 'projection shape'; end if;
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'block');
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'rows')<>0 then raise exception 'blocked projection remains'; end if;
end $$;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
do $$ declare i integer; begin
 for i in 11..30 loop
   perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',gen_random_uuid(),pg_temp.dossier(i));
 end loop;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',gen_random_uuid(),pg_temp.dossier(31)); raise exception 'quota bypass'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_daily_limit' then raise; end if; end;
 perform public.withdraw_rankings_v1(auth.uid());
 if jsonb_array_length(public.read_rankings_v1(auth.uid())->'rows')<>0 or jsonb_array_length(public.read_rankings_v1(auth.uid())->'submitted_trip_ids')<>0 then raise exception 'withdrawal incomplete'; end if;
 begin perform public.submit_ranking_v1(auth.uid(),'rank_alice','Alice',gen_random_uuid(),pg_temp.dossier(32)); raise exception 'withdrawal quota bypass'; exception when sqlstate 'P0001' then if sqlerrm<>'ranking_daily_limit' then raise; end if; end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.ranking_entries where user_id='11111111-1111-4111-8111-111111111111') then raise exception 'dossier remains'; end if;
 if not exists(select 1 from public.profiles where username='rank_alice' and visibility='private') then raise exception 'profile changed'; end if;
end $$;
set role anon;
do $$ begin
 begin perform public.read_rankings_v1(null); raise exception 'anonymous read'; exception when insufficient_privilege then null; end;
 begin perform public.submit_ranking_v1(null,null,null,null,null); raise exception 'anonymous write'; exception when insufficient_privilege then null; end;
 begin perform public.withdraw_rankings_v1(null); raise exception 'anonymous withdraw'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
