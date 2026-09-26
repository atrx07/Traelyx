begin;
insert into auth.users(id) values('33333333-3333-4333-8333-333333333333');
insert into public.profiles(user_id,username,display_name,visibility) values
 ('11111111-1111-4111-8111-111111111111','social_alice','Alice','private'),
 ('22222222-2222-4222-8222-222222222222','social_bob','Bob','public'),
 ('33333333-3333-4333-8333-333333333333','social_eve','Eve','public');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select public.request_friend_v1(auth.uid(),'social_bob','Bob','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
select public.request_friend_v1(auth.uid(),'social_bob','Bob','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
do $$ declare r record; begin
  select * into strict r from public.list_social_v1(auth.uid());
  if r.state <> 'outgoing' or r.revision <> 1 then raise exception 'request retry or direction'; end if;
  if (select count(*) from jsonb_object_keys(to_jsonb(r))) <> 5 then raise exception 'projection leak'; end if;
  begin perform public.change_friend_v1(auth.uid(),r.id,r.revision,'accept'); raise exception 'self accept'; exception when invalid_parameter_value then null; end;
  begin perform public.list_social_v1('22222222-2222-4222-8222-222222222222'); raise exception 'wrong account'; exception when insufficient_privilege then null; end;
  begin perform public.request_friend_v1('22222222-2222-4222-8222-222222222222','social_eve','Eve',gen_random_uuid()); raise exception 'switched request'; exception when insufficient_privilege then null; end;
  begin perform public.change_friend_v1('22222222-2222-4222-8222-222222222222',r.id,r.revision,'cancel'); raise exception 'switched action'; exception when insufficient_privilege then null; end;
  begin perform * from public.social_relationships; raise exception 'raw relationship read'; exception when insufficient_privilege then null; end;
  begin delete from public.social_relationships; raise exception 'raw relationship write'; exception when insufficient_privilege then null; end;
  begin perform * from public.social_request_limits; raise exception 'quota read'; exception when insufficient_privilege then null; end;
end $$;
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 if r.state <> 'incoming' or r.username <> 'social_alice' then raise exception 'private sender disclosure'; end if;
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'accept');
 begin perform public.change_friend_v1(auth.uid(),r.id,r.revision,'block'); raise exception 'stale action'; exception when serialization_failure then null; end;
 select * into strict r from public.list_social_v1(auth.uid());
 if r.state <> 'friend' then raise exception 'accept failed'; end if;
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'block');
 if (select state from public.list_social_v1(auth.uid())) <> 'blocked' then raise exception 'own block missing'; end if;
end $$;
-- Renaming a private former friend must not expose fresh private profile data.
reset role;
update public.profiles set display_name = 'Private changed name' where username = 'social_alice';
set role authenticated;
do $$ begin
 if (select display_name from public.list_social_v1(auth.uid())) <> 'Alice' then raise exception 'blocked name update leaked'; end if;
end $$;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
 if exists(select 1 from public.list_social_v1(auth.uid())) then raise exception 'other block revealed'; end if;
 begin perform public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid()); raise exception 'block bypass'; exception when sqlstate 'P0001' then if sqlerrm <> 'Unavailable' then raise; end if; end;
end $$;
set request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
do $$ begin
 if exists(select 1 from public.list_social_v1(auth.uid())) then raise exception 'third party list'; end if;
 begin perform public.request_friend_v1(auth.uid(),'social_alice','Private changed name',gen_random_uuid()); raise exception 'private discovery'; exception when sqlstate 'P0001' then if sqlerrm <> 'Unavailable' then raise; end if; end;
end $$;
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'unblock');
 if exists(select 1 from public.list_social_v1(auth.uid())) then raise exception 'unblock restored relationship'; end if;
end $$;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
 begin perform public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid()); raise exception 'cooldown bypass'; exception when sqlstate 'P0001' then if sqlerrm <> 'Unavailable' then raise; end if; end;
end $$;
reset role;
update public.social_relationships set closed_at = now() - interval '8 days' where low_user='11111111-1111-4111-8111-111111111111' and high_user='22222222-2222-4222-8222-222222222222';
set role authenticated;
select public.request_friend_v1(auth.uid(),'social_bob','Bob','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2');
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'decline');
end $$;
reset role;
update public.social_relationships set closed_at = now() - interval '8 days' where low_user='11111111-1111-4111-8111-111111111111' and high_user='22222222-2222-4222-8222-222222222222';
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid());
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'cancel');
end $$;
reset role;
update public.social_relationships set closed_at = now() - interval '8 days' where low_user='11111111-1111-4111-8111-111111111111' and high_user='22222222-2222-4222-8222-222222222222';
update public.social_request_limits set request_count=30 where user_id='11111111-1111-4111-8111-111111111111';
set role authenticated;
do $$ begin
 begin perform public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid()); raise exception 'rate bypass'; exception when sqlstate 'P0002' then null; end;
end $$;
reset role;
update public.social_request_limits set window_start=now()-interval '25 hours' where user_id='11111111-1111-4111-8111-111111111111';
set role authenticated;
select public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid());
reset role;
update public.social_relationships set requested_at=now()-interval '8 days' where low_user='11111111-1111-4111-8111-111111111111' and high_user='22222222-2222-4222-8222-222222222222';
set role authenticated;
do $$ begin
 if exists(select 1 from public.list_social_v1(auth.uid())) then raise exception 'expired request'; end if;
end $$;
-- Expired requests can be renewed, accepted, then removed by either participant.
select public.request_friend_v1(auth.uid(),'social_bob','Bob',gen_random_uuid());
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ declare r record; begin
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'accept');
 select * into strict r from public.list_social_v1(auth.uid());
 perform public.change_friend_v1(auth.uid(),r.id,r.revision,'remove');
end $$;
set role anon;
set request.jwt.claim.sub = '';
do $$ begin
 begin perform public.list_social_v1(null); raise exception 'anonymous list'; exception when insufficient_privilege then null; end;
 begin perform public.request_friend_v1(null,'social_bob','Bob',gen_random_uuid()); raise exception 'anonymous request'; exception when insufficient_privilege then null; end;
 begin perform public.change_friend_v1(null,gen_random_uuid(),1,'block'); raise exception 'anonymous change'; exception when insufficient_privilege then null; end;
 begin perform * from public.social_relationships; raise exception 'anonymous table'; exception when insufficient_privilege then null; end;
end $$;
rollback;
