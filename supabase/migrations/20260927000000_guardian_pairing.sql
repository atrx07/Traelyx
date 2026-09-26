-- Pairing/permission preferences only. This migration grants no telemetry access.
create table public.guardian_invites (
  driver_id uuid primary key references public.profiles(user_id) on delete cascade,
  id uuid not null unique default gen_random_uuid(),
  token_hash bytea not null unique,
  username text not null,
  display_name text not null,
  permissions jsonb not null,
  expires_at timestamptz not null,
  consumed boolean not null default false
);
create table public.guardian_connections (
  id uuid primary key default gen_random_uuid(),
  low_user uuid not null references public.profiles(user_id) on delete cascade,
  high_user uuid not null references public.profiles(user_id) on delete cascade,
  driver_id uuid not null,
  guardian_id uuid not null,
  driver_username text not null, driver_display_name text not null,
  guardian_username text not null, guardian_display_name text not null,
  status text not null check(status in ('pending','active','closed')),
  permissions jsonb not null,
  low_blocked boolean not null default false,
  high_blocked boolean not null default false,
  revision bigint not null default 1 check(revision>0),
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  unique(low_user,high_user),
  check(low_user<high_user),
  check(driver_id in (low_user,high_user) and guardian_id in (low_user,high_user) and driver_id<>guardian_id),
  check(not (low_blocked or high_blocked) or status='closed')
);
create index guardian_high_user_idx on public.guardian_connections(high_user);
create table public.guardian_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check(operation in ('create','preview','accept','edit')),
  window_start timestamptz not null, used integer not null check(used between 0 and 60),
  primary key(user_id,operation)
);
create table public.guardian_audit (
  id bigint generated always as identity primary key,
  connection_id uuid not null references public.guardian_connections(id) on delete cascade,
  actor_role text not null check(actor_role in ('driver','guardian')),
  action text not null,
  permissions jsonb not null,
  occurred_at timestamptz not null default now()
);
create index guardian_audit_connection_idx on public.guardian_audit(connection_id,id desc);
alter table public.guardian_invites enable row level security;
alter table public.guardian_connections enable row level security;
alter table public.guardian_limits enable row level security;
alter table public.guardian_audit enable row level security;
revoke all on public.guardian_invites,public.guardian_connections,public.guardian_limits,public.guardian_audit from public,anon,authenticated;
revoke all on sequence public.guardian_audit_id_seq from public,anon,authenticated;

create function public.guardian_permissions_valid_v1(p jsonb) returns boolean
language sql immutable set search_path='' as $$
  select case when jsonb_typeof(p) is distinct from 'object' then false else
    (select array_agg(k order by k) from jsonb_object_keys(p) k) is not distinct from
      array['crash_alert','current_safety_state','current_speed','live_location','severe_drive_alert','trip_history']
    and not exists(select 1 from jsonb_each(p) e where jsonb_typeof(e.value)<>'boolean')
    and p->'live_location'='false'::jsonb and p->'current_speed'='false'::jsonb and p->'trip_history'='false'::jsonb end
$$;
alter table public.guardian_invites add check(public.guardian_permissions_valid_v1(permissions));
alter table public.guardian_connections add check(public.guardian_permissions_valid_v1(permissions));

-- All quotas are private. Invalid previews return null, committing their attempt count.
create function public.guardian_quota_v1(owner_id uuid, op text) returns void
language plpgsql set search_path='' as $$
declare q public.guardian_limits; cap integer;
begin
  cap:=case op when 'create' then 10 when 'accept' then 10 when 'edit' then 30 when 'preview' then 60 else 0 end;
  insert into public.guardian_limits values(owner_id,op,now(),0) on conflict do nothing;
  select * into q from public.guardian_limits where user_id=owner_id and operation=op for update;
  if q.window_start<=now()-interval '24 hours' then q.used:=0; q.window_start:=now(); end if;
  if q.used>=cap then raise exception 'Guardian limit reached' using errcode='P0002'; end if;
  update public.guardian_limits set used=q.used+1,window_start=q.window_start where user_id=owner_id and operation=op;
