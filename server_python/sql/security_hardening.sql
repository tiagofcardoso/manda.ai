-- =============================================================================
-- SECURITY HARDENING: ROW LEVEL SECURITY (RLS)
-- =============================================================================
-- This script enables RLS on critical tables and sets up policies for:
-- 1. Clients: Can only see their own data.
-- 2. Drivers: Can see necessary delivery data.
-- 3. Admins: Can see everything.
-- =============================================================================

-- 1. PROFILES (Users)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own profile
CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Allow users to update their own profile (optional, e.g. phone/name)
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Allow Admins to read ALL profiles (needed for dashboard/user management)
CREATE POLICY "Admins can read all profiles" ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- 2. ORDERS
-- -----------------------------------------------------------------------------
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Clients: View own orders
CREATE POLICY "Clients can view own orders" ON public.orders
  FOR SELECT
  USING (user_id = auth.uid());

-- Clients: Insert own orders (Already authenticated)
CREATE POLICY "Clients can create orders" ON public.orders
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Admins: Full Access
CREATE POLICY "Admins can do everything on orders" ON public.orders
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Drivers: View available orders (e.g. ready for pickup) or Assigned to them
-- For simplicity and functionality of KDS/Driver App, we allow drivers to view orders
-- but only where they are involved or potential candidates.
-- SIMPLIFIED STRATEGY: Drivers can view ALL orders for now to avoid breaking "Open Pool" logic.
CREATE POLICY "Drivers can view all orders" ON public.orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'driver'
    )
  );


-- 3. ORDER ITEMS
-- -----------------------------------------------------------------------------
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Inherit permissions from parent Order
-- This is a little expensive (join), but safest.
CREATE POLICY "Users can view items of visible orders" ON public.order_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id
    )
  );

-- Clients can Insert items into their own orders
CREATE POLICY "Clients can insert items" ON public.order_items
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()
    )
  );

-- Admins: Full Access
CREATE POLICY "Admins can do everything on items" ON public.order_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- 4. DELIVERIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

-- Drivers: View all 'open' deliveries OR deliveries assigned to them
CREATE POLICY "Drivers see open or assigned deliveries" ON public.deliveries
  FOR SELECT
  USING (
    (status = 'open') OR 
    (driver_id = auth.uid()) OR
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'driver'
    ) -- Taking a permissive approach for Drivers to see the pool
  );

-- Drivers: Update their own deliveries (e.g. location, status)
CREATE POLICY "Drivers update own deliveries" ON public.deliveries
  FOR UPDATE
  USING (driver_id = auth.uid());

-- Drivers: Insert? Generally created by System/Admin, but if Drivers create 'requests', add here.
-- Assuming Drivers only update.

-- Admins: Full Access
CREATE POLICY "Admins full access deliveries" ON public.deliveries
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
