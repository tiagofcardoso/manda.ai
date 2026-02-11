-- =============================================================================
-- EMERGENCY: DISABLE RLS ON PROFILES (TEMPORARY DEBUG)
-- =============================================================================

-- WARNING: This removes all security from the profiles table.
-- Use ONLY for debugging. Re-enable after testing.

-- 1. Disable RLS on profiles
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Grant full access to authenticated users
GRANT ALL ON public.profiles TO authenticated;

-- 3. Ensure the super admin user exists and has correct role
UPDATE public.profiles
SET role = 'super_admin'
WHERE id IN (
    SELECT id 
    FROM auth.users 
    WHERE email = 'super@manda.ai'
);

-- 4. Verify
SELECT u.email, p.role 
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'super@manda.ai';

-- =============================================================================
-- AFTER TESTING: Re-enable RLS with simple policies
-- =============================================================================
-- Run this AFTER you successfully login:
/*
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Simple policy: users can read their own profile
CREATE POLICY "Enable read for users" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Simple policy: users can update their own profile  
CREATE POLICY "Enable update for users" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);
*/
