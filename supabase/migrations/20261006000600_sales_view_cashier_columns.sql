alter table public.orders
  add column if not exists cashier_name text;

update public.orders
set cashier_name = barista_name
where cashier_name is null or btrim(cashier_name) = '';

create or replace function public.sync_order_cashier_name()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.cashier_name is null or btrim(new.cashier_name) = '' then
    new.cashier_name := new.barista_name;
  end if;

  return new;
end;
$$;

drop trigger if exists orders_sync_cashier_name on public.orders;
create trigger orders_sync_cashier_name
before insert or update of cashier_name, barista_name
on public.orders
for each row
execute function public.sync_order_cashier_name();

drop view if exists public.sales;

create view public.sales
with (security_invoker = true) as
select
  o.id as order_id,
  o.ticket_no,
  o.created_at,
  (o.created_at at time zone 'Asia/Manila')::date as sales_date,
  o.cashier_name,
  o.subtotal,
  o.total,
  o.paid,
  o.change,
  o.payment_method,
  o.voided,
  o.void_reason,
  coalesce(items.item_count, 0) as item_count,
  coalesce(items.qty_total, 0) as qty_total,
  items.items
from public.orders o
left join lateral (
  select
    count(*) as item_count,
    coalesce(sum(oi.qty), 0) as qty_total,
    jsonb_agg(
      jsonb_build_object(
        'product_id', oi.product_id_snapshot,
        'name', oi.name_snapshot,
        'qty', oi.qty,
        'price', oi.price_snapshot,
        'style', oi.style,
        'addons', oi.addons
      )
      order by oi.created_at
    ) as items
  from public.order_items oi
  where oi.order_id = o.id
) items on true;

revoke all on public.sales from public, anon, authenticated;
grant select on public.sales to service_role;

notify pgrst, 'reload schema';
