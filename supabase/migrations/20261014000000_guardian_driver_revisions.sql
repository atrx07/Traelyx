-- M6.8: constant-size owner revision prevents activation after an earlier revoke.
-- No telemetry, recipient permissions, processing flags or scheduler changes.
create table public.guardian_driver_controls (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 0 check (revision >= 0)
);
alter table public.guardian_driver_controls enable row level security;
revoke all on public.guardian_driver_controls from public,anon,authenticated,service_role;

create function public.get_guardian_driver_revision_v2(expected_user_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare current_revision bigint;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  select revision into current_revision from public.guardian_driver_controls where user_id=expected_user_id;
  -- Decimal text avoids loss of bigint precision in mobile JSON decoding.
  return jsonb_build_object('revision',coalesce(current_revision,0)::text);
end $$;

create function public.set_guardian_driver_session_v2(expected_user_id uuid, activation uuid,
  credential text, expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare current_revision bigint; existing public.guardian_driver_sessions;
  expiry timestamptz:=now()+interval '8 hours';
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  if activation is null then raise exception 'Invalid activation' using errcode='22023'; end if;
  -- Same stable owner lock as ingestion/dispatch: concurrent activate/revoke serialize.
  perform 1 from auth.users where id=expected_user_id for update;
  insert into public.guardian_driver_controls(user_id) values(expected_user_id) on conflict do nothing;
  select revision into current_revision from public.guardian_driver_controls where user_id=expected_user_id;
  select * into existing from public.guardian_driver_sessions where user_id=expected_user_id;
  if credential is null then
    if current_revision=9223372036854775807 then raise exception 'Revision exhausted' using errcode='22003'; end if;
    -- Even an absent/superseded exact session invalidates earlier in-flight reviews.
    -- Preserve a newer session and its deliveries; never revoke all owner deliveries here.
    update public.guardian_driver_controls set revision=revision+1 where user_id=expected_user_id;
    delete from public.guardian_driver_sessions where user_id=expected_user_id and activation_id=activation;
    update public.guardian_alert_deliveries d set status='revoked'
      where d.user_id=expected_user_id and exists(select 1 from public.guardian_alert_events e
        where e.user_id=d.user_id and e.event_id=d.event_id and e.activation_id=activation);
    return jsonb_build_object('enabled',false);
  end if;
  if not public.guardian_alert_credential_valid_v1(credential) or expected_revision is null or expected_revision<0 then
    raise exception 'Invalid activation review' using errcode='22023'; end if;
  if existing.activation_id=activation then
    if existing.credential_hash<>sha256(convert_to(credential,'UTF8')) then
      raise exception 'Activation conflict' using errcode='40001'; end if;
    -- Exact retry never extends expiry, even if unrelated old cleanup advanced revision.
    return jsonb_build_object('enabled',existing.expires_at>now(),'activation_id',activation,'expires_at',existing.expires_at);
  end if;
  if expected_revision<>current_revision then raise exception 'Activation review changed' using errcode='40001'; end if;
  if current_revision=9223372036854775807 then raise exception 'Revision exhausted' using errcode='22003'; end if;
  if not exists(select 1 from public.guardian_connections c where c.driver_id=expected_user_id and
    (public.guardian_allows_v1(c.driver_id,c.guardian_id,'crash_alert') or public.guardian_allows_v1(c.driver_id,c.guardian_id,'severe_drive_alert'))) then
    raise exception 'No active alert permission' using errcode='42501'; end if;
  update public.guardian_driver_controls set revision=revision+1 where user_id=expected_user_id;
  update public.guardian_alert_deliveries set status='revoked' where user_id=expected_user_id;
  insert into public.guardian_driver_sessions values(expected_user_id,activation,sha256(convert_to(credential,'UTF8')),expiry)
    on conflict(user_id) do update set activation_id=excluded.activation_id,credential_hash=excluded.credential_hash,expires_at=excluded.expires_at;
  return jsonb_build_object('enabled',true,'activation_id',activation,'expires_at',expiry);
end $$;

-- Older dormant clients may clear exact tickets; they cannot bypass the revision gate.
create or replace function public.set_guardian_driver_session_v1(expected_user_id uuid, activation uuid, credential text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid()<>expected_user_id then raise insufficient_privilege; end if;
  if credential is not null then raise exception 'Revision review required' using errcode='55000'; end if;
  return public.set_guardian_driver_session_v2(expected_user_id,activation,null,null);
end $$;

revoke all on function public.get_guardian_driver_revision_v2(uuid),
  public.set_guardian_driver_session_v2(uuid,uuid,text,bigint),
  public.set_guardian_driver_session_v1(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.get_guardian_driver_revision_v2(uuid),
  public.set_guardian_driver_session_v2(uuid,uuid,text,bigint),
  public.set_guardian_driver_session_v1(uuid,uuid,text) to authenticated;
