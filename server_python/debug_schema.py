from database import supabase
import datetime

def test_insert():
    if not supabase:
        print("Supabase not connected")
        return

    print("--- Testing String Category ---")
    try:
        data = {
            "name": "Test String Cat",
            "price": 10.0,
            "category_id": "test_string",
            "establishment_id": 1 # Assuming 1 exists or is optional? 
            # Note: real code fetches establishment first. Let's try without if it fails.
        }
        # Try to find a valid establishment first like main.py does
        est_res = supabase.table("establishments").select("id").limit(1).execute()
        if est_res.data:
            data['establishment_id'] = est_res.data[0]['id']
            print(f"Using establishment_id: {data['establishment_id']}")
        
        res = supabase.table("products").insert(data).execute()
        print("SUCCESS: Inserted with String Category")
        # Cleanup
        supabase.table("products").delete().eq("id", res.data[0]['id']).execute()
    except Exception as e:
        print(f"FAILED: String Category: {e}")

    print("\n--- Testing Integer Category ---")
    try:
        data = {
            "name": "Test Int Cat",
            "price": 10.0,
            "category_id": 999,
             "establishment_id": 1
        }
        if est_res.data:
            data['establishment_id'] = est_res.data[0]['id']

        res = supabase.table("products").insert(data).execute()
        print("SUCCESS: Inserted with Integer Category")
             # Cleanup
        supabase.table("products").delete().eq("id", res.data[0]['id']).execute()
    except Exception as e:
        print(f"FAILED: Integer Category: {e}")

    print("\n--- Testing NULL Category ---")
    try:
        data = {
            "name": "Test Null Cat",
            "price": 10.0,
            "category_id": None
        }
        if est_res.data:
            data['establishment_id'] = est_res.data[0]['id']

        res = supabase.table("products").insert(data).execute()
        print("SUCCESS: Inserted with NULL Category")
             # Cleanup
        supabase.table("products").delete().eq("id", res.data[0]['id']).execute()
    except Exception as e:
        print(f"FAILED: NULL Category: {e}")


    print("\n--- Checking Categories Table ---")
    try:
        res = supabase.table("categories").select("*").execute()
        print(f"Categories found: {len(res.data)}")
        for cat in res.data:
            print(f"- {cat.get('name', 'No Name')}: {cat.get('id')}")
    except Exception as e:
        print(f"FAILED to list categories: {e}")

if __name__ == "__main__":
    # test_insert() # Disable insert test to focus on categories
    try:
        res = supabase.table("categories").select("*").execute()
        print(f"Categories found: {len(res.data)}")
        for cat in res.data:
             print(f"CAT_RESULT: {cat.get('name') or cat.get('slug') or 'Unknown'}|{cat.get('id')}")
    except Exception as e:
         print(f"Check failed: {e}")

