
import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Error: Missing env vars")
    exit(1)

supabase: Client = create_client(url, key)

def check_order(partial_id):
    print(f"Checking Order with ID containing: {partial_id}")
    
    # fetch order
    # Note: 'like' with uuid might not work directly in all postgres versions via this filtering syntax depending on casting
    # But usually 'eq' needs exact. Let's list recent and filter in python if needed, or try standard filter.
    # Actually, let's just fetch recent orders.
    
    res = supabase.table('orders').select('*').order('created_at', desc=True).limit(50).execute()
    
    target_order = None
    for o in res.data:
        if str(o['id']).startswith(partial_id):
            target_order = o
            break
            
    if not target_order:
        print("❌ Order NOT found in last 50 entries.")
        return

    print(f"✅ Order Found: {target_order['id']}")
    print(f"   User ID: {target_order.get('user_id')}")
    print(f"   Est ID:  {target_order.get('establishment_id')}")
    
    user_id = target_order.get('user_id')
    if user_id:
        print(f"\nChecking Profile for User ID: {user_id}")
        try:
            prof_res = supabase.table('profiles').select('*').eq('id', user_id).execute()
            if prof_res.data:
                p = prof_res.data[0]
                print("✅ Profile Found!")
                print(f"   Name: {p.get('full_name')}")
                print(f"   Address: {p.get('street')}, {p.get('city')}")
            else:
                print("❌ Profile NOT found (Row missing in public.profiles)")
                
                # Check auth.users (requires service role usually, but we are using anon/service? 
                # The python script usually uses what's in .env. If it is service_role, we can check auth.users)
                # print("   (Cannot check auth.users without service role key usually)")

        except Exception as e:
            print(f"❌ Error fetching profile: {e}")
            
    else:
        print("❌ Order has NO User ID linked.")

if __name__ == "__main__":
    check_order("f066ae22")
    check_order("eebfa45b") # The other one in screenshot
