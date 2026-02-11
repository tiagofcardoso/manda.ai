-- ============================================================================
-- ADMIN TEMPORARY PASSWORD SYSTEM
-- Creates users with temporary password and forces password change on first login
-- ============================================================================

-- 1. Add column to track if user needs to change password
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS welcome_shown BOOLEAN DEFAULT FALSE;

-- 2. Update the assign_establishment_admin RPC to create user if not exists
-- and set temporary password

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
  v_temp_password TEXT;
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

  -- 3. Create user if not exists (with temporary password)
  IF NOT v_user_exists THEN
    -- Generate temporary password
    v_temp_password := 'Manda2024!';
    
    -- Create user in auth.users (Supabase admin API should be used here)
    -- For now, we'll return the temp password for the calling app to handle user creation
    
    -- NOTE: User creation must be done via Supabase Admin SDK in the Flutter app
    -- because RPC cannot directly create auth users
    
    RETURN jsonb_build_object(
      'status', 'create_required',
      'message', 'User does not exist. Create via Admin SDK',
      'email', p_email,
      'temp_password', v_temp_password,
      'establishment_id', p_establishment_id
    );
  END IF;

  -- 4. Update existing user's profile
  UPDATE public.profiles
  SET 
    establishment_id = p_establishment_id,
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
GRANT EXECUTE ON FUNCTION public.assign_establishment_admin(TEXT, UUID) TO authenticated;

-- 3. Create helper function to check if password change is required
CREATE OR REPLACE FUNCTION public.check_password_change_required()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_must_change BOOLEAN;
BEGIN
  SELECT must_change_password INTO v_must_change
  FROM public.profiles
  WHERE id = auth.uid();
  
  RETURN COALESCE(v_must_change, FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_password_change_required() TO authenticated;

-- 4. Create function to mark password as changed and welcome as shown
CREATE OR REPLACE FUNCTION public.complete_password_change()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET 
    must_change_password = FALSE,
    welcome_shown = TRUE
  WHERE id = auth.uid();
  
  RETURN jsonb_build_object('status', 'success', 'message', 'Password change completed');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_password_change() TO authenticated;

-- 5. Create trigger to set default values for new profiles
CREATE OR REPLACE FUNCTION public.set_new_profile_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NEW.must_change_password := COALESCE(NEW.must_change_password, FALSE);
  NEW.welcome_shown := COALESCE(NEW.welcome_shown, FALSE);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_set_profile_defaults ON public.profiles;

CREATE TRIGGER trigger_set_profile_defaults
BEFORE INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_new_profile_defaults();
