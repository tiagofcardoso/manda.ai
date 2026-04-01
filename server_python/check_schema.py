
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

url = os.environ.get("SUPABASE_URL", "")
key = os.environ.get("SUPABASE_ANON_KEY", os.environ.get("SUPABASE_PUBLISHABLE_KEY", ""))
service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", key)

supabase = create_client(url, service_key)

try:
    # Use RPC if available, or just try to insert a dummy product with a bad category_id to see error message?
    # Better: Query information_schema via a trick or just assume based on error.
    # Let's try to fetch one product and see the category_id format.
    response = supabase.table('products').select('category_id').limit(1).execute()
    print("Sample category_id:", response.data)
except Exception as e:
    print("Error fetching products:", e)

