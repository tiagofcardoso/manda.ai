from database import supabase
import json

def check_pool():
    if not supabase:
        print("Supabase not configured")
        return

    try:
        # Check Deliveries
        print("--- OPEN DELIVERIES ---")
        res = supabase.table("deliveries").select("*").eq("status", "open").execute()
        print(json.dumps(res.data, indent=2))
        
        if not res.data:
            print("No open deliveries found.")
            
        # Check Most Recent Orders
        print("\n--- RECENT ORDERS ---")
        orders = supabase.table("orders").select("*").order("created_at", desc=True).limit(3).execute()
        print(json.dumps(orders.data, indent=2))

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_pool()
