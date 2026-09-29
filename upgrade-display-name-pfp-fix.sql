-- GlobeChat v1.1 display-name + profile-picture repair
-- Run once in Supabase SQL Editor.

alter table public.profiles
add column if not exists display_name text;

update public.profiles
set display_name = username
where display_name is null or char_length(trim(display_name)) = 0;

alter table public.profiles
drop constraint if exists profiles_display_name_length;

alter table public.profiles
add constraint profiles_display_name_length
check (char_length(trim(display_name)) between 1 and 40);

create or replace function public.change_display_name(p_display_name text)
returns text
language plpgsql
security definer
set search_path=public
as $$
declare d text:=trim(p_display_name);
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if char_length(d) not between 1 and 40 then
    raise exception 'Display name must be 1-40 characters';
  end if;
  update public.profiles set display_name=d where id=auth.uid();
  if not found then raise exception 'Profile not found'; end if;
  return d;
end;
$$;

grant execute on function public.change_display_name(text) to authenticated;

-- Profile pictures are public profile data, but only the owning UUID may write/delete.
update storage.buckets
set public=true,
    file_size_limit=5242880,
    allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']
where id='profile-pictures';

drop policy if exists "profile pictures read" on storage.objects;
create policy "profile pictures read"
on storage.objects for select
to public
using(bucket_id='profile-pictures');

drop policy if exists "profile pictures insert own" on storage.objects;
create policy "profile pictures insert own"
on storage.objects for insert
to authenticated
with check(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "profile pictures update own" on storage.objects;
create policy "profile pictures update own"
on storage.objects for update
to authenticated
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
on storage.objects for delete
to authenticated
using(
  bucket_id='profile-pictures'
  and (storage.foldername(name))[1]=auth.uid()::text
);
