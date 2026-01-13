import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")

if not url or not key:
    print("Error: Missing SUPABASE_URL or SUPABASE_KEY in .env")
    exit(1)

supabase: Client = create_client(url, key)

def list_orders():
    print("-" * 50)
    print("🛒  RECENT ORDERS")
    print("-" * 50)
    
    # Fetch last 5 orders, ordered by newest first
    response = supabase.table('orders') \
        .select('*, order_items(*, products(name))') \
        .order('created_at', desc=True) \
        .limit(5) \
        .execute()
    
    orders = response.data
    
    if not orders:
        print("No orders found.")
        return

    for order in orders:
        print(f"ID: {order['id']}")
        print(f"Status: {order['status'].upper()}")
        print(f"Total: €{order['total_amount']}")
        print(f"Time: {order['created_at']}")
        print("Items:")
        for item in order['order_items']:
            prod_name = item['products']['name'] if item['products'] else 'Unknown Product'
            print(f"  - {item['quantity']}x {prod_name}")
        print("-" * 30)

if __name__ == "__main__":
    list_orders()
