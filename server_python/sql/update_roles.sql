-- =============================================================================
-- SAAS MIGRATION PHASE 3: SUPER ADMIN ROLE
-- =============================================================================

-- 1. Update Role Constraint (if exists) or just comment
-- -----------------------------------------------------------------------------
-- If you have a check constraint on roles, you need to update it.
-- Checking current constraints:
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('client', 'auditor', 'driver', 'kitchen', 'admin', 'super_admin'));

-- 2. Create a Policy for Super Admins to see EVERYTHING
-- -----------------------------------------------------------------------------
-- Super Admins can read all profiles
CREATE POLICY "Super Admins can read all profiles" ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- Super Admins can read/update all establishments
CREATE POLICY "Super Admins full access establishments" ON public.establishments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );
