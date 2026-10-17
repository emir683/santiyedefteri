import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Box around (93462, 11915):
# X: [92000, 95000], Y: [10000, 13500]
print("Searching elements in X in [92000, 95000], Y in [10000, 13500]...")

# 1. Paths
paths = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', text)
box_paths = []
for d, s in paths:
    # check coordinates
    coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
    if len(coords) >= 4:
        # Check if any point is in box
        in_box = False
        for i in range(0, len(coords)-1, 2):
            if 92000 <= coords[i] <= 95000 and 10000 <= coords[i+1] <= 13500:
                in_box = True
                break
        if in_box:
            box_paths.append((d, s))

print(f"Total paths in box: {len(box_paths)}")
# Count by stroke color
stroke_counts = {}
for d, s in box_paths:
    st = re.search(r'stroke:([^;"]+)', s)
    color = st.group(1) if st else 'none'
    stroke_counts[color] = stroke_counts.get(color, 0) + 1

print("Path stroke colors in box:", stroke_counts)

# Look for long vertical lines in box (vertical axis lines have x1 == x2, large dy)
vertical_lines = []
for d, s in box_paths:
    coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
    if len(coords) == 4:
        x1, y1, x2, y2 = coords
        if abs(x1 - x2) < 2.0 and abs(y1 - y2) > 300:
            st = re.search(r'stroke:([^;"]+)', s)
            c = st.group(1) if st else 'unknown'
            vertical_lines.append((x1, y1, x2, y2, c))

print(f"\nLong vertical lines in box: {len(vertical_lines)}")
for vl in vertical_lines[:15]:
    print(f"  X={vl[0]:.1f}, Y1={vl[1]:.1f} -> Y2={vl[2]:.1f}, len={abs(vl[3]-vl[1]):.1f}, color={vl[4]}")

# 2. Texts in box
texts = re.findall(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', text)
box_texts = []
for x, y, f, t in texts:
    fx, fy = float(x), float(y)
    if 92000 <= fx <= 95000 and 10000 <= fy <= 13500:
        box_texts.append((fx, fy, f, t.strip()))

print(f"\nTotal texts in box: {len(box_texts)}")
print("Sample texts in box:", box_texts[:20])

# 3. Circles in box
circles = re.findall(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"[^>]*style="([^"]*)"', text)
box_circles = []
for cx, cy, r, s in circles:
    fcx, fcy = float(cx), float(cy)
    if 92000 <= fcx <= 95000 and 10000 <= fcy <= 13500:
        box_circles.append((fcx, fcy, float(r), s))

print(f"\nTotal circles in box: {len(box_circles)}")
for bc in box_circles[:10]:
    print(f"  Circle at ({bc[0]:.1f}, {bc[1]:.1f}), r={bc[2]:.1f}, style={bc[3]}")
