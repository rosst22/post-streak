create type public.report_reason as enum (
  'spam', 'harassment', 'hate_speech', 'sexual_content', 'violence', 'other'
);

create table public.blocked_users (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_different_users check (blocker_id <> blocked_id)
);

create table public.post_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  reason public.report_reason not null,
  details varchar(500),
  status varchar(20) not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  unique (reporter_id, post_id)
);

create index blocked_users_blocked_idx on public.blocked_users (blocked_id);
create index post_reports_status_created_idx on public.post_reports (status, created_at);

alter table public.blocked_users enable row level security;
alter table public.post_reports enable row level security;
revoke all on public.blocked_users, public.post_reports from anon, authenticated;
