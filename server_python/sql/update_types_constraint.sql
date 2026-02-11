-- ============================================================================
-- UPDATE ESTABLISHMENT TYPES CONSTRAINT
-- Allow new business types (Bakery, Pet Shop, etc.)
-- ============================================================================

-- 1. Drop existing check constraint if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'establishments_type_check'
        AND table_name = 'establishments'
    ) THEN
        ALTER TABLE public.establishments DROP CONSTRAINT establishments_type_check;
    END IF;
END $$;

-- 2. Add new constraint with all supported types
ALTER TABLE public.establishments
ADD CONSTRAINT establishments_type_check 
CHECK (type IN (
  'restaurant', 
  'pharmacy', 
  'grocery', 
  'shop',
  'bakery',
  'butchery',
  'pet_shop',
  'electronics',
  'fashion',
  'beverages',
  'home_decor',
  'stationery',
  'beauty',
  'florist',
  'services'
));
