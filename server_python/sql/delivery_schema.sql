-- Run this in Supabase SQL Editor

-- 1. Create Tables
create table if not exists deliveries (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references orders(id) not null,
  driver_name text default 'João Entregador', -- Mock driver
  current_lat float,
  current_lng float,
  status text check (status in ('assigned', 'picked_up', 'delivered')) default 'assigned',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2. Enable Realtime for this table
alter publication supabase_realtime add table deliveries;

-- 3. Policy (Open for now for testing, restrict later)
alter table deliveries enable row level security;

create policy "Enable all access for all users" on "public"."deliveries"
as permissive for all
to public
using (true)
with check (true);
