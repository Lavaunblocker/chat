-- GlobeChat v1.1: replies + forwarding
-- Run ONCE in Supabase SQL Editor before using this build.

alter table public.messages_v2
add column if not exists reply_to_message_id bigint references public.messages_v2(id) on delete set null,
add column if not exists forwarded_from_message_id bigint references public.messages_v2(id) on delete set null,
add column if not exists forwarded_content text,
add column if not exists forwarded_username text,
add column if not exists forwarded_display_name text,
add column if not exists forwarded_source text,
add column if not exists forwarded_attachments jsonb not null default '[]'::jsonb;

create index if not exists msg_reply_to_idx on public.messages_v2(reply_to_message_id);

create or replace function public.forward_message(
  p_source_message_id bigint,
  p_destination_group_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path=public
as $$
declare
  src public.messages_v2%rowtype;
  new_id bigint;
  my_username text;
  src_display text;
  src_label text;
  files jsonb;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;

  select * into src from public.messages_v2 where id=p_source_message_id;
  if not found then raise exception 'Message not found'; end if;

  if not src.is_global and not exists(
    select 1 from public.group_members gm
    where gm.group_id=src.chat_id and gm.user_id=auth.uid() and gm.active=true
  ) then raise exception 'You do not have access to the source message'; end if;

  if p_destination_group_id is not null and not exists(
    select 1 from public.group_members gm
    where gm.group_id=p_destination_group_id and gm.user_id=auth.uid() and gm.active=true
  ) then raise exception 'You are not a member of the destination group'; end if;

  select username into my_username from public.profiles where id=auth.uid();
  if my_username is null then raise exception 'Profile not found'; end if;
  select coalesce(display_name,username) into src_display from public.profiles where id=src.sender_id;

  if src.is_global then src_label:='# GlobeChat';
  else select '# '||name into src_label from public.chat_groups where id=src.chat_id;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'storage_path',a.storage_path,'file_name',a.file_name,'mime_type',a.mime_type,'size_bytes',a.size_bytes
  ) order by a.created_at),'[]'::jsonb)
  into files from public.attachments a where a.message_id=src.id;

  insert into public.messages_v2(
    sender_id,username,content,chat_id,is_global,
    forwarded_from_message_id,forwarded_content,forwarded_username,
    forwarded_display_name,forwarded_source,forwarded_attachments
  ) values(
    auth.uid(),my_username,'',p_destination_group_id,p_destination_group_id is null,
    src.id,src.content,src.username,src_display,src_label,files
  ) returning id into new_id;

  return new_id;
end;
$$;

revoke all on function public.forward_message(bigint,uuid) from public;
grant execute on function public.forward_message(bigint,uuid) to authenticated;
