-- Allow Kitchen and Manager roles to view all orders
-- This is necessary for KDS and Admin Dashboard (if logged in as manager) to see incoming orders in Realtime

-- 1. ORDERS
-- Drop existing policy if it exists to avoid errors on rerun
DROP POLICY IF EXISTS "Kitchen and Managers can view all orders" ON public.orders;

CREATE POLICY "Kitchen and Managers can view all orders" ON public.orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role IN ('kitchen', 'manager')
    )
  );

-- 3. ENSURE REALTIME
-- Just in case it wasn't run
do $$
begin
  -- Check and add table 'orders' to publication
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'orders') then
    alter publication supabase_realtime add table orders;
  end if;

  -- Check and add table 'order_items' to publication
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'order_items') then
    alter publication supabase_realtime add table order_items;
  end if;
end $$;
