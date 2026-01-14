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
    table_id: str
    items: list
    total: float

@app.post("/orders")
def place_order(order: OrderRequest):
    if not supabase:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    
    try:
        # 1. Get Establishment ID from Table ID
        # (In a real app, we'd cache this or send it from frontend)
        table_res = supabase.table("tables").select("establishment_id").eq("id", order.table_id).execute()
        
        # Fallback for dev: if table lookup fails (e.g. using dummy ID), try to get ANY establishment
        establishment_id = None
        if table_res.data:
             establishment_id = table_res.data[0]['establishment_id']
        else:
             # AUTO-FIX for Dev: Just grab the first establishment
             est_res = supabase.table("establishments").select("id").limit(1).execute()
             if est_res.data:
                 establishment_id = est_res.data[0]['id']
        
        if not establishment_id:
             raise HTTPException(status_code=400, detail="Invalid Table/Establishment")

        # 2. Create Order
        order_data = {
            "establishment_id": establishment_id,
            "table_id": order.table_id if table_res.data else None, # Nullable if pseudo-table
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
