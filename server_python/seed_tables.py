from database import supabase
import uuid

def seed_tables():
    if not supabase:
        print("Supabase not configured")
        return

    # Get Establishment ID
    est_res = supabase.table("establishments").select("id").limit(1).execute()
    if not est_res.data:
        print("No establishment found. Cannot seed tables.")
        return
    
    est_id = est_res.data[0]['id']
    print(f"Seeding for Establishment: {est_id}")

    # Check existing
    existing = supabase.table("tables").select("table_number").execute()
    existing_nums = {t['table_number'] for t in existing.data}
    print(f"Existing tables: {existing_nums}")

    new_tables = []
    for i in range(1, 11): # 1 to 10
        num_str = f"{i:02d}" # "01", "02", ...
        alt_str = str(i) # "1", "2" ...
        
        # Check if either format exists
        if num_str in existing_nums or alt_str in existing_nums:
            continue
            
        new_tables.append({
            "establishment_id": est_id,
            "table_number": str(i), # Using "5" not "05" to be simpler with user input? 
                                    # Actually better to stick to "5" if input is "5".
                                    # But previous checked "02". I will insert "5" directly.
            "qr_code_uuid": str(uuid.uuid4())
        })

    if new_tables:
        print(f"Inserting {len(new_tables)} tables...")
        res = supabase.table("tables").insert(new_tables).execute()
        print("Done!")
    else:
        print("All tables 1-10 already exist (or variants).")

if __name__ == "__main__":
    seed_tables()
