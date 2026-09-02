-- Do not derive a public-facing display name from the user's private email address.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = '' as $$
begin
  insert into public.users (id, display_name, timezone, weekly_target)
  values (
    new.id,
    'Creator',
    coalesce(nullif(new.raw_user_meta_data ->> 'timezone', ''), 'UTC'),
    coalesce((new.raw_user_meta_data ->> 'weekly_target')::integer, 3)
  );
  return new;
end;
$$;
