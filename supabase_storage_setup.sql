-- إعداد تخزين صور الفرق واللاعبين في Supabase Storage
-- شغّل هذا الملف في Supabase Dashboard > SQL Editor بصلاحية مالك المشروع.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tournament-images',
  'tournament-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif','image/avif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','image/avif'];

-- السماح للزوار بعرض الصور العامة داخل الموقع
 drop policy if exists "Public can view tournament images" on storage.objects;
 create policy "Public can view tournament images"
 on storage.objects for select
 using (bucket_id = 'tournament-images');

-- السماح فقط للمستخدمين المسجلين كـ admin أو editor برفع الصور
 drop policy if exists "Staff can upload tournament images" on storage.objects;
 create policy "Staff can upload tournament images"
 on storage.objects for insert to authenticated
 with check (
   bucket_id = 'tournament-images'
   and exists (
     select 1 from public.profiles
     where profiles.id = auth.uid()
       and profiles.role in ('admin', 'editor')
   )
 );
