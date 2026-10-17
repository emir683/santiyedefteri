import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find all circles
circles = []
for m in re.finditer(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"[^>]*style="([^"]*)"', text):
    cx = float(m.group(1))
    cy = float(m.group(2))
    r = float(m.group(3))
    s = m.group(4)
    circles.append((cx, cy, r, s))

print(f"Total circles: {len(circles)}")

# Distribution of circle radii:
radii = {}
for cx, cy, r, s in circles:
    rr = round(r, 1)
    radii[rr] = radii.get(rr, 0) + 1

print("Circle radii distribution (top 15):")
for r, cnt in sorted(radii.items(), key=lambda x: -x[1])[:15]:
    print(f"  radius {r}: {cnt}")

# Find larger circles (radius >= 10, likely axis bubbles!)
axis_bubbles = [c for c in circles if c[2] >= 10]
print(f"\nCircles with radius >= 10: {len(axis_bubbles)}")
for c in axis_bubbles[:15]:
    print(f"  Bubble at ({c[0]:.1f}, {c[1]:.1f}), r={c[2]:.1f}, style={c[3]}")

# Find texts near these bubbles
texts = []
for m in re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', text):
    x = float(m.group(1))
    y = float(m.group(2))
    f = m.group(3)
    t = m.group(4).strip()
    texts.append((x, y, f, t))

print(f"Total texts: {len(texts)}")

# Match texts to bubbles
for c in axis_bubbles[:15]:
    cx, cy, r, s = c
    # Find texts within distance r*2
    near = [t for t in texts if math.hypot(t[0]-cx, t[1]-cy) < r * 2.5]
    print(f"  Bubble at ({cx:.1f}, {cy:.1f}), r={r} -> Nearby texts: {[t[3] for t in near]}")
