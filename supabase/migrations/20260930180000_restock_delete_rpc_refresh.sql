create or replace function public.delete_restock_atomic(
  p_id text,
  p_inventory_item_id text,
  p_quantity_added numeric
)
returns jsonb
language plpgsql
as $$
declare
  v_restock public.restocks%rowtype;
  v_item_id text;
  v_matches integer;
begin
  select * into v_restock
  from public.restocks
  where id = p_id
  for update;

  if not found then
    return jsonb_build_object('ok', true, 'deleted', false, 'alreadyDeleted', true);
  end if;

  v_item_id := v_restock.inventory_item_id;

  if v_item_id is null then
    select count(*) into v_matches
    from public.inventory_items
    where lower(trim(name)) = lower(trim(v_restock.item_name_snapshot));

    if v_matches = 1 then
      select id into v_item_id
      from public.inventory_items
      where lower(trim(name)) = lower(trim(v_restock.item_name_snapshot));
    elsif v_matches > 1 then
      raise exception
        'delete_restock_atomic: cannot safely reverse restock % - % inventory items named "%"',
        p_id, v_matches, v_restock.item_name_snapshot;
    end if;
  end if;

  if v_item_id is not null then
    update public.inventory_items
    set stock = greatest(0, stock - v_restock.quantity_added)
    where id = v_item_id;

    if not found then
      v_item_id := null;
    end if;
  end if;

  delete from public.restocks where id = p_id;

  return jsonb_build_object(
    'ok', true,
    'deleted', true,
    'reversed', v_item_id is not null,
    'inventoryItemId', v_item_id,
    'quantityAdded', v_restock.quantity_added
  );
end;
$$;

revoke all on function public.delete_restock_atomic(text, text, numeric)
  from public, anon, authenticated;
grant execute on function public.delete_restock_atomic(text, text, numeric)
  to service_role;

notify pgrst, 'reload schema';