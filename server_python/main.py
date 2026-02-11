import json
import re
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import supabase, supabase_admin
from deps import get_current_user, get_current_admin, get_current_driver, get_current_super_admin

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
    user_id: str | None = None # Optional for logged-in users

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
        "user_id": order.user_id # Can be null or user_id
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
def get_kds_orders(admin = Depends(get_current_admin)):
    """Fetch active orders for the Kitchen Display System (pending or prep). Requires Auth."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        query = supabase.table('orders').select('*, tables(table_number), order_items(*, products(name))')
        
        # Filter by establishment if set
        if establishment_id:
            query = query.eq('establishment_id', establishment_id)
        
        response = query.or_('status.eq.pending,status.eq.prep').order('created_at', desc=False).execute()
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
    custom_category: str | None = None  # New field for user-defined categories
    is_available: bool = True

@app.post("/admin/products")
def create_product(product: ProductRequest, admin = Depends(get_current_admin)):
    """Create a new product. Admin only."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        if not establishment_id:
            raise HTTPException(status_code=400, detail="No establishment context. Please select an establishment.")

        data = product.dict()
        data['establishment_id'] = establishment_id
        
        response = supabase.table('products').insert(data).execute()
        return response.data[0]
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

# --- ADMIN SETTINGS ---

class CurrencyUpdateRequest(BaseModel):
    currency: str

@app.patch("/admin/settings/currency")
def update_currency(request: CurrencyUpdateRequest, admin = Depends(get_current_admin)):
    """Update establishment currency setting. Admin only."""
    user, establishment_id = admin  # Unpack admin context
    
    print(f"🔄 Currency Update Request: {request.currency}")
    print(f"👤 User: {user}")
    print(f"🏢 Establishment ID: {establishment_id}")
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    # Validate currency code (3 uppercase letters)
    import re
    if not re.match(r'^[A-Z]{3}$', request.currency):
        print(f"❌ Invalid currency format: {request.currency}")
        raise HTTPException(status_code=400, detail="Invalid currency code. Must be 3 uppercase letters (e.g., EUR, USD, BRL)")
    
    if not establishment_id:
        print(f"❌ No establishment assigned")
        raise HTTPException(status_code=403, detail="No establishment assigned")
    
    try:
        # Update currency in establishments table
        print(f"💾 Updating establishment {establishment_id} to currency {request.currency}")
        response = supabase.table('establishments').update({
            'currency': request.currency
        }).eq('id', establishment_id).execute()
        
        print(f"✅ Currency updated successfully: {response.data}")
        return {"message": "Currency updated successfully", "currency": request.currency}
    except Exception as e:
        print(f"❌ Error updating currency: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/admin/stats/sales")
def get_sales_stats(period: str = 'daily', admin = Depends(get_current_admin)):
    """Fetch sales stats aggregated by period (daily, weekly, monthly)."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        now = datetime.now()
        data_points = []
        
        if period == 'daily':
            # Last 24 hours or "Today"
            start_date = now.replace(hour=0, minute=0, second=0, microsecond=0)
            query = supabase.table('orders').select('created_at, total_amount').gte('created_at', start_date.isoformat())
            if establishment_id:
                query = query.eq('establishment_id', establishment_id)
            response = query.execute()
            
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
def get_top_products(limit: int = 5, admin = Depends(get_current_admin)):
    """Fetch top selling products based on order_items."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")

    try:
        # Fetch order items filtered by establishment through products relationship
        # First get products for this establishment, then their order items
        if establishment_id:
            # Filter by establishment: get order_items where product.establishment_id matches
            response = supabase.table('order_items').select('product_id, quantity, products!inner(name, price, establishment_id)').eq('products.establishment_id', establishment_id).execute()
        else:
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
    admin = Depends(get_current_admin)
):
    """Fetch all orders with filters. Admin only."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        # Build query with joins for related data
        query = supabase.table('orders').select(
            '*, order_items(*, products(name, price, image_url)), tables(table_number)'
        )
        
        # Apply establishment filter
        if establishment_id:
            query = query.eq('establishment_id', establishment_id)

        # Apply other filters
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
def get_admin_order_detail(order_id: str, admin = Depends(get_current_admin)):
    """Get detailed information about a specific order. Admin only."""
    user, establishment_id = admin  # Unpack admin context
    
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
def get_today_stats(admin = Depends(get_current_admin)):
    """Get quick stats for today only."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        now = datetime.now()
        start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
        
        query = supabase.table('orders').select('status, total_amount').gte('created_at', start_of_day.isoformat())
        
        # Filter by establishment if set
        if establishment_id:
            query = query.eq('establishment_id', establishment_id)
        
        response = query.execute()
        orders = response.data
        total_orders = len(orders)
        total_revenue = sum(float(o.get('total_amount', 0)) for o in orders)
        
        # Count by status
        pending = sum(1 for o in orders if o.get('status') == 'pending')
        prep = sum(1 for o in orders if o.get('status') == 'prep')
        ready = sum(1 for o in orders if o.get('status') == 'ready')
        delivered = sum(1 for o in orders if o.get('status') == 'delivered')
        
        return {
            "total_orders": total_orders,
            "total_revenue": total_revenue,
            "delivery_count": delivered,
            "kitchen_count": pending + prep
        }
    except Exception as e:
        print(f"Error fetching today stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/stats/orders-by-status")
