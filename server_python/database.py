import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

# Initialize Supabase
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
service_role_key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

# Regular client (for RLS-protected operations)
supabase: Client = None
if url and key:
    try:
        supabase = create_client(url, key)
        print("DEBUG: Supabase Client Initialized Successfully!")
    except Exception as e:
        print(f"DEBUG: Failed to init Supabase: {e}")
else:
    print("DEBUG: Missing URL or KEY - Supabase will remain None.")

# Admin client (bypasses RLS, for privileged operations)
supabase_admin: Client = None
if url and service_role_key:
    try:
        supabase_admin = create_client(url, service_role_key)
        print("DEBUG: Supabase Admin Client Initialized Successfully!")
    except Exception as e:
        print(f"DEBUG: Failed to init Supabase Admin: {e}")
else:
    print("DEBUG: Missing SERVICE_ROLE_KEY - Admin operations will be unavailable.")
