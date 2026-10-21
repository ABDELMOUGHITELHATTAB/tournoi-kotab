-- تشغيل مرة واحدة في Supabase SQL Editor لإضافة صفة قائد الفريق
alter table public.players add column if not exists is_captain boolean not null default false;
