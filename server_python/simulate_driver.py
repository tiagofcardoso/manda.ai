import time
import math
import asyncio
from supabase import create_client, Client
import os
from dotenv import load_dotenv
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut

# Load environment variables
load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Error: Missing SUPABASE_URL or SUPABASE_KEY in .env")
    exit(1)

supabase: Client = create_client(url, key)

# Configuration
ORDER_ID = os.environ.get("SIMULATE_ORDER_ID")

# Geocoding Setup
geolocator = Nominatim(user_agent="manda_ai_driver_sim")

def get_coordinates(address_str):
    try:
        print(f"Geocoding: {address_str}")
        location = geolocator.geocode(address_str)
        if location:
            return location.latitude, location.longitude
        else:
            print("  -> Not found")
            return None
    except Exception as e:
        print(f"  -> Geocoding error: {e}")
        return None

def build_address_string(data):
    if not data: return None
    components = [
        data.get('street'),
        data.get('zip_code'),
        data.get('city'),
        data.get('country')
    ]
    # Filter empty/null and join
    return ", ".join([c for c in components if c])

async def simulate_delivery():
    if not ORDER_ID:
        print("Error: SIMULATE_ORDER_ID env var not set.")
        return

    print(f"Starting simulation for Order: {ORDER_ID}")

    # 1. Fetch Order Data to get IDs
    print("Fetching Order Data...")
    order_res = supabase.table('orders').select('*').eq('id', ORDER_ID).execute()
    if not order_res.data:
        print("Error: Order not found")
        return
    
    order = order_res.data[0]
    est_id = order.get('establishment_id')
    user_id = order.get('user_id')

    # Defaults (Lisbon)
    start_lat, start_lng = 38.7223, -9.1393
    end_lat, end_lng = 38.7369, -9.1426
    
    # 2. Fetch Establishment Address
    if est_id:
        est_res = supabase.table('establishments').select('*').eq('id', est_id).execute()
        if est_res.data:
             addr_str = build_address_string(est_res.data[0])
             coords = get_coordinates(addr_str)
             if coords:
                 start_lat, start_lng = coords
                 print(f"  -> Establishment: {start_lat}, {start_lng} ({addr_str})")

    # 3. Fetch User Address
    if user_id:
        user_res = supabase.table('profiles').select('*').eq('id', user_id).execute()
        if user_res.data:
            addr_str = build_address_string(user_res.data[0])
            coords = get_coordinates(addr_str)
            if coords:
                 end_lat, end_lng = coords
                 print(f"  -> Customer: {end_lat}, {end_lng} ({addr_str})")
    
    print("-" * 40)
    print(f"Route: ({start_lat}, {start_lng}) -> ({end_lat}, {end_lng})")
    
    steps = 100
    
    for i in range(steps + 1):
        t = i / steps
        # Linear Interpolation
        current_lat = start_lat + (end_lat - start_lat) * t
        current_lng = start_lng + (end_lng - start_lng) * t
        
        if i % 10 == 0:
            print(f"Update {i}/{steps}: {current_lat:.5f}, {current_lng:.5f}")
        
        # Broadcast via Channel
        channel = supabase.channel(f'tracking:{ORDER_ID}')
        channel.send_broadcast('location_update', {'lat': current_lat, 'lng': current_lng})
        
        # Persistence (every 10 steps)
        if i % 10 == 0:
             supabase.table('deliveries').update({
                 'current_lat': current_lat,
                 'current_lng': current_lng,
                 'updated_at': 'now()'
             }).eq('order_id', ORDER_ID).execute()

        time.sleep(1) 

if __name__ == "__main__":
    asyncio.run(simulate_delivery())
