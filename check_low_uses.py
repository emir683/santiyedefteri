import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

# Find all <use> in ModelSpace
use_matches = list(re.finditer(r'<use[^>]+(?:xlink:href|href)="#([^"]+)"([^>]*)>', model_text))
print("Total uses in ModelSpace:", len(use_matches))

# For each use, let's see which ones have transform with x < 15000 or y < 15000
for m in use_matches:
    sym_id = m.group(1)
    attrs = m.group(2)
    t_match = re.search(r'transform="([^"]+)"', attrs)
    t_str = t_match.group(1) if t_match else ""
    # find translate
    tr = re.search(r'translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)', t_str)
    if tr:
        tx, ty = float(tr.group(1)), float(tr.group(2))
        if tx < 20000 and ty < 20000:
            print(f"Use {sym_id} at translate({tx}, {ty})")
