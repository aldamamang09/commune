alter table public.void_requests
  alter column requested_by_id drop not null;

alter table public.void_requests
  drop constraint if exists void_requests_requested_by_id_fkey;

alter table public.void_requests
  add constraint void_requests_requested_by_id_fkey
  foreign key (requested_by_id)
  references public.staff_users(id)
  on delete set null;

create or replace function public.null_missing_void_requester()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.requested_by_id is not null
     and not exists (
       select 1
       from public.staff_users
       where id = new.requested_by_id
     ) then
    new.requested_by_id := null;
  end if;

  return new;
end;
$$;

revoke all on function public.null_missing_void_requester() from public;

drop trigger if exists void_requests_null_missing_requester
  on public.void_requests;

create trigger void_requests_null_missing_requester
  before insert or update of requested_by_id
  on public.void_requests
  for each row
  execute function public.null_missing_void_requester();
