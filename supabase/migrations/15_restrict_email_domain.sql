-- ================================================================
-- 15_restrict_email_domain.sql
-- Security Hardening: Restrict Registration to @convergentbt.com
-- ================================================================

-- 1. Database-level trigger on auth.users before insert
-- Blocks any direct API, SDK, or bypass attempt from signing up with an unauthorized email domain.

create or replace function public.validate_user_email_domain()
returns trigger
language plpgsql
security definer
as $$
begin
  -- Reject any email that does not end in @convergentbt.com
  if lower(coalesce(new.email, '')) not like '%@convergentbt.com' then
    raise exception 'Registration is restricted to official @convergentbt.com email addresses.';
  end if;

  return new;
end;
$$;

-- Drop trigger if it already exists to avoid duplication
drop trigger if exists trg_validate_user_email_domain on auth.users;

-- Create the BEFORE INSERT trigger on auth.users
create trigger trg_validate_user_email_domain
  before insert on auth.users
  for each row
  execute function public.validate_user_email_domain();

-- 2. Also harden handle_new_user() profile creation trigger as secondary defense
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
  -- Validate email domain
  if lower(coalesce(new.email, '')) not like '%@convergentbt.com' then
    raise exception 'Access restricted: Only @convergentbt.com accounts are permitted.';
  end if;

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
