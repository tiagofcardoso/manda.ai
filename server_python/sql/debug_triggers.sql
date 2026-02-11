-- Check if handle_new_user trigger exists and what it does
SELECT 
    event_object_schema as table_schema,
    event_object_table as table_name,
    trigger_schema,
    trigger_name,
    string_agg(event_manipulation, ',') as event,
    action_timing as activation,
    action_statement as definition
FROM information_schema.triggers
WHERE event_object_table = 'users' -- Usually on auth.users
   OR event_object_table = 'profiles'
GROUP BY 1,2,3,4,6,7;

-- Also try to find the function definition if we know the name 'handle_new_user'
SELECT prosrc FROM pg_proc WHERE proname = 'handle_new_user';
