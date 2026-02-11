
import re
import json

def extract_json_from_error(error_str):
    """
    Robustly extracts JSON from an error string that might contain mixed quoting,
    byte string representations (b'...'), or be nested in other text.
    Target: find a JSON object containing "status".
    """
    if "status" not in error_str:
        return None
    
    # Strategy: Find "Innermost" JSON candidates.
    # We want a block starting with { and ending with } that does NOT contain other { or }.
    # This assumes the target JSON is flat (no nested objects).
    # The success response IS flat: {"status": "success", "message": "...", "user_id": "..."}
    
    # Pattern: { [no braces] "status" [no braces] }
    # We use [^{}]* to match content without braces.
    
    # However, "status" might be escaped as \"status\" or \\"status\\".
    # Regex: \{ [^{}]* status [^{}]* \}
    # We use re.IGNORECASE just in case.
    
    pattern = r'(\{[^{}]*?status[^{}]*?\})'
    
    candidates = re.findall(pattern, error_str, re.DOTALL | re.IGNORECASE)
    
    for candidate in candidates:
        # print(f"DEBUG CANDIDATE: {candidate}") # Valid candidate should be the inner json string
        
        # Cleaning possibilities
        attempts = [
            candidate,
            candidate.replace('\\"', '"'),
            candidate.replace('\\"', '"').replace("\\'", "'"),
            candidate.replace('\"', '"'),
            candidate.replace('\\\\"', '\\"').replace('\\"', '"'), # Quadruple escape handling
        ]
        
        for attempt in attempts:
            try:
                data = json.loads(attempt)
                # Ensure it's a dict and has status (standardized key)
                if isinstance(data, dict) and "status" in data:
                    return data
            except:
                continue
    
    # If that fails (e.g. if the JSON *is* nested or has braces in strings),
    # we might need to fall back to the greedy approach but filter better.
    # But for now, the success message is flat.
    
    return None

# Test Cases
cases = [
    # Case 1: The real error (simulated)
    """Exception: HTTP 500: {"detail": "{'message': 'JSON could not be generated', ... 'details': 'b\\'{\\\\"status\\\\": \\\\"success\\\\", \\\\"message\\\\": \\\\"User assigned as admin\\\\", \\\\"user_id\\\\": \\\\"c07e74fc...\\\\", \\\\"must_change_password\\\\": true}\\\\'}"}""",
    
    # Case 2: Simple b-prefix
    """ 'details': 'b\'{"status": "success"}\'' """,
    
    # Case 3: No b-prefix (Legacy)
    """ 'details': '{"status": "success"}' """,
    
    # Case 4: Double escaped
    """ 'details': "{\\"status\\": \\"success\\"}" """,
    
    # Case 5: With Newlines
    """ 'details': 'b\'{\n  "status": "success"\n}\'' """
]

print("--- Running Tests ---")
for i, case in enumerate(cases):
    print(f"\nCase {i+1}:")
    result = extract_json_from_error(case)
    if result:
        print(f"SUCCESS: {result}")
    else:
        print("FAILED")

