-- Allow anyone to read orders (needed for Drivers to see order details)
alter table public.orders enable row level security;

create policy "Allow read access for all"
on public.orders
for select
to public
using (true);

-- Ensure Deliveries is also open (just in case)
alter table public.deliveries enable row level security;

create policy "Allow all access for deliveries"
on public.deliveries
for all
to public
using (true)
with check (true);
