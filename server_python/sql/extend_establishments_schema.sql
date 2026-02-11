-- ============================================================================
-- EXTEND ESTABLISHMENTS SCHEMA
-- Adds contact info, more address details, and Admin Assignment RPC
-- ============================================================================

-- 1. Add new columns to 'establishments'
ALTER TABLE public.establishments 
ADD COLUMN IF NOT EXISTS contact_name TEXT,
ADD COLUMN IF NOT EXISTS contact_phone TEXT,
ADD COLUMN IF NOT EXISTS number TEXT,
ADD COLUMN IF NOT EXISTS complement TEXT,
ADD COLUMN IF NOT EXISTS latitude FLOAT,
ADD COLUMN IF NOT EXISTS longitude FLOAT;

-- 2. Create Secure Function to Assign Admin by Email
-- This function allows an authenticated user (who is Super Admin or Admin of the store)
-- to assign another user as Admin of that store.

CREATE OR REPLACE FUNCTION public.assign_establishment_admin(
  p_email TEXT, 
  p_establishment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/superuser)
AS $$
DECLARE
  v_user_id UUID;
  v_requester_role TEXT;
  v_requester_est UUID;
BEGIN
  -- 1. Check permission of the requester
  SELECT role, establishment_id INTO v_requester_role, v_requester_est
  FROM public.profiles
  WHERE id = auth.uid();

  -- Only Super Admin OR the Admin of THIS establishment can assign users
  IF v_requester_role != 'super_admin' AND (v_requester_role != 'admin' OR v_requester_est != p_establishment_id) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Permission denied');
  END IF;

  -- 2. Find the target user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_email;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'User not found');
  END IF;

  -- 3. Update the target user's profile
  UPDATE public.profiles
  SET 
    establishment_id = p_establishment_id,
    role = 'admin'
  WHERE id = v_user_id;

  RETURN jsonb_build_object('status', 'success', 'message', 'User assigned as admin', 'user_id', v_user_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.assign_establishment_admin(TEXT, UUID) TO authenticated;
