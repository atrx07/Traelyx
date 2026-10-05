-- M6.8 reviewed positive-receipt fixture, NOT a migration.
-- Requires explicit production approval, capability disabled during staging,
-- dispatch disabled throughout, one consented phone, and a quiescent queue.
-- It stages a provider-accepted state; no provider request has actually occurred.
begin;
lock table public.guardian_driver_sessions, public.guardian_push_devices,
  public.guardian_alert_events, public.guardian_alert_deliveries in exclusive mode;
do $$
declare
  driver constant uuid := '00000000-0000-4000-9000-000000000681';
  connection constant uuid := '00000000-0000-4000-9000-000000000682';
  activation constant uuid := '00000000-0000-4000-9000-000000000683';
  event constant uuid := '00000000-0000-4000-9000-000000000684';
  delivery constant uuid := '00000000-0000-4000-9000-000000000685';
  recipient record;
begin
  if exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries)
    or (select count(*) from public.guardian_push_devices) <> 1 then
    raise exception 'Receipt fixture requires no sessions/events/deliveries and exactly one device';
  end if;
  select id,user_id,generation,expires_at into strict recipient from public.guardian_push_devices
    where expires_at > now() + interval '10 minutes';
  if not exists(select 1 from public.profiles where user_id=recipient.user_id)
    or exists(select 1 from auth.users where id=driver)
    or exists(select 1 from public.profiles where username='traelyx_receipt_fixture')
    or exists(select 1 from public.guardian_connections where id=connection) then
    raise exception 'Receipt fixture identity precondition failed';
  end if;
  insert into auth.users(id) values(driver);
  insert into public.profiles(user_id,username,display_name,visibility)
    values(driver,'traelyx_receipt_fixture','Synthetic receipt test driver','private');
  insert into public.guardian_connections(id,low_user,high_user,driver_id,guardian_id,
    driver_username,driver_display_name,guardian_username,guardian_display_name,
    status,permissions,expires_at)
    values(connection,least(driver,recipient.user_id),greatest(driver,recipient.user_id),
      driver,recipient.user_id,'traelyx_receipt_fixture','Synthetic receipt test driver',
      'synthetic_receiver','Synthetic receipt test receiver','active',
      '{"crash_alert":false,"severe_drive_alert":true,"current_safety_state":false,"live_location":false,"current_speed":false,"trip_history":false}',
      now()+interval '10 minutes');
  -- No usable driver credential is returned or retained by a client.
  insert into public.guardian_driver_sessions values(driver,activation,
    sha256(convert_to(gen_random_uuid()::text||gen_random_uuid()::text,'UTF8')),
    now()+interval '10 minutes');
  insert into public.guardian_alert_events values(driver,event,activation,'severe_drive',1,
    now()-interval '40 seconds',now(),now()+interval '8 minutes');
  insert into public.guardian_alert_deliveries(id,user_id,event_id,connection_id,
    connection_revision,device_id,device_generation,status,attempts)
    values(delivery,driver,event,connection,1,recipient.id,recipient.generation,'provider_accepted',1);
  if not public.guardian_delivery_allowed_v1(delivery) then
    raise exception 'Synthetic receipt target not authorized';
  end if;
end $$;
select public.guardian_delivery_allowed_v1('00000000-0000-4000-9000-000000000685') as fixture_ready,
  (select count(*)=1 from public.guardian_push_devices) as one_device;
commit;
