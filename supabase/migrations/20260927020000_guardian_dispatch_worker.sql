-- M6.8: a trusted scheduled worker may retry already accepted events without
-- retaining a driver's ingestion capability or requiring the driver to stay online.
create index guardian_dispatch_due_idx on public.guardian_alert_deliveries(next_attempt_at,id)
  where status='pending';

create function public.claim_guardian_dispatch_batch_v1(batch_size integer default 30) returns jsonb
language plpgsql security definer set search_path='' as $$
declare delivery public.guardian_alert_deliveries; rows jsonb:='[]'; claim uuid;
begin
  if batch_size is null or batch_size not between 1 and 30 then
    raise exception 'Invalid batch size' using errcode='22023';
  end if;
  for delivery in select * from public.guardian_alert_deliveries d
    where d.status='pending' and d.next_attempt_at<=now()
    order by d.next_attempt_at,d.id for update skip locked limit batch_size loop
    if not public.guardian_delivery_allowed_v1(delivery.id) then
      update public.guardian_alert_deliveries set status='revoked',claim_id=null where id=delivery.id;
      continue;
    end if;
    if delivery.attempts>=6 then
      update public.guardian_alert_deliveries set status='failed',claim_id=null where id=delivery.id;
      continue;
    end if;
    claim:=gen_random_uuid();
    -- A reservation outlives the bounded provider HTTP request. A killed worker
    -- can be reclaimed later; the new claim invalidates its stale result.
    update public.guardian_alert_deliveries set attempts=attempts+1,claim_id=claim,
      next_attempt_at=now()+interval '120 seconds' where id=delivery.id;
    rows:=rows||jsonb_build_array(jsonb_build_object('delivery_id',delivery.id,'claim_id',claim));
  end loop;
  return rows;
end $$;

-- Recheck current permission immediately before provider IO, after OAuth setup.
-- Returns only the routing target and opaque receipt identifiers, never names/events.
create function public.guardian_dispatch_target_v1(delivery uuid, claim uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target jsonb;
begin
  select jsonb_build_object('routing_token',p.routing_token,'device_id',p.id,
    'device_generation',p.generation,'ttl_seconds',floor(extract(epoch from e.expires_at-now()))::integer)
    into target from public.guardian_alert_deliveries d
    join public.guardian_push_devices p on p.id=d.device_id
    join public.guardian_alert_events e on (e.user_id,e.event_id)=(d.user_id,d.event_id)
    where d.id=delivery and d.claim_id=claim and d.status='pending' and d.attempts>0
      and d.next_attempt_at>now() and public.guardian_delivery_allowed_v1(d.id);
  return target;
end $$;

create function public.finish_guardian_dispatch_v2(delivery uuid, claim uuid, accepted boolean,
  permanent_failure boolean, retry_after_seconds integer default 60) returns void
language plpgsql security definer set search_path='' as $$
begin
  if accepted is null or permanent_failure is null or (accepted and permanent_failure)
    or retry_after_seconds is null or retry_after_seconds not between 0 and 86400 then
    raise exception 'Invalid provider result' using errcode='22023';
  end if;
  update public.guardian_alert_deliveries d set status=case
      when not public.guardian_delivery_allowed_v1(d.id) then 'revoked'
      when d.status in ('device_received','viewed') then d.status
      when accepted then 'provider_accepted'
      when permanent_failure or d.attempts>=6 then 'failed' else 'pending' end,
    next_attempt_at=now()+make_interval(secs=>greatest(60,retry_after_seconds,
      least(120,5*power(2,greatest(0,d.attempts-1)))::integer)),
    claim_id=null
    where d.id=delivery and d.claim_id=claim and d.status in ('pending','device_received','viewed');
end $$;

revoke all on function public.claim_guardian_dispatch_batch_v1(integer),
  public.guardian_dispatch_target_v1(uuid,uuid),
  public.finish_guardian_dispatch_v2(uuid,uuid,boolean,boolean,integer)
  from public,anon,authenticated;
grant execute on function public.claim_guardian_dispatch_batch_v1(integer),
  public.guardian_dispatch_target_v1(uuid,uuid),
  public.finish_guardian_dispatch_v2(uuid,uuid,boolean,boolean,integer) to service_role;
