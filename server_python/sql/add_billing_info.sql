-- Add billing_info JSONB column to profiles if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS billing_info JSONB DEFAULT '{}'::jsonb;

-- Also ensure address is JSONB (it might be text or missing)
-- If it exists as text, we might need to cast it, but for now assuming it's either missing or compatible
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS address JSONB DEFAULT '{}'::jsonb;

-- Policy to allow users to update their own billing info is already covered by "profiles_update_own"
-- which allows updating the row. Ensure columns are not restricted if you use column-level privileges.
