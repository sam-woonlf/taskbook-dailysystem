-- 任务清单 · Supabase 一次性配置
-- 在 Supabase Dashboard → SQL Editor 中执行一次即可

create table if not exists public.taskbook_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  edited_at bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.taskbook_state enable row level security;

drop policy if exists taskbook_select on public.taskbook_state;
create policy taskbook_select on public.taskbook_state
  for select using (auth.uid() = user_id);

drop policy if exists taskbook_insert on public.taskbook_state;
create policy taskbook_insert on public.taskbook_state
  for insert with check (auth.uid() = user_id);

drop policy if exists taskbook_update on public.taskbook_state;
create policy taskbook_update on public.taskbook_state
  for update using (auth.uid() = user_id);

create or replace function public.sync_taskbook_state(p_data jsonb, p_edited_at bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  cur bigint;
begin
  select edited_at into cur from public.taskbook_state where user_id = auth.uid();
  if cur is not null and cur >= p_edited_at then
    return false;
  end if;

  insert into public.taskbook_state(user_id, data, edited_at, updated_at)
  values (auth.uid(), p_data, p_edited_at, now())
  on conflict (user_id) do update
    set data = excluded.data,
        edited_at = excluded.edited_at,
        updated_at = excluded.updated_at
  where public.taskbook_state.edited_at < excluded.edited_at;

  return true;
end;
$$;

revoke all on function public.sync_taskbook_state(jsonb, bigint) from public;
grant execute on function public.sync_taskbook_state(jsonb, bigint) to authenticated;
