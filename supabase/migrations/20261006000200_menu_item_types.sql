alter table public.menu_items
  add column if not exists types jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
