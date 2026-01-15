-- Allow Drivers/Authenticated users to read all profiles (needed for delivery address)
-- Run this in Supabase SQL Editor

-- Drop restrictive policy if conflicts (optional, safe to just add new one)
-- drop policy if exists "Users can read own profile" on public.profiles;

-- Create/Replace policy to allow reading any profile if you are logged in
create policy "Allow read access for authenticated users"
on public.profiles
for select
to authenticated
using (true);

-- Ensure RLS is enabled (should be already)
alter table public.profiles enable row level security;
