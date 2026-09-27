-- M6.8: opt-in, minimized, experimental client-reported alerts. No telemetry or route grants.
create table public.guardian_driver_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  activation_id uuid not null, credential_hash bytea not null,
  expires_at timestamptz not null
);
create table public.guardian_push_devices (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  generation uuid not null, routing_token text not null unique check(length(routing_token) between 16 and 4096),
  credential_hash bytea not null, expires_at timestamptz not null
);
create index guardian_push_owner_idx on public.guardian_push_devices(user_id);
create table public.guardian_alert_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid not null, activation_id uuid not null,
  kind text not null check(kind in ('severe_drive','possible_crash')),
  rule_version integer not null check(rule_version=1),
  occurred_at timestamptz not null, received_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key(user_id,event_id)
);
create table public.guardian_alert_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null, event_id uuid not null,
  connection_id uuid not null references public.guardian_connections(id) on delete cascade,
  connection_revision bigint not null,
  device_id uuid not null references public.guardian_push_devices(id) on delete cascade,
  device_generation uuid not null,
  status text not null default 'pending' check(status in ('pending','provider_accepted','device_received','viewed','revoked','failed')),
  attempts integer not null default 0 check(attempts between 0 and 6),
  next_attempt_at timestamptz not null default now(), claim_id uuid,
  foreign key(user_id,event_id) references public.guardian_alert_events(user_id,event_id) on delete cascade,
  unique(user_id,event_id,device_id)
);
alter table public.guardian_driver_sessions enable row level security;
alter table public.guardian_push_devices enable row level security;
alter table public.guardian_alert_events enable row level security;
alter table public.guardian_alert_deliveries enable row level security;
revoke all on public.guardian_driver_sessions,public.guardian_push_devices,
  public.guardian_alert_events,public.guardian_alert_deliveries from public,anon,authenticated,service_role;

create function public.guardian_alert_credential_valid_v1(credential text) returns boolean
language sql immutable set search_path='' as $$
  select credential is not null and credential ~ '^[a-f0-9]{64}$'
$$;

