-- Preserve order history after deleting a cashier/barista account. The
-- barista_name snapshot remains available after this staff reference is null.
alter table public.orders
  drop constraint if exists orders_barista_user_id_fkey;

alter table public.orders
  add constraint orders_barista_user_id_fkey
  foreign key (barista_user_id)
  references public.staff_users(id)
  on delete set null;
