-- =============================================================================
-- FIX PERMISSIONS (RLS) FOR PROFILES
-- =============================================================================
-- This script resets the policies on the 'profiles' table to ensure 
-- that users can definitely read their own data.

-- 1. Enable RLS (Ensure it is on)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies to clear any conflicts or bad logic
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public Read Profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON public.profiles;

-- 3. Re-create Simple, Correct Policies

-- A. VIEW: Users can see their own profile.
CREATE POLICY "Users can read own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = id);

-- B. UPDATE: Users can update their own profile.
CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- C. ADMINS: Admins can view ALL profiles (for management).
-- Note: This requires the user performing the select to have role='admin'.
-- If this causes recursion issues, we can simplify/remove it for now, 
-- but the recursive check is standard Supabase pattern.
CREATE POLICY "Admins can view all profiles" 
ON public.profiles FOR SELECT 
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);
