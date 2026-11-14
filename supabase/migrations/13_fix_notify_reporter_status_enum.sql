-- Migration 13: fix the `notify_reporter_of_issue_change()` trigger that throws
-- 22P02 on every facility-issues status change.
--
-- ROOT CAUSE
-- ----------
-- Migration 12 already added the missing `rejected` enum label, so the UPDATE
-- on `facility_issues.status` itself now succeeds for all four statuses the app
-- can send (pending, in_progress, resolved, rejected). But the row AFTER UPDATE
-- trigger created in migration 10 still crashes, because of this line in
-- public.notify_reporter_of_issue_change():
--
--     v_body := 'Status: ' || coalesce(new.status, 'unknown');
--
-- `new.status` is of the `issue_status` ENUM type. Postgres unifies all COALESCE
-- arguments to a single type, so it forces the string literal 'unknown' to be
-- cast to `issue_status`. 'unknown' is not a valid label, so every time the
-- status-change branch runs (i.e. on every status change, which is exactly when
-- `new.status IS DISTINCT FROM old.status`) Postgres raises:
--
--     22P02  invalid input value for enum issue_status: "unknown"
--
-- That is why saving ANY changed status from the app's Manage dialog fails, even
-- though the value being written is a perfectly valid label.
--
-- FIX
-----
-- Cast the enum to TEXT first so the literal stays a plain text fallback:
--
--     v_body := 'Status: ' || coalesce(new.status::text, 'unknown');
--
-- COALESCE(text, text) -> text. No enum cast of the literal, no 22P02. The
-- intent (show a placeholder if new.status is ever null) is preserved.
--
-- Because the function was created with `create or replace`, re-creating it with
-- the corrected body is sufficient; the trigger `trg_notify_reporter_issue_change`
-- already points at this function and its name/signature are unchanged, so it is
-- left untouched.
--
-- Idempotent and safe to re-run.

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
    v_body := 'Status: ' || coalesce(new.status::text, 'unknown');
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
