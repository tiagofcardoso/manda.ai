-- Replace 'your_email@example.com' with the email you used to login
-- Run this in your Supabase SQL Editor

UPDATE profiles
SET role = 'super_admin'
WHERE id IN (
    SELECT id 
    FROM auth.users 
    WHERE email = 'tiagofcardoso@gmail.com' -- CHANGE THIS TO YOUR EMAIL
);

-- Verify the change
SELECT * FROM profiles WHERE role = 'super_admin';
