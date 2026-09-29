-- GlobeChat v2.3.5: fix private-group passcode hashing on Supabase
-- Run this ONCE in the Supabase SQL Editor.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.create_private_group(p_name text, p_passcode text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if char_length(trim(p_name)) < 1 or char_length(trim(p_name)) > 40 then
    raise exception 'Group name must be 1-40 characters';
  end if;

  if p_passcode !~ '^[0-9]{6}$' then
    raise exception 'Passcode must be exactly 6 digits';
  end if;

  insert into public.chat_groups(name, owner_id, passcode_hash)
  values (
    trim(p_name),
    auth.uid(),
    extensions.crypt(p_passcode, extensions.gen_salt('bf'))
  )
  returning id into gid;

  insert into public.group_members(group_id, user_id, active)
  values (gid, auth.uid(), true)
  on conflict (group_id, user_id)
  do update set active = true, joined_at = now();

  return gid;
end;
$$;

grant execute on function public.create_private_group(text,text) to authenticated;

-- Also make the join function resolve crypt() reliably.
create or replace function public.join_private_group(p_group_id uuid,p_passcode text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare h text;
declare a public.group_access_attempts%rowtype;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;

  if exists (
    select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid() and active=true
  ) then
    return true;
  end if;

  select passcode_hash into h
  from public.chat_groups
  where id=p_group_id;

  if h is null then raise exception 'Group not found'; end if;

  insert into public.group_access_attempts(group_id,user_id)
  values(p_group_id,auth.uid())
  on conflict do nothing;

  select * into a
  from public.group_access_attempts
  where group_id=p_group_id and user_id=auth.uid()
  for update;

  if a.window_started_at < now()-interval '24 hours' then
    update public.group_access_attempts
    set attempts=0,window_started_at=now()
    where group_id=p_group_id and user_id=auth.uid();
    a.attempts:=0;
  end if;

  if a.attempts>=5 then
    raise exception 'Five attempts used. Try again after the 24-hour window resets.';
  end if;

  if extensions.crypt(p_passcode,h)<>h then
    update public.group_access_attempts
    set attempts=attempts+1
    where group_id=p_group_id and user_id=auth.uid();
    raise exception 'Incorrect passcode';
  end if;

  insert into public.group_members(group_id,user_id,active)
  values(p_group_id,auth.uid(),true)
  on conflict(group_id,user_id)
  do update set active=true,joined_at=now();

  return true;
end;
$$;

grant execute on function public.join_private_group(uuid,text) to authenticated;
