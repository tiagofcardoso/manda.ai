from database import supabase
import json

def check_tables():
    if not supabase:
        print("Supabase not configured")
        return

    try:
        print("--- TABLES ---")
        # Fetch one table to see structure
        res = supabase.table("tables").select("*").limit(1).execute()
        print(json.dumps(res.data, indent=2))

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_tables()
