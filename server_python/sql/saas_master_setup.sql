-- =============================================================================
-- MANDA.AI SAAS DATABASE - MASTER SETUP (FRESH START)
-- =============================================================================
-- Execute this script in your Supabase SQL Editor
-- This will set up a clean multi-tenant SaaS database structure
-- =============================================================================

-- ============================================================================
-- PART 1: CLEANUP - Remove all conflicting policies
-- ============================================================================

-- Drop all existing policies on profiles
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Enable read for users" ON public.profiles;
DROP POLICY IF EXISTS "Enable update for users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

-- Drop policies on other tables that depend on auth_role()
DROP POLICY IF EXISTS "Admins full access establishments" ON public.establishments;
DROP POLICY IF EXISTS "Admins full access categories" ON public.categories;
DROP POLICY IF EXISTS "Admins full access products" ON public.products;
DROP POLICY IF EXISTS "Admins full access tables" ON public.tables;
DROP POLICY IF EXISTS "Public can view establishments" ON public.establishments;
DROP POLICY IF EXISTS "Public can view categories" ON public.categories;
DROP POLICY IF EXISTS "Public can view products" ON public.products;
DROP POLICY IF EXISTS "Public can view tables" ON public.tables;

-- Drop problematic functions (now safe after policies are dropped)
DROP FUNCTION IF EXISTS public.auth_role();
DROP FUNCTION IF EXISTS public.get_my_role();
DROP FUNCTION IF EXISTS public.get_my_establishment();

-- Temporarily disable RLS to clean up
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.establishments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tables DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 2: SCHEMA UPDATES - Ensure all SaaS columns exist
-- ============================================================================

-- Add establishment_id to profiles (if not exists)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- Add type column to establishments (if not exists)
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS type text;

-- Add slug to establishments (if not exists)
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS slug text UNIQUE;

-- Ensure products have establishment_id
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- Ensure categories have establishment_id
ALTER TABLE public.categories 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- Ensure tables have establishment_id
ALTER TABLE public.tables 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- Set default type for existing establishments
UPDATE public.establishments
SET type = 'restaurant'
WHERE type IS NULL;

-- ============================================================================
-- PART 3: SECURITY DEFINER FUNCTIONS - Safe role/context access
-- ============================================================================

-- Function to get current user's role (bypasses RLS safely)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT role 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$;

-- Function to get current user's establishment_id (for context-aware queries)
CREATE OR REPLACE FUNCTION public.get_my_establishment()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
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
-- PART 4: RLS POLICIES - Clean, non-recursive policies
-- ============================================================================

-- ----------------
-- PROFILES
-- ----------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "profiles_read_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ----------------
-- ESTABLISHMENTS
-- ----------------
ALTER TABLE public.establishments ENABLE ROW LEVEL SECURITY;

-- Public can view all establishments (needed for marketplace)
CREATE POLICY "establishments_public_read"
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

-- ----------------
-- PRODUCTS
-- ----------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Public can view all products (filtered by app)
CREATE POLICY "products_public_read"
  ON public.products
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins can manage products in their establishment
CREATE POLICY "products_admin_all"
  ON public.products
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ----------------
-- CATEGORIES
-- ----------------
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Public can view all categories
CREATE POLICY "categories_public_read"
  ON public.categories
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins can manage categories in their establishment
CREATE POLICY "categories_admin_all"
  ON public.categories
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ----------------
-- TABLES
-- ----------------
ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

-- Public can view tables (needed to validate QR codes)
CREATE POLICY "tables_public_read"
  ON public.tables
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Admins can manage tables in their establishment
CREATE POLICY "tables_admin_all"
  ON public.tables
  FOR ALL
  TO authenticated
  USING (
    public.get_my_role() IN ('admin', 'super_admin') AND
    (establishment_id = public.get_my_establishment() OR public.get_my_role() = 'super_admin')
  );

-- ============================================================================
-- PART 5: SETUP SUPER ADMIN USER
-- ============================================================================

-- Enable pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Update password for super@manda.ai
UPDATE auth.users
SET encrypted_password = crypt('super123', gen_salt('bf'))
WHERE email = 'super@manda.ai';

-- Set role to super_admin
UPDATE public.profiles
SET role = 'super_admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'super@manda.ai');

-- ============================================================================
-- PART 6: VERIFICATION
-- ============================================================================

-- Check super admin user
SELECT u.email, p.role, p.establishment_id
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'super@manda.ai';

-- Check establishments
SELECT id, name, slug, type, is_active
FROM public.establishments;

-- Check RLS policies on profiles
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Test the get_my_role function
-- (Run this after logging in as super@manda.ai)
-- SELECT public.get_my_role();
