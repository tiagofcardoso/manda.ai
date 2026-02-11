-- =============================================================================
-- ADD 'TYPE' COLUMN TO ESTABLISHMENTS
-- =============================================================================

-- 1. Add the 'type' column if it doesn't exist
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS type text;

-- 2. Set a default type for existing records
UPDATE public.establishments
SET type = 'restaurant'
WHERE type IS NULL;

-- 3. Add a check constraint (optional but good practice)
ALTER TABLE public.establishments
ADD CONSTRAINT establishments_type_check 
CHECK (type IN ('restaurant', 'pharmacy', 'grocery'));

-- 4. Verify the result
SELECT id, name, slug, type, is_active
FROM public.establishments;
