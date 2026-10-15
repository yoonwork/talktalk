-- 톡톡방: 방장이 방 대화를 한 번에 지우기
create or replace function public.admin_clear_room(p_key text, p_room text)
returns integer language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.is_admin(p_key) then return -1; end if;
  delete from public.messages where room = p_room;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.admin_clear_room(text, text) from public;
grant execute on function public.admin_clear_room(text, text) to anon, authenticated;
