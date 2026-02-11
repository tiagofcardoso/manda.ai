-- =============================================================================
-- NUCLEAR RESET: Remove ALL RLS Policies Programmatically
-- =============================================================================

-- Step 1: Generate and execute DROP statements for ALL policies
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I CASCADE', 
                       r.policyname, r.schemaname, r.tablename);
        RAISE NOTICE 'Dropped policy % on %.%', r.policyname, r.schemaname, r.tablename;
    END LOOP;
END $$;

-- Step 2: Drop ALL custom functions that might be used by policies
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.auth_role() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_role() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_establishment() CASCADE;

-- Step 3: Disable RLS on ALL public tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', r.tablename);
        RAISE NOTICE 'Disabled RLS on public.%', r.tablename;
    END LOOP;
END $$;

-- Step 4: Set super admin role
UPDATE public.profiles
SET role = 'super_admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'super@manda.ai');

-- Step 5: Update password
CREATE EXTENSION IF NOT EXISTS pgcrypto;
UPDATE auth.users
SET encrypted_password = crypt('super123', gen_salt('bf'))
WHERE email = 'super@manda.ai';

-- Step 6: Verify everything
SELECT '=== ALL POLICIES REMOVED ===' as status;

SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

SELECT u.email, p.role, p.establishment_id
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'super@manda.ai';

SELECT '=== RLS COMPLETELY DISABLED - LOGIN SHOULD WORK ===' as final_status;
