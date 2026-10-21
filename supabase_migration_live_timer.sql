-- Migration آمنة لإضافة وقت بداية المرحلة، دون حذف أو تعديل بيانات قديمة.
alter table public.matches add column if not exists phase_started_at timestamptz;
create index if not exists matches_scheduled_at_idx on public.matches (scheduled_at);
notify pgrst, 'reload schema';
