import re

svg_path = '/home/ubuntu/cad-service/uploads/5fe1b241-24de-4e1e-aada-f0bf681dfe09.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_start = text.find('<defs>')
defs_end = text.find('</defs>')
print('defs_start:', defs_start, 'defs_end:', defs_end)

if defs_start != -1:
    defs_content = text[defs_start:defs_end+7]
    print('defs content length:', len(defs_content))
    # Check all tag names in defs
    tags = re.findall(r'<([a-zA-Z0-9]+)\b', defs_content)
    print('Tags in defs:', set(tags))
    
    # Check id matches
    ids = re.findall(r'id="([^"]+)"', defs_content)
    print('Total IDs in defs:', len(ids), 'sample:', ids[:5])
    
    # First 500 chars of defs
    print('defs snippet:', defs_content[:500])
else:
    print('No defs found in SVG!')
