alter table public.orders
  add column if not exists record_type text not null default 'Sale';

create table if not exists public.admin_transactions (
  id text primary key,
  type text not null,
  product_name text not null,
  quantity integer not null,
  price numeric not null,
  amount numeric not null,
  created_at timestamptz not null,
  order_id text,
  order_item_id text
);

alter table public.admin_transactions
  add column if not exists order_id text,
  add column if not exists order_item_id text;

create index if not exists admin_transactions_order_id_idx
  on public.admin_transactions (order_id);

create or replace function public.sync_admin_transactions_for_order(p_order_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select *
  into v_order
  from public.orders
  where id = p_order_id;

  if not found then
    delete from public.admin_transactions where order_id = p_order_id;
    return;
  end if;

  delete from public.admin_transactions where order_id = p_order_id;

  if v_order.voided or v_order.deleted_at is not null then
    return;
  end if;

  with lines as (
    select
      oi.id,
      oi.name_snapshot,
      oi.qty,
      oi.price_snapshot,
      oi.price_snapshot::numeric * oi.qty as gross_amount,
      coalesce(sum(oi.price_snapshot::numeric * oi.qty) over (), 0) as gross_total,
      row_number() over (order by oi.id) as row_number,
      count(*) over () as row_count
    from public.order_items oi
    where oi.order_id = p_order_id
  ),
  allocated as (
    select
      lines.*,
      case
        when row_number = row_count then
          v_order.total::numeric - coalesce(
            sum(
              case
                when gross_total > 0 then round(v_order.total::numeric * gross_amount / gross_total, 2)
                else 0
              end
            ) over (
              order by id
              rows between unbounded preceding and 1 preceding
            ),
            0
          )
        when gross_total > 0 then round(v_order.total::numeric * gross_amount / gross_total, 2)
        else 0
      end as line_amount
    from lines
  )
  insert into public.admin_transactions (
    id,
    type,
    product_name,
    quantity,
    price,
    amount,
    created_at,
    order_id,
    order_item_id
  )
  select
    id,
    case when v_order.record_type = 'Purchase' then 'Purchase' else 'Sale' end,
    name_snapshot,
    qty,
    price_snapshot,
    line_amount,
    v_order.created_at,
    p_order_id,
    id
  from allocated
  on conflict (id) do update set
    type = excluded.type,
    product_name = excluded.product_name,
    quantity = excluded.quantity,
    price = excluded.price,
    amount = excluded.amount,
    created_at = excluded.created_at,
    order_id = excluded.order_id,
    order_item_id = excluded.order_item_id;
end;
$$;

create or replace function public.sync_admin_transactions_from_order_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.sync_admin_transactions_for_order(old.order_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.order_id is distinct from new.order_id then
    perform public.sync_admin_transactions_for_order(old.order_id);
  end if;

  perform public.sync_admin_transactions_for_order(new.order_id);
  return new;
end;
$$;

create or replace function public.sync_admin_transactions_from_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.sync_admin_transactions_for_order(old.id);
    return old;
  end if;

  perform public.sync_admin_transactions_for_order(new.id);
  return new;
end;
$$;

drop trigger if exists order_items_sync_admin_transactions on public.order_items;
create trigger order_items_sync_admin_transactions
after insert or update or delete on public.order_items
for each row execute function public.sync_admin_transactions_from_order_item();

drop trigger if exists orders_sync_admin_transactions on public.orders;
create trigger orders_sync_admin_transactions
after insert or update of total, record_type, created_at, voided, deleted_at or delete
on public.orders
for each row execute function public.sync_admin_transactions_from_order();

select public.sync_admin_transactions_for_order(id)
from public.orders
where not voided and deleted_at is null;

notify pgrst, 'reload schema';
