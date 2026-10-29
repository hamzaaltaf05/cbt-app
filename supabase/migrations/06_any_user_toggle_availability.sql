-- ================================================================
-- Allow ALL authenticated users to toggle item availability.
-- Run AFTER 05_allow_self_insert_profile.sql.
--
-- The existing "manageable by admins/managers" policy keeps
-- add / edit / delete restricted to admin + shop_manager.
-- This migration adds a narrow security-definer RPC so any
-- authenticated user can toggle is_available only, WITHOUT
-- gaining the ability to change name / price / category.
-- ================================================================

create or replace function public.set_shop_item_availability(
  p_id           uuid,
  p_is_available boolean
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.shop_items
  set is_available = p_is_available
  where id = p_id;
$$;

grant execute on function public.set_shop_item_availability(uuid, boolean)
  to authenticated;

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================
