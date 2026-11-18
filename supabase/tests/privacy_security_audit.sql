-- M8.3: run after all migrations. Catalog gates supplement behavioral RLS tests.
-- Uses synthetic ACL mutations in rollback-only subtransactions; no hosted data.
begin;

create function pg_temp.assert_privacy_catalog_v1() returns void
language plpgsql as $$
declare
  target text;
  item record;
  procedure_id oid;
  audited_tables constant text[] := array[
    'profiles','vehicles','trip_summaries','social_relationships','social_request_limits',
    'ranking_members','ranking_entries','ranking_limits','guardian_invites',
    'guardian_connections','guardian_limits','guardian_audit','guardian_driver_sessions',
    'guardian_push_devices','guardian_alert_events','guardian_alert_deliveries','guardian_driver_controls'
  ];
begin
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p')
      and c.relname<>all(audited_tables) and c.relname<>'event_trigger_fires') then
    raise exception 'audit_unreviewed_private_table';
  end if;
  foreach target in array audited_tables loop
    if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=target and c.relrowsecurity) then
      raise exception 'audit_rls_missing';
    end if;
    if has_table_privilege('anon','public.'||target,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
      or has_any_column_privilege('anon','public.'||target,'SELECT,INSERT,UPDATE,REFERENCES') then
      raise exception 'audit_anonymous_private_table_access';
    end if;
  end loop;

  foreach target in array array['guardian_driver_sessions','guardian_push_devices',
    'guardian_alert_events','guardian_alert_deliveries','guardian_driver_controls'] loop
    if has_table_privilege('authenticated','public.'||target,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
      or has_any_column_privilege('authenticated','public.'||target,'SELECT,INSERT,UPDATE,REFERENCES') then
      raise exception 'audit_guardian_private_table_grant';
    end if;
  end loop;

  for item in select p.* from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef loop
    -- Platform-owned event helper is represented by bootstrap's minimal stub,
    -- not an app RPC definition. Keep its client ACL closed; do not assert an
    -- uninspected hosted implementation's search-path configuration.
    if item.oid=to_regprocedure('public.rls_auto_enable()')::oid then
      if item.prorettype<>'event_trigger'::regtype
        or has_function_privilege('authenticated',item.oid,'EXECUTE') then
        raise exception 'audit_platform_helper_exposure';
      end if;
    elsif not exists(select 1 from unnest(item.proconfig) option
      where option in ('search_path=""','search_path=')) then
        raise exception 'audit_definer_search_path';
    end if;
    if exists(select 1 from aclexplode(coalesce(item.proacl,acldefault('f',item.proowner))) a
      where a.grantee=0 and a.privilege_type='EXECUTE') then
      raise exception 'audit_public_definer_execute';
    end if;
    if item.oid<>'public.lookup_public_profile_v1(text)'::regprocedure::oid
      and has_function_privilege('anon',item.oid,'EXECUTE') then
      raise exception 'audit_anonymous_definer_execute';
    end if;
  end loop;

  foreach target in array array[
    'public.ingest_guardian_alert_v1(uuid,text,jsonb)',
    'public.claim_guardian_deliveries_v1(uuid,text,uuid)',
    'public.finish_guardian_dispatch_v1(uuid,uuid,boolean,boolean)',
    'public.receive_guardian_alert_v1(uuid,text,uuid)',
    'public.claim_guardian_dispatch_batch_v1(integer)',
    'public.guardian_dispatch_target_v1(uuid,uuid)',
    'public.finish_guardian_dispatch_v2(uuid,uuid,boolean,boolean,integer)'
  ] loop
    procedure_id := target::regprocedure::oid;
    if has_function_privilege('anon',procedure_id,'EXECUTE')
      or has_function_privilege('authenticated',procedure_id,'EXECUTE')
      or not has_function_privilege('service_role',procedure_id,'EXECUTE') then
      raise exception 'audit_guardian_server_only_rpc';
    end if;
  end loop;
end $$;

select pg_temp.assert_privacy_catalog_v1();

do $$ begin
  begin
    grant execute on function public.rls_auto_enable() to authenticated;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_platform_helper_exposure' then raise; end if;
  end;
  begin
    create table public.unreviewed_private_probe(id integer);
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_unreviewed_private_table' then raise; end if;
  end;
  begin
    alter table public.trip_summaries disable row level security;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_rls_missing' then raise; end if;
  end;
  begin
    grant select on public.trip_summaries to anon;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_anonymous_private_table_access' then raise; end if;
  end;
  begin
    grant select(source_trip_id) on public.trip_summaries to anon;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_anonymous_private_table_access' then raise; end if;
  end;
  begin
    alter function public.list_guardian_v1(uuid) set search_path=public;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_definer_search_path' then raise; end if;
  end;
  begin
    grant execute on function public.list_guardian_v1(uuid) to public;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_public_definer_execute' then raise; end if;
  end;
  begin
    grant select on public.guardian_push_devices to authenticated;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_guardian_private_table_grant' then raise; end if;
  end;
  begin
    grant execute on function public.ingest_guardian_alert_v1(uuid,text,jsonb) to authenticated;
    perform pg_temp.assert_privacy_catalog_v1();
    raise exception 'audit_negative_probe_missed';
  exception when raise_exception then
    if sqlerrm<>'audit_guardian_server_only_rpc' then raise; end if;
  end;
end $$;

select pg_temp.assert_privacy_catalog_v1();
rollback;
