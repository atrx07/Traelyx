-- Experimental friends-only safe rankings. Dossiers are private and separately consented.
create table public.ranking_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null check(username ~ '^[a-z][a-z0-9_]{2,29}$'),
  display_name text not null check(length(display_name) between 1 and 80),
  vehicle_class text not null check(vehicle_class in ('car','motorcycle','other'))
);
create table public.ranking_entries (
  source_trip_id uuid primary key,
  user_id uuid not null references public.ranking_members(user_id) on delete cascade,
  source_digest text not null unique check(source_digest ~ '^[0-9a-f]{64}$'),
  dossier jsonb not null check(octet_length(dossier::text) <= 65536),
  smoothness_milli integer not null check(smoothness_milli between 0 and 100000),
  accepted_order bigint generated always as identity unique,
  accepted_at timestamptz not null default now()
);
create index ranking_owner_order_idx on public.ranking_entries(user_id, accepted_order desc);
create table public.ranking_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  used integer not null default 0 check(used between 0 and 30)
);
alter table public.ranking_members enable row level security;
alter table public.ranking_entries enable row level security;
alter table public.ranking_limits enable row level security;
revoke all on public.ranking_members, public.ranking_entries, public.ranking_limits from public, anon, authenticated;
revoke all on sequence public.ranking_entries_accepted_order_seq from public, anon, authenticated;

-- Private pure validator. An exact allowlist prevents accidental sensitive-field admission.
create function public.validate_ranking_dossier_v1(d jsonb)
returns integer language plpgsql immutable set search_path = '' as $$
declare
  dim jsonb; ev jsonb; moving bigint; duration bigint;
  opportunity bigint; usable bigint; full_duration bigint;
  penalties bigint[] := array[0,0,0,0]; counts integer[] := array[0,0,0];
  scores bigint[]; code integer; severity integer; i integer;
