-- Run this in Supabase SQL Editor

-- 1. Backfill Missing Profiles (for users created before the trigger was fixed)
insert into public.profiles (id, full_name, role, phone_number, street, zip_code, city, state, country)
select 
  id,
  raw_user_meta_data->>'full_name',
  coalesce(raw_user_meta_data->>'role', 'client'),
  raw_user_meta_data->>'phone',
  raw_user_meta_data->'address'->>'street',
  raw_user_meta_data->'address'->>'zip_code',
  raw_user_meta_data->'address'->>'city',
  raw_user_meta_data->'address'->>'state',
  raw_user_meta_data->'address'->>'country'
from auth.users
on conflict (id) do update set
  street = excluded.street,
  zip_code = excluded.zip_code,
  city = excluded.city,
  country = excluded.country;

-- 2. Ensure RLS is permissive for drivers to read client info
alter table public.profiles enable row level security;

-- Drop limiting policies if they exist/conflict
drop policy if exists "Users can read own profile" on public.profiles;

-- Create a broad read policy
create policy "Allow all authenticated to read profiles"
on public.profiles for select
to authenticated
using (true);
