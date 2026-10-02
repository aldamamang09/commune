-- Persist configurable staff login paths across server restarts and instances.
create table if not exists public.login_links (
  id text primary key,
  admin_path text not null,
  cashier_path text not null default '',
  updated_at timestamptz not null default now()
);

-- Older/manual versions of this table may have constrained id to a different
-- singleton value. The service-role-only table does not need that constraint.
alter table public.login_links
  drop constraint if exists login_links_id_check;

alter table public.login_links enable row level security;
revoke all on public.login_links from public, anon, authenticated;
grant select, insert, update, delete on public.login_links to service_role;

insert into public.login_links (id, admin_path, cashier_path)
values ('commune-coffee', 'mouna1233', '')
on conflict (id) do nothing;