end $$;
create function public.guardian_record_v1(connection uuid, actor text, event text, p jsonb) returns void
language plpgsql set search_path='' as $$
begin
  insert into public.guardian_audit(connection_id,actor_role,action,permissions) values(connection,actor,event,p);
  delete from public.guardian_audit where connection_id=connection and id not in
    (select id from public.guardian_audit where connection_id=connection order by id desc limit 100);
end $$;

create function public.create_guardian_invite_v1(expected_user_id uuid, expected_username text,
  expected_display_name text, requested_permissions jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare secret text; invite public.guardian_invites;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  if public.guardian_permissions_valid_v1(requested_permissions) is distinct from true then raise exception 'Invalid permissions' using errcode='22023'; end if;
  if not exists(select 1 from public.profiles where user_id=expected_user_id and username=expected_username and display_name=expected_display_name) then
    raise exception 'Review current profile' using errcode='40001'; end if;
  perform public.guardian_quota_v1(expected_user_id,'create');
  -- Two independently generated v4 UUIDs provide 244 random bits; no new extension.
  secret:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  insert into public.guardian_invites(driver_id,token_hash,username,display_name,permissions,expires_at)
    values(expected_user_id,sha256(convert_to(secret,'UTF8')),expected_username,expected_display_name,requested_permissions,now()+interval '10 minutes')
    on conflict(driver_id) do update set id=gen_random_uuid(),token_hash=excluded.token_hash,
      username=excluded.username,display_name=excluded.display_name,permissions=excluded.permissions,
      expires_at=excluded.expires_at,consumed=false returning * into invite;
  return jsonb_build_object('id',invite.id,'token',secret,'expires_at',invite.expires_at,'permissions',invite.permissions);
end $$;

create function public.cancel_guardian_invite_v1(expected_user_id uuid, invite_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  update public.guardian_invites set consumed=true where driver_id=expected_user_id and id=invite_id;
end $$;

create function public.preview_guardian_invite_v1(expected_user_id uuid, invite_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare invite public.guardian_invites; own public.profiles;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  perform public.guardian_quota_v1(expected_user_id,'preview');
  if invite_token is null or invite_token !~ '^[0-9a-f]{64}$' then return null; end if;
  select * into own from public.profiles where user_id=expected_user_id;
  if own.user_id is null then return null; end if;
  select * into invite from public.guardian_invites where token_hash=sha256(convert_to(invite_token,'UTF8'))
    and not consumed and expires_at>clock_timestamp() and driver_id<>expected_user_id;
  if invite.id is null or exists(select 1 from public.guardian_connections c where
    c.low_user=least(expected_user_id,invite.driver_id) and c.high_user=greatest(expected_user_id,invite.driver_id)
    and (c.low_blocked or c.high_blocked or c.status='active' or (c.status='pending' and c.expires_at>clock_timestamp()))) then return null; end if;
  return jsonb_build_object('id',invite.id,'username',invite.username,'display_name',invite.display_name,
    'expires_at',invite.expires_at,'permissions',invite.permissions,
    'own_username',own.username,'own_display_name',own.display_name);
end $$;

create function public.accept_guardian_invite_v1(expected_user_id uuid, invite_id uuid, invite_token text,
  expected_username text, expected_display_name text) returns void
language plpgsql security definer set search_path='' as $$
declare invite public.guardian_invites; r public.guardian_connections; lo uuid; hi uuid;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  if invite_token is null or invite_token !~ '^[0-9a-f]{64}$' then raise exception 'Unavailable'; end if;
  if not exists(select 1 from public.profiles where user_id=expected_user_id and username=expected_username and display_name=expected_display_name) then
    raise exception 'Review current profile' using errcode='40001'; end if;
  select * into invite from public.guardian_invites where id=invite_id and token_hash=sha256(convert_to(invite_token,'UTF8')) for update;
  if invite.id is null or invite.consumed or invite.expires_at<=clock_timestamp() or invite.driver_id=expected_user_id then raise exception 'Unavailable'; end if;
  lo:=least(expected_user_id,invite.driver_id); hi:=greatest(expected_user_id,invite.driver_id);
  perform pg_advisory_xact_lock(6701,hashtext(lo::text||hi::text));
  -- Ordered account locks bound total relationships under concurrent invitations.
  perform pg_advisory_xact_lock(6702,hashtext(lo::text));
  perform pg_advisory_xact_lock(6702,hashtext(hi::text));
  select * into r from public.guardian_connections where low_user=lo and high_user=hi for update;
  if r.low_blocked or r.high_blocked or r.status='active' or (r.status='pending' and r.expires_at>clock_timestamp()) then raise exception 'Unavailable'; end if;
  if r.id is null and ((select count(*) from public.guardian_connections where lo in (low_user,high_user))>=100 or
    (select count(*) from public.guardian_connections where hi in (low_user,high_user))>=100) then raise exception 'Connection limit reached'; end if;
  perform public.guardian_quota_v1(expected_user_id,'accept');
  if r.id is null then
    insert into public.guardian_connections(low_user,high_user,driver_id,guardian_id,driver_username,driver_display_name,
      guardian_username,guardian_display_name,status,permissions,expires_at)
    values(lo,hi,invite.driver_id,expected_user_id,invite.username,invite.display_name,expected_username,expected_display_name,
      'pending',invite.permissions,now()+interval '24 hours') returning * into r;
  else
    update public.guardian_connections set driver_id=invite.driver_id,guardian_id=expected_user_id,
      driver_username=invite.username,driver_display_name=invite.display_name,
      guardian_username=expected_username,guardian_display_name=expected_display_name,status='pending',
      permissions=invite.permissions,expires_at=now()+interval '24 hours',updated_at=now(),revision=revision+1
      where id=r.id returning * into r;
  end if;
  update public.guardian_invites set consumed=true where id=invite.id;
  perform public.guardian_record_v1(r.id,'guardian','accept_pending',r.permissions);
end $$;

create function public.change_guardian_connection_v1(expected_user_id uuid, connection_id uuid,
  expected_revision bigint, action_name text, requested_permissions jsonb default null) returns void
language plpgsql security definer set search_path='' as $$
declare r public.guardian_connections; own_block boolean; other_block boolean; actor text;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  select * into r from public.guardian_connections where id=connection_id and expected_user_id in (low_user,high_user) for update;
  if r.id is null or expected_revision is null or r.revision<>expected_revision then raise exception 'Reload required' using errcode='40001'; end if;
  own_block:=case when r.low_user=expected_user_id then r.low_blocked else r.high_blocked end;
  other_block:=case when r.low_user=expected_user_id then r.high_blocked else r.low_blocked end;
  actor:=case when r.driver_id=expected_user_id then 'driver' else 'guardian' end;
  if action_name='block' then
    update public.guardian_connections set status='closed',low_blocked=low_blocked or low_user=expected_user_id,
      high_blocked=high_blocked or high_user=expected_user_id where id=r.id;
  elsif action_name='unblock' and own_block then
    update public.guardian_connections set status='closed',
      low_blocked=case when low_user=expected_user_id then false else low_blocked end,
      high_blocked=case when high_user=expected_user_id then false else high_blocked end where id=r.id;
  elsif action_name='disconnect' then
    update public.guardian_connections set status='closed' where id=r.id;
  elsif own_block or other_block or r.status='closed' or (r.status='pending' and r.expires_at<=clock_timestamp()) then raise exception 'Unavailable';
  elsif action_name='confirm' and actor='driver' and r.status='pending' then
    update public.guardian_connections set status='active' where id=r.id;
  elsif action_name='permissions' and actor='driver' and r.status='active' then
    if public.guardian_permissions_valid_v1(requested_permissions) is distinct from true then raise exception 'Invalid permissions' using errcode='22023'; end if;
    -- Reductions must remain available even after edit quotas are exhausted.
    if exists(select 1 from jsonb_each(requested_permissions) e where e.value='true'::jsonb and r.permissions->e.key='false'::jsonb) then
      perform public.guardian_quota_v1(expected_user_id,'edit'); end if;
    update public.guardian_connections set permissions=requested_permissions where id=r.id;
  else raise exception 'Invalid transition' using errcode='22023'; end if;
  update public.guardian_connections set revision=revision+1,updated_at=now() where id=r.id returning * into r;
  perform public.guardian_record_v1(r.id,actor,action_name,r.permissions);
end $$;

-- Future delivery must re-check this private predicate at dispatch/read time.
-- No delivery or telemetry read endpoint is introduced in M6.7.
create function public.guardian_allows_v1(driver uuid, guardian uuid, permission_name text) returns boolean
language sql stable set search_path='' as $$
  select permission_name in ('crash_alert','severe_drive_alert','current_safety_state') and exists(
    select 1 from public.guardian_connections where driver_id=driver and guardian_id=guardian
      and status='active' and not low_blocked and not high_blocked and permissions->permission_name='true'::jsonb)
$$;

create function public.list_guardian_v1(expected_user_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare rows jsonb;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'revision',c.revision,
    'role',case when c.driver_id=expected_user_id then 'driver' else 'guardian' end,
    'username',case when c.driver_id=expected_user_id then c.guardian_username else c.driver_username end,
    'display_name',case when c.driver_id=expected_user_id then c.guardian_display_name else c.driver_display_name end,
    'state',case when (c.low_user=expected_user_id and c.low_blocked) or (c.high_user=expected_user_id and c.high_blocked) then 'blocked'
      when c.low_blocked or c.high_blocked or c.status='closed' or (c.status='pending' and c.expires_at<=clock_timestamp()) then 'closed'
      when c.status='active' then 'active' when c.driver_id=expected_user_id then 'confirm' else 'waiting' end,
    'permissions',c.permissions,'updated_at',c.updated_at,
    'history',coalesce((select jsonb_agg(jsonb_build_object('action',a.action,'actor',a.actor_role,
      'permissions',a.permissions,'at',a.occurred_at) order by a.id desc) from
      (select * from public.guardian_audit where connection_id=c.id order by id desc limit 20) a),'[]'::jsonb)
    ) order by c.updated_at desc),'[]'::jsonb) into rows from public.guardian_connections c
    where expected_user_id in (c.low_user,c.high_user);
  return jsonb_build_object('connections',rows,
    'profile',(select jsonb_build_object('username',username,'display_name',display_name) from public.profiles where user_id=expected_user_id),
    'invite',(select jsonb_build_object('id',id,'expires_at',expires_at,'permissions',permissions) from public.guardian_invites
      where driver_id=expected_user_id and not consumed and expires_at>clock_timestamp()));
end $$;
revoke all on function public.guardian_allows_v1(uuid,uuid,text),public.guardian_permissions_valid_v1(jsonb),public.guardian_quota_v1(uuid,text),
  public.guardian_record_v1(uuid,text,text,jsonb),public.create_guardian_invite_v1(uuid,text,text,jsonb),
  public.cancel_guardian_invite_v1(uuid,uuid),public.preview_guardian_invite_v1(uuid,text),
  public.accept_guardian_invite_v1(uuid,uuid,text,text,text),public.change_guardian_connection_v1(uuid,uuid,bigint,text,jsonb),
  public.list_guardian_v1(uuid) from public,anon,authenticated;
grant execute on function public.create_guardian_invite_v1(uuid,text,text,jsonb),public.cancel_guardian_invite_v1(uuid,uuid),
  public.preview_guardian_invite_v1(uuid,text),public.accept_guardian_invite_v1(uuid,uuid,text,text,text),
  public.change_guardian_connection_v1(uuid,uuid,bigint,text,jsonb),public.list_guardian_v1(uuid) to authenticated;
notify pgrst,'reload schema';
