do $$
begin
  if to_regclass('public.sales_summary_base') is null then
    if to_regclass('public.sales_summary') is null then
      raise exception 'public.sales_summary does not exist; apply its base migration first';
    end if;
    execute 'alter view public.sales_summary rename to sales_summary_base';
  end if;
end;
$$;

drop view if exists public.sales_summary;

create view public.sales_summary
with (security_invoker = true) as
with live_lines as (
  select
    o.id as order_id,
    (o.created_at at time zone 'Asia/Manila')::date as sales_date,
    o.total::numeric as order_total,
    oi.id as order_item_id,
    oi.product_id_snapshot as product_id,
    oi.name_snapshot as product_name,
    oi.qty,
    oi.price_snapshot::numeric * oi.qty as gross_amount,
    coalesce(nullif(btrim(mc.type), ''), 'other') as type,
    sum(oi.price_snapshot::numeric * oi.qty) over (partition by o.id) as gross_total,
    row_number() over (partition by o.id order by oi.created_at, oi.id) as line_number,
    count(*) over (partition by o.id) as line_count
  from public.orders o
  join public.order_items oi on oi.order_id = o.id
  left join public.menu_items mi on mi.id = oi.product_id_snapshot
  left join public.menu_categories mc on mc.id = mi.category_id
  where not o.voided
    and o.deleted_at is null
),
allocated_live_lines as (
  select
    live_lines.*,
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
  from live_lines
),
daily_drinks as (
  select
    sales_date,
    sum(quantity)::bigint as total_drinks_sold,
    jsonb_agg(
      jsonb_build_object(
        'product_id', product_id,
        'name', product_name,
        'quantity', quantity,
        'sales', sales
      )
      order by quantity desc, product_name
    ) as drinks_breakdown
  from (
    select
      sales_date,
      product_id,
      product_name,
      sum(qty)::bigint as quantity,
      sum(allocated_sales) as sales
    from allocated_live_lines
    where lower(btrim(type)) ~ '(^|[^a-z])drinks?([^a-z]|$)'
    group by sales_date, product_id, product_name
  ) grouped_drinks
  group by sales_date
)
select
  summary.sales_date,
  summary.total_sales,
  summary.types_sold,
  summary.net_summary,
  coalesce(daily_drinks.total_drinks_sold, 0::bigint) as total_drinks_sold,
  coalesce(daily_drinks.drinks_breakdown, '[]'::jsonb) as drinks_breakdown,
  summary.today_sales,
  summary.payment_breakdown,
  summary.peak_hour,
  summary.peak_hour_items,
  summary.expenses,
  summary.credits,
  summary.void_count,
  summary.void_total,
  summary.void_breakdown
from public.sales_summary_base summary
left join daily_drinks using (sales_date);

revoke all on public.sales_summary_base from public, anon, authenticated;
grant select on public.sales_summary_base to service_role;
revoke all on public.sales_summary from public, anon, authenticated;
grant select on public.sales_summary to service_role;

notify pgrst, 'reload schema';
