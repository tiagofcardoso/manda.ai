import time
import math
import asyncio
from supabase import create_client, Client
import os
from dotenv import load_dotenv

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

if not ORDER_ID:
    print("Error: SIMULATE_ORDER_ID env var not set.")
    exit(1)

# Lisbon Route Simulation
start_lat = 38.7223  # Shop
start_lng = -9.1393
end_lat = 38.7369    # Some destination
end_lng = -9.1426

steps = 100

async def simulate_delivery():
    print(f"Starting simulation for Order: {ORDER_ID}")
    
    # Update status to 'out for delivery' if not already
    # supabase.table('deliveries').upsert({...}) # Optional
    
    for i in range(steps + 1):
        t = i / steps
        # Linear Interpolation (Lerp)
        current_lat = start_lat + (end_lat - start_lat) * t
        current_lng = start_lng + (end_lng - start_lng) * t
        
        print(f"Update {i}/{steps}: {current_lat:.5f}, {current_lng:.5f}")
        
        # 1. Broadcast to Realtime Channel (Low Latency)
        # Using Supabase Realtime HTTP interface is tricky from Python client directly for Broadcast sometimes, 
        # but updating the Row triggers Postgres Changes if we were listening to that.
        # However, our Flutter app listens to 'broadcast' events OR postgres changes?
        # Let's double check Flutter code: It listens to 'tracking:order_id' -> 'location_update'.
        
        # Since Python SDK broadcast support might be limited or different, 
        # let's just update the DB row which is also efficient enough for testing 
        # OR we can try to emit the event if the SDK supports it.
        # Actually, the simplest way to test the BROADCAST listener in Flutter 
        # is to verify if we can trigger it. 
        # If not, let's update the DB row and ensure Flutter also falls back or listen to DB?
        
        # Wait, my Flutter code listens to:
        # channel('tracking:$_activeOrderId').onBroadcast(event: 'location_update', ...)
        
        # It does NOT listen to DB changes for location (only initial load).
        # So I MUST send a broadcast. 
        
        # Allow me to update the Python script to use the PROPER broadcast method if available,
        # or fallback to DB update and change Flutter to listen to DB changes too?
        # "High Frequency" plan said Broadcast.
        
        # Workaround: For the simulation, let's UPDATE the DB row 
        # AND have Flutter listen to Postgres Changes for location too (as a backup/easier test).
        
        channel = supabase.channel(f'tracking:{ORDER_ID}')
        channel.send_broadcast('location_update', {'lat': current_lat, 'lng': current_lng})
        
        # Also update DB for persistence
        if i % 10 == 0:
             supabase.table('deliveries').update({
                 'current_lat': current_lat,
                 'current_lng': current_lng,
                 'updated_at': 'now()'
             }).eq('order_id', ORDER_ID).execute()

        time.sleep(1) # 1 update per second

if __name__ == "__main__":
    # Just a placeholder, user needs to run this manually with a valid ID
    print("Please edit the script with a valid ORDER_ID before running.")
