-- ==========================================
-- FIX ORDER STATUS CHECK CONSTRAINT
-- Run this in Supabase SQL Editor
-- ==========================================

-- 1. Drop existing constraint
ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_status_check;

-- 2. Re-create constraint with 'on_way' included
ALTER TABLE public.orders 
ADD CONSTRAINT orders_status_check 
CHECK (status IN (
    'pending', 
    'prep', 
    'ready', 
    'delivered', 
    'completed', 
    'cancelled', 
    'on_way' -- [NEW] Added this
));

-- 3. Verify it works
-- You don't need to run this part, but it confirms the fix.
-- UPDATE public.orders SET status = 'on_way' WHERE id = '...';
