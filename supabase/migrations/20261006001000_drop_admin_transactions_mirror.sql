drop trigger if exists order_items_sync_admin_transactions on public.order_items;
drop trigger if exists orders_sync_admin_transactions on public.orders;

drop function if exists public.sync_admin_transactions_from_order_item();
drop function if exists public.sync_admin_transactions_from_order();
drop function if exists public.sync_admin_transactions_for_order(text);

drop table if exists public.admin_transactions;

notify pgrst, 'reload schema';
