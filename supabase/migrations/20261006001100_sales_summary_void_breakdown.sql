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
with daily_expense_details as (
  select
    entry_date as sales_date,
    jsonb_agg(
      jsonb_build_object(
        'amount', amount,
        'reason', reason
      )
      order by created_at, id
    ) as expenses_breakdown
  from public.admin_ledger_entries
  where kind = 'expense'
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
summary_dates as (
  select sales_date from public.sales_summary_base
  union
  select sales_date from daily_expense_details
  union
  select sales_date from daily_voids
)
select
  dates.sales_date,
  coalesce(summary.total_sales, 0::numeric) as total_sales,
  coalesce(summary.types_sold, '[]'::jsonb) as types_sold,
  coalesce(summary.total_expenses, 0::numeric) as total_expenses,
  coalesce(summary.total_credits, 0::numeric) as total_credits,
  coalesce(summary.net_summary, 0::numeric) as net_summary,
  coalesce(summary.total_drinks_sold, 0::bigint) as total_drinks_sold,
  coalesce(summary.drinks_breakdown, '[]'::jsonb) as drinks_breakdown,
  coalesce(summary.today_sales, 0::numeric) as today_sales,
  coalesce(summary.payment_breakdown, '[]'::jsonb) as payment_breakdown,
  summary.peak_hour,
  coalesce(summary.peak_hour_items, 0::bigint) as peak_hour_items,
  coalesce(daily_expense_details.expenses_breakdown, '[]'::jsonb) as expenses_breakdown,
  coalesce(daily_voids.void_count, 0::bigint) as void_count,
  coalesce(daily_voids.void_total, 0::numeric) as void_total,
  coalesce(daily_voids.void_breakdown, '[]'::jsonb) as void_breakdown
from summary_dates dates
left join public.sales_summary_base summary using (sales_date)
left join daily_expense_details using (sales_date)
left join daily_voids using (sales_date);

revoke all on public.sales_summary_base from public, anon, authenticated;
grant select on public.sales_summary_base to service_role;
revoke all on public.sales_summary from public, anon, authenticated;
grant select on public.sales_summary to service_role;

notify pgrst, 'reload schema';