begin
  if d is null or jsonb_typeof(d) <> 'object' or octet_length(d::text) > 65536 or
    (select array_agg(k order by k) from jsonb_object_keys(d) k) is distinct from
      array['calibration','dimensions','duration_ms','events','integrity_counts','moving_ms','source_digest','vehicle_class','versions'] or
    d->>'vehicle_class' not in ('car','motorcycle','other') or
    jsonb_typeof(d->'vehicle_class') <> 'string' or
    d->'versions' <> '{"analysis":1,"raw":1,"encoding":1,"schema":1,"timeline":1,"gnss":1,"calibration":1,"orientation":1,"derived":1,"confidence":1,"taxonomy":1,"merge":1,"integrity":1,"scoring":1,"validation":1}'::jsonb or
    d->'calibration' <> '[1,1,1]'::jsonb or
    jsonb_typeof(d->'source_digest') <> 'string' or
    (d->>'source_digest') !~ '^[0-9a-f]{64}$' or
    d->'integrity_counts' <> '[0,0,0,0,0,0,0,0,0,0,0]'::jsonb or
    jsonb_typeof(d->'dimensions') <> 'array' or jsonb_array_length(d->'dimensions') <> 4 or
    jsonb_typeof(d->'events') <> 'array' or jsonb_array_length(d->'events') > 1000 then
    raise exception 'ranking_evidence_invalid' using errcode='22023';
  end if;
  foreach dim in array array[d->'duration_ms',d->'moving_ms'] loop
    if jsonb_typeof(dim) <> 'number' or (dim::text) !~ '^[0-9]+$' then
      raise exception 'ranking_duration_invalid' using errcode='22023';
    end if;
  end loop;
  duration := (d->>'duration_ms')::bigint;
  moving := (d->>'moving_ms')::bigint;
  if duration not between 60000 and 7200000 or moving not between 60000 and duration then
    raise exception 'ranking_duration_ineligible' using errcode='22023';
  end if;
  -- Dimension order: smoothness, braking, acceleration, cornering. No client score accepted.
  for i in 0..3 loop
    dim := d->'dimensions'->i;
    if jsonb_typeof(dim) <> 'array' or jsonb_array_length(dim) <> 3 then
      raise exception 'ranking_dimension_invalid' using errcode='22023';
    end if;
    for ev in select value from jsonb_array_elements(dim) loop
      if jsonb_typeof(ev) <> 'number' or ev::text !~ '^[0-9]+$' then
        raise exception 'ranking_dimension_invalid' using errcode='22023';
      end if;
    end loop;
    opportunity := (dim->>0)::bigint; usable := (dim->>1)::bigint; full_duration := (dim->>2)::bigint;
    if opportunity not between 500 and moving or usable not between 0 and opportunity or
      full_duration not between 0 and usable or full_duration * 1000 < opportunity * 800 or
      (i=0 and opportunity <> moving) then
      raise exception 'ranking_coverage_ineligible' using errcode='22023';
    end if;
  end loop;
  -- Event tuples: governed category ordinal, clamped severity permille, confidence permille.
  -- Recompute penalties exactly as native scoring v1, preserving submitted event order.
  for ev in select value from jsonb_array_elements(d->'events') loop
    if jsonb_typeof(ev) <> 'array' or jsonb_array_length(ev) <> 3 then
      raise exception 'ranking_event_invalid' using errcode='22023';
    end if;
    for dim in select value from jsonb_array_elements(ev) loop
      if jsonb_typeof(dim) <> 'number' or dim::text !~ '^[0-9]+$' then
        raise exception 'ranking_event_invalid' using errcode='22023';
      end if;
    end loop;
    code := (ev->>0)::integer; severity := (ev->>1)::integer;
    if code not between 0 and 8 or severity not between 1000 and 2000 or (ev->>2)::integer <> 1000 then
      raise exception 'ranking_event_ineligible' using errcode='22023';
    end if;
    case code
      when 0 then counts[1]:=counts[1]+1; if counts[1]>1 then penalties[3]:=penalties[3]+3*severity; end if;
      when 1 then penalties[1]:=penalties[1]+6*severity; penalties[3]:=penalties[3]+10*severity;
      when 2 then counts[2]:=counts[2]+1; if counts[2]>1 then penalties[2]:=penalties[2]+4*severity; end if;
      when 3 then penalties[1]:=penalties[1]+6*severity; penalties[2]:=penalties[2]+12*severity;
      when 4,5 then counts[3]:=counts[3]+1; if counts[3]>1 then penalties[4]:=penalties[4]+3*severity; end if;
      when 6 then penalties[1]:=penalties[1]+5*severity; penalties[4]:=penalties[4]+10*severity;
      when 7 then penalties[1]:=penalties[1]+5*severity; penalties[4]:=penalties[4]+8*severity;
      when 8 then null; -- Road-impact evidence has no scoring penalty/reward in v1.
    end case;
  end loop;
  scores := array[greatest(0,100000-penalties[1]),greatest(0,100000-penalties[2]),
    greatest(0,100000-penalties[3]),greatest(0,100000-penalties[4])];
  return scores[1]::integer;
end $$;
revoke all on function public.validate_ranking_dossier_v1(jsonb) from public, anon, authenticated;

