drop view if exists public.sales_summary;
drop view if exists public.sales_summary_base;

create view public.sales_summary
with (security_invoker = true) as
with live_orders as (
  select
    o.id,
    o.total::numeric as total,
    o.payment_method,
    o.created_at,
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
    lo.created_at,
    oi.id as order_item_id,
    oi.product_id_snapshot as product_id,
    oi.name_snapshot as product_name,
    oi.qty,
    oi.price_snapshot::numeric * oi.qty as gross_amount,
    lower(coalesce(nullif(btrim(mc.type), ''), 'other')) as type,
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
daily_drink_products as (
  select
    sales_date,
    jsonb_agg(
      jsonb_build_object(
        'product_id', product_id,
        'name', product_name,
        'quantity', quantity,
        'sales', sales
      )
      order by quantity desc, product_name
    ) as drinks_breakdown,
    sum(quantity)::bigint as drinks_quantity
  from (
    select
      sales_date,
      product_id,
      product_name,
      sum(qty)::bigint as quantity,
      sum(allocated_sales) as sales
    from allocated_order_lines
    where lower(btrim(type)) ~ '(^|[^a-z])drinks?([^a-z]|$)'
    group by sales_date, product_id, product_name
  ) grouped_drinks
  group by sales_date
),
daily_payment_methods as (
  select
    sales_date,
    case
      when lower(coalesce(payment_method, '')) = 'gcash' then 'gcash'
      when lower(coalesce(payment_method, '')) = 'maya' then 'maya'
      else 'cash'
    end as payment_method,
    count(*)::bigint as order_count,
    sum(total) as amount
  from live_orders
  group by
    sales_date,
    case
      when lower(coalesce(payment_method, '')) = 'gcash' then 'gcash'
      when lower(coalesce(payment_method, '')) = 'maya' then 'maya'
      else 'cash'
    end
),
payment_methods as (
  select unnest(array['cash', 'gcash', 'maya']::text[]) as payment_method
),
daily_ledger as (
  select
    entry_date as sales_date,
    sum(amount) filter (where kind = 'expense') as total_expenses,
    sum(amount) filter (where kind = 'credit') as total_credits
  from public.admin_ledger_entries
  group by entry_date
),
daily_expense_details as (
  select
    entry_date as sales_date,
    jsonb_agg(
      jsonb_build_object(
        'amount', amount,
        'reason', reason
      )
      order by created_at, id
    ) as expenses
  from public.admin_ledger_entries
  where kind = 'expense'
  group by entry_date
),
daily_credit_details as (
  select
    entry_date as sales_date,
    jsonb_agg(
      jsonb_build_object(
        'amount', amount,
        'reason', reason
      )
      order by created_at, id
    ) as credits
  from public.admin_ledger_entries
  where kind = 'credit'
  group by entry_date
),
daily_voids as (
  select
    (coalesce(o.voided_at, o.created_at) at time zone 'Asia/Manila')::date as sales_date,
    count(*)::bigint as void_count,
    sum(o.total)::numeric as void_total,
    jsonb_agg(
      jsonb_build_object(
        'order_id', o.id,
        'ticket_no', o.ticket_no,
        'amount', o.total,
        'reason', coalesce(nullif(btrim(o.void_reason), ''), 'No reason provided'),
        'voided_at', coalesce(o.voided_at, o.created_at)
      )
      order by coalesce(o.voided_at, o.created_at), o.ticket_no
    ) as void_breakdown
  from public.orders o
  where o.voided
    and o.deleted_at is null
  group by (coalesce(o.voided_at, o.created_at) at time zone 'Asia/Manila')::date
),
date_bounds as (
  select
    least(
      coalesce((select min(sales_date) from daily_sales), (now() at time zone 'Asia/Manila')::date),
      coalesce((select min(sales_date) from daily_ledger), (now() at time zone 'Asia/Manila')::date),
      coalesce((select min(sales_date) from daily_voids), (now() at time zone 'Asia/Manila')::date)
    ) as first_date,
    greatest(
      (now() at time zone 'Asia/Manila')::date,
      coalesce((select max(sales_date) from daily_sales), (now() at time zone 'Asia/Manila')::date),
      coalesce((select max(sales_date) from daily_ledger), (now() at time zone 'Asia/Manila')::date),
      coalesce((select max(sales_date) from daily_voids), (now() at time zone 'Asia/Manila')::date)
    ) as last_date
),
all_dates as (
  select generated.day::date as sales_date
  from date_bounds
  cross join lateral generate_series(
    date_bounds.first_date::timestamp,
    date_bounds.last_date::timestamp,
    interval '1 day'
  ) as generated(day)
),
daily_payment_breakdown as (
  select
    dates.sales_date,
    jsonb_agg(
      jsonb_build_object(
        'method', methods.payment_method,
        'orders', coalesce(daily_payment_methods.order_count, 0),
        'total', coalesce(daily_payment_methods.amount, 0::numeric)
      )
      order by case methods.payment_method
        when 'cash' then 1
        when 'gcash' then 2
        else 3
      end
    ) as payment_breakdown
  from all_dates dates
  cross join payment_methods methods
  left join daily_payment_methods
    on daily_payment_methods.sales_date = dates.sales_date
    and daily_payment_methods.payment_method = methods.payment_method
  group by dates.sales_date
),
daily_peak_hours as (
  select
    sales_date,
    hour,
    item_count
  from (
    select
      sales_date,
      hour,
      item_count,
      row_number() over (
        partition by sales_date
        order by item_count desc, hour
      ) as rank
    from (
      select
        sales_date,
        extract(hour from created_at at time zone 'Asia/Manila')::integer as hour,
        sum(qty)::bigint as item_count
      from allocated_order_lines
      group by sales_date, extract(hour from created_at at time zone 'Asia/Manila')
    ) hourly_items
    where hour between 10 and 23 or hour = 0
  ) ranked_hours
  where rank = 1
)
select
  dates.sales_date,
  coalesce(daily_sales.total_sales, 0::numeric) as total_sales,
  coalesce(daily_types.types_sold, '[]'::jsonb) as types_sold,
  coalesce(daily_sales.total_sales, 0::numeric)
    - coalesce(daily_ledger.total_expenses, 0::numeric)
    - coalesce(daily_ledger.total_credits, 0::numeric) as net_summary,
  coalesce(daily_drink_products.drinks_quantity, 0::bigint) as total_drinks_sold,
  coalesce(daily_drink_products.drinks_breakdown, '[]'::jsonb) as drinks_breakdown,
  case
    when dates.sales_date = (now() at time zone 'Asia/Manila')::date
      then coalesce(daily_sales.total_sales, 0::numeric)
    else 0::numeric
  end as today_sales,
  coalesce(daily_payment_breakdown.payment_breakdown, '[]'::jsonb) as payment_breakdown,
  case daily_peak_hours.hour
    when 0 then '12 AM'
    when 12 then '12 PM'
    when 1 then '1 AM'
    when 2 then '2 AM'
    when 3 then '3 AM'
    when 4 then '4 AM'
    when 5 then '5 AM'
    when 6 then '6 AM'
    when 7 then '7 AM'
    when 8 then '8 AM'
    when 9 then '9 AM'
    when 10 then '10 AM'
    when 11 then '11 AM'
    when 13 then '1 PM'
    when 14 then '2 PM'
    when 15 then '3 PM'
    when 16 then '4 PM'
    when 17 then '5 PM'
    when 18 then '6 PM'
    when 19 then '7 PM'
    when 20 then '8 PM'
    when 21 then '9 PM'
    when 22 then '10 PM'
    when 23 then '11 PM'
    else null
  end as peak_hour,
  coalesce(daily_peak_hours.item_count, 0::bigint) as peak_hour_items,
  coalesce(daily_expense_details.expenses, '[]'::jsonb) as expenses,
  coalesce(daily_credit_details.credits, '[]'::jsonb) as credits,
  coalesce(daily_voids.void_count, 0::bigint) as void_count,
  coalesce(daily_voids.void_total, 0::numeric) as void_total,
  coalesce(daily_voids.void_breakdown, '[]'::jsonb) as void_breakdown
from all_dates dates
left join daily_sales using (sales_date)
left join daily_types using (sales_date)
left join daily_drink_products using (sales_date)
left join daily_ledger using (sales_date)
left join daily_expense_details using (sales_date)
left join daily_credit_details using (sales_date)
left join daily_payment_breakdown using (sales_date)
left join daily_peak_hours using (sales_date)
left join daily_voids using (sales_date);

revoke all on public.sales_summary from public, anon, authenticated;
grant select on public.sales_summary to service_role;

notify pgrst, 'reload schema';
