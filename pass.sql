-- 톡톡방: 대화방 비밀번호
create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  pass_hash text
);
alter table public.app_settings enable row level security;  -- 아무도 직접 못 읽음

create or replace function public.check_pass(p text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select pass_hash is null or pass_hash = encode(sha256(convert_to(coalesce(p, ''), 'UTF8')), 'hex')
                   from public.app_settings where id = 1), true);
$$;
revoke all on function public.check_pass(text) from public;
grant execute on function public.check_pass(text) to anon, authenticated;

create or replace function public.req_pass_ok()
returns boolean language sql stable security definer set search_path = public as $$
  select public.check_pass(coalesce(nullif(current_setting('request.headers', true), '')::json ->> 'x-room-pass', ''));
$$;
grant execute on function public.req_pass_ok() to anon, authenticated;

-- 비밀번호를 모르면 글을 못 씀 (내보낸 기기도 못 씀)
drop policy if exists "anyone can write" on public.messages;
create policy "anyone can write" on public.messages for insert to anon, authenticated
  with check (
    not exists (select 1 from public.banned b where b.client_id = messages.client_id)
    and public.req_pass_ok()
  );
