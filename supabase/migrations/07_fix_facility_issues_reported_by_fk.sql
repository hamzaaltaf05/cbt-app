-- 07_fix_facility_issues_reported_by_fk.sql
-- ----------------------------------------------------------------------------
-- Fixes PostgREST PGRST200 on the Facility Issues screen:
--   "failed to resolve relationship between 'facility_issues' and 'profiles'
--    using the hint 'facility_issues_reported_by_key'"
--
-- Root cause: the app embeds the reporter with
--   select = *, profiles!facility_issues_reported_by_key(full_name)
-- which requires a FOREIGN KEY named exactly 'facility_issues_reported_by_key'
-- from facility_issues.reported_by to profiles.id. The live database has no FK
-- under that name (it was created ad-hoc, or auto-named, e.g.
-- 'facility_issues_reported_by_fkey'), so PostgREST cannot resolve the embed.
--
-- This migration is deterministic and idempotent:
--   1. Drops any FK on facility_issues.reported_by -> profiles.id (any name).
--   2. Ensures reported_by exists and is nullable (needed for ON DELETE SET NULL).
--   3. Nulls out reported_by values that don't reference an existing profile
--      (otherwise the FK add would fail; the UI already shows 'Unknown' for a
--      missing reporter, so this is safe).
--   4. Adds exactly one FK named 'facility_issues_reported_by_key'.
--
-- Run this in the Supabase SQL Editor (or `supabase db push`).
-- ----------------------------------------------------------------------------

-- 1) Drop any existing FK on facility_issues.reported_by -> profiles.id.
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t  on t.oid  = c.conrelid
    join pg_class ft on ft.oid = c.confrelid
    where c.contype = 'f'
      and t.relnamespace  = 'public'::regnamespace
      and t.relname       = 'facility_issues'
      and ft.relnamespace = 'public'::regnamespace
      and ft.relname      = 'profiles'
      and c.conkey = (
        select array_agg(a.attnum)
        from pg_attribute a
        where a.attrelid = 'public.facility_issues'::regclass
          and a.attname  = 'reported_by'
      )
  loop
    execute format('alter table public.facility_issues drop constraint %I', r.conname);
  end loop;
end
$$;

-- 2) Ensure the column exists and is nullable (required for ON DELETE SET NULL).
alter table public.facility_issues add column if not exists reported_by uuid;
alter table public.facility_issues alter column reported_by drop not null;

-- 3) Null out orphaned reported_by values so the FK can be added safely.
update public.facility_issues fi
set reported_by = null
where fi.reported_by is not null
  and not exists (select 1 from public.profiles p where p.id = fi.reported_by);

-- 4) Create the single, correctly-named FK the app's join hint expects.
alter table public.facility_issues
  add constraint facility_issues_reported_by_key
  foreign key (reported_by)
  references public.profiles (id)
  on delete set null;
