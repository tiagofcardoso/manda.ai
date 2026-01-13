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
            .select('*, order_items(*, products(name))') \
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
