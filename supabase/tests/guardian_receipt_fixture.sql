-- Disposable PostgreSQL test database only; never run this wrapper in production.
begin;
insert into public.profiles(user_id,username,display_name,visibility)
  values('22222222-2222-4222-8222-222222222222','receipt_test_peer','Synthetic receipt peer','private');
insert into public.guardian_push_devices values(
  '66666666-6666-4666-8666-666666666666','22222222-2222-4222-8222-222222222222',
  '77777777-7777-4777-8777-777777777777','synthetic-receipt-routing-token',
  sha256(convert_to(repeat('b',64),'UTF8')),now()+interval '1 day');
commit;
\ir ../manual_tests/guardian_receipt_stage.sql
begin;
set local role service_role;
do $$ begin
  if not public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
    '00000000-0000-4000-9000-000000000685') then raise exception 'Positive receipt rejected'; end if;
  if not public.receive_guardian_alert_v1('66666666-6666-4666-8666-666666666666',repeat('b',64),
    '00000000-0000-4000-9000-000000000685') then raise exception 'Receipt retry rejected'; end if;
end $$;
reset role;
do $$ begin
  if not exists(select 1 from public.guardian_alert_deliveries
    where id='00000000-0000-4000-9000-000000000685' and status='device_received') then
    raise exception 'Receipt state not recorded';
  end if;
  if exists(select 1 from public.profiles where user_id='22222222-2222-4222-8222-222222222222'
    and (username<>'receipt_test_peer' or display_name<>'Synthetic receipt peer' or visibility<>'private')) then
    raise exception 'Recipient profile changed';
  end if;
end $$;
rollback;
\ir ../manual_tests/guardian_receipt_cleanup.sql
\ir ../manual_tests/guardian_receipt_cleanup.sql
begin;
do $$ begin
  if exists(select 1 from auth.users where id='00000000-0000-4000-9000-000000000681')
    or exists(select 1 from public.guardian_driver_sessions)
    or exists(select 1 from public.guardian_alert_events)
    or exists(select 1 from public.guardian_alert_deliveries)
    or (select count(*) from public.guardian_push_devices)<>1
    or not exists(select 1 from auth.users where id='22222222-2222-4222-8222-222222222222')
    or not exists(select 1 from public.profiles where user_id='22222222-2222-4222-8222-222222222222'
      and username='receipt_test_peer' and display_name='Synthetic receipt peer' and visibility='private') then
    raise exception 'Fixture cleanup did not preserve recipient or remove synthetic state';
  end if;
end $$;
delete from public.guardian_push_devices where id='66666666-6666-4666-8666-666666666666';
delete from public.profiles where user_id='22222222-2222-4222-8222-222222222222';
commit;
select true as receipt_fixture_staging_retry_and_cleanup_passed;
