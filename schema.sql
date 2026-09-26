-- Arch View WhatsApp Orders — Supabase schema
-- Run once in Supabase → SQL Editor. Safe to re-run.

create extension if not exists pgcrypto;

-- 1. Profiles: one row per login. Role decides what the app shows.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  role text not null default 'staff' check (role in ('manager','staff')),
  created_at timestamptz not null default now()
);

-- Create a profile automatically when a user is added in Auth → Users.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- the first user ever created becomes the manager; everyone after starts as staff
  insert into public.profiles (id, name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          case when exists (select 1 from public.profiles where role = 'manager') then 'staff' else 'manager' end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_manager() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'manager');
$$;

-- 2. Orders
create table if not exists public.orders (
  id text primary key,
  at timestamptz not null default now(),
  day date generated always as ((at at time zone 'Asia/Riyadh')::date) stored,
  phone text not null,
  name text not null default '',
  type text not null check (type in ('Pickup','Delivery','Dine-in')),
  pay text not null,
  src text not null default 'staff' check (src in ('staff','menu')),
  status text not null default 'ok' check (status in ('ok','void')),
  total numeric(10,2) not null,
  lines jsonb not null,          -- [{id,name,price,qty}]
  by uuid not null references public.profiles(id),
  void_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists orders_day_idx on public.orders(day desc);
create index if not exists orders_phone_idx on public.orders(phone);

-- 3. Daily POS totals (Z-report), managers only
create table if not exists public.z_totals (
  day date primary key,
  total numeric(12,2) not null,
  by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

-- 4. Row-level security
alter table public.profiles enable row level security;
alter table public.orders   enable row level security;
alter table public.z_totals enable row level security;

drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles self"   on public.profiles;
drop policy if exists "profiles manage" on public.profiles;
create policy "profiles read"   on public.profiles for select to authenticated using (true);
create policy "profiles manage" on public.profiles for update to authenticated using (public.is_manager()) with check (public.is_manager());

drop policy if exists "orders read"   on public.orders;
drop policy if exists "orders insert" on public.orders;
drop policy if exists "orders void"   on public.orders;
create policy "orders read"   on public.orders for select to authenticated using (true);
create policy "orders insert" on public.orders for insert to authenticated with check (by = auth.uid() and status = 'ok');
create policy "orders void"   on public.orders for update to authenticated using (public.is_manager()) with check (public.is_manager());

drop policy if exists "z read"  on public.z_totals;
drop policy if exists "z write" on public.z_totals;
create policy "z read"  on public.z_totals for select to authenticated using (true);
create policy "z write" on public.z_totals for all to authenticated using (public.is_manager()) with check (public.is_manager());

-- 5. Live updates in the app
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.z_totals;
exception when duplicate_object then null; end $$;

-- 6. The first login you create in Authentication → Users becomes the manager automatically.
