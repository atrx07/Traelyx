-- Minimal Supabase Auth stand-in for testing the migration with PostgreSQL 17.
-- This file is test-only and is never deployed to a hosted project.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid
  language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

-- Mirror the hosted event-trigger wiring and record each post-DDL invocation.
create table public.event_trigger_fires (n integer not null);
create function public.rls_auto_enable() returns event_trigger
  language plpgsql security definer
  as $$ begin insert into public.event_trigger_fires values (1); end $$;
create event trigger ensure_rls on ddl_command_end
  execute function public.rls_auto_enable();

insert into auth.users (id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
