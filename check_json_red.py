import json
import re

# Compare b3c9... and 9378...
path1 = '/home/ubuntu/cad-service/uploads/b3c9291a-7f7a-4bf4-a40f-fd5f8ae51327.svg'
path2 = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'

with open(path1, 'r', errors='ignore') as f1:
    t1 = f1.read()
with open(path2, 'r', errors='ignore') as f2:
    t2 = f2.read()

print("File 1 len:", len(t1), "File 2 len:", len(t2))

# In JSON:
with open('/home/ubuntu/cad-service/public/cad_data.json', 'r') as fj:
    d = json.load(fj)

lines = d['lines']
red_lines = []
for i in range(0, len(lines), 5):
    x1, y1, x2, y2, c = lines[i:i+5]
    if c in [0xff3b30, 0xff0000, 0xff2d55]:
        red_lines.append((x1, y1, x2, y2, c))

print(f"Total lines in JSON: {len(lines)//5}, Red lines: {len(red_lines)}")

# Look at bounds of red lines vs all lines
xs = [p[0] for p in red_lines] + [p[2] for p in red_lines]
ys = [p[1] for p in red_lines] + [p[3] for p in red_lines]
if xs and ys:
    print(f"Red lines X range: [{min(xs):.1f}, {max(xs):.1f}], Y range: [{min(ys):.1f}, {max(ys):.1f}]")

# Sample some red lines
print("\nSample 10 red lines in JSON:")
for p in red_lines[:10]:
    print(" ", p)

# Check long red lines (axes are typically long, e.g. length > 500 or 1000)
long_red = []
for x1, y1, x2, y2, c in red_lines:
    dx = x2 - x1
    dy = y2 - y1
    dist = (dx*dx + dy*dy)**0.5
    if dist > 500:
        long_red.append((x1, y1, x2, y2, dist))

print(f"\nLong red lines (len > 500): {len(long_red)}")
for p in long_red[:10]:
    print(f"  ({p[0]}, {p[1]}) -> ({p[2]}, {p[3]}), len={p[4]:.1f}")
