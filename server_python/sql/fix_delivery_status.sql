-- Update Status Constraint to include 'in_progress'
alter table public.deliveries drop constraint if exists deliveries_status_check;

alter table public.deliveries 
add constraint deliveries_status_check 
check (status in ('open', 'assigned', 'picked_up', 'in_progress', 'delivered'));
