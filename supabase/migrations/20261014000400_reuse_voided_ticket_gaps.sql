-- Reuse voided ticket numbers even when later tickets have already been
-- issued. The void rows remain in orders; an active order can share that no.

create or replace function public.next_ticket_no(p_at timestamptz default now())
returns text
language plpgsql
as $$
declare
  v_day date;
  v_n integer;
  v_reusable integer;
begin
  v_day := (p_at at time zone 'Asia/Manila')::date;

  -- The counter row is the per-day mutex. Hold its lock until create_order_atomic
  -- inserts the order so concurrent checkouts cannot claim the same gap.
  insert into public.ticket_counters (day, n)
  values (v_day, 0)
  on conflict (day) do nothing;

  select n into v_n
    from public.ticket_counters
   where day = v_day
   for update;

  -- Reclaim the lowest voided number that has no completed order using it.
  -- This also repairs gaps left by voids created before this allocator shipped.
  select min(
           case
             when regexp_replace(o.ticket_no, '^#', '') ~ '^[0-9]+$'
               then regexp_replace(o.ticket_no, '^#', '')::integer
             else null
           end
         )
    into v_reusable
    from public.orders o
   where (o.created_at at time zone 'Asia/Manila')::date = v_day
     and o.voided
     and not exists (
       select 1
         from public.orders active_order
        where (active_order.created_at at time zone 'Asia/Manila')::date = v_day
          and not active_order.voided
          and case
                when regexp_replace(active_order.ticket_no, '^#', '') ~ '^[0-9]+$'
                  then regexp_replace(active_order.ticket_no, '^#', '')::integer
                else null
              end = case
                      when regexp_replace(o.ticket_no, '^#', '') ~ '^[0-9]+$'
                        then regexp_replace(o.ticket_no, '^#', '')::integer
                      else null
                    end
     );

  if v_reusable is not null then
    v_n := v_reusable;
  else
    select coalesce(max(
             case
               when regexp_replace(o.ticket_no, '^#', '') ~ '^[0-9]+$'
                 then regexp_replace(o.ticket_no, '^#', '')::integer
               else null
             end
           ), 0) + 1
      into v_n
      from public.orders o
     where (o.created_at at time zone 'Asia/Manila')::date = v_day;
  end if;

  update public.ticket_counters set n = v_n where day = v_day;
  return lpad(v_n::text, 3, '0');
end;
$$;

revoke all on function public.next_ticket_no(timestamptz) from public, anon, authenticated;
grant execute on function public.next_ticket_no(timestamptz) to service_role;

-- Allocation now inspects void rows directly, so the older rewind trigger is
-- unnecessary and would make the counter's diagnostic value misleading.
drop trigger if exists orders_rewind_ticket_counter_on_void on public.orders;
drop function if exists public.rewind_ticket_counter_for_voided_order();
