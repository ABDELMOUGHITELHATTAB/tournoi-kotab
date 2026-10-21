-- مخطط أولي لقاعدة بيانات دوري كتاب السيدة فاطمة
-- شغّل هذا الملف في Supabase SQL Editor بعد إنشاء مشروع جديد.
-- راجع سياسات RLS واختبرها قبل نشر الموقع رسمياً.

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
  stage text not null default 'groups'
    check (stage in ('groups','semifinal','final')),
  scheduled_at timestamptz,
  venue text,
  status text not null default 'upcoming'
    check (status in ('upcoming','live','finished','postponed','cancelled')),
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
  display_name text not null,
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

create index if not exists matches_scheduled_at_idx on public.matches(scheduled_at);
create index if not exists matches_status_idx on public.matches(status);
create index if not exists events_match_id_idx on public.match_events(match_id);
create index if not exists events_type_idx on public.match_events(event_type);
create index if not exists players_team_id_idx on public.players(team_id);

-- تفعيل RLS على كل الجداول.
alter table public.groups enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_events enable row level security;
alter table public.profiles enable row level security;
alter table public.announcements enable row level security;

-- قراءة عامة للمعلومات المنشورة/الرياضية.
create policy "Public can read groups" on public.groups for select using (true);
create policy "Public can read teams" on public.teams for select using (true);
create policy "Public can read players" on public.players for select using (true);
create policy "Public can read matches" on public.matches for select using (true);
create policy "Public can read match events" on public.match_events for select using (true);
create policy "Public can read published announcements" on public.announcements for select using (published = true);

-- لا توجد سياسات كتابة عامة هنا عن قصد.
-- قبل النشر، أضف سياسات كتابة مرتبطة بـ profiles.role بعد اختبارها،
-- ولا تضع service_role key داخل أي كود يعمل في المتصفح.

-- Realtime: من لوحة Supabase > Database > Replication، فعّل بث updates
-- للجداول matches و match_events عند ربط الواجهة.
