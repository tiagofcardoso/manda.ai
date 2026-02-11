import re

# Read the file
with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to find function definitions using get_current_admin
# and usages of user.establishment_id

# First, update all function signatures
content = re.sub(
    r'def (\w+)\([^)]*user\s*=\s*Depends\(get_current_admin\)',
    r'def \1(admin: tuple = Depends(get_current_admin)',
    content
)

# Add unpacking at the start of each function that uses admin
# This is more complex, so we'll do it line by line

lines = content.split('\n')
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # Check if this line is a function definition with admin: tuple = Depends
    if 'admin: tuple = Depends(get_current_admin)' in line:
        # Find the next line that's not a docstring or comment
        j = i + 1
        while j < len(lines):
            next_line = lines[j]
            stripped = next_line.strip()
            
            # Skip docstrings and empty lines
            if stripped.startswith('"""') or stripped.startswith("'''") or not stripped or stripped.startswith('#'):
                new_lines.append(next_line)
                j += 1
                continue
            
            # If we find closing docstring, add unpack after it
            if '"""' in stripped or "'''" in stripped:
                new_lines.append(next_line)
                # Check if docstring closes on this line
                if stripped.count('"""') ==  2 or stripped.count("'''") == 2 or (stripped.endswith('"""') or stripped.endswith("'''")):
                    # Add the unpacking line with proper indentation
                    indent = len(next_line) - len(next_line.lstrip())
                    new_lines.append(' ' * indent + 'user, establishment_id = admin  # Unpack the tuple')
                    break
                j += 1
                continue
            
            # First real line of code - insert before it
            indent = len(next_line) - len(next_line.lstrip())
            new_lines.append(' ' * indent + 'user, establishment_id = admin  # Unpack the tuple')
            break
            
        i = j
    
    i += 1

# Join back
content = '\n'.join(new_lines)

# Now replace all user.establishment_id with establishment_id
content = content.replace('user.establishment_id', 'establishment_id')

# Write back
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated main.py successfully!")
