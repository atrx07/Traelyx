-- Only after BOTH functions are false. Removes only the reviewed disposable fixture.
begin;
do $$
declare driver constant uuid := '00000000-0000-4000-9000-000000000691';
begin
  if exists(select 1 from auth.users where id=driver) then
    if not exists(select 1 from public.profiles where user_id=driver
      and username='traelyx_push_fixture' and display_name='Synthetic push test driver'
      and visibility='private') then
      raise exception 'Refusing cleanup: push fixture identity does not match';
    end if;
    delete from auth.users where id=driver;
  end if;
end $$;
select not exists(select 1 from auth.users where id='00000000-0000-4000-9000-000000000691') as fixture_user_absent,
  not exists(select 1 from public.guardian_connections where id='00000000-0000-4000-9000-000000000692') as fixture_connection_absent,
  not exists(select 1 from public.guardian_alert_deliveries where id='00000000-0000-4000-9000-000000000695') as fixture_delivery_absent,
  (select count(*) from public.guardian_push_devices) as device_rows;
commit;
