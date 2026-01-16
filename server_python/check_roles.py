import os
from database import supabase

def check_roles():
    if not supabase:
        print("Supabase not connected")
        return

    try:
        print("Fetching Profiles...")
        response = supabase.table('profiles').select('*').execute()
        
        for p in response.data:
            print(f"RAW: {p}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_roles()
