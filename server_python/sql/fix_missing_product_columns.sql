-- Ensure custom_category exists on products
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS custom_category TEXT;

-- Ensure category_id is nullable (to allow custom categories without ID)
ALTER TABLE public.products 
ALTER COLUMN category_id DROP NOT NULL;

-- Force schema cache reload (usually automatic, but this helps)
NOTIFY pgrst, 'reload schema';
