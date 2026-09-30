create or replace function public.save_recipe_costing(
  p_id text,
  p_name text,
  p_hot_cup_inventory_item_id text,
  p_iced_cup_inventory_item_id text,
  p_other_cup_inventory_item_id text,
  p_menu_items jsonb,
  p_ingredients jsonb
)
returns void
language plpgsql
as $$
begin
  if p_id is null or length(trim(p_id)) = 0 then
    raise exception 'save_recipe_costing: p_id is required';
  end if;
  if p_menu_items is null or jsonb_typeof(p_menu_items) <> 'array' then
    raise exception 'save_recipe_costing: p_menu_items must be a JSON array';
  end if;
  if p_ingredients is null or jsonb_typeof(p_ingredients) <> 'array' then
    raise exception 'save_recipe_costing: p_ingredients must be a JSON array';
  end if;

  insert into public.recipe_costings (
    id, name, hot_cup_inventory_item_id, iced_cup_inventory_item_id,
    other_cup_inventory_item_id
  )
  values (
    p_id,
    trim(coalesce(p_name, '')),
    nullif(trim(coalesce(p_hot_cup_inventory_item_id, '')), ''),
    nullif(trim(coalesce(p_iced_cup_inventory_item_id, '')), ''),
    nullif(trim(coalesce(p_other_cup_inventory_item_id, '')), '')
  )
  on conflict (id) do update
    set name = excluded.name,
        hot_cup_inventory_item_id = excluded.hot_cup_inventory_item_id,
        iced_cup_inventory_item_id = excluded.iced_cup_inventory_item_id,
        other_cup_inventory_item_id = excluded.other_cup_inventory_item_id,
        updated_at = now();

  delete from public.recipe_costing_menu_items where recipe_costing_id = p_id;
  insert into public.recipe_costing_menu_items (recipe_costing_id, menu_item_name)
  select p_id, trim(value)
  from jsonb_array_elements_text(p_menu_items) as value
  where trim(value) <> '';

  delete from public.recipe_costing_ingredients where recipe_costing_id = p_id;
  insert into public.recipe_costing_ingredients (
    id, recipe_costing_id, inventory_item_id, name, amount, unit
  )
  select
    p_id || '-ing-' || row_number() over (),
    p_id,
    nullif(nullif(trim(coalesce(elem->>'inventoryItemId', '')), ''), 'other'),
    trim(elem->>'name'),
    (elem->>'amount')::numeric,
    coalesce(nullif(trim(elem->>'unit'), ''), '')
  from jsonb_array_elements(p_ingredients) as elem
  where trim(coalesce(elem->>'name', '')) <> '';
end;
$$;

revoke all on function public.save_recipe_costing(text, text, text, text, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.save_recipe_costing(text, text, text, text, text, jsonb, jsonb)
  to service_role;

notify pgrst, 'reload schema';