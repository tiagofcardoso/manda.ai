-- =============================================================================
-- FORCE PASSWORD UPDATE
-- =============================================================================

-- 1. Enable pgcrypto extension (required for hashing)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Update the password
-- Replace 'super123' with your new password
UPDATE auth.users
SET encrypted_password = crypt('super123', gen_salt('bf'))
WHERE email = 'super@manda.ai';

-- 3. Confirm the user exists (just for feedback)
SELECT id, email, created_at 
FROM auth.users 
WHERE email = 'super@manda.ai';
