-- =============================================================================
-- FIX LOGIN PERMISSIONS
-- =============================================================================

-- 1. Ensure RLS is enabled on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policy to avoid conflicts (if it exists)
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;

-- 3. Re-create the policy: Allow users to read their own profile
CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- 4. Grant access to authenticated users (just in case)
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO service_role;

-- 5. Force update the user role (Hardcoded for your email)
UPDATE public.profiles
SET role = 'super_admin'
WHERE id IN (
    SELECT id 
    FROM auth.users 
    WHERE email = 'super@manda.ai'
);

-- 6. Verify the result
SELECT email, p.role as profile_role
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE email = 'super@manda.ai';