create function public.set_guardian_driver_session_v1(expected_user_id uuid, activation uuid, credential text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare expiry timestamptz:=now()+interval '8 hours'; existing public.guardian_driver_sessions;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  -- Lock a stable owner row: activation replacement and event ingestion serialize on it.
  perform 1 from auth.users where id=expected_user_id for update;
  select * into existing from public.guardian_driver_sessions where user_id=expected_user_id;
  if credential is null then
    if existing.user_id is not null and existing.activation_id is distinct from activation then
      raise exception 'Activation changed' using errcode='40001'; end if;
    delete from public.guardian_driver_sessions where user_id=expected_user_id and activation_id=activation;
    update public.guardian_alert_deliveries set status='revoked' where user_id=expected_user_id;
    return jsonb_build_object('enabled',false);
  end if;
  if activation is null or not public.guardian_alert_credential_valid_v1(credential) then raise exception 'Invalid activation' using errcode='22023'; end if;
  if existing.activation_id=activation then
    if existing.credential_hash<>sha256(convert_to(credential,'UTF8')) then raise exception 'Activation conflict' using errcode='40001'; end if;
    return jsonb_build_object('enabled',existing.expires_at>now(),'activation_id',activation,'expires_at',existing.expires_at);
  end if;
  if not exists(select 1 from public.guardian_connections c where c.driver_id=expected_user_id and
    (public.guardian_allows_v1(c.driver_id,c.guardian_id,'crash_alert') or public.guardian_allows_v1(c.driver_id,c.guardian_id,'severe_drive_alert'))) then
    raise exception 'No active alert permission' using errcode='42501'; end if;
  update public.guardian_alert_deliveries set status='revoked' where user_id=expected_user_id;
  insert into public.guardian_driver_sessions values(expected_user_id,activation,sha256(convert_to(credential,'UTF8')),expiry)
    on conflict(user_id) do update set activation_id=excluded.activation_id,credential_hash=excluded.credential_hash,expires_at=excluded.expires_at;
  return jsonb_build_object('enabled',true,'activation_id',activation,'expires_at',expiry);
end $$;

create function public.set_guardian_push_device_v1(expected_user_id uuid, device uuid, generation uuid,
  routing_token text, credential text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  perform 1 from auth.users where id=expected_user_id for update;
  if exists(select 1 from public.guardian_push_devices d where d.id=device and d.user_id<>expected_user_id) then raise insufficient_privilege; end if;
  if routing_token is null then
    delete from public.guardian_push_devices d where d.id=device and d.user_id=expected_user_id;
    return;
  end if;
  if device is null or generation is null or length(routing_token) not between 16 and 4096 or
    not public.guardian_alert_credential_valid_v1(credential) then raise exception 'Invalid device registration' using errcode='22023'; end if;
  delete from public.guardian_push_devices d where d.user_id=expected_user_id and d.expires_at<=now();
  if not exists(select 1 from public.guardian_push_devices d where d.id=device) and
    (select count(*) from public.guardian_push_devices d where d.user_id=expected_user_id)>=3 then
    raise exception 'Device limit reached' using errcode='P0002'; end if;
  update public.guardian_alert_deliveries d set status='revoked' where d.device_id=device and exists(
    select 1 from public.guardian_push_devices p where p.id=device and
      (p.generation<>set_guardian_push_device_v1.generation or p.routing_token<>set_guardian_push_device_v1.routing_token or p.credential_hash<>sha256(convert_to(credential,'UTF8'))));
  insert into public.guardian_push_devices values(device,expected_user_id,generation,routing_token,sha256(convert_to(credential,'UTF8')),now()+interval '30 days')
    on conflict(id) do update set generation=excluded.generation,routing_token=excluded.routing_token,
      credential_hash=excluded.credential_hash,expires_at=excluded.expires_at;
end $$;

-- Private helper; validity is rechecked at every transition, not cached in a push payload.
create function public.guardian_delivery_allowed_v1(delivery uuid) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from public.guardian_alert_deliveries d
    join public.guardian_alert_events e on (e.user_id,e.event_id)=(d.user_id,d.event_id)
    join public.guardian_driver_sessions s on s.user_id=e.user_id and s.activation_id=e.activation_id
    join public.guardian_connections c on c.id=d.connection_id and c.revision=d.connection_revision
    join public.guardian_push_devices p on p.id=d.device_id and p.generation=d.device_generation
    where d.id=delivery and e.expires_at>now() and s.expires_at>now() and p.expires_at>now()
    and c.driver_id=e.user_id and c.guardian_id=p.user_id and d.status not in ('revoked','failed')
    and public.guardian_allows_v1(c.driver_id,c.guardian_id,case e.kind when 'possible_crash' then 'crash_alert' else 'severe_drive_alert' end))
$$;

-- These functions are server-only. An Edge Function supplies a restricted activation credential;
-- mobile clients never receive a Supabase service-role key or share rotating Auth refresh tokens.
create function public.ingest_guardian_alert_v1(owner_id uuid, credential text, envelope jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare session public.guardian_driver_sessions; event public.guardian_alert_events;
  identifier uuid; happened timestamptz; event_kind text; inserted_count integer;
begin
  if owner_id is null or not public.guardian_alert_credential_valid_v1(credential) then raise insufficient_privilege; end if;
  perform 1 from auth.users where id=owner_id for update;
  select * into session from public.guardian_driver_sessions where user_id=owner_id and expires_at>now()
    and credential_hash=sha256(convert_to(credential,'UTF8'));
  if not found then raise insufficient_privilege; end if;
  if jsonb_typeof(envelope) is distinct from 'object' or octet_length(envelope::text)>1024 then raise exception 'Invalid alert envelope' using errcode='22023'; end if;
  if (select array_agg(k order by k) from jsonb_object_keys(envelope) k) is distinct from
    array['event_id','kind','occurred_at_epoch_ms','rule_version','schema_version','uncertainty'] or
    envelope->'schema_version' is distinct from '1'::jsonb or envelope->'rule_version' is distinct from '1'::jsonb or
    envelope->>'uncertainty' is distinct from 'experimental_not_confirmed' or
    jsonb_typeof(envelope->'occurred_at_epoch_ms') is distinct from 'number' then raise exception 'Invalid alert envelope' using errcode='22023'; end if;
  identifier:=(envelope->>'event_id')::uuid;
  event_kind:=envelope->>'kind';
  happened:=to_timestamp((envelope->>'occurred_at_epoch_ms')::bigint/1000.0);
  if identifier is null or event_kind not in ('severe_drive','possible_crash') or event_kind is null or
    happened>now()-interval '30 seconds' or happened<=now()-interval '10 minutes' then
    raise exception 'Invalid or expired alert' using errcode='22023'; end if;
  select * into event from public.guardian_alert_events where user_id=owner_id and event_id=identifier;
  if found then
    if event.activation_id<>session.activation_id or event.kind<>event_kind or event.occurred_at<>happened then
      raise exception 'Event identity conflict' using errcode='40001'; end if;
    return jsonb_build_object('event_id',identifier,'state','backend_accepted','duplicate',true);
  end if;
  delete from public.guardian_alert_events where user_id=owner_id and received_at<=now()-interval '24 hours';
  if (select count(*) from public.guardian_alert_events where user_id=owner_id)>=10 or
    exists(select 1 from public.guardian_alert_events e where e.user_id=owner_id and
      ((event_kind='possible_crash' and e.kind='possible_crash' and e.received_at>now()-interval '30 minutes') or
       (event_kind='severe_drive' and e.received_at>now()-interval '5 minutes'))) then
    raise exception 'Alert limit reached' using errcode='P0002'; end if;
  insert into public.guardian_alert_events values(owner_id,identifier,session.activation_id,event_kind,1,happened,now(),happened+interval '10 minutes');
  insert into public.guardian_alert_deliveries(user_id,event_id,connection_id,connection_revision,device_id,device_generation)
    select owner_id,identifier,c.id,c.revision,p.id,p.generation from public.guardian_connections c
    join public.guardian_push_devices p on p.user_id=c.guardian_id and p.expires_at>now()
    where c.driver_id=owner_id and public.guardian_allows_v1(c.driver_id,c.guardian_id,
      case event_kind when 'possible_crash' then 'crash_alert' else 'severe_drive_alert' end);
  get diagnostics inserted_count = row_count;
  if inserted_count>30 then raise exception 'Recipient device limit reached' using errcode='P0002'; end if;
  return jsonb_build_object('event_id',identifier,'state','backend_accepted','duplicate',false,'recipient_devices',inserted_count);
end $$;

create function public.claim_guardian_deliveries_v1(owner_id uuid, credential text, alert_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare delivery public.guardian_alert_deliveries; rows jsonb:='[]'; claim uuid;
begin
  if not public.guardian_alert_credential_valid_v1(credential) or not exists(select 1 from public.guardian_driver_sessions
    where user_id=owner_id and credential_hash=sha256(convert_to(credential,'UTF8')) and expires_at>now()) then raise insufficient_privilege; end if;
  -- Recover a dispatcher interrupted after reserving its final bounded attempt.
  update public.guardian_alert_deliveries set status='failed' where user_id=owner_id and event_id=alert_id
    and status='pending' and attempts>=6 and next_attempt_at<=now();
  for delivery in select * from public.guardian_alert_deliveries d where d.user_id=owner_id and d.event_id=alert_id
    and d.status='pending' and d.attempts<6 and d.next_attempt_at<=now() order by d.id for update skip locked limit 30 loop
    if not public.guardian_delivery_allowed_v1(delivery.id) then
      update public.guardian_alert_deliveries set status='revoked' where id=delivery.id;
      continue;
    end if;
    claim:=gen_random_uuid();
    update public.guardian_alert_deliveries set attempts=attempts+1,claim_id=claim,
      next_attempt_at=now()+make_interval(secs=>least(120,5*power(2,attempts))::integer) where id=delivery.id;
    rows:=rows||jsonb_build_array((select jsonb_build_object('delivery_id',delivery.id,'claim_id',claim,
      'routing_token',p.routing_token,'device_generation',p.generation,
      'ttl_seconds',floor(extract(epoch from e.expires_at-now()))::integer)
      from public.guardian_push_devices p join public.guardian_alert_events e on e.user_id=owner_id and e.event_id=alert_id where p.id=delivery.device_id));
  end loop;
  return rows;
end $$;

create function public.finish_guardian_dispatch_v1(delivery uuid, claim uuid, accepted boolean, permanent_failure boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  update public.guardian_alert_deliveries d set status=case
    when not public.guardian_delivery_allowed_v1(d.id) then 'revoked'
    when d.status in ('device_received','viewed') then d.status
    when accepted then 'provider_accepted'
    when permanent_failure or attempts>=6 then 'failed' else 'pending' end
    where d.id=delivery and d.claim_id=claim and d.status in ('pending','provider_accepted','device_received','viewed');
end $$;

create function public.receive_guardian_alert_v1(device uuid, credential text, delivery uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if not public.guardian_alert_credential_valid_v1(credential) or not exists(select 1 from public.guardian_push_devices p
    where p.id=device and p.credential_hash=sha256(convert_to(credential,'UTF8')) and p.expires_at>now()) then raise insufficient_privilege; end if;
  if not exists(select 1 from public.guardian_alert_deliveries d where d.id=delivery and d.device_id=device and d.attempts>0)
    or not public.guardian_delivery_allowed_v1(delivery) then return false; end if;
  update public.guardian_alert_deliveries set status='device_received' where id=delivery and status in ('pending','provider_accepted');
  return true;
end $$;

create function public.list_guardian_alerts_v1(expected_user_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(row) from (
    select d.id as delivery_id,e.kind,e.rule_version,e.occurred_at,'experimental_not_confirmed' as uncertainty,
      d.status,c.driver_display_name,c.guardian_display_name,(c.driver_id=expected_user_id) as own_event
    from public.guardian_alert_deliveries d
    join public.guardian_alert_events e on (e.user_id,e.event_id)=(d.user_id,d.event_id)
    join public.guardian_connections c on c.id=d.connection_id
    where expected_user_id in (c.driver_id,c.guardian_id) and public.guardian_delivery_allowed_v1(d.id)
    order by e.received_at desc,d.id limit 100) row),'[]'::jsonb);
end $$;

create function public.view_guardian_alert_v1(expected_user_id uuid, delivery uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  if not exists(select 1 from public.guardian_alert_deliveries d join public.guardian_push_devices p on p.id=d.device_id
    where d.id=delivery and p.user_id=expected_user_id) or not public.guardian_delivery_allowed_v1(delivery) then return false; end if;
  update public.guardian_alert_deliveries set status='viewed' where id=delivery;
  return true;
end $$;

revoke all on function public.guardian_alert_credential_valid_v1(text),public.guardian_delivery_allowed_v1(uuid),
  public.set_guardian_driver_session_v1(uuid,uuid,text),public.set_guardian_push_device_v1(uuid,uuid,uuid,text,text),
  public.ingest_guardian_alert_v1(uuid,text,jsonb),public.claim_guardian_deliveries_v1(uuid,text,uuid),
  public.finish_guardian_dispatch_v1(uuid,uuid,boolean,boolean),public.receive_guardian_alert_v1(uuid,text,uuid),
  public.list_guardian_alerts_v1(uuid),public.view_guardian_alert_v1(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.set_guardian_driver_session_v1(uuid,uuid,text),
  public.set_guardian_push_device_v1(uuid,uuid,uuid,text,text),public.list_guardian_alerts_v1(uuid),
  public.view_guardian_alert_v1(uuid,uuid) to authenticated;
grant execute on function public.ingest_guardian_alert_v1(uuid,text,jsonb),public.claim_guardian_deliveries_v1(uuid,text,uuid),
  public.finish_guardian_dispatch_v1(uuid,uuid,boolean,boolean),public.receive_guardian_alert_v1(uuid,text,uuid) to service_role;
