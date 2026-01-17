import requests
import json
from dotenv import load_dotenv
import os

load_dotenv()

# Get token from environment or use a test one
# You'll need to replace this with a valid admin token
BASE_URL = "http://localhost:8000"

print("Testing /admin/orders endpoint...")
print("-" * 50)

try:
    # First, let's test without auth to see the error
    response = requests.get(f"{BASE_URL}/admin/orders?limit=10")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code != 200:
        print("\n❌ Error occurred!")
        try:
            error_detail = response.json()
            print(f"Error Detail: {json.dumps(error_detail, indent=2)}")
        except:
            print(f"Raw Response: {response.text}")
            
except Exception as e:
    print(f"Exception: {e}")
    import traceback
    traceback.print_exc()
