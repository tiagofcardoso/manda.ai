from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import supabase
from deps import get_current_user, get_current_admin, get_current_driver

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

class TableOrderRequest(BaseModel):
    table_id: str
    items: list
    total: float
    # No user_id or address required for Table/Guest

class DeliveryOrderRequest(BaseModel):
    items: list
    total: float
    user_id: str
    delivery_address: str
    # No table_id allowed

@app.post("/orders/table")
def place_table_order(order: TableOrderRequest):
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    # 1. Validate Table
    establishment_id = None
    final_table_id = None
    
    if len(order.table_id) < 10:
        # Resolve short number
        print(f"Resolving Table Number: {order.table_id}")
        table_res = supabase.table("tables").select("id, establishment_id").eq("table_number", order.table_id).execute()
        if not table_res.data and len(order.table_id) == 1:
            padded = f"0{order.table_id}"
            table_res = supabase.table("tables").select("id, establishment_id").eq("table_number", padded).execute()
            
        if table_res.data:
            final_table_id = table_res.data[0]['id']
            establishment_id = table_res.data[0]['establishment_id']
        else:
             raise HTTPException(status_code=400, detail="Invalid Table Number")
    else:
        # UUID
        final_table_id = order.table_id
        try:
            table_res = supabase.table("tables").select("establishment_id").eq("id", final_table_id).execute()
            if table_res.data:
                establishment_id = table_res.data[0]['establishment_id']
        except Exception:
             pass

    if not establishment_id:
         raise HTTPException(status_code=400, detail="Invalid Table/Establishment")

    # 2. Create Order (Dine-In)
    order_data = {
        "establishment_id": establishment_id,
        "table_id": final_table_id,
        "order_type": "dine_in", # Explicit Flag
        "total_amount": order.total,
        "status": "pending",
        # user_id is null for guests
    }
    
    new_order = supabase.table("orders").insert(order_data).execute()
    order_id = new_order.data[0]['id']

    # 3. Create Items
    _insert_order_items(order_id, order.items)

    return {"status": "success", "order_id": order_id, "type": "dine_in"}

@app.post("/orders/delivery")
def place_delivery_order(order: DeliveryOrderRequest):
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    # 1. Validate Establishment (Default for now)
    est_res = supabase.table("establishments").select("id").limit(1).execute()
    establishment_id = est_res.data[0]['id'] if est_res.data else None
    
    if not establishment_id:
         raise HTTPException(status_code=500, detail="No Establishment Configured")

    # 2. Create Order (Delivery)
    order_data = {
        "establishment_id": establishment_id,
        "user_id": order.user_id,
        "order_type": "delivery", # Explicit Flag
        "total_amount": order.total,
        "status": "pending",
        "delivery_address": order.delivery_address
    }
    
    new_order = supabase.table("orders").insert(order_data).execute()
    order_id = new_order.data[0]['id']

    # 3. Create Items
    _insert_order_items(order_id, order.items)

    # 4. Trigger Delivery Logic (Driver Assignment)
    delivery_data = {
        "order_id": order_id,
        "status": "open",
        "address": order.delivery_address,
        "current_lat": 38.7223,
        "current_lng": -9.1393 
    }
    supabase.table("deliveries").insert(delivery_data).execute()

    return {"status": "success", "order_id": order_id, "type": "delivery"}

def _insert_order_items(order_id, items):
    items_data = []
    for item in items:
        items_data.append({
            "order_id": order_id,
            "product_id": item['product_id'],
            "quantity": item['quantity'],
            "unit_price": item['price'],
            "notes": item.get('notes')
        })
    
    if items_data:
        supabase.table("order_items").insert(items_data).execute()

# Kept for backward compatibility if needed, but deprecated
@app.post("/orders") 
def place_order_legacy(order: dict):
    raise HTTPException(status_code=410, detail="Endpoint Deprecated. Use /orders/table or /orders/delivery")



# --- KDS ENDPOINTS ---

@app.get("/kds/orders")
def get_kds_orders(user = Depends(get_current_admin)):
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
def update_order_status(order_id: str, request: StatusUpdateRequests, user = Depends(get_current_admin)):
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
def create_product(product: ProductRequest, user = Depends(get_current_admin)): # Admin only
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
def update_product(product_id: str, product: ProductRequest, user = Depends(get_current_admin)): # Admin only
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
def delete_product(product_id: str, user = Depends(get_current_admin)): # Admin only
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
def get_sales_stats(period: str = 'daily', user = Depends(get_current_admin)):
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
def get_top_products(limit: int = 5, user = Depends(get_current_admin)):
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

