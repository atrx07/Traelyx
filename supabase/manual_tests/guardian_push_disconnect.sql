-- Reviewed synthetic revocation-after-send control; NOT a migration.
-- Uses the production guarded disconnect API as the disposable synthetic driver.
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
      and d.connection_revision=1
      and d.event_id='00000000-0000-4000-9000-000000000694'
      and e.activation_id='00000000-0000-4000-9000-000000000693'
      and p.username='traelyx_push_fixture' and p.display_name='Synthetic push test driver'
      and p.visibility='private' and d.status='provider_accepted' and d.attempts=1
      and d.claim_id is null and e.expires_at>now()+interval '2 minutes'
      and public.guardian_delivery_allowed_v1(d.id)) then
    raise exception 'Refusing disconnect: exact accepted-once synthetic fixture required';
  end if;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-9000-000000000691';
set local request.jwt.claims='{"sub":"00000000-0000-4000-9000-000000000691","role":"authenticated"}';
set local role authenticated;
select public.change_guardian_connection_v1('00000000-0000-4000-9000-000000000691',
  '00000000-0000-4000-9000-000000000692',1,'disconnect',null);
reset role;
select not public.guardian_delivery_allowed_v1('00000000-0000-4000-9000-000000000695')
  as revoked_receipt_denied,
  exists(select 1 from public.guardian_audit
    where connection_id='00000000-0000-4000-9000-000000000692'
    and actor_role='driver' and action='disconnect') as disconnect_audited,
  exists(select 1 from public.guardian_alert_deliveries
    where id='00000000-0000-4000-9000-000000000695'
    and status='provider_accepted' and attempts=1) as receipt_not_recorded;
commit;
