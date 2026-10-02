-- Cashier login paths are no longer configurable; keep only the admin path.
alter table public.login_links
  drop column if exists cashier_path;
