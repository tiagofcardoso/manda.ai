-- Run this in Supabase SQL Editor

-- Add currency column to products table
alter table public.products 
add column if not exists currency text default '€';
