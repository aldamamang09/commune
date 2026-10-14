-- Keep the checkout service mode directly on orders as well as on each item.
alter table public.orders
  add column if not exists service_mode text;

update public.orders o
set service_mode = (
  select oi.service_mode
  from public.order_items oi
  where oi.order_id = o.id
    and oi.service_mode in ('dine-in', 'take-out')
  order by oi.id
  limit 1
)
where o.service_mode is null;

create or replace function public.sync_order_service_mode_from_item()
returns trigger
language plpgsql
as $$
begin
  if new.service_mode in ('dine-in', 'take-out') then
    update public.orders
       set service_mode = new.service_mode
     where id = new.order_id
       and service_mode is distinct from new.service_mode;
  end if;
  return new;
end;
$$;

drop trigger if exists order_items_sync_service_mode on public.order_items;
create trigger order_items_sync_service_mode
after insert or update of service_mode on public.order_items
for each row
execute function public.sync_order_service_mode_from_item();
