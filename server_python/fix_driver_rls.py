import os
import sys
sys.path.append('server_python')
from database import supabase

def run():
    print("Fixing RLS for driver app...")
    sql = """
    -- Allow everyone to read establishments
    CREATE POLICY IF NOT EXISTS "Allow everyone read establishments" ON public.establishments FOR SELECT USING (true);
    
    -- Allow authenticated to read profiles
    CREATE POLICY IF NOT EXISTS "Allow authenticated read profiles" ON public.profiles FOR SELECT USING (auth.role() = 'authenticated');
    """
    
    try:
        res = supabase.rpc('execute_sql', {'sql_string': sql}).execute()
        print("Success:", res)
    except Exception as e:
        print("Error executing SQL via RPC.", e)
        print("Driver might still not see the names if policies are missing.")

if __name__ == '__main__':
    run()
