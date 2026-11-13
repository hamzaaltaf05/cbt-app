-- Migration 11: add the missing `updated_at` audit column to facility_issues.
--
-- ROOT CAUSE OF PGRST204
-- ----------------------
-- The `facility_issues` table was created WITHOUT an `updated_at` column,
-- but the rest of the codebase assumes one exists:
--   * lib/models/facility_issue.dart        -> fromMap reads  map['updated_at']
--   * facility_issue_detail_screen.dart     -> update payload sets 'updated_at'
--   * migration 08 (request/cancel deletion)-> set updated_at = now()
--   * migration 10 (issue-change trigger)   -> fires on UPDATE of this table
-- PostgREST rejects the unknown column on UPDATE with:
--   PGRST204  "Could not find the '<column>' column of 'facility_issues'
--              in the schema cache"
-- Adding the column fixes the "Save Changes" update and every path that
-- writes it. Safe to re-run (uses IF NOT EXISTS / drop-if-exists).

alter table public.facility_issues
  add column if not exists updated_at timestamptz default now();

-- Keep the timestamp fresh on every row update (mirrors shop_items).
create or replace function public.set_facility_issues_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_facility_issues_set_updated_at on public.facility_issues;
create trigger trg_facility_issues_set_updated_at
  before update on public.facility_issues
  for each row
  execute procedure public.set_facility_issues_updated_at();
