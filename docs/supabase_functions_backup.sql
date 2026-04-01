-- ============================================================
-- MANDA.AI — BACKUP DAS FUNÇÕES SQL EXISTENTES
-- Exportado em: 2026-04-01
-- ============================================================

-- FUNÇÃO: assign_establishment_admin
CREATE OR REPLACE FUNCTION public.assign_establishment_admin(
  p_email TEXT,
  p_establishment_id UUID,
  p_establishment_name TEXT DEFAULT NULL,
  p_custom_password TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_requester_role TEXT;
  v_requester_est UUID;
  v_final_password TEXT;
  v_user_exists BOOLEAN;
BEGIN
  SELECT role, establishment_id INTO v_requester_role, v_requester_est
  FROM public.profiles WHERE id = auth.uid();

  IF v_requester_role != 'super_admin' AND (v_requester_role != 'admin' OR v_requester_est != p_establishment_id) THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Permission denied');
  END IF;

  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  v_user_exists := v_user_id IS NOT NULL;

  IF NOT v_user_exists THEN
    v_final_password := COALESCE(p_custom_password, 'Manda2024!');
    RETURN jsonb_build_object(
      'status', 'create_required',
      'message', 'User does not exist. Create via Admin SDK',
      'email', p_email,
      'temp_password', v_final_password,
      'establishment_id', p_establishment_id,
      'establishment_name', p_establishment_name
    );
  END IF;

  UPDATE public.profiles
  SET 
    establishment_id = p_establishment_id,
    establishment_name = COALESCE(p_establishment_name, establishment_name),
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

-- FUNÇÃO: check_password_change_required
CREATE OR REPLACE FUNCTION public.check_password_change_required()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_must_change BOOLEAN;
BEGIN
  SELECT must_change_password INTO v_must_change
  FROM public.profiles WHERE id = auth.uid();
  RETURN COALESCE(v_must_change, FALSE);
END;
$$;

-- FUNÇÃO: complete_password_change
CREATE OR REPLACE FUNCTION public.complete_password_change()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET must_change_password = FALSE, welcome_shown = TRUE
  WHERE id = auth.uid();
  RETURN jsonb_build_object('status', 'success', 'message', 'Password change completed');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- FUNÇÃO: get_my_establishment
CREATE OR REPLACE FUNCTION public.get_my_establishment()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (SELECT establishment_id FROM public.profiles WHERE id = auth.uid());
END;
$$;

-- FUNÇÃO: get_my_role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (SELECT role FROM public.profiles WHERE id = auth.uid());
END;
$$;

-- FUNÇÃO: handle_new_user (TRIGGER)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, full_name, role, phone_number, establishment_id,
    street, zip_code, city, state, country
  )
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    COALESCE(new.raw_user_meta_data->>'role', 'client'),
    new.raw_user_meta_data->>'phone',
    (new.raw_user_meta_data->>'establishment_id')::uuid,
    new.raw_user_meta_data->'address'->>'street',
    new.raw_user_meta_data->'address'->>'zip_code',
    new.raw_user_meta_data->'address'->>'city',
    new.raw_user_meta_data->'address'->>'state',
    new.raw_user_meta_data->'address'->>'country'
  );
  RETURN new;
END;
$$;

-- FUNÇÃO: set_new_profile_defaults (TRIGGER)
CREATE OR REPLACE FUNCTION public.set_new_profile_defaults()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NEW.must_change_password := COALESCE(NEW.must_change_password, FALSE);
  NEW.welcome_shown := COALESCE(NEW.welcome_shown, FALSE);
  RETURN NEW;
END;
$$;
