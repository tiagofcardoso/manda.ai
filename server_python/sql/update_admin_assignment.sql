-- ============================================================================
-- UPDATE ESTABLISHMENT CREATION FLOW
-- 1. Add establishment_name to profiles
-- 2. Allow custom initial password for admin
-- ============================================================================

-- 1. Add column to profiles for easy identification
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS establishment_name TEXT;

-- 2. Update the assign_establishment_admin RPC to accept custom password and establishment name

DROP FUNCTION IF EXISTS public.assign_establishment_admin(TEXT, UUID);

CREATE OR REPLACE FUNCTION public.assign_establishment_admin(
  p_email TEXT, 
  p_establishment_id UUID,
  p_custom_password TEXT DEFAULT NULL,
  p_establishment_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/superuser)
AS $$
DECLARE
  v_user_id UUID;
  v_requester_role TEXT;
  v_requester_est UUID;
  v_final_password TEXT;
  v_user_exists BOOLEAN;
BEGIN
  -- 1. Check permission of the requester
  SELECT role, establishment_id INTO v_requester_role, v_requester_est
  FROM public.profiles
  WHERE id = auth.uid();

  -- Only Super Admin OR the Admin of THIS establishment can assign users
  IF v_requester_role != 'super_admin' AND (v_requester_role != 'admin' OR v_requester_est != p_establishment_id) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Permission denied');
  END IF;

  -- 2. Check if user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_email;

  v_user_exists := v_user_id IS NOT NULL;

  -- 3. Create user if not exists (with custom password or default)
  IF NOT v_user_exists THEN
    -- Use custom password if provided, otherwise default
    v_final_password := COALESCE(p_custom_password, 'Manda2024!');
    
    -- NOTE: User creation must be done via Supabase Admin SDK in the Python Backend
    -- because RPC cannot directly create auth users. We return the info needed.
    
    RETURN jsonb_build_object(
      'status', 'create_required',
      'message', 'User does not exist. Create via Admin SDK',
      'email', p_email,
      'temp_password', v_final_password,
      'establishment_id', p_establishment_id,
      'establishment_name', p_establishment_name
    );
  END IF;

  -- 4. Update existing user's profile
  UPDATE public.profiles
  SET 
    establishment_id = p_establishment_id,
    establishment_name = COALESCE(p_establishment_name, establishment_name), -- Update name if provided
    role = 'admin',
    must_change_password = TRUE,
    welcome_shown = FALSE
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'status', 'success', 
    'message', 'User assigned as admin', 
    'user_id', v_user_id,
    'must_change_password', TRUE
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.assign_establishment_admin(TEXT, UUID, TEXT, TEXT) TO authenticated;
