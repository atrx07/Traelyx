-- Disposable database only: apply/roll back the migration around a legacy session.
begin;
insert into auth.users(id) values('48484848-4848-4848-8848-484848484848');
insert into public.guardian_driver_sessions values('48484848-4848-4848-8848-484848484848',
 '49494949-4949-4949-8949-494949494949',sha256(convert_to(repeat('a',64),'UTF8')),now()+interval '1 hour');
create temp table legacy_driver_snapshot as select * from public.guardian_driver_sessions
 where user_id='48484848-4848-4848-8848-484848484848';
\ir ../migrations/20261014000000_guardian_driver_revisions.sql
do $$ begin
  if exists((select * from legacy_driver_snapshot) except (select * from public.guardian_driver_sessions)) then
    raise exception 'Upgrade altered legacy session identity, credential or expiry'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','48484848-4848-4848-8848-484848484848',true);
do $$ begin
  if public.get_guardian_driver_revision_v2('48484848-4848-4848-8848-484848484848')<>'{"revision":"0"}'::jsonb then
    raise exception 'Upgrade revision unavailable'; end if;
  begin
    perform public.set_guardian_driver_session_v1('48484848-4848-4848-8848-484848484848',
      '49494949-4949-4949-8949-494949494949',repeat('a',64));
    raise exception 'Legacy activation bypassed revision review';
  exception when sqlstate '55000' then null; end;
  if public.set_guardian_driver_session_v1('48484848-4848-4848-8848-484848484848',
      '49494949-4949-4949-8949-494949494949',null)<>'{"enabled":false}'::jsonb then
    raise exception 'Legacy cleanup was not confirmed'; end if;
end $$;
reset role;
do $$ begin
  if exists(select 1 from public.guardian_driver_sessions where user_id='48484848-4848-4848-8848-484848484848')
    or not exists(select 1 from public.guardian_driver_controls where user_id='48484848-4848-4848-8848-484848484848' and revision=1) then
    raise exception 'Legacy exact cleanup failed'; end if;
end $$;
rollback;
select true as legacy_upgrade_preservation_and_cleanup_passed;
