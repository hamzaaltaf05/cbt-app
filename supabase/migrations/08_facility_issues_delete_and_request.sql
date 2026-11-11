-- Migration 08: Facility issues — deletion + deletion-request flow
--
-- 1. Adds a new "office_admin" value to the `user_role` enum.
--    (New role in `profiles`: sees the facility list, can request a
--     deletion from the reporter, but cannot delete directly.)
-- 2. Adds deletion-request audit columns to `facility_issues`.
-- 3. Adds a DELETE policy on `facility_issues` (creator or admin only).
-- 4. Adds the `request_issue_deletion(uuid)` security-definer RPC that an
--    Office Admin can call to ask the reporter to delete an issue.

-- 1. New role value.
alter type public.user_role add value if not exists 'office_admin';

-- 2. Deletion-request audit columns (set only by request_issue_deletion).
alter table public.facility_issues
  add column if not exists deletion_requested_by uuid
  references public.profiles (id) on delete set null,
  add column if not exists deletion_requested_at timestamptz
  default now();

-- 3. DELETE: the reporter themselves, or an admin.
create policy "facility_issues delete (creator or admin)"
  on public.facility_issues
  for delete
  using (
    reported_by = auth.uid()
    or get_user_role() = 'admin'
  );

-- 4. Office Admin "request deletion" flow.
--    NOTE: parameter names must match the Supabase client keys exactly
--    (PostgREST resolves named functions by parameter name), so the client
--    calls this as rpc('request_issue_deletion', params: {'issue_id': ...}).
create or replace function public.request_issue_deletion(issue_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if get_user_role() is distinct from 'office_admin' then
    raise exception 'Only Office Admin can request issue deletion';
  end if;

  if not exists (select 1 from public.facility_issues where id = issue_id) then
    raise exception 'Issue not found';
  end if;

  if (select reported_by from public.facility_issues where id = issue_id) = auth.uid() then
    raise exception 'You are the reporter; delete this issue directly instead';
  end if;

  update public.facility_issues
  set deletion_requested_by = auth.uid(),
      deletion_requested_at = now(),
      updated_at = now()
  where id = issue_id;
end;
$$;

grant execute on function public.request_issue_deletion(uuid) to authenticated;

-- 5. The reporter (or the requesting Office Admin) can cancel a pending
--    deletion request, keeping the issue visible. The row still exists here
--    (the terminal "delete" path removes the row outright, so no cleanup is
--    needed on that side).
create or replace function public.cancel_issue_deletion_request(issue_id uuid, requester_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter  uuid;
  v_requester uuid;
begin
  -- The caller must act as themselves (do not trust a client-supplied id).
  if requester_id is distinct from auth.uid() then
    raise exception 'requester_id must match the authenticated user';
  end if;

  select reported_by, deletion_requested_by
    into v_reporter, v_requester
    from public.facility_issues
   where id = issue_id;

  if not found then
    raise exception 'Issue not found';
  end if;

  if v_reporter  is distinct from auth.uid()
     and v_requester is distinct from auth.uid()
  then
    raise exception 'Not allowed to cancel this deletion request';
  end if;

  update public.facility_issues
  set deletion_requested_by = null,
      deletion_requested_at = null,
      updated_at = now()
  where id = issue_id;
end;
$$;

grant execute on function public.cancel_issue_deletion_request(uuid, uuid) to authenticated;

-- The app connects as `authenticated`; the RLS policy above scopes who can
-- actually delete (creator OR admin). Make sure that role holds the
-- DELETE privilege while keeping it away from the untrusted `public` role.
grant delete on table public.facility_issues to authenticated;
revoke delete on table public.facility_issues from public;
