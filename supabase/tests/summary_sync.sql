-- Run after all versioned migrations. Every fixture change is rolled back.
begin;
insert into auth.users (id) values ('33333333-3333-4333-8333-333333333333');
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
insert into public.trip_summaries (user_id, source_trip_id, summary_version, duration_seconds)
values ('33333333-3333-4333-8333-333333333333', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, 120)
on conflict (user_id, source_trip_id) do nothing;
-- Lost acknowledgement can be retried without duplicate or overwritten data.
insert into public.trip_summaries (user_id, source_trip_id, summary_version, duration_seconds)
values ('33333333-3333-4333-8333-333333333333', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, 999)
on conflict (user_id, source_trip_id) do nothing;
do $$ begin
  if (select count(*) from public.profiles) <> 0 then raise exception 'unexpected profile prerequisite'; end if;
  if (select count(*) from public.trip_summaries) <> 1 or
     (select duration_seconds from public.trip_summaries) <> 120 then
    raise exception 'summary retry changed data';
  end if;
end $$;
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$ begin
  if (select count(*) from public.trip_summaries) <> 0 then raise exception 'cross-owner summary visible'; end if;
  begin
    insert into public.trip_summaries (user_id, source_trip_id)
    values ('33333333-3333-4333-8333-333333333333', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
    raise exception 'cross-owner insert succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
delete from auth.users where id = '33333333-3333-4333-8333-333333333333';
do $$ begin
  if exists (select 1 from public.trip_summaries where user_id = '33333333-3333-4333-8333-333333333333') then
    raise exception 'auth deletion did not cascade';
  end if;
end $$;
rollback;
