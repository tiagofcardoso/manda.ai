-- =============================================================================
-- FINAL FIX: RLS-SAFE ROLE FUNCTION
-- =============================================================================

-- 1. Create a public function that fetches the user's role safely
-- This function bypasses RLS because it's SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
BEGIN
  RETURN (
    SELECT role 
    FROM public.profiles 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;

-- 3. Test the function (should return 'super_admin')
SELECT public.get_my_role();
