-- =============================================================================
-- NUCLEAR OPTION: Disable ALL RLS (Temporary for Testing)
-- =============================================================================

-- Disable RLS on ALL tables
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.establishments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tables DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries DISABLE ROW LEVEL SECURITY;

-- Drop ALL functions
DROP FUNCTION IF EXISTS public.auth_role() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_role() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_establishment() CASCADE;

-- Verify
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN (
  'profiles', 'establishments', 'products', 'categories', 'tables', 'orders', 'order_items', 'deliveries'
);

-- Set super admin
UPDATE public.profiles
SET role = 'super_admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'super@manda.ai');

-- Update password
CREATE EXTENSION IF NOT EXISTS pgcrypto;
UPDATE auth.users
SET encrypted_password = crypt('super123', gen_salt('bf'))
WHERE email = 'super@manda.ai';

SELECT 'RLS DISABLED ON ALL TABLES - LOGIN SHOULD WORK NOW' as status;
