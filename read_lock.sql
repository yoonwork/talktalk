-- 톡톡방: 읽기도 비밀번호가 있어야만
drop policy if exists "anyone can read" on public.messages;
create policy "read with password" on public.messages for select to anon, authenticated
  using (public.req_pass_ok());
-- 실시간 DB 알림은 더 이상 쓰지 않음 (비밀 통로로 대체)
do $$ begin
  alter publication supabase_realtime drop table public.messages;
exception when others then null; end $$;
