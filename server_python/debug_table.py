from database import supabase
import json

def debug_check():
    if not supabase:
        print("Supabase not configured")
        return

    print("\n--- CHECKING TABLES '5' or '05' ---")
    res_5 = supabase.table("tables").select("*").eq("table_number", "5").execute()
    print(f"Table '5': {len(res_5.data)} found")
    
    res_05 = supabase.table("tables").select("*").eq("table_number", "05").execute()
    print(f"Table '05': {len(res_05.data)} found")
    if res_05.data:
        print(f"Table 05 Data: {res_05.data[0]}")

    print("\n--- CHECKING LAST ORDER ---")
    # Fetch last order to see what happened
    last_order = supabase.table("orders").select("*").order("created_at", desc=True).limit(1).execute()
    if last_order.data:
        o = last_order.data[0]
        print(f"Order UUID: {o.get('id')}")
        print(f"Table ID used: {o.get('table_id')}")
        print(f"Establishment ID: {o.get('establishment_id')}")
    else:
        print("No orders found.")

if __name__ == "__main__":
    debug_check()
