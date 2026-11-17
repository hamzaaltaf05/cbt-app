-- ================================================================
-- Migration 16: promote_to_admin RPC
--
-- Provides a secure server-side function that lets an admin promote
-- (or demote) another user's role.  Callers never touch the profiles
-- table directly — all permission checks happen inside the function.
-- ================================================================


-- ----------------------------------------------------------------
-- 1. promote_to_admin
--    Promotes target_user_id to 'admin'.
--    Caller must themselves be an admin; raises otherwise.
-- ----------------------------------------------------------------
create or replace function public.promote_to_admin(target_user_id uuid)
returns void
language plpgsql
security definer          -- runs as the DB owner, bypassing RLS
set search_path = public  -- prevent search-path injection
as $$
declare
  caller_role public.user_role;
  target_exists boolean;
begin
  -- 1. Confirm the caller is authenticated
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- 2. Confirm the caller is an admin
  select role into caller_role
  from public.profiles
  where id = auth.uid();

  if caller_role is distinct from 'admin'::public.user_role then
    raise exception 'Permission denied: only admins can promote users';
  end if;

  -- 3. Confirm the target user exists
  select exists(
    select 1 from public.profiles where id = target_user_id
  ) into target_exists;

  if not target_exists then
    raise exception 'User not found: %', target_user_id;
  end if;

  -- 4. Prevent an admin from accidentally re-promoting themselves
  --    (harmless but gives a clear feedback message)
  if target_user_id = auth.uid() then
    raise exception 'You are already an admin';
  end if;

  -- 5. Promote
  update public.profiles
  set role = 'admin'::public.user_role
  where id = target_user_id;
end;
$$;

-- ----------------------------------------------------------------
-- 2. set_user_role  (more flexible: promote OR demote)
--    Admin-only function to set any user to any valid role.
--    Usage:  select set_user_role('<uuid>', 'manager');
-- ----------------------------------------------------------------
create or replace function public.set_user_role(
  target_user_id uuid,
  new_role        public.user_role
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role public.user_role;
  target_exists boolean;
begin
  -- 1. Authenticated check
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- 2. Admin check
  select role into caller_role
  from public.profiles
  where id = auth.uid();

  if caller_role is distinct from 'admin'::public.user_role then
    raise exception 'Permission denied: only admins can change user roles';
  end if;

  -- 3. Target exists
  select exists(
    select 1 from public.profiles where id = target_user_id
  ) into target_exists;

  if not target_exists then
    raise exception 'User not found: %', target_user_id;
  end if;

  -- 4. Update role
  update public.profiles
  set role = new_role
  where id = target_user_id;
end;
$$;

-- ----------------------------------------------------------------
-- 3. Grant EXECUTE only to authenticated users
--    (anon / service-role do not need these)
-- ----------------------------------------------------------------
revoke all on function public.promote_to_admin(uuid)        from public, anon;
revoke all on function public.set_user_role(uuid, public.user_role) from public, anon;

grant execute on function public.promote_to_admin(uuid)              to authenticated;
grant execute on function public.set_user_role(uuid, public.user_role) to authenticated;

-- ================================================================
-- USAGE EXAMPLES (run in Supabase SQL Editor)
-- ================================================================
--
-- A) Promote a specific user to admin by their UUID:
--    select public.promote_to_admin('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx');
--
-- B) Set a user's role to any valid role (admin / manager / employee):
--    select public.set_user_role('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'manager');
--    select public.set_user_role('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'admin');
--    select public.set_user_role('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'employee');
--
-- C) From Flutter (Supabase Dart client), called while signed in as admin:
--    await Supabase.instance.client.rpc(
--      'promote_to_admin',
--      params: {'target_user_id': '<uuid>'},
--    );
--
--    await Supabase.instance.client.rpc(
--      'set_user_role',
--      params: {'target_user_id': '<uuid>', 'new_role': 'manager'},
--    );
--
-- ================================================================
