import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

print(f"ModelSpace length: {len(model_text)}, Defs length: {len(defs_text)}")

# Find all circles in model_text and defs_text
circles_ms = re.findall(r'<circle[^>]+>', model_text)
circles_defs = re.findall(r'<circle[^>]+>', defs_text)
print(f"Circles in ModelSpace: {len(circles_ms)}, in Defs: {len(circles_defs)}")
if circles_ms:
    print("Sample circle MS:", circles_ms[0])
if circles_defs:
    print("Sample circle Defs:", circles_defs[0])

# Find red lines in ModelSpace vs Defs
red_ms = len(re.findall(r'stroke:(red|#ff0000|#ff2d55|#ff3b30)', model_text, re.I))
red_defs = len(re.findall(r'stroke:(red|#ff0000|#ff2d55|#ff3b30)', defs_text, re.I))
print(f"Red strokes: ModelSpace={red_ms}, Defs={red_defs}")

# Find long vertical lines in ModelSpace or Defs (axis lines are typically long vertical or horizontal lines!)
# Look for path coordinates near x ~ 93462, 97507, 103831 (where 235 is)
print("\nLooking for lines near X in [93000, 105000] and Y in [11000, 13000]:")
paths = re.findall(r'<path[^>]+d="M\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)\s*L\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)"[^>]*style="([^"]*)"', model_text)
near_paths = []
for x1, y1, x2, y2, s in paths:
    fx1, fy1, fx2, fy2 = float(x1), float(y1), float(x2), float(y2)
    if (93000 <= fx1 <= 105000 or 93000 <= fx2 <= 105000) and (9000 <= fy1 <= 15000 or 9000 <= fy2 <= 15000):
        near_paths.append((fx1, fy1, fx2, fy2, s))

print(f"Paths near 235 region in ModelSpace: {len(near_paths)}")
for p in near_paths[:10]:
    # Check length
    dx = p[2] - p[0]
    dy = p[3] - p[1]
    dist = math.sqrt(dx*dx + dy*dy)
    print(f"  ({p[0]:.1f}, {p[1]:.1f}) -> ({p[2]:.1f}, {p[3]:.1f}), len={dist:.1f}, style={p[4]}")

# What about dashed lines? stroke-dasharray?
dash_paths = [p for p in near_paths if 'dash' in p[4]]
print(f"Dashed paths near 235: {len(dash_paths)}")
if dash_paths:
    for p in dash_paths[:5]:
        print("  Dashed:", p)

# What uses are in this region?
uses = re.findall(r'<use[^>]+transform="translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)[^"]*"[^>]*xlink:href="#([^"]+)"', model_text)
near_uses = []
for ux, uy, href in uses:
    fux, fuy = float(ux), float(uy)
    if 93000 <= fux <= 105000 and 9000 <= fuy <= 15000:
        near_uses.append((fux, fuy, href))
print(f"\nUses near 235 region in ModelSpace: {len(near_uses)}")
for u in near_uses[:10]:
    print("  Use:", u)
