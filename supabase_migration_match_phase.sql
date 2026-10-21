-- تحديث آمن لإضافة حالة الشوط/مرحلة المباراة.
-- شغّله مرة واحدة في Supabase SQL Editor.
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS match_phase text NOT NULL DEFAULT 'upcoming';
ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_match_phase_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_match_phase_check CHECK (match_phase IN ('upcoming','first_half','half_time','second_half','finished','extra_time','penalties'));
NOTIFY pgrst, 'reload schema';
