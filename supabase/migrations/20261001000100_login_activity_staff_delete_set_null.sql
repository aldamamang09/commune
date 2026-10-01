begin;

alter table public.login_activity
  alter column user_id drop not null;

alter table public.login_activity
  drop constraint if exists login_activity_user_id_fkey;

alter table public.login_activity
  add constraint login_activity_user_id_fkey
  foreign key (user_id)
  references public.staff_users(id)
  on delete set null;

commit;