create function public.submit_ranking_v1(expected_user_id uuid, expected_username text,
  expected_display_name text, trip_id uuid, evidence jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare points integer; previous public.ranking_entries; quota public.ranking_limits;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid() <> expected_user_id then raise insufficient_privilege; end if;
  if trip_id is null then raise exception 'ranking_trip_required'; end if;
  points := public.validate_ranking_dossier_v1(evidence);
  -- Serialize all per-account operations, including withdrawal, without client locks.
  perform pg_advisory_xact_lock(hashtextextended(expected_user_id::text, 661));
  if not exists(select 1 from public.profiles p where p.user_id=expected_user_id and
    p.username=expected_username and p.display_name=expected_display_name) then
    raise exception 'ranking_profile_changed';
  end if;
  if not exists(select 1 from public.vehicles v where v.user_id=expected_user_id and
    v.vehicle_class=evidence->>'vehicle_class') or exists(select 1 from public.ranking_members m
    where m.user_id=expected_user_id and m.vehicle_class<>evidence->>'vehicle_class') then
    raise exception 'ranking_vehicle_class_invalid';
  end if;
  select * into previous from public.ranking_entries where source_trip_id=trip_id;
  if found then
    if previous.user_id=expected_user_id and previous.dossier=evidence then return; end if;
    raise exception 'ranking_snapshot_conflict';
  end if;
  if exists(select 1 from public.ranking_entries where source_digest=evidence->>'source_digest') then
    raise exception 'ranking_snapshot_conflict';
  end if;
  if (select count(*) from public.ranking_entries where user_id=expected_user_id)>=1000 then
    raise exception 'ranking_capacity_reached';
  end if;
  insert into public.ranking_limits(user_id) values(expected_user_id) on conflict do nothing;
  select * into quota from public.ranking_limits where user_id=expected_user_id for update;
  if now() >= quota.window_start+interval '24 hours' then
    quota.used:=0; quota.window_start:=now();
  end if;
  if quota.used>=30 then raise exception 'ranking_daily_limit'; end if;
  update public.ranking_limits set used=quota.used+1,window_start=quota.window_start where user_id=expected_user_id;
  insert into public.ranking_members values(expected_user_id,expected_username,expected_display_name,evidence->>'vehicle_class')
    on conflict(user_id) do update set username=excluded.username,display_name=excluded.display_name;
  insert into public.ranking_entries(source_trip_id,user_id,source_digest,dossier,smoothness_milli)
    values(trip_id,expected_user_id,evidence->>'source_digest',evidence,points);
end $$;

create function public.withdraw_rankings_v1(expected_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or expected_user_id is null or auth.uid() <> expected_user_id then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended(expected_user_id::text,661));
  delete from public.ranking_members where user_id=expected_user_id;
  -- Keep rate-limit counters so withdrawal cannot bypass submission quotas.
end $$;

create function public.read_rankings_v1(expected_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if auth.uid() is null or expected_user_id is null or auth.uid() <> expected_user_id then raise insufficient_privilege; end if;
  with visible as (
    select m.* from public.ranking_members m where m.user_id=expected_user_id or exists(
      select 1 from public.social_relationships r where r.status='accepted' and not r.low_blocked and not r.high_blocked and
      ((r.low_user=expected_user_id and r.high_user=m.user_id) or
       (r.high_user=expected_user_id and r.low_user=m.user_id)))
  ), recent as (
    select v.user_id,v.username,v.display_name,v.vehicle_class,e.smoothness_milli,
      row_number() over(partition by v.user_id order by e.accepted_order desc) n
    from visible v cross join lateral (
      select smoothness_milli,accepted_order from public.ranking_entries where user_id=v.user_id
      order by accepted_order desc limit 10) e
  ), means as (
    select user_id,username,display_name,vehicle_class,count(*) c,
      avg(smoothness_milli) filter(where n<=5) recent_mean,
      avg(smoothness_milli) filter(where n>5) prior_mean
    from recent group by user_id,username,display_name,vehicle_class
  ), metrics as (
    select m.*, (select avg(abs(r.smoothness_milli-m.recent_mean)) from recent r
      where r.user_id=m.user_id and r.n<=5) deviation from means m
  ) select coalesce(jsonb_agg(jsonb_build_object(
    'username',username,'display_name',display_name,'is_self',user_id=expected_user_id,
    'vehicle_class',vehicle_class,
    'sample_count',c,'smoothness',case when c=10 then round(recent_mean/1000,2) end,
    'consistency',case when c=10 then round((100000-deviation)/1000,2) end,
    'improvement',case when c=10 then round((recent_mean-prior_mean)/1000,2) end
  ) order by recent_mean desc,username),'[]'::jsonb) into result from metrics;
  return jsonb_build_object('rows',result,
    'vehicle_classes',coalesce((select jsonb_agg(distinct v.vehicle_class) from public.vehicles v
      where v.user_id=expected_user_id and v.vehicle_class in ('car','motorcycle','other') and
      not exists(select 1 from public.ranking_members m where m.user_id=expected_user_id and m.vehicle_class<>v.vehicle_class)), '[]'::jsonb),
    'profile',(select jsonb_build_object('username',username,'display_name',display_name)
      from public.profiles where user_id=expected_user_id),
    'submitted_trip_ids',coalesce((select jsonb_agg(source_trip_id order by accepted_order)
      from public.ranking_entries where user_id=expected_user_id),'[]'::jsonb));
end $$;

revoke all on function public.submit_ranking_v1(uuid,text,text,uuid,jsonb),
  public.withdraw_rankings_v1(uuid),public.read_rankings_v1(uuid) from public, anon, authenticated;
grant execute on function public.submit_ranking_v1(uuid,text,text,uuid,jsonb),
  public.withdraw_rankings_v1(uuid),public.read_rankings_v1(uuid) to authenticated;
notify pgrst,'reload schema';