def get_orders_by_status(admin = Depends(get_current_admin)):
    """Get count of orders by status."""
    user, establishment_id = admin  # Unpack admin context
    
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        # Fetch orders filtered by establishment
        query = supabase.table('orders').select('status')
        if establishment_id:
            query = query.eq('establishment_id', establishment_id)
        response = query.execute()
        
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
def assign_delivery(req: DeliveryRequest, admin = Depends(get_current_admin)):
    """Create a delivery. If driver_id/name is missing, it's an OPEN request (Pool)."""
    user, establishment_id = admin  # Unpack admin context
    
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

# ============================================================================
# ADMIN USER MANAGEMENT
# ============================================================================

class CreateAdminRequest(BaseModel):
    email: str
    establishment_id: str
    full_name: str | None = None
    phone_number: str | None = None
    password: str | None = None          # NEW
    establishment_name: str | None = None # NEW

@app.post("/admin/create-establishment-admin")
async def create_establishment_admin(
    request: CreateAdminRequest, 
    user = Depends(get_current_super_admin)
):
    """
    Creates a new admin user with temporary password.
    Only accessible by Super Admins.
    
    Flow:
    1. Checks if user exists
    2. If not, creates user with provided or temp password
    3. Assigns admin role and establishment via RPC
    4. Returns temp credentials
    """
    if not supabase_admin:
        raise HTTPException(status_code=500, detail="Admin client not configured")
    
    email = request.email.strip().lower()
    establishment_id = request.establishment_id
    temp_password = request.password if request.password else "Manda2024!"
    
    try:
        # 1. Check if user already exists
        # NOTE: supabase_admin.auth.admin.list_users() can be slow if many users, 
        # but for now it's okay. Better to use get_user_by_email if available but it's not exposed in python sdk easily
        existing_users = supabase_admin.auth.admin.list_users()
        user_exists = any(u.email == email for u in existing_users)
        
        user_id = None
        
        if not user_exists:
            # 2. Create new user with password
            print(f"Creating new admin user: {email}")
            create_response = supabase_admin.auth.admin.create_user({
                "email": email,
                "password": temp_password,
                "email_confirm": True
            })
            
            # The structure of create_response might differ based on SDK version
            # Usually create_response.user.id
            if hasattr(create_response, 'user') and create_response.user:
                user_id = create_response.user.id
            elif hasattr(create_response, 'id'):
                user_id = create_response.id
            else:
                 # Fallback for some versions
                 user_id = getattr(create_response, 'id', None)

            print(f"User created with ID: {user_id}")
        else:
            # Get existing user ID
            for u in existing_users:
                if u.email == email:
                    user_id = u.id
                    break
        
        if not user_id:
            raise HTTPException(status_code=500, detail="Failed to retrieve User ID")
            
        # 3. Assign establishment and role via RPC
        # RPC allows us to safely update the profile without RLS issues
        try:
            rpc_response = supabase_admin.rpc(
                'assign_establishment_admin', 
                {
                    'p_email': email, 
                    'p_establishment_id': establishment_id,
                    'p_custom_password': temp_password,
                    'p_establishment_name': request.establishment_name
                }
            ).execute()
            data = rpc_response.data
        except Exception as rpc_error:
            print(f"RPC Error: {rpc_error}")
            # Try to parse error if it's a JSON string in the exception message
            # logic same as before...
            # --------------------------------------------------------------------------------
            # Handle APIError (e.g. from postgrest-py) on success (code 200)
            # --------------------------------------------------------------------------------
            recovered_data = None
            
            # Check for APIError/code attribute
            code = getattr(rpc_error, 'code', None)
            details = getattr(rpc_error, 'details', None)

            if str(code) == '200' and details:
                # This happens when postgrest-py fails to interpret the response body (e.g. invalid content-type)
                # but the request was actually successful.
                # The 'details' is often the response body (bytes or string).
                try:
                     import json
                     # If it's bytes or b'...' string representation, handle it?
                     # Usually it is a string.
                     if isinstance(details, bytes):
                        details_str = details.decode('utf-8')
                     else:
                        details_str = str(details)
                     
                     # Simple heuristics to clean up b'...' representation if present in string
                     if details_str.startswith("b'") and details_str.endswith("'"):
                         details_str = details_str[2:-1]
                         # Unescape escaped quotes if needed
                         details_str = details_str.replace('\\"', '"').replace("\\'", "'")
                     
                     recovered_data = json.loads(details_str)
                     print(f"Recovered success data from APIError: {recovered_data}")
                except Exception as parse_err:
                     print(f"Failed to parse APIError details: {parse_err}")
            
            if recovered_data:
                data = recovered_data
            else:
                # Fallback to old string parsing logic just in case
                import json
                error_str = str(rpc_error)
                recovered_fallback = None
                
                if "{" in error_str:
                    try:
                        start = error_str.find("{")
                        end = error_str.rfind("}") + 1
                        json_str = error_str[start:end]
                        # Attempt cleanup of escaped quotes
                        candidates = [
                             json_str,
                             json_str.replace('\\"', '"'),
                             json_str.replace('\\"', '"').replace("\\'", "'")
                        ]
                        for c in candidates:
                             try:
                                 parsed = json.loads(c)
                                 if isinstance(parsed, dict) and "status" in parsed:
                                     recovered_fallback = parsed
                                     break
                             except:
                                 continue
                    except:
                        pass
                
                if recovered_fallback:
                    data = recovered_fallback
                else:
                    raise rpc_error

        # Handle list response
        if isinstance(data, list) and len(data) > 0:
            data = data[0]
            
        if data and (data.get('status') == 'success' or data.get('status') == 'create_required'):
            
            # UPDATE PROFILE if name/phone provided
            if user_id and (request.full_name or request.phone_number):
                try:
                    profile_update = {}
                    if request.full_name:
                        profile_update['full_name'] = request.full_name
                    if request.phone_number:
                        profile_update['phone_number'] = request.phone_number
                    
                    print(f"Updating admin profile for {user_id}: {profile_update}")
                    supabase_admin.from_('profiles').update(profile_update).eq('id', user_id).execute()
                except Exception as pe:
                    print(f"WARNING: Failed to update admin profile: {pe}")

            return {
                "status": "success",
                "message": f"Admin {'created' if not user_exists else 'updated'} successfully",
                "email": email,
                "temp_password": temp_password if not user_exists else None,
                "user_id": user_id,
                "user_existed": user_exists,
                "rpc_response": data
            }
        else:
             error_msg = data.get('message') if data else 'Unknown RPC handling error'
             print(f"RPC Error Data: {data}")
             raise HTTPException(status_code=500, detail=f"Failed to assign admin: {error_msg}")

    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error creating admin: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/establishment-admin/{establishment_id}")
