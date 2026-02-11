-- =============================================================================
-- ENABLE RLS PROPERLY - CLEAN AND SAFE
-- =============================================================================
-- This script re-enables RLS with clean policies that DON'T cause recursion
-- =============================================================================

-- ============================================================================
-- STEP 1: Create SECURITY DEFINER functions (bypass RLS safely)
-- ============================================================================

-- Function to get current user's role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN (
    SELECT role 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$;

-- Function to get current user's establishment_id
CREATE OR REPLACE FUNCTION public.get_my_establishment()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN (
    SELECT establishment_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_establishment() TO authenticated;

-- ============================================================================
-- STEP 2: PROFILES - Simple, non-recursive policies
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users read their own profile
CREATE POLICY "profiles_read_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- STEP 3: ESTABLISHMENTS - Public read, super admin full access
-- ============================================================================

ALTER TABLE public.establishments ENABLE ROW LEVEL SECURITY;

-- Anyone can view establishments (needed for marketplace)
CREATE POLICY "establishments_read_public"
  ON public.establishments
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Super admins can do everything
CREATE POLICY "establishments_super_admin_all"
  ON public.establishments
  FOR ALL
  TO authenticated
  USING (public.get_my_role() = 'super_admin');

-- ============================================================================
-- STEP 4: PRODUCTS - Public read, admin manage own establishment
-- ============================================================================

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Anyone can view products
CREATE POLICY "products_read_public"
  ON public.products
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins/super_admins manage products
CREATE POLICY "products_admin_all"
  ON public.products
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ============================================================================
-- STEP 5: CATEGORIES - Public read, admin manage own establishment
-- ============================================================================

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Anyone can view categories
CREATE POLICY "categories_read_public"
  ON public.categories
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins manage categories
CREATE POLICY "categories_admin_all"
  ON public.categories
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ============================================================================
-- STEP 6: TABLES - Public read, admin manage own establishment
-- ============================================================================

ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

-- Anyone can view tables (validate QR codes)
CREATE POLICY "tables_read_public"
  ON public.tables
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins manage tables
CREATE POLICY "tables_admin_all"
  ON public.tables
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ============================================================================
-- STEP 7: ORDERS - Clients read own, admins read establishment orders
-- ============================================================================

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Clients read their own orders
CREATE POLICY "orders_read_own"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Clients create their own orders
CREATE POLICY "orders_create_own"
  ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Admins/kitchen/managers read establishment orders
CREATE POLICY "orders_admin_read"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'kitchen', 'manager', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- Admins update orders
CREATE POLICY "orders_admin_update"
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'kitchen', 'manager', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ============================================================================
-- STEP 8: ORDER_ITEMS - Inherit from orders
-- ============================================================================

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Users can view items of orders they can see
CREATE POLICY "order_items_read"
  ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id
    )
  );

-- Users can insert items into their own orders
CREATE POLICY "order_items_create"
  ON public.order_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()
    )
  );

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '=== RLS RE-ENABLED WITH CLEAN POLICIES ===' as status;

-- Show all RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN (
  'profiles', 'establishments', 'products', 'categories', 'tables', 'orders', 'order_items'
)
ORDER BY tablename;

-- Show policy count
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

SELECT '=== SECURITY RESTORED ===' as final_status;
