-- Starter policy baseline. Run in a dedicated Supabase project only after review.
create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  created_at timestamptz not null default now()
);
create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);
create table if not exists public.sync_events (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  device_id uuid not null,
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  encrypted_payload bytea not null
);
create index if not exists sync_events_workspace_created on public.sync_events(workspace_id, created_at);
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.sync_events enable row level security;
create policy "members can read own workspaces" on public.workspaces for select using (
  exists(select 1 from public.workspace_members m where m.workspace_id = id and m.user_id = auth.uid())
);
create policy "members can read membership" on public.workspace_members for select using (user_id = auth.uid());
create policy "members can read workspace events" on public.sync_events for select using (
  exists(select 1 from public.workspace_members m where m.workspace_id = public.workspaces.id and m.user_id = auth.uid())
);
create policy "editors can append workspace events" on public.sync_events for insert with check (
  actor_id = auth.uid() and exists(
    select 1 from public.workspace_members m
    where m.workspace_id = public.sync_events.workspace_id and m.user_id = auth.uid() and m.role in ('owner', 'editor')
  )
);