async def get_establishment_admin(
    establishment_id: str,
    user = Depends(get_current_super_admin)
):
    """
    Fetches the admin user info (email) for a specific establishment.
    """
    if not supabase_admin:
        raise HTTPException(status_code=500, detail="Admin client not configured")
        
    try:
        # 1. Find the profile with role 'admin' for this establishment
        # Note: We assume only one admin per establishment for now, or take the first one
        response = supabase_admin.from_('profiles')\
            .select('id, full_name, phone_number')\
            .eq('establishment_id', establishment_id)\
            .eq('role', 'admin')\
            .execute()
            
        profiles = response.data
        if not profiles:
             return {"email": None, "full_name": None, "phone_number": None}
             
        # 2. Get the user email from auth admin
        admin_profile = profiles[0]
        user_id = admin_profile['id']
        
        user_info = supabase_admin.auth.admin.get_user_by_id(user_id)
        
        return {
            "email": user_info.user.email,
            "full_name": admin_profile.get('full_name'),
            "phone_number": admin_profile.get('phone_number')
        }
        
    except Exception as e:
        print(f"Error fetching establishment admin: {e}")
        # Don't fail the UI if we can't find the admin, just return empty
        return {"email": None, "error": str(e)}

# Add Logging Middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {request.method} {request.url.path}")
    response = await call_next(request)
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Completed {response.status_code}")
    return response

