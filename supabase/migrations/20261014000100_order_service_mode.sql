
alter table public.order_items add column if not exists service_mode text;

create or replace function public.create_order_atomic(
  p_order_id text,
  p_created_at timestamptz,
  p_barista_name text,
  p_barista_user_id text,
  p_items jsonb,
  p_subtotal integer,
  p_discount integer,
  p_promo_id text,
  p_promo_label text,
  p_total integer,
  p_payment_method text,
  p_ticket_no text default null,
  p_paid integer default 0,
  p_change integer default 0,
  p_deductions jsonb default '[]'::jsonb,
  p_voided boolean default false,
  p_void_reason text default null,
  p_voided_by text default null
)
returns jsonb
language plpgsql
as $$
declare
  v_item jsonb;
  v_index integer := 0;
  v_menu_item_id text;
  v_deduction jsonb;
  v_updated_rows integer;
  v_ticket_no text;
begin
  if p_order_id is null or length(trim(p_order_id)) = 0 then
    raise exception 'create_order_atomic: p_order_id is required';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'create_order_atomic: p_items must be a non-empty JSON array';
  end if;

  v_ticket_no := public.next_ticket_no(p_created_at);

  insert into public.orders (
    id, created_at, barista_name, barista_user_id, subtotal, discount,
    promo_id, promo_label, total, payment_method, ticket_no, paid, change,
    voided, void_reason, voided_at, voided_by
  )
  values (
    p_order_id, p_created_at, p_barista_name, p_barista_user_id, p_subtotal, p_discount,
    p_promo_id, p_promo_label, p_total, p_payment_method, v_ticket_no, p_paid, p_change,
    p_voided,
    case when p_voided then p_void_reason else null end,
    case when p_voided then now() else null end,
    case when p_voided then p_voided_by else null end
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_index := v_index + 1;
    -- product_id_snapshot/name_snapshot are the historical source of truth;
    -- menu_item_id is a live-lookup convenience and must stay NULL for
    -- manual/synthetic entries that are not a real menu_items.id (e.g. the
    -- Transactions tab's "manual-<id>" rows), since it has an FK.
    select id into v_menu_item_id from public.menu_items where id = v_item->>'productId';
    insert into public.order_items (id, order_id, menu_item_id, product_id_snapshot, name_snapshot, qty, price_snapshot, style, addons, service_mode)
    values (
      p_order_id || '-item-' || v_index,
      p_order_id,
      v_menu_item_id,
      v_item->>'productId',
      v_item->>'name',
      (v_item->>'qty')::integer,
      (v_item->>'price')::integer,
      nullif(v_item->>'style', ''),
      case when jsonb_typeof(v_item->'addons') = 'array' then v_item->'addons' else '[]'::jsonb end,
      case when v_item->>'serviceMode' in ('take-in', 'take-out') then v_item->>'serviceMode' else null end
    );
  end loop;

  if not p_voided and p_deductions is not null and jsonb_typeof(p_deductions) = 'array' then
    for v_deduction in select * from jsonb_array_elements(p_deductions)
    loop
      update public.inventory_items
      set stock = stock - (v_deduction->>'amount')::numeric
      where id = v_deduction->>'inventoryItemId'
        and stock >= (v_deduction->>'amount')::numeric;

      get diagnostics v_updated_rows = row_count;
      if v_updated_rows = 0 then
        raise exception 'INSUFFICIENT_STOCK:%', coalesce(v_deduction->>'itemName', v_deduction->>'inventoryItemId');
      end if;

      insert into public.usage_logs (id, order_id, order_item_id, inventory_item_id, item_name_snapshot, used_amount, unit)
      values (
        p_order_id || '-' || (v_deduction->>'inventoryItemId') || '-usage',
        p_order_id,
        coalesce(v_deduction->>'orderItemId', ''),
        v_deduction->>'inventoryItemId',
        v_deduction->>'itemName',
        (v_deduction->>'amount')::numeric,
        v_deduction->>'unit'
      );
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'orderId', p_order_id, 'ticketNo', v_ticket_no);
end;
$$;

revoke all on function public.create_order_atomic(
  text, timestamptz, text, text, jsonb, integer, integer, text, text,
  integer, text, text, integer, integer, jsonb, boolean, text, text
) from public, anon, authenticated;
grant execute on function public.create_order_atomic(
  text, timestamptz, text, text, jsonb, integer, integer, text, text,
  integer, text, text, integer, integer, jsonb, boolean, text, text
) to service_role;
