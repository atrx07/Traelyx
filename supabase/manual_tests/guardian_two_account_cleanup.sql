-- Separate action-time approval; run only after both functions are disabled.
-- Exact test lineage only. Never delete a profile, pair, device, revision row or newer session.
begin;
lock table public.guardian_driver_sessions, public.guardian_alert_events,
  public.guardian_alert_deliveries in exclusive mode;
do $$
declare
  activation constant uuid := '00000000-0000-4000-9000-000000001001';
  event constant uuid := '00000000-0000-4000-9000-000000001002';
  delivery constant uuid := '00000000-0000-4000-9000-000000001003';
  fixture public.guardian_alert_events;
begin
  if (select count(*) from public.guardian_alert_events where event_id=event)>1 then
    raise exception 'Refusing cleanup: ambiguous test event';
  end if;
  select * into fixture from public.guardian_alert_events where event_id=event;
  if not found then
    if exists(select 1 from public.guardian_alert_deliveries where id=delivery)
      or exists(select 1 from public.guardian_driver_sessions where activation_id=activation) then
      raise exception 'Refusing cleanup: partial fixture needs reviewed recovery';
    end if;
    return;
  end if;
  if fixture.activation_id<>activation or fixture.kind<>'possible_crash'
    or fixture.rule_version<>1
    or fixture.occurred_at<>fixture.received_at-interval '40 seconds'
    or fixture.expires_at<>fixture.received_at+interval '8 minutes'
    or exists(select 1 from public.guardian_alert_events
      where activation_id=activation and (user_id,event_id)<>(fixture.user_id,event))
    or exists(select 1 from public.guardian_driver_sessions
      where activation_id=activation and user_id<>fixture.user_id)
    or exists(select 1 from public.guardian_alert_deliveries
      where (user_id,event_id)=(fixture.user_id,event) and id<>delivery)
    or exists(select 1 from public.guardian_alert_deliveries
      where id=delivery and (user_id,event_id)<>(fixture.user_id,event)) then
    raise exception 'Refusing cleanup: test lineage does not match';
  end if;
  delete from public.guardian_alert_deliveries where id=delivery
    and (user_id,event_id)=(fixture.user_id,event);
  delete from public.guardian_alert_events where (user_id,event_id)=(fixture.user_id,event)
    and activation_id=activation;
  delete from public.guardian_driver_sessions where user_id=fixture.user_id
    and activation_id=activation;
end $$;
select not exists(select 1 from public.guardian_alert_events
    where event_id='00000000-0000-4000-9000-000000001002') as fixture_event_absent,
  not exists(select 1 from public.guardian_alert_deliveries
    where id='00000000-0000-4000-9000-000000001003') as fixture_delivery_absent,
  not exists(select 1 from public.guardian_driver_sessions
    where activation_id='00000000-0000-4000-9000-000000001001') as fixture_session_absent,
  (select count(*) from public.guardian_push_devices) as device_rows;
commit;
