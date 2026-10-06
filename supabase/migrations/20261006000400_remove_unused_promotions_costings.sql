drop function if exists public.save_costing(text, text, jsonb);

drop table if exists public.costing_ingredients;
drop table if exists public.costings;
drop table if exists public.promotions;

notify pgrst, 'reload schema';
