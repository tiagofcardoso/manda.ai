-- Enable RLS policies for product images storage bucket
-- This allows authenticated admin users to upload product images

-- Enable RLS on the products bucket (if not already enabled)
-- Note: This is done via Supabase Dashboard > Storage > products bucket > Policies

-- Policy 1: Allow authenticated users to INSERT (upload) images
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'products');

-- Policy 2: Allow authenticated users to UPDATE (replace) images
CREATE POLICY "Authenticated users can update product images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'products');

-- Policy 3: Allow authenticated users to DELETE images
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'products');

-- Policy 4: Allow public SELECT (read) access to product images
CREATE POLICY "Public users can view product images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'products');

-- Verify policies
SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%product%';
