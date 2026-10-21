-- تشكيلة الفريق: 5 لاعبين ميدانيين فقط، بلا حارس. يحافظ على جدول التشكيلات الموجود.
create table if not exists public.team_lineups (
 id uuid primary key default gen_random_uuid(),
 team_id uuid not null references public.teams(id) on delete cascade,
 player_id uuid not null references public.players(id) on delete cascade,
 position text not null,
 slot integer not null check (slot between 0 and 4),
 formation text not null default '2-2-1',
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(team_id, player_id), unique(team_id, slot)
);
-- ترحيل آمن من التصميم القديم (حارس + 5): يحذف فقط خانة الحارس من التشكيلات المحفوظة ثم يعيد ترقيم الخمسة الباقين.
alter table public.team_lineups drop constraint if exists team_lineups_slot_check;
alter table public.team_lineups drop constraint if exists team_lineups_position_check;
delete from public.team_lineups where slot = 0 and position = 'GK';
update public.team_lineups set slot = slot - 1 where slot between 1 and 5;
alter table public.team_lineups add constraint team_lineups_slot_check check (slot between 0 and 4);
update public.team_lineups set position = 'FIELD' where position = 'GK';
create index if not exists team_lineups_team_idx on public.team_lineups(team_id);
alter table public.team_lineups enable row level security;
drop policy if exists "Public can read team lineups" on public.team_lineups;
create policy "Public can read team lineups" on public.team_lineups for select using (true);
drop policy if exists "Staff insert team lineups" on public.team_lineups;
create policy "Staff insert team lineups" on public.team_lineups for insert to authenticated with check (public.has_tournament_role(array['admin','editor']));
drop policy if exists "Staff update team lineups" on public.team_lineups;
create policy "Staff update team lineups" on public.team_lineups for update to authenticated using (public.has_tournament_role(array['admin','editor'])) with check (public.has_tournament_role(array['admin','editor']));
drop policy if exists "Staff delete team lineups" on public.team_lineups;
create policy "Staff delete team lineups" on public.team_lineups for delete to authenticated using (public.has_tournament_role(array['admin','editor']));
