-- Reviewed synthetic duplicate-delivery control; NOT a migration.
-- Use only after the first notice was received/dismissed. Requires send review.
begin;
lock table public.guardian_alert_deliveries, public.guardian_alert_events,
  public.guardian_connections in exclusive mode;
do $$ begin
  if (select count(*) from public.guardian_alert_deliveries)<>1
    or not exists(select 1 from public.guardian_alert_deliveries d
      join public.profiles p on p.user_id=d.user_id
      join public.guardian_alert_events e on (e.user_id,e.event_id)=(d.user_id,d.event_id)
      where d.id='00000000-0000-4000-9000-000000000695'
      and d.user_id='00000000-0000-4000-9000-000000000691'
      and d.connection_id='00000000-0000-4000-9000-000000000692'
      and d.event_id='00000000-0000-4000-9000-000000000694'
      and e.activation_id='00000000-0000-4000-9000-000000000693'
      and p.username='traelyx_push_fixture' and p.display_name='Synthetic push test driver'
      and p.visibility='private' and d.status='device_received' and d.attempts=1
      and d.claim_id is null and e.expires_at>now()+interval '2 minutes'
      and public.guardian_delivery_allowed_v1(d.id)) then
    raise exception 'Refusing requeue: exact received-once synthetic fixture required';
  end if;
  -- Preserve envelope IDs, generation and attempt history. Never erase phone claims.
  update public.guardian_alert_deliveries set status='pending',next_attempt_at=now()
    where id='00000000-0000-4000-9000-000000000695';
end $$;
select exists(select 1 from public.guardian_alert_deliveries
  where id='00000000-0000-4000-9000-000000000695' and status='pending'
  and attempts=1 and claim_id is null) as same_delivery_requeued_once;
commit;
