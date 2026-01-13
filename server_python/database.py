import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

# Initialize Supabase
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")

print(f"DEBUG: Loading Supabase...")
print(f"DEBUG: URL found? {bool(url)}")
print(f"DEBUG: KEY found? {bool(key)}")

# For now, we'll initialize conditionally
supabase: Client = None
if url and key:
    try:
        supabase = create_client(url, key)
        print("DEBUG: Supabase Client Initialized Successfully!")
    except Exception as e:
        print(f"DEBUG: Failed to init Supabase: {e}")
else:
    print("DEBUG: Missing URL or KEY - Supabase will remain None.")
