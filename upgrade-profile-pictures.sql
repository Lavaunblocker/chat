-- GlobeChat v1.1 profile picture upgrade
-- Run once in Supabase SQL Editor.

alter table public.profiles
add column if not exists avatar_path text;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'profile-pictures',
  'profile-pictures',
  false,
  5242880,
  array['image/png','image/jpeg','image/webp','image/gif']
)
on conflict(id) do update set
  public=false,
  file_size_limit=5242880,
  allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif'];

drop policy if exists "profile pictures read" on storage.objects;
create policy "profile pictures read"
on storage.objects for select to authenticated
using(bucket_id='profile-pictures');

drop policy if exists "profile pictures insert own" on storage.objects;
create policy "profile pictures insert own"
on storage.objects for insert to authenticated
with check(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "profile pictures update own" on storage.objects;
create policy "profile pictures update own"
on storage.objects for update to authenticated
using(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
)
with check(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "profile pictures delete own" on storage.objects;
create policy "profile pictures delete own"
on storage.objects for delete to authenticated
using(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
);
