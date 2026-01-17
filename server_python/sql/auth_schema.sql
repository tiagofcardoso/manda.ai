-- Run this in Supabase SQL Editor

-- 1. Create Profiles Table (Extension of auth.users)
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  full_name text,
  role text check (role in ('admin', 'driver', 'client')) default 'client',
  phone_number text,
  vehicle_info text, -- Only for drivers
  updated_at timestamp with time zone default now()
);

-- 2. Toggle RLS
alter table public.profiles enable row level security;

-- 3. Create Policy: Everyone can read their own profile
create policy "Users can read own profile"
  on public.profiles for select
  using ( auth.uid() = id );

-- 4. Create Policy: Users can update their own profile
create policy "Users can update own profile"
  on public.profiles for update
  using ( auth.uid() = id );
  
-- 5. Create Policy: Public Read (Optional, for sharing driver info)
create policy "Public Read Profiles"
  on public.profiles for select
  using ( true );

-- 6. Trigger to auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    coalesce(new.raw_user_meta_data->>'role', 'client')
  );
  return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists to avoid duplication error on re-run
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
