-- ================================================================
-- Honour Shop — Patch for existing schema
-- Run AFTER 01_schema_and_rls, 02_user_profile_trigger, 03_storage_policies
-- Do NOT run 001_initial_setup.sql (it conflicts with this schema)
-- ================================================================

-- ================================================================
-- 1. Add missing columns to shop_items
-- ================================================================

alter table public.shop_items
  add column if not exists category     text        not null default 'Other',
  add column if not exists is_available boolean     not null default true,
  add column if not exists created_at   timestamptz not null default now();

-- ================================================================
-- 2. Replace handle_new_user — first user ever = admin, rest = employee
--    (Replaces the version in 02_user_profile_trigger)
-- ================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
declare
  full_name     text;
  initial_role  public.user_role;
  profile_count integer;
begin
  full_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Anonymous User');

  select count(*) into profile_count from public.profiles;

  initial_role := case
    when profile_count = 0 then 'admin'::public.user_role
    else 'employee'::public.user_role
  end;

  insert into public.profiles (id, full_name, role)
  values (new.id, full_name, initial_role)
  on conflict (id) do nothing;

  return new;
end;
$$;

-- Trigger name and definition already exist from 02 — no need to recreate.
-- The function body is replaced above; the existing trigger now calls the new version.

-- ================================================================
-- 3. Prevent non-admin users from changing any user's role
-- ================================================================

create or replace function public.prevent_role_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Block a non-admin from changing their OWN role
  if new.id = auth.uid()
     and new.role is distinct from old.role
     and old.role is distinct from 'admin' then
    raise exception 'Non-admin users cannot change their role';
  end if;

  -- Block a non-admin from changing ANOTHER user's role
  if new.id is distinct from auth.uid()
     and new.role is distinct from old.role then
    if public.get_user_role() is distinct from 'admin' then
      raise exception 'Only admins can change other users roles';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_role_self_change on public.profiles;
create trigger trg_prevent_role_self_change
  before update on public.profiles
  for each row
  execute procedure public.prevent_role_self_change();

-- ================================================================
-- 4. Auto-update updated_at on shop_items
-- ================================================================

create or replace function public.update_shop_items_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_items_updated_at on public.shop_items;
create trigger trg_shop_items_updated_at
  before update on public.shop_items
  for each row
  execute procedure public.update_shop_items_updated_at();

-- ================================================================
-- 5. RLS: admin can update ANY profile row (needed for role assignment)
-- ================================================================

drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update"
  on public.profiles for update to authenticated
  using (public.get_user_role() = 'admin')
  with check (public.get_user_role() = 'admin');

-- ================================================================
-- 6. Indexes
-- ================================================================

create index if not exists idx_shop_items_category     on public.shop_items (category);
create index if not exists idx_shop_items_is_available on public.shop_items (is_available);
create index if not exists idx_shop_items_created_at   on public.shop_items (created_at desc);

-- ================================================================
-- PATCH COMPLETE
-- ================================================================
