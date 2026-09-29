alter table public.restocks
  add column if not exists purchase_qty numeric,
  add column if not exists purchase_unit text;

drop function if exists public.create_restock_atomic(text, text, text, numeric, timestamptz);

create or replace function public.create_restock_atomic(
  p_id text,
  p_inventory_item_id text,
  p_item_name_snapshot text,
  p_quantity_added numeric,
  p_created_at timestamptz,
  p_purchase_qty numeric default null,
  p_purchase_unit text default null
)
returns jsonb
language plpgsql
as $$
begin
  insert into public.restocks (
    id,
    inventory_item_id,
    item_name_snapshot,
    quantity_added,
    purchase_qty,
    purchase_unit,
    created_at
  )
  values (
    p_id,
    p_inventory_item_id,
    p_item_name_snapshot,
    p_quantity_added,
    p_purchase_qty,
    p_purchase_unit,
    p_created_at
  );

  if p_inventory_item_id is not null then
    update public.inventory_items
    set stock = stock + p_quantity_added
    where id = p_inventory_item_id;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.create_restock_atomic(text, text, text, numeric, timestamptz, numeric, text)
  from public, anon, authenticated;
grant execute on function public.create_restock_atomic(text, text, text, numeric, timestamptz, numeric, text)
  to service_role;

notify pgrst, 'reload schema';