# --- ADMIN ORDER MANAGEMENT ENDPOINTS ---

@app.get("/admin/orders")
def get_admin_orders(
    status: str | None = None,
    order_type: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    limit: int = 100,
    user = Depends(get_current_admin)
):
    """Fetch all orders with filters. Admin only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        # Build query with joins for related data
        # Note: Removed profiles join because many orders don't have user_id (guest/table orders)
        query = supabase.table('orders').select(
            '*, order_items(*, products(name, price, image_url)), tables(table_number)'
        )
        
        # Apply filters
        if status:
            query = query.eq('status', status)
        if order_type:
            query = query.eq('order_type', order_type)
        if date_from:
            query = query.gte('created_at', date_from)
        if date_to:
            query = query.lte('created_at', date_to)
        
        # Order by most recent first
        query = query.order('created_at', desc=True).limit(limit)
        response = query.execute()
        
        # Optionally fetch user info separately for orders that have user_id
        orders = response.data
        for order in orders:
            if order.get('user_id'):
                try:
                    profile = supabase.table('profiles').select('full_name, email').eq('id', order['user_id']).single().execute()
                    order['profiles'] = profile.data if profile.data else None
                except:
                    order['profiles'] = None
            else:
                order['profiles'] = None
        
        return orders
    except Exception as e:
        print(f"Error fetching admin orders: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/orders/{order_id}")
def get_admin_order_detail(order_id: str, user = Depends(get_current_admin)):
    """Get detailed information about a specific order. Admin only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        response = supabase.table('orders').select(
            '*, order_items(*, products(name, price, image_url)), tables(table_number), deliveries(*)'
        ).eq('id', order_id).single().execute()
        
        order = response.data
        
        # Fetch profile separately if user_id exists
        if order.get('user_id'):
            try:
                profile = supabase.table('profiles').select('full_name, email, phone_number').eq('id', order['user_id']).single().execute()
                order['profiles'] = profile.data if profile.data else None
            except:
                order['profiles'] = None
        else:
            order['profiles'] = None
        
        return order
    except Exception as e:
        print(f"Error fetching order detail: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=404, detail="Order not found")

@app.get("/admin/stats/today")
def get_today_stats(user = Depends(get_current_admin)):
    """Get quick stats for today only."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        now = datetime.now()
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        
        # Fetch today's orders
        response = supabase.table('orders').select('status, total_amount').gte('created_at', start_of_day.isoformat()).execute()
        
        orders = response.data
        total_orders = len(orders)
        total_revenue = sum(order['total_amount'] for order in orders)
        
        # Count by status
        active_orders = len([o for o in orders if o['status'] in ['pending', 'prep', 'ready', 'on_way']])
        completed_orders = len([o for o in orders if o['status'] in ['delivered', 'completed']])
        
        avg_order_value = total_revenue / total_orders if total_orders > 0 else 0.0
        
        return {
            "total_orders": total_orders,
            "total_revenue": round(total_revenue, 2),
            "active_orders": active_orders,
            "completed_orders": completed_orders,
            "avg_order_value": round(avg_order_value, 2)
        }
    except Exception as e:
        print(f"Error fetching today stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/stats/orders-by-status")
def get_orders_by_status(user = Depends(get_current_admin)):
    """Get count of orders by status."""
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        # Fetch all orders (or recent ones)
        response = supabase.table('orders').select('status').execute()
        
        orders = response.data
        status_counts = {}
        
        for order in orders:
            status = order['status']
            status_counts[status] = status_counts.get(status, 0) + 1
        
        return status_counts
    except Exception as e:
        print(f"Error fetching orders by status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DELIVERY ENDPOINTS ---

class DeliveryRequest(BaseModel):
    order_id: str
    driver_name: str | None = None # If None, it goes to Pool
    driver_id: str | None = None

@app.post("/admin/deliveries/assign")
def assign_delivery(req: DeliveryRequest, user = Depends(get_current_admin)):
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
def accept_delivery(delivery_id: str, user = Depends(get_current_driver)):
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
