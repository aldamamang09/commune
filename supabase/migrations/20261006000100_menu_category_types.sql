alter table public.menu_categories
  add column if not exists type text;

update public.menu_categories
set type = case
  when lower(name) ~ '(food|meal|snack)' then 'food'
  when lower(name) ~ '(pastr|cake|bread|dessert)' then 'pastry'
  when lower(name) ~ '(drink|coffee|matcha|tea|juice|smoothie|beverage|fresh)' then 'drink'
  else 'other'
end
where type is null;

notify pgrst, 'reload schema';
