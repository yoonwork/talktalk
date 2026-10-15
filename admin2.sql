-- 톡톡방: 방장 기기 표시 (모두에게 '방장' 배지)
create table if not exists public.admin_devices (
  client_id text primary key,
  created_at timestamptz not null default now()
);
alter table public.admin_devices enable row level security;
drop policy if exists "anyone can read admin devices" on public.admin_devices;
create policy "anyone can read admin devices" on public.admin_devices for select to anon, authenticated using (true);

create or replace function public.admin_register(p_key text, p_client_id text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  insert into public.admin_devices (client_id) values (left(p_client_id, 64)) on conflict do nothing;
  return true;
end $$;
revoke all on function public.admin_register(text, text) from public;
grant execute on function public.admin_register(text, text) to anon, authenticated;

-- 방장은 내보낼 수 없게
create or replace function public.admin_ban(p_key text, p_client_id text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  if exists (select 1 from public.admin_devices where client_id = p_client_id) then return false; end if;
  insert into public.banned (client_id) values (left(p_client_id, 64)) on conflict do nothing;
  return true;
end $$;