@app.delete("/admin/establishments/{establishment_id}")
async def delete_establishment(
    establishment_id: str,
    user = Depends(get_current_super_admin)
):
    """
    Deletes an establishment and unlinks all associated users.
    Checks for pending orders first.
    Only accessible by Super Admins.
    """
    if not supabase_admin:
        raise HTTPException(status_code=500, detail="Admin client not configured")
        
    try:
        print(f"Super Admin {user.user.email} requesting deletion of establishment {establishment_id}")
        
        # 0. Check for PENDING orders
        # We consider pending if status is NOT 'completed' or 'cancelled' or 'rejected'
        pending_orders = supabase_admin.from_('orders')\
            .select('id', count='exact')\
            .eq('establishment_id', establishment_id)\
            .not_.in_('status', ['completed', 'cancelled', 'rejected'])\
            .execute()
            
        if pending_orders.count and pending_orders.count > 0:
            return JSONResponse(
                status_code=409, 
                content={
                    "status": "error", 
                    "code": "PENDING_ORDERS", 
                    "message": f"There are {pending_orders.count} active orders.",
                    "count": pending_orders.count
                }
            )

        # 1. CLEANUP DATA (Manual Cascade)
        # We need to delete data in order to avoid FK violations (deliveries -> orders -> establishment)
        
        # Get all order IDs for this establishment
        orders_res = supabase_admin.from_('orders').select('id').eq('establishment_id', establishment_id).execute()
        order_ids = [o['id'] for o in orders_res.data]
        
        if order_ids:
            # Delete Deliveries linked to these orders
            supabase_admin.from_('deliveries').delete().in_('order_id', order_ids).execute()
            # Delete Order Items linked to these orders
            supabase_admin.from_('order_items').delete().in_('order_id', order_ids).execute()
            # Delete Orders
            supabase_admin.from_('orders').delete().in_('id', order_ids).execute()
            
        # Delete Products, Categories, Tables (usually have FK cascade to establishment, but let's be safe)
        supabase_admin.from_('products').delete().eq('establishment_id', establishment_id).execute()
        supabase_admin.from_('categories').delete().eq('establishment_id', establishment_id).execute()
        supabase_admin.from_('tables').delete().eq('establishment_id', establishment_id).execute()

        # 2. Unlink all profiles associated with this establishment
        supabase_admin.from_('profiles')\
            .update({'establishment_id': None})\
            .eq('establishment_id', establishment_id)\
            .execute()
            
        # 3. Delete the establishment
        delete_response = supabase_admin.from_('establishments')\
            .delete()\
            .eq('id', establishment_id)\
            .execute()
            
        print(f"Deleted establishment response: {delete_response}")
        
        return {"status": "success", "message": "Establishment deleted successfully"}
        
    except Exception as e:
        print(f"Error deleting establishment: {e}")
        # If we caught the 409 above, it's already returned. This catches unexpected errors.
        raise HTTPException(status_code=500, detail=str(e))
