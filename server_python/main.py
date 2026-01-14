from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import supabase
from deps import get_current_user

app = FastAPI()

# Allow CORS for Flutter Web/Client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow all origins for dev
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Manda.AI Backend is running"}

class OrderRequest(BaseModel):
    table_id: str | None = None
    items: list
    total: float

@app.post("/orders")
def place_order(order: OrderRequest):
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        establishment_id = None
        
        # 1. Try to get Establishment from Table if provided
        # 1. Try to get Establishment from Table if provided
        if order.table_id:
             # Handle short "Table Number" (e.g. "5")
            if len(order.table_id) < 10:
                print(f"Resolving Table Number: {order.table_id}")
                # Try finding the table by number. Note: table_number might be "05" or "5".
                # We'll try exact match first.
                table_res = supabase.table("tables").select("id, establishment_id").eq("table_number", order.table_id).execute()
                
                # If not found, try padding with 0 (e.g. "5" -> "05")
                if not table_res.data and len(order.table_id) == 1:
                     padded = f"0{order.table_id}"
                     table_res = supabase.table("tables").select("id, establishment_id").eq("table_number", padded).execute()
                     
                if table_res.data:
                    print(f"Resolved to UUID: {table_res.data[0]['id']}")
                    order.table_id = table_res.data[0]['id'] # Replace with real UUID
                    establishment_id = table_res.data[0]['establishment_id']
                else:
                    print(f"Table {order.table_id} not found. Falling back to Delivery Mode.")
                    order.table_id = None # Invalid table number -> convert to Delivery
            else:
                # UUID provided
                try:
                    table_res = supabase.table("tables").select("establishment_id").eq("id", order.table_id).execute()
                    if table_res.data:
                        establishment_id = table_res.data[0]['establishment_id']
                except Exception as e:
                     print(f"Error querying table UUID: {e}")
                     order.table_id = None
        
        # 2. Fallback / Default logic (for Delivery or invalid table)
        if not establishment_id:
             # Just grab the first establishment (Dev mode shortcut)
             # In production, we should probably require establishment_id in the request
             est_res = supabase.table("establishments").select("id").limit(1).execute()
             if est_res.data:
                 establishment_id = est_res.data[0]['id']
        
        if not establishment_id:
             raise HTTPException(status_code=400, detail="Invalid Establishment (No default found)")

        # 3. Create Order
        order_data = {
            "establishment_id": establishment_id,
            "table_id": order.table_id, # Can be None
            "total_amount": order.total,
            "status": "pending"
        }
        
        new_order = supabase.table("orders").insert(order_data).execute()
        order_id = new_order.data[0]['id']

        # 3. Create Order Items
        items_data = []
        for item in order.items:
            items_data.append({
                "order_id": order_id,
                "product_id": item['product_id'],
                "quantity": item['quantity'],
                "unit_price": item['price'], # Map frontend 'price' to DB 'unit_price'
                "notes": item.get('notes')
            })
        
        if items_data:
            supabase.table("order_items").insert(items_data).execute()

        # 4. Auto-Create Delivery Request if it's a Delivery Order (No Table)
        if not order.table_id:
             delivery_data = {
                 "order_id": order_id,
                 "status": "open",
                 "current_lat": 38.7223, # Shop location
                 "current_lng": -9.1393 
             }
             supabase.table("deliveries").insert(delivery_data).execute()

        return {"status": "success", "order_id": order_id}

    except Exception as e:
        print(f"Error placing order: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- KDS ENDPOINTS ---

@app.get("/kds/orders")
def get_kds_orders(user = Depends(get_current_user)):
    """Fetch active orders for the Kitchen Display System (pending or prep). Requires Auth."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    # Optional: Check if user belongs to the establishment (future improvement)
    # est_id = user.user_metadata.get('establishment_id')

    try:
        # Fetch orders with status 'pending' or 'prep'
        # We fetch related items and products for display
        response = supabase.table('orders') \
            .select('*, tables(table_number), order_items(*, products(name))') \
            .or_('status.eq.pending,status.eq.prep') \
            .order('created_at', desc=False) \
            .execute()
            
        return response.data
    except Exception as e:
        print(f"Error fetching KDS orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class StatusUpdateRequests(BaseModel):
    status: str

@app.patch("/kds/orders/{order_id}")
def update_order_status(order_id: str, request: StatusUpdateRequests, user = Depends(get_current_user)):
    """Update order status (e.g. pending -> prep -> ready). Requires Auth."""
    if not supabase:
         raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        response = supabase.table('orders') \
            .update({'status': request.status}) \
            .eq('id', order_id) \
            .execute()
            
        return {"status": "success", "data": response.data}
    except Exception as e:
        print(f"Error updating status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- ADMIN ENDPOINTS ---

class ProductRequest(BaseModel):
    name: str
    description: str | None = None
    price: float
    image_url: str | None = None
    category_id: str | None = None
    is_available: bool = True

@app.post("/admin/products")
def create_product(product: ProductRequest): # Add Auth dependency later
    """Create a new product. Admin only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # 1. Get Establishment (Mock for now, or use first one)
        est_res = supabase.table("establishments").select("id").limit(1).execute()
        est_id = est_res.data[0]['id'] if est_res.data else None
        
        if not est_id:
             raise HTTPException(status_code=400, detail="No establishment found")

        data = product.dict()
        data['establishment_id'] = est_id
        
        response = supabase.table("products").insert(data).execute()
        return {"status": "success", "data": response.data}
    except Exception as e:
        print(f"Error creating product: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/admin/products/{product_id}")
def update_product(product_id: str, product: ProductRequest): # Add Auth dependency later
    """Update an existing product. Admin only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        print(f"DEBUG UPDATE: {product_id} with {product}")
        payload = product.dict(exclude_unset=True)
        print(f"DEBUG PAYLOAD: {payload}")
        response = supabase.table("products").update(payload).eq("id", product_id).execute()
        return {"status": "success", "data": response.data}
    except Exception as e:
        print(f"Error updating product: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/admin/products/{product_id}")
def delete_product(product_id: str): # Add Auth dependency later
    """Delete a product. Admin only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # Soft delete is better, but user asked for delete. Using hard delete for now.
        response = supabase.table("products").delete().eq("id", product_id).execute()
        return {"status": "success", "data": response.data}
    except Exception as e:
        print(f"Error deleting product: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/stats/sales")
def get_sales_stats(period: str = 'daily'):
    """Fetch sales stats aggregated by period (daily, weekly, monthly)."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        now = datetime.now()
        data_points = []
        
        if period == 'daily':
            # Last 24 hours or "Today"
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
            response = supabase.table('orders').select('created_at, total_amount').gte('created_at', start_date.isoformat()).execute()
            
            # Aggregate by hour
            hourly_data = {i: 0.0 for i in range(24)}
            for order in response.data:
                # Handle Z timezone or offset if present
                ts = order['created_at'].replace('Z', '+00:00')
                dt = datetime.fromisoformat(ts)
                hourly_data[dt.hour] += order['total_amount']
            
            data_points = [{"label": f"{h}h", "value": hourly_data[h]} for h in range(24)]

        elif period == 'weekly':
            # Last 7 days
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=6)
            response = supabase.table('orders').select('created_at, total_amount').gte('created_at', start_date.isoformat()).execute()
            
            daily_data = {} 
            for i in range(7):
                 d = start_date + timedelta(days=i)
                 daily_data[d.strftime('%Y-%m-%d')] = 0.0

            for order in response.data:
                ts = order['created_at'].replace('Z', '+00:00')
                dt = datetime.fromisoformat(ts)
                key = dt.strftime('%Y-%m-%d')
                if key in daily_data:
                    daily_data[key] += order['total_amount']
            
            data_points = []
            for date_str, total in daily_data.items():
                dt = datetime.strptime(date_str, '%Y-%m-%d')
                data_points.append({"label": dt.strftime('%a'), "value": total})

        elif period == 'monthly':
             # Last 30 days
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=29)
            response = supabase.table('orders').select('created_at, total_amount').gte('created_at', start_date.isoformat()).execute()
            
            daily_data = {}
            for i in range(30):
                 d = start_date + timedelta(days=i)
                 daily_data[d.strftime('%Y-%m-%d')] = 0.0

            for order in response.data:
                 ts = order['created_at'].replace('Z', '+00:00')
                 dt = datetime.fromisoformat(ts)
                 key = dt.strftime('%Y-%m-%d')
                 if key in daily_data:
                     daily_data[key] += order['total_amount']
            
            data_points = [{"label": date_str[8:], "value": total} for date_str, total in daily_data.items()] # label = day part only

        return data_points

    except Exception as e:
        print(f"Error fetching stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/stats/top_products")
def get_top_products(limit: int = 5):
    """Fetch top selling products based on order_items."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # Fetch all order items and their related product names
        # Note: In a real production DB, this should be a SQL view or RPC for performance.
        # For now, we fetch and aggregate in Python.
        response = supabase.table('order_items').select('product_id, quantity, products(name, price)').execute()
        
        product_sales = {}
        
        for item in response.data:
            pid = item['product_id']
            qty = item['quantity']
            product_name = item['products']['name'] if item.get('products') else 'Unknown'
            # price = item['products']['price'] # Not strictly needed if we sort by qty
            
            if pid not in product_sales:
                product_sales[pid] = {'name': product_name, 'quantity': 0, 'revenue': 0.0}
            
            product_sales[pid]['quantity'] += qty
            # We could add revenue here if we had unit_price history or average
        
        # Sort by quantity desc
        sorted_products = sorted(product_sales.values(), key=lambda x: x['quantity'], reverse=True)
        
        return sorted_products[:limit]

    except Exception as e:
        print(f"Error fetching top products: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DELIVERY ENDPOINTS ---

class DeliveryRequest(BaseModel):
    order_id: str
    driver_name: str | None = None # If None, it goes to Pool
    driver_id: str | None = None

@app.post("/admin/deliveries/assign")
def assign_delivery(req: DeliveryRequest):
    """Create a delivery. If driver_id/name is missing, it's an OPEN request (Pool)."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # Check if already assigned
        existing = supabase.table('deliveries').select('id').eq('order_id', req.order_id).execute()
        if existing.data:
            return {"status": "exists", "delivery_id": existing.data[0]['id']}

        # Create new delivery
        status = "open" if not req.driver_name and not req.driver_id else "assigned"
        
        data = {
            "order_id": req.order_id,
            "driver_name": req.driver_name, # Can be null
            "driver_id": req.driver_id,     # Can be null
            "status": status,
            # Start at shop location (mock Lisbon)
            "current_lat": 38.7223,
            "current_lng": -9.1393 
        }
        res = supabase.table('deliveries').insert(data).execute()
        return {"status": "success", "delivery_id": res.data[0]['id']}
    except Exception as e:
        print(f"Error assigning delivery: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/driver/deliveries/{delivery_id}/accept")
def accept_delivery(delivery_id: str, user = Depends(get_current_user)):
    """Driver accepts an open delivery."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # UserResponse wrapper handling
        driver_id = user.user.id if hasattr(user, 'user') else user.id
        
        # Get driver name from profile safely
        driver_name = "Unknown Driver"
        try:
            profile = supabase.table('profiles').select('full_name').eq('id', driver_id).single().execute()
            if profile.data:
                driver_name = profile.data.get('full_name') or "Driver"
        except Exception:
             print("Profile not found for driver, using default.")
             # Fallback if profile doesn't exist
             pass

        # 1. Check if available
        existing = supabase.table('deliveries').select('driver_id, status').eq('id', delivery_id).single().execute()
        if not existing.data:
             raise HTTPException(status_code=404, detail="Delivery not found")
        
        if existing.data.get('driver_id') is not None:
             raise HTTPException(status_code=400, detail="Delivery already taken")

        # 2. Update
        res = supabase.table('deliveries').update({
            "driver_id": driver_id,
            "driver_name": driver_name,
            "status": "assigned"
        }).eq('id', delivery_id).execute()
        
        return {"status": "success", "message": "Delivery accepted"}

    except Exception as e:
        print(f"Error accepting delivery: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/admin/deliveries/simulate/{order_id}")
async def simulate_delivery_endpoint(order_id: str):
    """Trigger the background simulation script for a specific order."""
    import subprocess
    import sys
    import os
    
    # We run the script as a separate process to not block the API
    # This is a simple dev-mode way to do background tasks
    try:
        # Pass the ORDER_ID as an env var or argument to the script
        # We need to modify the script to accept args or use this env idea
        
        # Actually simplest is just to run the script and let it use the arg
        # But our script currently has a hardcoded placeholder.
        # Let's update the script to read from sys.argv first? 
        # Or better, we just spawn it with an env var.
        
        env = os.environ.copy()
        env["SIMULATE_ORDER_ID"] = order_id
        
        # Assuming simulate_driver.py is in the same dir
        script_path = "simulate_driver.py"
        
        subprocess.Popen([sys.executable, script_path], env=env, cwd=os.getcwd())
        
        return {"status": "started", "message": f"Simulation started for {order_id}"}
    except Exception as e:
        print(f"Error starting simulation: {e}")
        raise HTTPException(status_code=500, detail=str(e))
