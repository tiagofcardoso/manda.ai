-- Run this in Supabase SQL Editor

-- Add address columns to establishments table
comment on table public.establishments is 'Validation: Ensure table exists before altering';

alter table public.establishments 
add column if not exists street text,
add column if not exists zip_code text,
add column if not exists city text,
add column if not exists state text,
add column if not exists country text;
