-- Migration 10: Role-based, real-time in-app notifications.
--
-- 1. `notifications` table: one row per *recipient* per event, deep-linkable
--    via (ref_type, ref_id).
-- 2. RLS: a user can read and mark-read only their own notifications.
-- 3. Server-side triggers create the notifications for the right roles.
-- 4. Realtime publication so new notifications stream to the app instantly.
--
-- Idempotent: safe to re-run (create-if-not-exists, drop+recreate policies,
-- replace functions).

-- 1. Table ---------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references public.profiles (id) on delete cascade,
  type       text        not null,
  title      text        not null,
  body       text,
  ref_type   text,
  ref_id     uuid,
  is_read    boolean     not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_unread
  on public.notifications (user_id, is_read, created_at desc);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

-- 2. RLS ------------------------------------------------------------------
alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
  on public.notifications for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, update on table public.notifications to authenticated;

-- 3. Helper ---------------------------------------------------------------
-- Inserts a single notification for one recipient. `security definer` so it
-- can be called from inside other triggers (bypasses RLS) and is safe.
create or replace function public.create_notification(
  p_user_id  uuid,
  p_type     text,
  p_title    text,
  p_body     text,
  p_ref_type text default null,
  p_ref_id   uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  insert into public.notifications (user_id, type, title, body, ref_type, ref_id)
  values (p_user_id, p_type, p_title, p_body, p_ref_type, p_ref_id);
end;
$$;

grant execute on function public.create_notification(uuid, text, text, text, text, uuid)
  to authenticated;

-- 3a. New facility issue -> notify admins + office admins -----------------
create or replace function public.notify_admins_of_new_issue()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter_name text;
  r record;
begin
  select full_name into v_reporter_name
    from public.profiles where id = new.reported_by;

  for r in (
    select id from public.profiles
    where role in ('admin', 'office_admin')
      and id is distinct from new.reported_by
  ) loop
    perform public.create_notification(
      r.id,
      'facility_reported',
      'New facility issue reported',
      coalesce(new.title, 'A facility issue')
        || ' by ' || coalesce(v_reporter_name, 'a user'),
      'facility_issue',
      new.id
    );
  end loop;

  return new;
end;
$$;

create or replace trigger trg_notify_admins_new_issue
  after insert on public.facility_issues
  for each row execute procedure public.notify_admins_of_new_issue();

-- 3b. Facility issue changed -> notify the reporter -----------------------
create or replace function public.notify_reporter_of_issue_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_body text;
begin
  if new.reported_by is null then
    return new;
  end if;

  if new.status is distinct from old.status then
    v_body := 'Status: ' || coalesce(new.status, 'unknown');
    if new.admin_response is not null then
      v_body := v_body || ' | ' || new.admin_response;
    end if;
    perform public.create_notification(
      new.reported_by,
      'facility_status',
      'Your issue was updated',
      v_body,
      'facility_issue',
      new.id
    );
  end if;

  if new.deletion_requested_by is not null
     and (old.deletion_requested_by is null
          or old.deletion_requested_by is distinct from new.deletion_requested_by) then
    perform public.create_notification(
      new.reported_by,
      'facility_deletion_requested',
      'Deletion requested for your issue',
      'An office admin asked you to review a deletion request.',
      'facility_issue',
      new.id
    );
  end if;

  return new;
end;
$$;

create or replace trigger trg_notify_reporter_issue_change
  after update on public.facility_issues
  for each row execute procedure public.notify_reporter_of_issue_change();

-- 3c. Facility issue removed -> notify the reporter -----------------------
create or replace function public.notify_reporter_of_issue_deleted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.reported_by is not null then
    perform public.create_notification(
      old.reported_by,
      'facility_deleted',
      'Your issue was removed',
      coalesce(old.title, 'A facility issue'),
      'facility_issue',
      old.id
    );
  end if;
  return old;
end;
$$;

create or replace trigger trg_notify_reporter_issue_deleted
  after delete on public.facility_issues
  for each row execute procedure public.notify_reporter_of_issue_deleted();

-- 3d. Shop item added/edited/removed -> notify admins + shop managers ------
create or replace function public.notify_shop_admins_of_item_added()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
  r record;
begin
  v_actor := auth.uid();
  for r in (
    select id from public.profiles
    where role in ('admin', 'shop_manager')
      and id is distinct from v_actor
  ) loop
    perform public.create_notification(
      r.id,
      'shop_item_added',
      'New shop item added',
      coalesce(new.name, 'A shop item'),
      'shop_item',
      new.id
    );
  end loop;
  return new;
end;
$$;

create or replace trigger trg_notify_shop_item_added
  after insert on public.shop_items
  for each row execute procedure public.notify_shop_admins_of_item_added();

create or replace function public.notify_shop_admins_of_item_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
  r record;
begin
  v_actor := auth.uid();

  -- Only real content changes (name/price). Availability toggles by any user
  -- are intentionally excluded to avoid noisy notifications.
  if (new.name is distinct from old.name)
     or (new.price is distinct from old.price) then
    for r in (
      select id from public.profiles
      where role in ('admin', 'shop_manager')
        and id is distinct from v_actor
    ) loop
      perform public.create_notification(
        r.id,
        'shop_item_updated',
        'Shop item updated',
        coalesce(new.name, 'A shop item'),
        'shop_item',
        new.id
      );
    end loop;
  end if;

  return new;
end;
$$;

create or replace trigger trg_notify_shop_item_updated
  after update on public.shop_items
  for each row execute procedure public.notify_shop_admins_of_item_updated();

create or replace function public.notify_shop_admins_of_item_removed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid;
  r record;
begin
  v_actor := auth.uid();
  for r in (
    select id from public.profiles
    where role in ('admin', 'shop_manager')
      and id is distinct from v_actor
  ) loop
    perform public.create_notification(
      r.id,
      'shop_item_removed',
      'Shop item removed',
      coalesce(old.name, 'A shop item'),
      'shop_item',
      old.id
    );
  end loop;
  return old;
end;
$$;

create or replace trigger trg_notify_shop_item_removed
  after delete on public.shop_items
  for each row execute procedure public.notify_shop_admins_of_item_removed();

-- 4. Realtime -------------------------------------------------------------
-- Publish `notifications` so new rows stream to subscribed clients. The client
-- filters by user_id = auth.uid(), so each user only receives their own.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

