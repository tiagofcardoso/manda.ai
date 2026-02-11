-- ============================================================================
-- ADD LOGO SUPPORT TO ESTABLISHMENTS
-- ============================================================================

-- 1. Add logo_url column to establishments table
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- 2. Storage Policies for 'establishments' bucket
-- NOTE: Please create a public bucket named 'establishments' in Supabase Storage first.

-- Enable RLS on storage.objects if not already enabled (usually is)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow public read access to establishment logos
CREATE POLICY "Public Access Establishment Logos"
ON storage.objects FOR SELECT
USING ( bucket_id = 'establishments' );

-- Allow authenticated users (admins) to upload logos
CREATE POLICY "Admins Upload Establishment Logos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'establishments' );

-- Allow authenticated users to update their logos
CREATE POLICY "Admins Update Establishment Logos"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'establishments' );

-- Allow authenticated users to delete their logos
CREATE POLICY "Admins Delete Establishment Logos"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'establishments' );
