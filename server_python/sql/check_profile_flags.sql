-- Check if the created profiles have the flag set correctly
SELECT id, role, must_change_password, welcome_shown, establishment_id
FROM public.profiles
ORDER BY created_at DESC
LIMIT 5;

-- Also check function definition for debug
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'check_password_change_required';
