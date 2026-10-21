-- شغّل هاد الملف مرة واحدة في Supabase SQL Editor لتخزين نتيجة ضربات الجزاء
alter table public.matches
  add column if not exists penalty_home_score integer,
  add column if not exists penalty_away_score integer;
