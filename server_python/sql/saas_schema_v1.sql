-- =============================================================================
-- SAAS MIGRATION PHASE 1: SCHEMA UPDATES
-- =============================================================================

-- 1. PROFILES: Link Users to Establishments
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- Update handle_new_user to capture establishment_id from metadata (for future invites)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (
    id, 
    full_name, 
    role, 
    phone_number,
    establishment_id, -- NEW
    street,
    zip_code,
    city,
    state,
    country
  )
  VALUES (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    COALESCE(new.raw_user_meta_data->>'role', 'client'),
    new.raw_user_meta_data->>'phone',
    (new.raw_user_meta_data->>'establishment_id')::uuid, -- NEW
    new.raw_user_meta_data->'address'->>'street',
    new.raw_user_meta_data->'address'->>'zip_code',
    new.raw_user_meta_data->'address'->>'city',
    new.raw_user_meta_data->'address'->>'state',
    new.raw_user_meta_data->'address'->>'country'
  );
  return new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. CATEGORIES: Link to Establishment
-- -----------------------------------------------------------------------------
ALTER TABLE public.categories 
ADD COLUMN IF NOT EXISTS establishment_id uuid REFERENCES public.establishments(id);

-- 3. TABLES: Link to Establishment (Safety Check)
-- -----------------------------------------------------------------------------
-- Ensure it exists and is FK
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tables' AND column_name='establishment_id') THEN
    ALTER TABLE public.tables ADD COLUMN establishment_id uuid REFERENCES public.establishments(id);
  END IF;
END $$;

-- 4. ESTABLISHMENTS: Add Slug for URLs
-- -----------------------------------------------------------------------------
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS slug text UNIQUE;

-- 5. PRODUCTS: Safety Check
-- -----------------------------------------------------------------------------
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='establishment_id') THEN
    ALTER TABLE public.products ADD COLUMN establishment_id uuid REFERENCES public.establishments(id);
  END IF;
END $$;
