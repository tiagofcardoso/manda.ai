
-- Add free text category column to products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS custom_category TEXT;

-- We don't need a strict FK if custom_category is used
-- But let's ensure category_id is optional or can be null if custom is used
ALTER TABLE public.products 
ALTER COLUMN category_id DROP NOT NULL;
