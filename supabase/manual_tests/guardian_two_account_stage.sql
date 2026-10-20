-- Prepared M6.8 existing-pair fixture 1001-1003, NOT a migration.
-- Separate production approval is required; stage only while both functions are disabled.
-- No profile/account/pair/device changes, usable ingestion credential or token output.
begin;
lock table public.guardian_connections, public.guardian_driver_sessions,
  public.guardian_push_devices, public.guardian_alert_events,
  public.guardian_alert_deliveries in exclusive mode;
do $$
declare
  activation constant uuid := '00000000-0000-4000-9000-000000001001';
  event constant uuid := '00000000-0000-4000-9000-000000001002';
  delivery constant uuid := '00000000-0000-4000-9000-000000001003';
  pair record;
  receiver record;
begin
  if exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries)
    or (select count(*) from public.guardian_connections where status='active')<>1
    or (select count(*) from public.guardian_push_devices)<>2 then
    raise exception 'Two-account fixture requires an empty queue, one active pair and two devices';
  end if;
  select id,driver_id,guardian_id,revision,permissions into strict pair
    from public.guardian_connections where status='active';
  if pair.permissions is distinct from
    '{"crash_alert":true,"severe_drive_alert":false,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}'::jsonb
    or not public.guardian_allows_v1(pair.driver_id,pair.guardian_id,'crash_alert')
    or (select count(*) from public.profiles where user_id in (pair.driver_id,pair.guardian_id))<>2
    or (select count(*) from public.guardian_push_devices where user_id=pair.driver_id
      and expires_at>now()+interval '10 minutes')<>1
    or (select count(*) from public.guardian_push_devices where user_id=pair.guardian_id
      and expires_at>now()+interval '10 minutes')<>1 then
    raise exception 'Two-account fixture permission or device precondition failed';
  end if;
  select id,generation into strict receiver from public.guardian_push_devices where user_id=pair.guardian_id;
  -- This administrative fixture tests delivery/inbox only. The random hash has
  -- no retained usable capability; no mobile activation or sensor consent is simulated.
  insert into public.guardian_driver_sessions values(pair.driver_id,activation,
    sha256(convert_to(gen_random_uuid()::text||gen_random_uuid()::text,'UTF8')),
    now()+interval '8 minutes');
  insert into public.guardian_alert_events values(pair.driver_id,event,activation,
    'possible_crash',1,now()-interval '40 seconds',now(),now()+interval '8 minutes');
  insert into public.guardian_alert_deliveries(id,user_id,event_id,connection_id,
    connection_revision,device_id,device_generation)
    values(delivery,pair.driver_id,event,pair.id,pair.revision,receiver.id,receiver.generation);
  if not public.guardian_delivery_allowed_v1(delivery) then
    raise exception 'Two-account synthetic delivery was not authorized';
  end if;
end $$;
select public.guardian_delivery_allowed_v1('00000000-0000-4000-9000-000000001003') as fixture_ready,
  (select count(*)=1 and bool_and(status='pending' and attempts=0 and claim_id is null)
    from public.guardian_alert_deliveries) as one_pending_delivery,
  (select count(*)=2 from public.guardian_push_devices) as two_devices;
commit;
