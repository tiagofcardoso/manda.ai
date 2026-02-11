-- =============================================================================
-- SECURITY HARDENING V2: COMPLETE RLS COVERAGE
-- =============================================================================

-- 1. ESTABLISHMENTS
-- -----------------------------------------------------------------------------
ALTER TABLE public.establishments ENABLE ROW LEVEL SECURITY;

-- Public Read (Needed for landing page)
CREATE POLICY "Public can view establishments" ON public.establishments
  FOR SELECT
  USING (true);

-- Admin Full Access
CREATE POLICY "Admins full access establishments" ON public.establishments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 2. CATEGORIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Public Read
CREATE POLICY "Public can view categories" ON public.categories
  FOR SELECT
  USING (true);

-- Admin Full Access
CREATE POLICY "Admins full access categories" ON public.categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 3. PRODUCTS
-- -----------------------------------------------------------------------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Public Read (Only available ones, or all?) 
-- Let's allow reading all for now, frontend filters.
CREATE POLICY "Public can view products" ON public.products
  FOR SELECT
  USING (true);

-- Admin Full Access
CREATE POLICY "Admins full access products" ON public.products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 4. TABLES
-- -----------------------------------------------------------------------------
ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

-- Public Read (Needed to validate table number)
CREATE POLICY "Public can view tables" ON public.tables
  FOR SELECT
  USING (true);

-- Admin Full Access
CREATE POLICY "Admins full access tables" ON public.tables
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 5. ORDERS (Refining)
-- -----------------------------------------------------------------------------
-- Ensure no one can DELETE orders except admins
CREATE POLICY "Admins can delete orders" ON public.orders
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
