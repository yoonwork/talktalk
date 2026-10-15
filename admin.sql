-- 톡톡방 방장 기능: 아무 메시지 삭제, 사람 내보내기

-- 방장 열쇠(해시만 저장, 아무도 읽을 수 없음)
create table if not exists public.app_admin (
  id int primary key default 1 check (id = 1),
  key_hash text not null
);
alter table public.app_admin enable row level security;

-- 내보낸 기기 목록 (누구나 읽기만 가능, 쓰기는 방장 함수로만)
create table if not exists public.banned (
  client_id text primary key,
  created_at timestamptz not null default now()
);
alter table public.banned enable row level security;
drop policy if exists "anyone can read banned" on public.banned;
create policy "anyone can read banned" on public.banned for select to anon, authenticated using (true);

create or replace function public.is_admin(p_key text)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from public.app_admin where key_hash = encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex'));
$$;

create or replace function public.admin_delete_message(p_key text, p_id bigint)
returns boolean language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.is_admin(p_key) then return false; end if;
  delete from public.messages where id = p_id;
  get diagnostics n = row_count;
  return n > 0;
end $$;

create or replace function public.admin_ban(p_key text, p_client_id text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  insert into public.banned (client_id) values (left(p_client_id, 64)) on conflict do nothing;
  return true;
end $$;

create or replace function public.admin_unban(p_key text, p_client_id text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  delete from public.banned where client_id = p_client_id;
  return true;
end $$;

revoke all on function public.is_admin(text) from public;
revoke all on function public.admin_delete_message(text, bigint) from public;
revoke all on function public.admin_ban(text, text) from public;
revoke all on function public.admin_unban(text, text) from public;
grant execute on function public.is_admin(text) to anon, authenticated;
grant execute on function public.admin_delete_message(text, bigint) to anon, authenticated;
grant execute on function public.admin_ban(text, text) to anon, authenticated;
grant execute on function public.admin_unban(text, text) to anon, authenticated;

-- 내보낸 기기는 글을 못 쓰게
drop policy if exists "anyone can write" on public.messages;
create policy "anyone can write" on public.messages for insert to anon, authenticated
  with check (not exists (select 1 from public.banned b where b.client_id = messages.client_id));
