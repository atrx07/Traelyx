-- M6.5 participant-only relationships. No trip/vehicle/profile table grants.
create table public.social_relationships (
  id uuid primary key default gen_random_uuid(),
  low_user uuid not null references public.profiles(user_id) on delete cascade,
  high_user uuid not null references public.profiles(user_id) on delete cascade,
  requester uuid not null,
  low_username text not null,
  low_display_name text not null,
  high_username text not null,
  high_display_name text not null,
  status text not null check (status in ('pending', 'accepted', 'closed')),
  low_blocked boolean not null default false,
  high_blocked boolean not null default false,
  revision bigint not null default 1 check (revision > 0),
  requested_at timestamptz not null default now(),
  closed_at timestamptz,
  request_mutation uuid not null,
  unique(low_user, high_user),
  check(low_user < high_user),
  check(requester in (low_user, high_user)),
  check(not (low_blocked or high_blocked) or status = 'closed')
);
create index social_high_user_idx on public.social_relationships(high_user);
create table public.social_request_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null,
  request_count integer not null check(request_count between 0 and 30)
);
alter table public.social_relationships enable row level security;
alter table public.social_request_limits enable row level security;
revoke all on public.social_relationships, public.social_request_limits
  from public, anon, authenticated;
-- No client policies: only the narrow SECURITY DEFINER RPCs below can access.

create function public.list_social_v1(expected_user_id uuid)
returns table (id uuid, revision bigint, username text, display_name text, state text)
language plpgsql security definer set search_path = '' as $$
begin
  if expected_user_id is null or auth.uid() is null or auth.uid() <> expected_user_id then
    raise insufficient_privilege;
  end if;
  return query
  select r.id, r.revision,
    case when r.low_user = expected_user_id then r.high_username else r.low_username end,
    case when r.low_user = expected_user_id then r.high_display_name else r.low_display_name end,
    case when (r.low_user = expected_user_id and r.low_blocked) or
                   (r.high_user = expected_user_id and r.high_blocked) then 'blocked'
         when r.status = 'accepted' then 'friend'
         when r.requester = expected_user_id then 'outgoing' else 'incoming' end
  from public.social_relationships r
  where expected_user_id in (r.low_user, r.high_user) and (
    (r.low_user = expected_user_id and r.low_blocked) or
    (r.high_user = expected_user_id and r.high_blocked) or
    (not r.low_blocked and not r.high_blocked and
      (r.status = 'accepted' or (r.status = 'pending' and r.requested_at > now() - interval '7 days')))
  ) order by r.id limit 1000;
end $$;

