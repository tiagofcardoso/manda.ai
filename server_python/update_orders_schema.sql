-- Add missing columns to orders table to support delivery and user tracking
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS delivery_address TEXT,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders';
