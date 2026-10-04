-- M6.8 hosted recipient check. Synthetic IDs only; every mutation is rolled back.
begin;

do $$
begin
  if exists(select 1 from auth.users where id='f92aab34-58a0-4e32-980d-93a8cb0108e2')
     or exists(select 1 from public.guardian_push_devices where id='a790a40e-300a-41e8-9660-5b5c81f18d31') then
    raise exception 'Synthetic fixture ID already exists; no test data was inserted';
  end if;
end $$;

create function pg_temp.m6_check(ok boolean, label text) returns void
language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'M6.8 check failed: %', label; end if;
end $$;

create function pg_temp.m6_expect_denied(query text) returns void
language plpgsql as $$
begin
  begin
    execute query;
  exception when insufficient_privilege then return;
  end;
  raise exception 'M6.8 wrong-owner operation was accepted';
end $$;

insert into auth.users(id) values('f92aab34-58a0-4e32-980d-93a8cb0108e2');
select pg_temp.m6_check(
  not has_table_privilege('authenticated','public.guardian_push_devices','SELECT'),
  'private device table grant');

set local role authenticated;
select set_config('request.jwt.claim.sub','f92aab34-58a0-4e32-980d-93a8cb0108e2',true);
select public.set_guardian_push_device_v1(
  'f92aab34-58a0-4e32-980d-93a8cb0108e2',
  'a790a40e-300a-41e8-9660-5b5c81f18d31',
  '806eb918-8c1a-4e41-8650-f82b986aa4c5',
  'synthetic-m6-routing-token',repeat('a',64));
select public.set_guardian_push_device_v1(
  'f92aab34-58a0-4e32-980d-93a8cb0108e2',
  'a790a40e-300a-41e8-9660-5b5c81f18d31',
  '806eb918-8c1a-4e41-8650-f82b986aa4c5',
  'synthetic-m6-routing-token',repeat('a',64));
reset role;
select pg_temp.m6_check(
  (select count(*)=1 from public.guardian_push_devices
   where id='a790a40e-300a-41e8-9660-5b5c81f18d31'
     and user_id='f92aab34-58a0-4e32-980d-93a8cb0108e2'
     and generation='806eb918-8c1a-4e41-8650-f82b986aa4c5'
     and routing_token='synthetic-m6-routing-token'),
  'registration and same-owner retry');

set local role authenticated;
select set_config('request.jwt.claim.sub','038af663-384f-4fd0-8a17-7b8381a07912',true);
select pg_temp.m6_expect_denied($q$
  select public.set_guardian_push_device_v1(
    'f92aab34-58a0-4e32-980d-93a8cb0108e2',
    'a790a40e-300a-41e8-9660-5b5c81f18d31',
    '806eb918-8c1a-4e41-8650-f82b986aa4c5',null,null)
$q$);
select set_config('request.jwt.claim.sub','f92aab34-58a0-4e32-980d-93a8cb0108e2',true);
select public.set_guardian_push_device_v1(
  'f92aab34-58a0-4e32-980d-93a8cb0108e2',
  'a790a40e-300a-41e8-9660-5b5c81f18d31',
  '806eb918-8c1a-4e41-8650-f82b986aa4c5',null,null);
reset role;
select pg_temp.m6_check(
  not exists(select 1 from public.guardian_push_devices
             where id='a790a40e-300a-41e8-9660-5b5c81f18d31'),
  'server-first withdrawal');

rollback;
select
  not exists(select 1 from auth.users where id='f92aab34-58a0-4e32-980d-93a8cb0108e2')
    as synthetic_user_absent,
  not exists(select 1 from public.guardian_push_devices where id='a790a40e-300a-41e8-9660-5b5c81f18d31')
    as synthetic_device_absent,
  true as registration_retry_withdrawal_checks_passed;
