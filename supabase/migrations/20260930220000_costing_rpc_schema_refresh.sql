create or replace function public.save_costing(
  p_id text,
  p_product_name text,
  p_ingredients jsonb
)
returns void
language plpgsql
as $$
declare
  v_name text;
begin
  if p_id is null or length(trim(p_id)) = 0 then
    raise exception 'save_costing: p_id is required';
  end if;

  v_name := trim(coalesce(p_product_name, ''));
  if v_name = '' then
    raise exception 'save_costing: p_product_name is required';
  end if;

  if p_ingredients is null or jsonb_typeof(p_ingredients) <> 'array' then
    raise exception 'save_costing: p_ingredients must be a JSON array';
  end if;

  insert into public.costings (id, product_name)
  values (p_id, v_name)
  on conflict (id) do update
    set product_name = excluded.product_name,
        updated_at = now();

  delete from public.costing_ingredients where costing_id = p_id;

  insert into public.costing_ingredients (id, costing_id, name, amount, unit, output_cups)
  select
    p_id || '-ing-' || row_number() over (),
    p_id,
    trim(elem->>'name'),
    (elem->>'amount')::numeric,
    nullif(trim(elem->>'unit'), ''),
    nullif(elem->>'outputCups', '')::numeric
  from jsonb_array_elements(p_ingredients) as elem
  where trim(coalesce(elem->>'name', '')) <> '';
end;
$$;

revoke all on function public.save_costing(text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.save_costing(text, text, jsonb)
  to service_role;

notify pgrst, 'reload schema';