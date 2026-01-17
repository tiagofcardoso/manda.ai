-- Run this in Supabase SQL Editor

-- 1. Add individual address columns to profiles
alter table public.profiles 
add column if not exists street text,
add column if not exists zip_code text,
add column if not exists city text,
add column if not exists state text,
add column if not exists country text;

-- Optional: Drop the JSONB address column if you added it previously
-- alter table public.profiles drop column if exists address;

-- 2. Update the handle_new_user function to sync individual fields
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (
    id, 
    full_name, 
    role, 
    phone_number,
    street,
    zip_code,
    city,
    state,
    country
  )
  values (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    coalesce(new.raw_user_meta_data->>'role', 'client'),
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->'address'->>'street',
    new.raw_user_meta_data->'address'->>'zip_code',
    new.raw_user_meta_data->'address'->>'city',
    new.raw_user_meta_data->'address'->>'state',
    new.raw_user_meta_data->'address'->>'country'
  );
  return new;
end;
$$ language plpgsql security definer;
