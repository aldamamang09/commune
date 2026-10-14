-- A voided ticket stays in the order history, but the next successful order
-- may reuse its number when it was the latest allocated ticket.

create or replace function public.next_ticket_no(p_at timestamptz default now())
returns text
language plpgsql
as $$
declare
  v_day date;
  v_max integer;
  v_n integer;
begin
  v_day := (p_at at time zone 'Asia/Manila')::date;

  -- Seed a new daily counter from the highest ticket that is still active.
  -- If the highest issued number belongs only to voided orders, reuse it.
  select max(
           case
             when regexp_replace(o.ticket_no, '^#', '') ~ '^[0-9]+$'
               then regexp_replace(o.ticket_no, '^#', '')::integer
             else null
           end
         )
    into v_max
    from public.orders o
   where (o.created_at at time zone 'Asia/Manila')::date = v_day;

  if v_max is null or v_max = 0 then
    v_n := 1;
  elsif exists (
    select 1
      from public.orders o
     where (o.created_at at time zone 'Asia/Manila')::date = v_day
       and not o.voided
       and case
             when regexp_replace(o.ticket_no, '^#', '') ~ '^[0-9]+$'
               then regexp_replace(o.ticket_no, '^#', '')::integer
             else null
           end = v_max
  ) then
    v_n := v_max + 1;
  else
    v_n := v_max;
  end if;

  insert into public.ticket_counters (day, n)
  values (v_day, v_n)
  on conflict (day) do update set n = ticket_counters.n + 1
  returning n into v_n;

  return lpad(v_n::text, 3, '0');
end;
$$;

revoke all on function public.next_ticket_no(timestamptz) from public, anon, authenticated;
grant execute on function public.next_ticket_no(timestamptz) to service_role;

create or replace function public.rewind_ticket_counter_for_voided_order()
returns trigger
language plpgsql
as $$
declare
  v_day date;
  v_ticket integer;
begin
  if not new.voided
     or (tg_op = 'UPDATE' and coalesce(old.voided, false))
     or new.ticket_no is null
     or regexp_replace(new.ticket_no, '^#', '') !~ '^[0-9]+$' then
    return new;
  end if;

  v_day := (new.created_at at time zone 'Asia/Manila')::date;
  v_ticket := regexp_replace(new.ticket_no, '^#', '')::integer;

  -- Only rewind when this voided ticket is still the counter's latest value.
  -- The conditional update is serialized by the same daily row used by the
  -- allocator, so the following order safely receives the reclaimed number.
  update public.ticket_counters
     set n = n - 1
   where day = v_day
     and n = v_ticket
     and n > 0;

  return new;
end;
$$;

drop trigger if exists orders_rewind_ticket_counter_on_void on public.orders;
create trigger orders_rewind_ticket_counter_on_void
after insert or update of voided on public.orders
for each row
execute function public.rewind_ticket_counter_for_voided_order();
