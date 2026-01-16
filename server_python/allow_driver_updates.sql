-- Allow authenticated users (like drivers) to UPDATE orders
-- specifically needed so they can mark status as 'delivered'

create policy "Enable update for authenticated users on orders"
on "public"."orders"
for update
to authenticated
using (true)
with check (true);

-- Also ensure they can SELECT (likely already exists, but safe to add if missing)
create policy "Enable read for authenticated users on orders"
on "public"."orders"
for select
to authenticated
using (true);
