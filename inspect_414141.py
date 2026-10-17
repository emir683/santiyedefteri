import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find all paths with #414141
paths_41 = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="[^"]*#414141[^"]*"', text)
print(f"Total paths with #414141: {len(paths_41)}")

# Are they mostly axis dashdot lines?
lengths = []
for p in paths_41:
    coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', p)]
    if len(coords) == 4:
        dx = coords[2] - coords[0]
        dy = coords[3] - coords[1]
        lengths.append((dx*dx + dy*dy)**0.5)

print(f"Sample lengths of #414141 paths: {lengths[:20]}")
from collections import Counter
print("Length distribution (rounded):", Counter(round(l, 0) for l in lengths).most_common(10))

# What about texts with #414141?
texts_41 = re.findall(r'<text[^>]+fill="#414141"[^>]*>([^<]+)</text>', text)
print(f"Texts with #414141: {len(texts_41)}")
print("Sample texts:", texts_41[:10])
