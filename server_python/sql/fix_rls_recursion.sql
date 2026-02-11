-- =============================================================================
-- FIX RLS INFINITE RECURSION
-- =============================================================================

-- PROBLEM:
-- The policy "Admins can read all profiles" queries the "profiles" table to check the role.
-- Querying "profiles" triggers the policy again -> Infinite Loop.

-- SOLUTION:
-- Create a "SECURITY DEFINER" function.
-- This function runs with "superuser" privileges (bypassing RLS) just to get the role.

-- 1. Create the helper function
CREATE OR REPLACE FUNCTION public.auth_role()
RETURNS text AS $$
BEGIN
  -- Returns the role of the current user from public.profiles
  -- SECURITY DEFINER ensures this runs without triggering RLS on the user
  RETURN (
    SELECT role 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the problematic recursive policies
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins full access establishments" ON public.establishments;
DROP POLICY IF EXISTS "Admins full access categories" ON public.categories;
DROP POLICY IF EXISTS "Admins full access products" ON public.products;
DROP POLICY IF EXISTS "Admins full access tables" ON public.tables;

-- 3. Re-create "Admins can read all profiles" using the safe function
CREATE POLICY "Admins can read all profiles" ON public.profiles
  FOR SELECT
  USING (
    public.auth_role() IN ('admin', 'super_admin')
  );

-- 4. Update other Admin policies to use the new function (Optimization)
--    (Optional, but good practice to allow super_admin everywhere)

CREATE POLICY "Admins full access establishments" ON public.establishments
  FOR ALL
  USING (public.auth_role() IN ('admin', 'super_admin'));

CREATE POLICY "Admins full access categories" ON public.categories
  FOR ALL
  USING (public.auth_role() IN ('admin', 'super_admin'));

CREATE POLICY "Admins full access products" ON public.products
  FOR ALL
  USING (public.auth_role() IN ('admin', 'super_admin'));

CREATE POLICY "Admins full access tables" ON public.tables
  FOR ALL
  USING (public.auth_role() IN ('admin', 'super_admin'));
