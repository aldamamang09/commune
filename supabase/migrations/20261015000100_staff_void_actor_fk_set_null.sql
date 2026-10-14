-- Keep a void's name snapshot when its staff account is deleted. The FK is
-- only needed while the account exists; voided_by_name remains the historical
-- record and continues to render in Recent Orders after deletion.
alter table public.orders
  drop constraint if exists orders_voided_by_fkey;

alter table public.orders
  add constraint orders_voided_by_fkey
  foreign key (voided_by)
  references public.staff_users(id)
  on delete set null;
