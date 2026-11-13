-- Field Management data layer: real user-owned fields backing the
-- My Fields screen and the foundation for weather, irrigation,
-- satellite, and AI features.

create extension if not exists pgcrypto;

create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  crop_type text not null,
  area_acres numeric not null default 0 check (area_acres >= 0),
  location_name text,
  latitude double precision,
  longitude double precision,
  health_score numeric not null default 0 check (health_score >= 0 and health_score <= 100),
  moisture numeric not null default 0 check (moisture >= 0 and moisture <= 100),
  risk_level text not null default 'low' check (risk_level in ('low', 'medium', 'high')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fields_user_id_idx on public.fields(user_id);

alter table public.fields enable row level security;

grant select, insert, update, delete on table public.fields to authenticated;

drop policy if exists "Users can read their own fields" on public.fields;
create policy "Users can read their own fields"
  on public.fields
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own fields" on public.fields;
create policy "Users can insert their own fields"
  on public.fields
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own fields" on public.fields;
create policy "Users can update their own fields"
  on public.fields
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own fields" on public.fields;
create policy "Users can delete their own fields"
  on public.fields
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Keep updated_at current on every row update.
create or replace function public.set_fields_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_fields_updated_at on public.fields;
create trigger set_fields_updated_at
  before update on public.fields
  for each row
  execute function public.set_fields_updated_at();
