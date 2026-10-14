-- Only snapshot an approver's name when voided_by points to a manager/admin.
-- This prevents cashier session IDs from being stored as the void actor name.
create or replace function public.snapshot_order_void_actor_name()
returns trigger
language plpgsql
as $$
declare
  v_actor_name text;
begin
  if not new.voided or new.voided_by is null then
    return new;
  end if;

  select name into v_actor_name
    from public.staff_users
   where id = new.voided_by
     and (
       lower(coalesce(role, '')) in ('manager', 'admin')
       or lower(coalesce(title, '')) ~ '(manager|admin|owner)'
     );

  if v_actor_name is not null then
    new.voided_by_name := v_actor_name;
  else
    new.voided_by_name := null;
  end if;

  return new;
end;
$$;

drop trigger if exists orders_snapshot_void_actor_name on public.orders;
create trigger orders_snapshot_void_actor_name
before insert or update of voided, voided_by on public.orders
for each row
execute function public.snapshot_order_void_actor_name();

-- Backfill names only where the referenced account is actually a manager/admin.
update public.orders o
   set voided_by_name = u.name
  from public.staff_users u
 where o.voided
   and o.voided_by = u.id
   and o.voided_by_name is null
   and (
     lower(coalesce(u.role, '')) in ('manager', 'admin')
     or lower(coalesce(u.title, '')) ~ '(manager|admin|owner)'
   );
