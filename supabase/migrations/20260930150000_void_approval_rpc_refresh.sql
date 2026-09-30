-- Replace the legacy four-argument approval RPC with the actor-aware,
-- atomic five-argument version and refresh PostgREST's function schema cache.
drop function if exists public.approve_void_request_atomic(text, text, text, text);

create or replace function public.approve_void_request_atomic(
  p_request_id text,
  p_approved_by_id text,
  p_approved_by_name text,
  p_new_order_id text default null,
  p_ticket_no text default null
)
returns jsonb
language plpgsql
as $$
declare
  v_req public.void_requests%rowtype;
  v_result jsonb;
  v_processed text;
begin
  select * into v_req
  from public.void_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    return jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  end if;
  if v_req.status <> 'pending' then
    return jsonb_build_object('ok', false, 'error', 'ALREADY_APPROVED');
  end if;

  if v_req.order_id is not null then
    select public.void_order_atomic(
      v_req.order_id,
      v_req.reason,
      p_approved_by_id
    ) into v_result;
    if not coalesce((v_result->>'ok')::boolean, false) then
      return v_result;
    end if;
    v_processed := v_req.order_id;
  else
    if p_new_order_id is null or length(trim(p_new_order_id)) = 0 then
      raise exception 'approve_void_request_atomic: p_new_order_id is required for pre-checkout void requests';
    end if;

    select public.create_order_atomic(
      p_new_order_id,
      now(),
      v_req.requested_by_name,
      v_req.requested_by_id,
      v_req.items,
      v_req.subtotal,
      v_req.discount,
      null,
      v_req.promo_label,
      v_req.total,
      v_req.payment_method,
      null,
      0,
      0,
      '[]'::jsonb,
      true,
      v_req.reason,
      p_approved_by_id
    ) into v_result;
    v_processed := p_new_order_id;
  end if;

  update public.void_requests
  set status = 'approved',
      approved_at = now(),
      approved_by_name = p_approved_by_name,
      processed_order_id = v_processed
  where id = p_request_id;

  return jsonb_build_object('ok', true, 'processedOrderId', v_processed);
end;
$$;

revoke all on function public.approve_void_request_atomic(text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.approve_void_request_atomic(text, text, text, text, text)
  to service_role;

notify pgrst, 'reload schema';
