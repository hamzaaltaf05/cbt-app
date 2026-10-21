-- ================================================================
-- Allow each authenticated user to insert their OWN profile row.
-- This is the DB-side half of the app-side fix in home_screen.dart:
-- if a profile row is missing (e.g. the account was created before
-- the handle_new_user trigger existed), the app recreates it as a
-- plain employee instead of silently degrading to "Simple User".
--
-- Run AFTER 04_patch_existing_schema.sql.
-- ================================================================

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================