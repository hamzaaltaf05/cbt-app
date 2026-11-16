-- Migration 14: FCM Device Tokens table
--
-- Stores the Firebase Cloud Messaging registration token per device
-- associated with authenticated user profiles.

create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

-- Index for fast token lookup by user_id
create index if not exists idx_fcm_tokens_user_id
  on public.fcm_tokens (user_id);

-- Enable Row Level Security
alter table public.fcm_tokens enable row level security;

-- Policy: Users can view their own device tokens
drop policy if exists "fcm_tokens_select_own" on public.fcm_tokens;
create policy "fcm_tokens_select_own"
  on public.fcm_tokens for select to authenticated
  using (auth.uid() = user_id);

-- Policy: Users can insert/update their own device tokens
drop policy if exists "fcm_tokens_upsert_own" on public.fcm_tokens;
create policy "fcm_tokens_upsert_own"
  on public.fcm_tokens for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "fcm_tokens_update_own" on public.fcm_tokens;
create policy "fcm_tokens_update_own"
  on public.fcm_tokens for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Policy: Users can delete their own tokens on logout
drop policy if exists "fcm_tokens_delete_own" on public.fcm_tokens;
create policy "fcm_tokens_delete_own"
  on public.fcm_tokens for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on table public.fcm_tokens to authenticated;
