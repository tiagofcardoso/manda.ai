-- =============================================================================
-- FIX RLS RECURSION (INFINITE LOOP)
-- =============================================================================
-- The previous policy caused an infinite loop:
-- "To check if I am admin, look at my profile." -> "To look at my profile, check if I am admin."
-- 
-- SOLUTION: Use a helper function (SECURITY DEFINER) to check admin status safely.

-- 1. Create a function that bypasses RLS to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  -- perform a direct check on the profiles table
  -- Since this function is SECURITY DEFINER, it runs with higher privileges
  -- and ignores the Row Level Security on the table for this specific check.
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop the buggy recursive policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;

-- 3. Re-create the Admin policy using the safe function
CREATE POLICY "Admins can view all profiles" 
ON public.profiles FOR SELECT 
USING ( public.is_admin() );

-- 4. Ensure the Basic Owner policy still exists
-- (This allows normal users to read their own profile without being admin)
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = id);

-- 5. Grant execute permission on the function (just in case)
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon; -- (optional)
