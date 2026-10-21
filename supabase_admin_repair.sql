-- إصلاح توافق قاعدة البيانات مع لوحة إدارة دوري كتاب السيدة فاطمة
-- آمن للتشغيل أكثر من مرة؛ لا يحذف بيانات اللاعبين أو الفرق أو المباريات.

ALTER TABLE public.players
  ADD COLUMN IF NOT EXISTS is_captain boolean NOT NULL DEFAULT false;

ALTER TABLE public.match_events
  ADD COLUMN IF NOT EXISTS assist_player_id text,
  ADD COLUMN IF NOT EXISTS assist_player_name text,
  ADD COLUMN IF NOT EXISTS goal_method text;

-- السماح بأنواع الأحداث التي تستخدمها صفحة الإدارة.
ALTER TABLE public.match_events
  DROP CONSTRAINT IF EXISTS match_events_event_type_check;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.match_events'::regclass
      AND conname = 'match_events_event_type_check'
  ) THEN
    ALTER TABLE public.match_events
      ADD CONSTRAINT match_events_event_type_check
      CHECK (event_type IN ('goal','own_goal','yellow','red','second_yellow','injury'));
  END IF;
END $$;

-- تحديث PostgREST schema cache بعد إضافة الأعمدة.
NOTIFY pgrst, 'reload schema';
