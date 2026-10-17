import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_part = text[:defs_idx]
defs_part = text[defs_idx:]

# Parse defs symbols and mark is_offset
sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)
symbols = {}

for m in sym_regex.finditer(defs_part):
    sym_id = m.group(1)
    attrs = m.group(2)
    body = m.group(3)
    
    # Check if points in body are offset (Y < -10000)
    pts = re.findall(r'([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', body[:500])
    is_offset = False
    if pts:
        avg_y = sum(float(p[1]) for p in pts[:10]) / min(len(pts), 10)
        is_offset = avg_y < -10000
        
    t_match = re.search(r'transform="([^"]+)"', attrs)
    base_trans = t_match.group(1) if t_match else ""
    symbols[sym_id] = {
        'base_trans': base_trans,
        'is_offset': is_offset,
        'body': body
    }

print(f"Total symbols: {len(symbols)}")
print(f"Offset symbols: {sum(1 for s in symbols.values() if s['is_offset'])}")
print(f"Normal symbols: {sum(1 for s in symbols.values() if not s['is_offset'])}")

# Now test parsing all <use> in ModelSpace
proper_uses = []
for m in re.finditer(r'<use\s+([^>]+)>', model_part):
    tag = m.group(1)
    href = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag)
    tr = re.search(r'transform="([^"]+)"', tag)
    if href:
        sym_id = href.group(1)
        proper_uses.append((sym_id, tr.group(1) if tr else "none"))

print(f"Total ModelSpace <use>: {len(proper_uses)}")

# Check where offset symbols are used vs normal symbols
offset_uses = [u for u in proper_uses if symbols.get(u[0], {}).get('is_offset', False)]
normal_uses = [u for u in proper_uses if not symbols.get(u[0], {}).get('is_offset', False)]

print(f"ModelSpace uses referencing offset symbols: {len(offset_uses)}")
print(f"ModelSpace uses referencing normal symbols: {len(normal_uses)}")
print("\nSample offset uses with transform:")
for u in offset_uses[:10]:
    print(" ", u)

print("\nSample normal uses with transform:")
for u in normal_uses[:10]:
    print(" ", u)
