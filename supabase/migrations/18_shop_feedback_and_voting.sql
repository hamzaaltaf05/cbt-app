-- ================================================================
-- Migration 18: Honour Shop Feedback & Suggestions + Instant Voting
-- ================================================================

-- 1. HONOUR SHOP FEEDBACK & SUGGESTIONS TABLE ---------------------

create table if not exists public.shop_feedback (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        references public.profiles(id) on delete set null,
  type           text        not null check (type in ('suggestion', 'feedback')),
  title          text        not null check (length(trim(title)) > 0),
  description    text        not null check (length(trim(description)) > 0),
  admin_response text,
  responded_by   uuid        references public.profiles(id) on delete set null,
  responded_at   timestamptz,
  upvotes_count  integer     not null default 0,
  downvotes_count integer    not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Named foreign key for PostgREST profile embedding
alter table public.shop_feedback
  drop constraint if exists shop_feedback_user_id_fkey;

alter table public.shop_feedback
  add constraint shop_feedback_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete set null;

-- Indexes for fast feed filtering & sorting
create index if not exists idx_shop_feedback_feed
  on public.shop_feedback (type, created_at desc);

create index if not exists idx_shop_feedback_created_at
  on public.shop_feedback (created_at desc);

create index if not exists idx_shop_feedback_user
  on public.shop_feedback (user_id);

-- Auto-update updated_at on edits/responses
create or replace function public.update_shop_feedback_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_feedback_updated_at on public.shop_feedback;
create trigger trg_shop_feedback_updated_at
  before update on public.shop_feedback
  for each row execute procedure public.update_shop_feedback_updated_at();

-- 2. ADD VOTE COUNTERS TO EXISTING TABLES -----------------------

alter table public.facility_issues
  add column if not exists upvotes_count   integer not null default 0,
  add column if not exists downvotes_count integer not null default 0;

alter table public.shop_items
  add column if not exists upvotes_count   integer not null default 0,
  add column if not exists downvotes_count integer not null default 0;

-- 3. UNIFIED REDDIT-STYLE ENTITY VOTES TABLE --------------------

create table if not exists public.entity_votes (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles(id) on delete cascade,
  target_type text        not null check (target_type in ('facility_issue', 'shop_item', 'shop_feedback')),
  target_id   uuid        not null,
  vote        smallint    not null check (vote in (-1, 1)),
  created_at  timestamptz not null default now(),
  constraint uq_entity_votes_user_target unique (user_id, target_type, target_id)
);

create index if not exists idx_entity_votes_target
  on public.entity_votes (target_type, target_id);

create index if not exists idx_entity_votes_user
  on public.entity_votes (user_id, target_type);

-- 4. ATOMIC VOTE SYNC TRIGGER -----------------------------------
-- Recalculates exact counts on insert, update, or delete

create or replace function public.sync_entity_vote_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_type text;
  v_target_id   uuid;
  v_up          integer;
  v_down        integer;
begin
  v_target_type := coalesce(new.target_type, old.target_type);
  v_target_id   := coalesce(new.target_id, old.target_id);

  select
    count(*) filter (where vote = 1),
    count(*) filter (where vote = -1)
  into v_up, v_down
  from public.entity_votes
  where target_type = v_target_type and target_id = v_target_id;

  if v_target_type = 'facility_issue' then
    update public.facility_issues
    set upvotes_count = v_up, downvotes_count = v_down
    where id = v_target_id;
  elsif v_target_type = 'shop_item' then
    update public.shop_items
    set upvotes_count = v_up, downvotes_count = v_down
    where id = v_target_id;
  elsif v_target_type = 'shop_feedback' then
    update public.shop_feedback
    set upvotes_count = v_up, downvotes_count = v_down
    where id = v_target_id;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_entity_vote_counts on public.entity_votes;
create trigger trg_sync_entity_vote_counts
  after insert or update or delete on public.entity_votes
  for each row execute procedure public.sync_entity_vote_counts();

-- 5. ATOMIC VOTE RPC (Optimistic Persistence) ------------------
-- vote: 1 (upvote), -1 (downvote), 0 (toggle off / remove vote)

create or replace function public.cast_vote(
  p_target_type text,
  p_target_id   uuid,
  p_vote        smallint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_up      integer;
  v_down    integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to vote';
  end if;

  if p_vote = 0 then
    delete from public.entity_votes
    where user_id = v_user_id
      and target_type = p_target_type
      and target_id = p_target_id;
  elsif p_vote in (-1, 1) then
    insert into public.entity_votes (user_id, target_type, target_id, vote)
    values (v_user_id, p_target_type, p_target_id, p_vote)
    on conflict (user_id, target_type, target_id)
    do update set vote = excluded.vote, created_at = now();
  else
    raise exception 'Invalid vote value: must be -1, 0, or 1';
  end if;

  select
    count(*) filter (where vote = 1),
    count(*) filter (where vote = -1)
  into v_up, v_down
  from public.entity_votes
  where target_type = p_target_type and target_id = p_target_id;

  return jsonb_build_object(
    'target_id', p_target_id,
    'upvotes', v_up,
    'downvotes', v_down,
    'score', (v_up - v_down),
    'user_vote', p_vote
  );
end;
$$;

grant execute on function public.cast_vote(text, uuid, smallint) to authenticated;

-- Clean up votes if a parent row is deleted
create or replace function public.cleanup_target_entity_votes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.entity_votes
  where target_type = TG_ARGV[0] and target_id = old.id;
  return old;
end;
$$;

drop trigger if exists trg_cleanup_facility_issue_votes on public.facility_issues;
create trigger trg_cleanup_facility_issue_votes
  after delete on public.facility_issues
  for each row execute procedure public.cleanup_target_entity_votes('facility_issue');

drop trigger if exists trg_cleanup_shop_item_votes on public.shop_items;
create trigger trg_cleanup_shop_item_votes
  after delete on public.shop_items
  for each row execute procedure public.cleanup_target_entity_votes('shop_item');

drop trigger if exists trg_cleanup_shop_feedback_votes on public.shop_feedback;
create trigger trg_cleanup_shop_feedback_votes
  after delete on public.shop_feedback
  for each row execute procedure public.cleanup_target_entity_votes('shop_feedback');

-- 6. NOTIFICATION TRIGGERS FOR SHOP FEEDBACK --------------------

-- 6a. Notify Admins & Shop Managers on new Feedback/Suggestion
create or replace function public.notify_shop_managers_of_feedback()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_name text;
  r record;
begin
  select full_name into v_author_name
  from public.profiles where id = new.user_id;

  for r in (
    select id from public.profiles
    where role in ('admin', 'shop_manager')
      and id is distinct from new.user_id
  ) loop
    perform public.create_notification(
      r.id,
      'shop_feedback_created',
      case when new.type = 'suggestion' then 'New Shop Suggestion' else 'New Shop Feedback' end,
      coalesce(new.title, 'A post was submitted') || ' by ' || coalesce(v_author_name, 'a user'),
      'shop_feedback',
      new.id
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_shop_managers_feedback on public.shop_feedback;
create trigger trg_notify_shop_managers_feedback
  after insert on public.shop_feedback
  for each row execute procedure public.notify_shop_managers_of_feedback();

-- 6b. Notify author when Admin/Shop Manager responds
create or replace function public.notify_author_of_feedback_response()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is not null
     and new.admin_response is not null
     and (old.admin_response is null or old.admin_response is distinct from new.admin_response) then
    perform public.create_notification(
      new.user_id,
      'shop_feedback_response',
      'Response to your ' || new.type,
      new.admin_response,
      'shop_feedback',
      new.id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_author_feedback_response on public.shop_feedback;
create trigger trg_notify_author_feedback_response
  after update on public.shop_feedback
  for each row execute procedure public.notify_author_of_feedback_response();

-- 7. ROW LEVEL SECURITY (RLS) -----------------------------------

alter table public.shop_feedback enable row level security;
alter table public.entity_votes   enable row level security;

-- Shop Feedback RLS
drop policy if exists "shop_feedback_select" on public.shop_feedback;
create policy "shop_feedback_select"
  on public.shop_feedback for select to authenticated
  using (true);

drop policy if exists "shop_feedback_insert" on public.shop_feedback;
create policy "shop_feedback_insert"
  on public.shop_feedback for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "shop_feedback_update" on public.shop_feedback;
create policy "shop_feedback_update"
  on public.shop_feedback for update to authenticated
  using (
    auth.uid() = user_id
    or public.get_user_role() in ('admin', 'shop_manager')
  )
  with check (
    auth.uid() = user_id
    or public.get_user_role() in ('admin', 'shop_manager')
  );

drop policy if exists "shop_feedback_delete" on public.shop_feedback;
create policy "shop_feedback_delete"
  on public.shop_feedback for delete to authenticated
  using (
    auth.uid() = user_id
    or public.get_user_role() in ('admin', 'shop_manager')
  );

-- Entity Votes RLS
drop policy if exists "entity_votes_select" on public.entity_votes;
create policy "entity_votes_select"
  on public.entity_votes for select to authenticated
  using (true);

drop policy if exists "entity_votes_manage_own" on public.entity_votes;
create policy "entity_votes_manage_own"
  on public.entity_votes for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on table public.shop_feedback to authenticated;
grant select, insert, update, delete on table public.entity_votes   to authenticated;

-- 8. REALTIME SUBSCRIPTION --------------------------------------

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'shop_feedback'
  ) then
    alter publication supabase_realtime add table public.shop_feedback;
  end if;
end;
$$;
