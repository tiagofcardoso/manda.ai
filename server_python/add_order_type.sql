-- Add order_type column to orders table
ALTER TABLE "orders" ADD COLUMN "order_type" text DEFAULT 'delivery';

-- Optional: Update existing records based on table_id presence
UPDATE "orders" SET "order_type" = 'dine_in' WHERE "table_id" IS NOT NULL;
