-- Check if currency column exists in establishments table
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'establishments' 
AND column_name = 'currency';

-- If the above returns no rows, run the migration:
-- ALTER TABLE establishments ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'EUR';

-- Check current currency values
SELECT id, name, currency 
FROM establishments 
LIMIT 10;
