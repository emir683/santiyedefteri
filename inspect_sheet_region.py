import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

print(f"Investigating region X in [35000, 55000], Y in [8000, 15000]...")

# 1. Direct paths in ModelSpace in this region
paths_in_region = []
for m in re.finditer(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', model_text):
    d = m.group(1)
    s = m.group(2)
    coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
    if coords and any(35000 <= coords[i] <= 55000 and 8000 <= coords[i+1] <= 15000 for i in range(0, len(coords)-1, 2)):
        paths_in_region.append((d, s))

print(f"Direct paths in ModelSpace in region: {len(paths_in_region)}")
from collections import Counter
st_colors = Counter()
for d, s in paths_in_region:
    st = re.search(r'stroke:([^;"]+)', s)
    c = st.group(1) if st else 'none'
    st_colors[c] += 1
print("Direct path colors in region:", st_colors)

# 2. Uses in ModelSpace in this region
uses_in_region = []
for m in re.finditer(r'<use\s+([^>]+)>', model_text):
    tag = m.group(1)
    href = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag)
    tr = re.search(r'transform="([^"]+)"', tag)
    if href:
        sym_id = href.group(1)
        t_str = tr.group(1) if tr else ""
        t_xy = re.search(r'translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)', t_str)
        if t_xy:
            tx, ty = float(t_xy.group(1)), float(t_xy.group(2))
            if 35000 <= tx <= 55000 and 8000 <= ty <= 15000:
                uses_in_region.append((sym_id, tx, ty, t_str))

print(f"<use> instances translated into this region: {len(uses_in_region)}")
for u in uses_in_region[:15]:
    print("  Use in region:", u)
