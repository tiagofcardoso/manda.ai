from database import supabase

# Desired Categories
REQUIRED_CATS = {
    'fast_food': 'Fast Food',
    'pizza': 'Pizzas',
    'sushi': 'Sushi',
    'bbq': 'Churrasco',
    'sandwiches': 'Sandwiches',
    'vegan': 'Vegan',
    'dessert': 'Desserts',
    'drinks': 'Bebidas',
    'italian': 'Italiana',
    'japanese': 'Japonesa',
    'chinese': 'Chinesa',
    'brazilian': 'Brasileira',
    'portuguese': 'Portuguesa',
    'mexican': 'Mexicana',
    'healthy': 'Saudável',
    'pastry': 'Pastelaria',
    'seafood': 'Peixes e Mariscos',
    'vegetarian': 'Vegetariana',
}

def setup():
    if not supabase:
        print("No Supabase")
        return

    print("Fetching existing categories...")
    res = supabase.table("categories").select("*").execute()
    existing_names = {c['name']: c['id'] for c in res.data}
    
    print(f"Found {len(existing_names)} existing: {list(existing_names.keys())}")

    # Insert missing
    for slug, name in REQUIRED_CATS.items():
        if name in existing_names:
            print(f"Skipping {name} (exists)")
            continue
        
        print(f"Inserting {name}...")
        try:
             # Look for establishment
            est_res = supabase.table("establishments").select("id").limit(1).execute()
            est_id = est_res.data[0]['id'] if est_res.data else 1

            new_cat = supabase.table("categories").insert({
                "name": name,
                "establishment_id": est_id
            }).execute()
            print(f"Created {name}: {new_cat.data[0]['id']}")
        except Exception as e:
            print(f"Error creating {name}: {e}")

    # Print FINAL MAPPING for me to copy
    print("\n\n--- FINAL CATEGORY MAPPING (COPY THIS) ---")
    final_res = supabase.table("categories").select("*").execute()
    for cat in final_res.data:
        print(f"'{cat['name']}': '{cat['id']}',")

if __name__ == "__main__":
    setup()
