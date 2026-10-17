import json

with open('/home/ubuntu/cad-service/public/cad_data.json', 'r') as f:
    d = json.load(f)

lines = d['lines']

pile_lines = []
for i in range(0, len(lines), 5):
    x1, y1, x2, y2, c = lines[i:i+5]
    if 0 <= x1 <= 15000 and 0 <= y1 <= 15000:
        pile_lines.append((x1, y1, x2, y2, c))

print(f"Total lines in pile [0..15000, 0..15000]: {len(pile_lines)}")

# Let's inspect coordinates in pile_lines
xs = [p[0] for p in pile_lines]
ys = [p[1] for p in pile_lines]
print(f"Pile X range: [{min(xs):.1f}, {max(xs):.1f}], Y range: [{min(ys):.1f}, {max(ys):.1f}]")

# Where did these lines come from? Let's check in the SVG!
