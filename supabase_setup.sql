-- Supabase setup for دوري كتاب السيدة فاطمة
-- Run in Supabase Dashboard > SQL Editor.
-- Public visitors can read tournament data. Only authenticated admin/editor profiles can write.

create extension if not exists pgcrypto;

create table if not exists public.groups (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now()
);

-- Default groups used by the admin form; safe to run repeatedly.
insert into public.groups (id, name) values ('A', 'المجموعة A'), ('B', 'المجموعة B')
on conflict (id) do nothing;
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  short_name text,
  logo_url text,
  group_id text references public.groups(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  full_name text not null,
  shirt_number integer,
  photo_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(team_id, shirt_number)
);
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  home_team_id uuid not null references public.teams(id),
  away_team_id uuid not null references public.teams(id),
  group_id text references public.groups(id) on delete set null,
  stage text not null default 'groups' check (stage in ('groups','semifinal','final')),
  scheduled_at timestamptz,
  venue text,
  status text not null default 'upcoming' check (status in ('upcoming','live','finished','postponed','cancelled')),
  home_score integer not null default 0 check (home_score >= 0),
  away_score integer not null default 0 check (away_score >= 0),
  current_minute integer check (current_minute between 0 and 150),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint different_teams check (home_team_id <> away_team_id)
);
create table if not exists public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  team_id uuid not null references public.teams(id),
  player_id uuid references public.players(id) on delete set null,
  player_name text,
  event_type text not null check (event_type in ('goal','yellow','red')),
  minute integer check (minute between 0 and 150),
  added_time integer check (added_time between 0 and 30),
  description text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'عضو اللجنة',
  role text not null default 'viewer' check (role in ('admin','editor','viewer')),
  created_at timestamptz not null default now()
);
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  published boolean not null default false,
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Create a viewer profile automatically for every new Auth account.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', 'عضو اللجنة'), 'viewer')
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Helper avoids recursive RLS when checking the caller's role.
create or replace function public.has_tournament_role(allowed_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = any(allowed_roles)
  );
$$;
revoke all on function public.has_tournament_role(text[]) from public;
grant execute on function public.has_tournament_role(text[]) to anon, authenticated;

create index if not exists matches_scheduled_at_idx on public.matches(scheduled_at);
create index if not exists matches_status_idx on public.matches(status);
create index if not exists events_match_id_idx on public.match_events(match_id);
create index if not exists events_type_idx on public.match_events(event_type);
create index if not exists players_team_id_idx on public.players(team_id);

alter table public.groups enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_events enable row level security;
alter table public.profiles enable row level security;
alter table public.announcements enable row level security;

do $$ declare t text; begin
  foreach t in array array['groups','teams','players','matches','match_events'] loop
    execute format('drop policy if exists "Public read %s" on public.%I', t, t);
    execute format('create policy "Public read %s" on public.%I for select to anon, authenticated using (true)', t, t);
    execute format('drop policy if exists "Staff insert %s" on public.%I', t, t);
    execute format('create policy "Staff insert %s" on public.%I for insert to authenticated with check (public.has_tournament_role(array[''admin'',''editor'']))', t, t);
    execute format('drop policy if exists "Staff update %s" on public.%I', t, t);
    execute format('create policy "Staff update %s" on public.%I for update to authenticated using (public.has_tournament_role(array[''admin'',''editor''])) with check (public.has_tournament_role(array[''admin'',''editor'']))', t, t);
    execute format('drop policy if exists "Admin delete %s" on public.%I', t, t);
    execute format('create policy "Admin delete %s" on public.%I for delete to authenticated using (public.has_tournament_role(array[''admin'']))', t, t);
  end loop;
end $$;

drop policy if exists "Users read own profile" on public.profiles;
drop policy if exists "Admin update profiles" on public.profiles;
drop policy if exists "Public read published announcements" on public.announcements;
drop policy if exists "Staff create announcements" on public.announcements;
drop policy if exists "Staff update announcements" on public.announcements;
drop policy if exists "Admin delete announcements" on public.announcements;

create policy "Users read own profile" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.has_tournament_role(array['admin']));
create policy "Admin update profiles" on public.profiles for update to authenticated using (public.has_tournament_role(array['admin'])) with check (public.has_tournament_role(array['admin']));
create policy "Public read published announcements" on public.announcements for select to anon, authenticated using (published = true or public.has_tournament_role(array['admin','editor']));
create policy "Staff create announcements" on public.announcements for insert to authenticated with check (public.has_tournament_role(array['admin','editor']));
create policy "Staff update announcements" on public.announcements for update to authenticated using (public.has_tournament_role(array['admin','editor'])) with check (public.has_tournament_role(array['admin','editor']));
create policy "Admin delete announcements" on public.announcements for delete to authenticated using (public.has_tournament_role(array['admin']));

-- Enable Realtime for score and event changes.
do $$ begin
  alter publication supabase_realtime add table public.matches;
exception when duplicate_object then null; when undefined_object then raise notice 'Publication supabase_realtime not found; enable Realtime from Dashboard.';
end $$;
do $$ begin
  alter publication supabase_realtime add table public.match_events;
exception when duplicate_object then null; when undefined_object then raise notice 'Publication supabase_realtime not found; enable Realtime from Dashboard.';
end $$;

-- IMPORTANT: after creating your first user in Authentication > Users,
-- replace EMAIL_HERE with the organizer's email and run this one-time statement:
-- update public.profiles p set role = 'admin'
-- from auth.users u where p.id = u.id and u.email = 'EMAIL_HERE';
-- Never put the service_role key in frontend code.
