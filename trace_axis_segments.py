import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

paths = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', text)

for ax_x, ax_name in [(96217.5, 'A'), (94467.5, 'B'), (93620.1, 'C')]:
    print(f"\n=== Searching all segments on Axis {ax_name} (X ~ {ax_x}) ===")
    matches = []
    for d, s in paths:
        coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
        if len(coords) == 4:
            x1, y1, x2, y2 = coords
            if abs(x1 - ax_x) < 5.0 and abs(x2 - ax_x) < 5.0:
                matches.append((y1, y2, s))
    print(f"Found {len(matches)} vertical segments:")
    for y1, y2, s in sorted(matches, key=lambda x: min(x[0], x[1])):
        print(f"  Y: {y1:.1f} -> {y2:.1f} (len={abs(y2-y1):.1f}) | {s}")