create function public.request_friend_v1(expected_user_id uuid, target_username text,
  target_display_name text, mutation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare peer uuid; lo uuid; hi uuid; r public.social_relationships;
  quota public.social_request_limits; low_profile public.profiles; high_profile public.profiles;
begin
  if expected_user_id is null or auth.uid() is null or auth.uid() <> expected_user_id then
    raise insufficient_privilege;
  end if;
  if mutation_id is null or target_username is null or target_username !~ '^[a-z][a-z0-9_]{2,29}$' then
    raise exception 'Invalid request' using errcode = '22023';
  end if;
  select p.user_id into peer from public.profiles p where p.username = target_username
    and p.display_name = target_display_name and p.visibility = 'public';
  if peer is null or peer = expected_user_id or
     not exists(select 1 from public.profiles where user_id = expected_user_id) then
    raise exception 'Unavailable' using errcode = 'P0001';
  end if;
  lo := least(peer, expected_user_id); hi := greatest(peer, expected_user_id);
  perform pg_catalog.pg_advisory_xact_lock(6105, pg_catalog.hashtext(lo::text || hi::text));
  perform pg_catalog.pg_advisory_xact_lock(6106, pg_catalog.hashtext(lo::text));
  perform pg_catalog.pg_advisory_xact_lock(6106, pg_catalog.hashtext(hi::text));
  select * into low_profile from public.profiles where user_id = lo;
  select * into high_profile from public.profiles where user_id = hi;
  select * into r from public.social_relationships where low_user = lo and high_user = hi for update;
  if r.low_blocked or r.high_blocked then raise exception 'Unavailable' using errcode = 'P0001'; end if;
  if r.requester = expected_user_id and r.request_mutation = mutation_id then return; end if;
  if r.id is not null and (r.status = 'accepted' or
      (r.status = 'pending' and r.requested_at > now() - interval '7 days') or
      (r.closed_at is not null and r.closed_at > now() - interval '7 days')) then
    raise exception 'Unavailable' using errcode = 'P0001';
  end if;
  if r.id is null and ((select count(*) from public.social_relationships where expected_user_id in (low_user, high_user)) >= 1000
    or (select count(*) from public.social_relationships where peer in (low_user, high_user)) >= 1000) then
    raise exception 'Unavailable' using errcode = 'P0001';
  end if;
  insert into public.social_request_limits values(expected_user_id, now(), 0) on conflict do nothing;
  select * into quota from public.social_request_limits where user_id = expected_user_id for update;
  if quota.window_start <= now() - interval '24 hours' then
    update public.social_request_limits set window_start = now(), request_count = 0 where user_id = expected_user_id;
    quota.request_count := 0;
  end if;
  if quota.request_count >= 30 then raise exception 'Request limit reached' using errcode = 'P0002'; end if;
  update public.social_request_limits set request_count = request_count + 1 where user_id = expected_user_id;
  if r.id is null then
    insert into public.social_relationships(low_user, high_user, requester, status, request_mutation,
      low_username, low_display_name, high_username, high_display_name)
    values(lo, hi, expected_user_id, 'pending', mutation_id,
      low_profile.username, low_profile.display_name, high_profile.username, high_profile.display_name);
  else
    update public.social_relationships set requester = expected_user_id, status = 'pending',
      requested_at = now(), closed_at = null, request_mutation = mutation_id, revision = revision + 1,
      low_username = low_profile.username, low_display_name = low_profile.display_name,
      high_username = high_profile.username, high_display_name = high_profile.display_name where id = r.id;
  end if;
end $$;

create function public.change_friend_v1(expected_user_id uuid, relationship_id uuid,
  expected_revision bigint, action_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.social_relationships; own_block boolean; other_block boolean;
begin
  if expected_user_id is null or auth.uid() is null or auth.uid() <> expected_user_id then raise insufficient_privilege; end if;
  select * into r from public.social_relationships where id = relationship_id
    and expected_user_id in (low_user, high_user) for update;
  if r.id is null or expected_revision is null or r.revision <> expected_revision then
    raise exception 'Reload required' using errcode = '40001';
  end if;
  own_block := case when r.low_user = expected_user_id then r.low_blocked else r.high_blocked end;
  other_block := case when r.low_user = expected_user_id then r.high_blocked else r.low_blocked end;
  if action_name = 'unblock' and own_block then
    update public.social_relationships set
      low_blocked = case when low_user = expected_user_id then false else low_blocked end,
      high_blocked = case when high_user = expected_user_id then false else high_blocked end,
      closed_at = now(), revision = revision + 1 where id = r.id;
    return;
  end if;
  if own_block or other_block or r.status = 'closed' or
     (r.status = 'pending' and r.requested_at <= now() - interval '7 days') then
    raise exception 'Unavailable' using errcode = 'P0001';
  end if;
  if action_name = 'block' then
    update public.social_relationships set status = 'closed', closed_at = now(),
      low_blocked = low_user = expected_user_id or low_blocked,
      high_blocked = high_user = expected_user_id or high_blocked,
      revision = revision + 1 where id = r.id;
  elsif action_name = 'accept' and r.status = 'pending' and r.requester <> expected_user_id then
    update public.social_relationships set status = 'accepted', revision = revision + 1 where id = r.id;
  elsif (action_name = 'decline' and r.status = 'pending' and r.requester <> expected_user_id) or
        (action_name = 'cancel' and r.status = 'pending' and r.requester = expected_user_id) or
        (action_name = 'remove' and r.status = 'accepted') then
    update public.social_relationships set status = 'closed', closed_at = now(), revision = revision + 1 where id = r.id;
  else raise exception 'Invalid transition' using errcode = '22023'; end if;
end $$;
revoke all on function public.list_social_v1(uuid),
 public.request_friend_v1(uuid,text,text,uuid), public.change_friend_v1(uuid,uuid,bigint,text)
 from public, anon, authenticated;
grant execute on function public.list_social_v1(uuid),
 public.request_friend_v1(uuid,text,text,uuid), public.change_friend_v1(uuid,uuid,bigint,text)
 to authenticated;
notify pgrst, 'reload schema';
