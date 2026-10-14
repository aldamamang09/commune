-- Preserve the manager/admin name that authorized each void alongside the FK.
alter table public.orders
  add column if not exists voided_by_name text;

create or replace function public.snapshot_order_void_actor_name()
returns trigger
language plpgsql
as $$
declare
  v_should_snapshot boolean;
begin
  if tg_op = 'INSERT' then
    v_should_snapshot := true;
  else
    v_should_snapshot := not coalesce(old.voided, false)
      or new.voided_by is distinct from old.voided_by;
  end if;

  if new.voided
     and new.voided_by is not null
     and new.voided_by_name is null
     and v_should_snapshot then
    select name into new.voided_by_name
      from public.staff_users
     where id = new.voided_by;
  end if;

  return new;
end;
$$;

drop trigger if exists orders_snapshot_void_actor_name on public.orders;
create trigger orders_snapshot_void_actor_name
before insert or update of voided, voided_by on public.orders
for each row
execute function public.snapshot_order_void_actor_name();
