-- =============================================================
-- 17_facility_issues_add_private_flag.sql
-- Add a "private" flag to facility_issues.
--
--   * is_private = false (default) -> visible to all logged-in users
--     (same behaviour as before, and as all existing data).
--   * is_private = true -> visible ONLY to the reporter and to
--     admin / office_admin roles.
--
-- Visibility is enforced server-side in Postgres RLS; the Flutter
-- client never filters on this column itself.
-- =============================================================

alter table public.facility_issues
  add column if not exists is_private boolean not null default false;

comment on column public.facility_issues.is_private is
  'Private issues are only visible to the reporter and admin roles';

-- Recreate the shared SELECT policy with the private-visibility rule.
-- The original policy was created by 01_schema_and_rls as
-- "Facility issues are viewable by authenticated users" (visible to ALL
-- authenticated users). Because multiple SELECT policies combine with OR,
-- it MUST be removed — otherwise it would still expose private issues.
-- To be name-proof (and to catch any extra SELECT policies added ad-hoc),
-- drop EVERY existing SELECT policy on the table first.
do $$
declare
  r record;
begin
  for r in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'facility_issues'
      and cmd = 'SELECT'
  loop
    execute format('drop policy if exists %I on public.facility_issues', r.policyname);
  end loop;
end
$$;

create policy "facility_issues_select" on public.facility_issues
  for select
  using (
    is_private = false
    or auth.uid() = reported_by
    or coalesce(public.get_user_role(), 'employee') in ('admin', 'office_admin')
  );