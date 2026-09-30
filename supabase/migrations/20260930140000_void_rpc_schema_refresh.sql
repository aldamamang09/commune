create or replace function public.void_order_atomic(
  p_order_id text,
  p_reason text,
  p_voided_by text
)
returns jsonb
language plpgsql
as $$
declare
  v_id text;
  v_voided boolean;
  v_created_at timestamptz;
  v_ticket_no text;
  v_usage record;
begin
  select id, voided, created_at, ticket_no
    into v_id, v_voided, v_created_at, v_ticket_no
    from public.orders
    where id = p_order_id
    for update;

  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'ORDER_NOT_FOUND');
  end if;
  if v_voided then
    return jsonb_build_object('ok', false, 'error', 'ALREADY_VOIDED');
  end if;

  for v_usage in
    select inventory_item_id, used_amount
    from public.usage_logs
    where order_id = p_order_id and inventory_item_id is not null
  loop
    update public.inventory_items
    set stock = stock + v_usage.used_amount
    where id = v_usage.inventory_item_id;
  end loop;

  update public.orders
  set voided = true,
      void_reason = p_reason,
      voided_at = now(),
      voided_by = p_voided_by
  where id = p_order_id;

  if v_ticket_no ~ '^[0-9]+$' then
    update public.ticket_counters
    set n = n - 1
    where day = (v_created_at at time zone 'Asia/Manila')::date
      and n = v_ticket_no::integer;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.void_order_atomic(text, text, text)
  from public, anon, authenticated;
grant execute on function public.void_order_atomic(text, text, text)
  to service_role;

notify pgrst, 'reload schema';