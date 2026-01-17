-- Add missing address column to deliveries table
ALTER TABLE deliveries 
ADD COLUMN IF NOT EXISTS address TEXT;

-- Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'deliveries';
