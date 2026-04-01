import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Load from .env — never hardcode credentials
url = os.environ.get("SUPABASE_URL", "")
key = os.environ.get("SUPABASE_ANON_KEY", os.environ.get("SUPABASE_PUBLISHABLE_KEY", ""))
service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not service_key:
    raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")

supabase: Client = create_client(url, service_key)

def apply_sql(filepath):
    print(f"Applying {filepath}...")
    with open(filepath, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    # PostgREST doesn't support executing arbitrary SQL directly via the client 
    # unless you have a specific RPC for it or use the PG connection.
    # However, supabase-py client often communicates via REST.
    # We might need to use the `rpc` call if we have an `exec_sql` function, 
    # OR we are stuck.
    
    # WAIT. Creating functions (DDL) via Client SDK is not standard unless there is a specific endpoint.
    # Standard way: User runs SQL in Supabase Dashboard SQL Editor.
    
    print("Content read. Please run this in Supabase Dashboard SQL Editor.")
    print("-" * 20)
    print(sql_content)
    print("-" * 20)

if __name__ == "__main__":
    apply_sql("sql/admin_temp_password_system.sql")
