-- دوري كتاب السيدة فاطمة: تحديث قاعدة البيانات للنسخة المطورة
-- شغّل هذا الملف مرة واحدة من Supabase Dashboard > SQL Editor.

-- حقول الهوية البصرية للفرق موجودة في بعض النسخ القديمة؛ أضفها إذا كانت ناقصة.
alter table public.teams add column if not exists logo_url text;
alter table public.teams add column if not exists short_name text;

-- تأكيد حقول اللاعبين المستخدمة في صفحة الفريق ولوحة التسجيل.
alter table public.players add column if not exists shirt_number integer;
alter table public.players add column if not exists photo_url text;
alter table public.players add column if not exists active boolean not null default true;

-- أنواع الأحداث الجديدة، وربط الحدث باللاعب وصاحب الأسيست.
alter table public.match_events add column if not exists player_id uuid references public.players(id) on delete set null;
alter table public.match_events add column if not exists player_name text;
alter table public.match_events add column if not exists added_time integer;
alter table public.match_events add column if not exists description text;
alter table public.match_events add column if not exists goal_method text;
alter table public.match_events add column if not exists assist_player_id uuid references public.players(id) on delete set null;
alter table public.match_events add column if not exists assist_player_name text;

alter table public.match_events drop constraint if exists match_events_event_type_check;
alter table public.match_events add constraint match_events_event_type_check
  check (event_type in ('goal','own_goal','yellow','red','second_yellow','injury'));
alter table public.match_events drop constraint if exists match_events_goal_method_check;
alter table public.match_events add constraint match_events_goal_method_check
  check (goal_method is null or goal_method in ('normal','penalty','free_kick'));
alter table public.match_events drop constraint if exists match_events_minute_check;
alter table public.match_events add constraint match_events_minute_check
  check (minute is null or minute between 0 and 45);
alter table public.match_events drop constraint if exists match_events_added_time_check;
alter table public.match_events add constraint match_events_added_time_check
  check (added_time is null or added_time between 0 and 15);

-- تضمن أن بيانات الفريق واللاعب يمكن قراءتها علناً، بينما الكتابة تبقى حسب سياسات اللجنة المنظمة.
-- لا نفتح صلاحيات كتابة عامة ولا نضع service_role key في ملفات الواجهة.
create index if not exists match_events_player_id_idx on public.match_events(player_id);
create index if not exists match_events_assist_player_id_idx on public.match_events(assist_player_id);
