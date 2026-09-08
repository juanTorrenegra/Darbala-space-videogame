-- Darbala / juanhooter_camera
-- Paste this in Supabase → SQL Editor → Run
-- After running:
--   Authentication → Providers → Email
--   turn OFF "Confirm email" so NOMBRE + CONTRASEÑA works without a mailbox.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint display_name_len check (char_length(display_name) between 2 and 24)
);

create table if not exists public.leaderboard_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  display_name text not null,
  score integer not null check (score >= 0),
  created_at timestamptz not null default now()
);

create index if not exists leaderboard_scores_score_idx
  on public.leaderboard_scores (score desc, created_at asc);

create index if not exists leaderboard_scores_user_idx
  on public.leaderboard_scores (user_id);

-- Best score per pilot (what Ranking reads)
create or replace view public.leaderboard_best as
select distinct on (user_id)
  id,
  user_id,
  display_name,
  score,
  created_at
from public.leaderboard_scores
order by user_id, score desc, created_at asc;

alter table public.profiles enable row level security;
alter table public.leaderboard_scores enable row level security;

drop policy if exists profiles_select_all on public.profiles;
create policy profiles_select_all
  on public.profiles for select
  using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own
  on public.profiles for delete
  using (auth.uid() = id);

drop policy if exists scores_select_all on public.leaderboard_scores;
create policy scores_select_all
  on public.leaderboard_scores for select
  using (true);

drop policy if exists scores_insert_own on public.leaderboard_scores;
create policy scores_insert_own
  on public.leaderboard_scores for insert
  with check (auth.uid() = user_id);

drop policy if exists scores_delete_own on public.leaderboard_scores;
create policy scores_delete_own
  on public.leaderboard_scores for delete
  using (auth.uid() = user_id);

-- Auto-create a profile when Auth creates a user
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'PILOTO')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Player can delete their own Auth user (cascades to profile + scores)
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
grant select on public.leaderboard_best to anon, authenticated;
