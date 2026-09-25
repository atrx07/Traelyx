-- Supabase projects can already contain a public SECURITY DEFINER helper
-- named rls_auto_enable(). Event triggers may continue to use it, but Data API
-- client roles must not invoke it directly. A fresh local test database may
-- not have this project-specific helper, so keep the migration conditional.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable()
      from public, anon, authenticated;
  end if;
end $$;
