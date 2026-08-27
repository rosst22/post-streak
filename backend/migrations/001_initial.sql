-- Run in the Supabase SQL editor. Auth remains owned by Supabase; app data is public.
create extension if not exists pgcrypto;

create type public.platform as enum ('instagram', 'tiktok', 'youtube', 'other');
create type public.post_format as enum ('post', 'reel', 'story', 'video', 'short', 'other');
create type public.friendship_status as enum ('pending', 'accepted');

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name varchar(80) not null default 'Creator',
  timezone varchar(64) not null default 'UTC',
  weekly_target integer not null default 3 check (weekly_target between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  platform public.platform not null,
  posted_at timestamptz not null default now(),
  format public.post_format not null default 'post',
  url text,
  title varchar(300),
  created_at timestamptz not null default now()
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.users(id) on delete cascade,
  addressee_id uuid not null references public.users(id) on delete cascade,
  status public.friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friendships_different_users check (requester_id <> addressee_id)
);

-- A pair can have only one relationship, regardless of who sent the request.
create unique index friendships_unique_pair_idx
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index posts_user_posted_at_idx on public.posts (user_id, posted_at desc);
create index posts_posted_at_idx on public.posts (posted_at desc);
create index friendships_requester_idx on public.friendships (requester_id, status);
create index friendships_addressee_idx on public.friendships (addressee_id, status);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_set_updated_at before update on public.users
for each row execute function public.set_updated_at();
create trigger friendships_set_updated_at before update on public.friendships
for each row execute function public.set_updated_at();

-- A profile is created atomically whenever Supabase Auth creates a user.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = '' as $$
begin
  insert into public.users (id, display_name, timezone, weekly_target)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, 'Creator'), '@', 1)),
    coalesce(nullif(new.raw_user_meta_data ->> 'timezone', ''), 'UTC'),
    coalesce((new.raw_user_meta_data ->> 'weekly_target')::integer, 3)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- FastAPI owns authorization. Deny direct Data API access to app tables.
alter table public.users enable row level security;
alter table public.posts enable row level security;
alter table public.friendships enable row level security;
revoke all on public.users, public.posts, public.friendships from anon, authenticated;

