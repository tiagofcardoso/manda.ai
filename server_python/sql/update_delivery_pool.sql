-- 1. Add driver_id column
alter table public.deliveries 
add column if not exists driver_id uuid references auth.users(id);

-- 2. Update Status Constraint to include 'open'
-- We have to drop the old check constraint first. 
-- Note: The name might vary, usually 'deliveries_status_check'.
alter table public.deliveries drop constraint if exists deliveries_status_check;

alter table public.deliveries 
add constraint deliveries_status_check 
check (status in ('open', 'assigned', 'picked_up', 'delivered'));

-- 3. Policy: Allow drivers (authenticated) to update 'driver_id' if it is null
-- (For simplicity, we are keeping the broad 'permissive' policy from before, 
-- but in production we'd want specific policies)
