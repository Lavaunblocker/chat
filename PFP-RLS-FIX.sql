-- GlobeChat v1.1 - profile picture RLS repair
-- Run this ONCE in Supabase SQL Editor.
--
-- Why this is needed:
-- Storage upload already succeeds, but the browser's direct UPDATE of
-- public.profiles.avatar_path can be filtered by the profiles RLS policy.
-- This RPC updates ONLY the currently authenticated user's profile.

create or replace function public.set_avatar_path(p_avatar_path text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if p_avatar_path is not null then
    if p_avatar_path !~ ('^' || auth.uid()::text || '/avatar-[0-9]+\.(png|jpg|webp|gif)$') then
      raise exception 'Invalid profile picture path';
    end if;
  end if;

  update public.profiles
  set avatar_path = p_avatar_path
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;

  return p_avatar_path;
end;
$$;

revoke all on function public.set_avatar_path(text) from public;
grant execute on function public.set_avatar_path(text) to authenticated;
