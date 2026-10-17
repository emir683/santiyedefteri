import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]

# Check direct paths in model_text that have coordinates in [0..10000, 0..10000]
direct_in_box = 0
for m in re.finditer(r'<path[^>]+d="([^"]+)"', model_text):
    d = m.group(1)
    coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
    if coords and any(0 <= coords[i] <= 10000 and 0 <= coords[i+1] <= 10000 for i in range(0, len(coords)-1, 2)):
        direct_in_box += 1

print(f"Direct paths in ModelSpace in [0..10000, 0..10000]: {direct_in_box}")

# Check <use> tags in ModelSpace: which <use> tags have translate in [0..10000, 0..10000]?
uses_in_box = []
for m in re.finditer(r'<use[^>]+transform="translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)[^"]*"[^>]*xlink:href="#([^"]+)"', model_text):
    tx, ty, sym = float(m.group(1)), float(m.group(2)), m.group(3)
    if -5000 <= tx <= 15000 and -5000 <= ty <= 15000:
        uses_in_box.append((tx, ty, sym))

print(f"<use> tags in ModelSpace translated to [0..15000, 0..15000]: {len(uses_in_box)}")
for u in uses_in_box[:10]:
    print("  Use in box:", u)
