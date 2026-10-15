-- 톡톡방 설치 SQL: Supabase > SQL Editor에 통째로 붙여넣고 Run

-- 1) 메시지 표
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  room text not null default 'lobby' check (char_length(room) <= 40),
  client_id text not null check (char_length(client_id) <= 64),
  nick text not null check (char_length(nick) between 1 and 20),
  body text check (char_length(body) <= 2000),
  media_url text check (char_length(media_url) <= 500),
  media_type text check (media_type in ('image', 'video')),
  owner_hash text check (char_length(owner_hash) <= 64),
  check (body is not null or media_url is not null)
);
alter table public.messages add column if not exists owner_hash text;
create index if not exists messages_room_id on public.messages (room, id desc);

-- 2) 링크 받은 누구나 읽고 쓰기 (수정·삭제는 불가)
alter table public.messages enable row level security;
drop policy if exists "anyone can read" on public.messages;
drop policy if exists "anyone can write" on public.messages;
create policy "anyone can read" on public.messages for select to anon, authenticated using (true);
create policy "anyone can write" on public.messages for insert to anon, authenticated with check (true);

-- 2-1) 내가 보낸 메시지만 삭제 (기기에 저장된 비밀키로 확인)
create or replace function public.delete_message(p_id bigint, p_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  delete from public.messages
  where id = p_id
    and owner_hash is not null
    and owner_hash = encode(sha256(convert_to(p_key, 'UTF8')), 'hex');
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function public.delete_message(bigint, text) from public;
grant execute on function public.delete_message(bigint, text) to anon, authenticated;

-- 3) 실시간 전송 켜기
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;

-- 4) 사진·동영상 저장소 (파일당 50MB)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-media', 'chat-media', true, 52428800, array['image/*', 'video/*'])
on conflict (id) do update set public = true, file_size_limit = 52428800, allowed_mime_types = array['image/*', 'video/*'];

drop policy if exists "chat media upload" on storage.objects;
drop policy if exists "chat media read" on storage.objects;
create policy "chat media upload" on storage.objects for insert to anon, authenticated with check (bucket_id = 'chat-media');
create policy "chat media read" on storage.objects for select to anon, authenticated using (bucket_id = 'chat-media');
