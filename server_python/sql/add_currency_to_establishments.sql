-- Add currency column to establishments table
-- This allows each establishment to configure their preferred currency

-- Add currency column with default EUR
ALTER TABLE establishments 
ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'EUR';

-- Add check constraint for valid ISO 4217 currency codes (3 uppercase letters)
ALTER TABLE establishments
ADD CONSTRAINT valid_currency_code 
CHECK (currency ~ '^[A-Z]{3}$');

-- Update existing records to have EUR as default
UPDATE establishments 
SET currency = 'EUR' 
WHERE currency IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN establishments.currency IS 'ISO 4217 currency code (e.g., EUR, USD, BRL)';
