create table if not exists public.admin_ledger_entries (
  id text primary key,
  kind text not null check (kind in ('expense', 'credit')),
  title text not null,
  reason text not null default '',
  amount numeric(12, 2) not null check (amount > 0),
  entry_date date not null default ((now() at time zone 'Asia/Manila')::date),
  created_at timestamptz not null default now()
);

create index if not exists admin_ledger_entries_date_kind_idx
  on public.admin_ledger_entries (entry_date desc, kind);

alter table public.admin_ledger_entries enable row level security;
revoke all on public.admin_ledger_entries from public, anon, authenticated;
grant select, insert, update, delete on public.admin_ledger_entries to service_role;

create or replace view public.sales_summary
with (security_invoker = true) as
with live_orders as (
  select
    o.id,
    o.total::numeric as total,
    (o.created_at at time zone 'Asia/Manila')::date as sales_date
  from public.orders o
  where not o.voided
    and o.deleted_at is null
),
daily_sales as (
  select sales_date, sum(total) as total_sales
  from live_orders
  group by sales_date
),
order_lines as (
  select
    lo.id as order_id,
    lo.sales_date,
    lo.total as order_total,
    oi.id as order_item_id,
    oi.qty,
    oi.price_snapshot::numeric * oi.qty as gross_amount,
    coalesce(nullif(btrim(mc.type), ''), 'other') as type,
    sum(oi.price_snapshot::numeric * oi.qty) over (partition by lo.id) as gross_total,
    row_number() over (partition by lo.id order by oi.created_at, oi.id) as line_number,
    count(*) over (partition by lo.id) as line_count
  from live_orders lo
  join public.order_items oi on oi.order_id = lo.id
  left join public.menu_items mi on mi.id = oi.product_id_snapshot
  left join public.menu_categories mc on mc.id = mi.category_id
),
allocated_order_lines as (
  select
    order_lines.*,
    case
      when line_number = line_count then
        order_total - coalesce(
          sum(
            case
              when gross_total > 0 then round(order_total * gross_amount / gross_total, 2)
              else 0
            end
          ) over (
            partition by order_id
            order by line_number
            rows between unbounded preceding and 1 preceding
          ),
          0
        )
      when gross_total > 0 then round(order_total * gross_amount / gross_total, 2)
      else 0
    end as allocated_sales
  from order_lines
),
daily_types as (
  select
    sales_date,
    jsonb_agg(
      jsonb_build_object(
        'type', type,
        'quantity', quantity,
        'sales', sales
      )
      order by type
    ) as types_sold
  from (
    select
      sales_date,
      type,
      sum(qty)::bigint as quantity,
      sum(allocated_sales) as sales
    from allocated_order_lines
    group by sales_date, type
  ) grouped_types
  group by sales_date
),
daily_ledger as (
  select
    entry_date as sales_date,
    sum(amount) filter (where kind = 'expense') as total_expenses,
    sum(amount) filter (where kind = 'credit') as total_credits
  from public.admin_ledger_entries
  group by entry_date
),
all_dates as (
  select sales_date from daily_sales
  union
  select sales_date from daily_ledger
  union
  select (now() at time zone 'Asia/Manila')::date
)
select
  dates.sales_date,
  coalesce(daily_sales.total_sales, 0::numeric) as total_sales,
  coalesce(daily_types.types_sold, '[]'::jsonb) as types_sold,
  coalesce(daily_ledger.total_expenses, 0::numeric) as total_expenses,
  coalesce(daily_ledger.total_credits, 0::numeric) as total_credits,
  coalesce(daily_sales.total_sales, 0::numeric)
    - coalesce(daily_ledger.total_expenses, 0::numeric)
    - coalesce(daily_ledger.total_credits, 0::numeric) as net_summary
from all_dates dates
left join daily_sales using (sales_date)
left join daily_types using (sales_date)
left join daily_ledger using (sales_date);

revoke all on public.sales_summary from public, anon, authenticated;
grant select on public.sales_summary to service_role;

notify pgrst, 'reload schema';
