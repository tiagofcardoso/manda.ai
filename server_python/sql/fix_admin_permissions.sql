-- ============================================================================
-- FIX ADMIN PERMISSIONS
-- Allows admins to manage their own establishment (Update info, Upload logos/products)
-- ============================================================================

-- 1. Allow Admins to UPDATE their own Establishment
-- (Previous policies only allowed SELECT for public/admins)

DROP POLICY IF EXISTS "establishments_admin_update" ON public.establishments;

CREATE POLICY "establishments_admin_update"
  ON public.establishments
  FOR UPDATE
  TO authenticated
  USING (
    -- Admin of THIS establishment OR Super Admin
    (public.get_my_role() = 'admin' AND id = public.get_my_establishment()) OR
    public.get_my_role() = 'super_admin'
  )
  WITH CHECK (
    (public.get_my_role() = 'admin' AND id = public.get_my_establishment()) OR
    public.get_my_role() = 'super_admin'
  );


-- 2. Ensure Storage Permissions for 'establishments' bucket (Logos)
-- Drop to avoid conflicts if they exist
DROP POLICY IF EXISTS "Admins Upload Establishment Logos" ON storage.objects;
DROP POLICY IF EXISTS "Admins Update Establishment Logos" ON storage.objects;
DROP POLICY IF EXISTS "Admins Delete Establishment Logos" ON storage.objects;
DROP POLICY IF EXISTS "Public Access Establishment Logos" ON storage.objects;

-- Create policies for 'establishments' bucket
CREATE POLICY "Admins Upload Establishment Logos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK ( bucket_id = 'establishments' );

CREATE POLICY "Admins Update Establishment Logos"
ON storage.objects FOR UPDATE TO authenticated
USING ( bucket_id = 'establishments' );

CREATE POLICY "Admins Delete Establishment Logos"
ON storage.objects FOR DELETE TO authenticated
USING ( bucket_id = 'establishments' );

CREATE POLICY "Public Access Establishment Logos"
ON storage.objects FOR SELECT
USING ( bucket_id = 'establishments' );


-- 3. Ensure Storage Permissions for 'products' bucket (Product Images)
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update product images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete product images" ON storage.objects;
DROP POLICY IF EXISTS "Public users can view product images" ON storage.objects;

-- Create policies for 'products' bucket
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'products');

CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'products');

CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'products');

CREATE POLICY "Public users can view product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'products');
