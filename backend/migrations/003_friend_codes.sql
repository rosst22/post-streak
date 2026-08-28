-- Friend codes let users connect without exposing email addresses or internal UUIDs.
alter table public.users
  add column friend_code varchar(12);

update public.users
set friend_code = lower(encode(gen_random_bytes(6), 'hex'))
where friend_code is null;

alter table public.users
  alter column friend_code set default lower(encode(gen_random_bytes(6), 'hex')),
  alter column friend_code set not null;

create unique index users_friend_code_idx on public.users (friend_code);
