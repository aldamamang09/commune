alter table public.pos_state
  add column if not exists inventory_features_enabled boolean not null default true;
