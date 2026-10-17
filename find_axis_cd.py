import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find texts 'C' and 'D' that are single characters
# And find if they have a nearby circle
circles = []
for m in re.finditer(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"', text):
    circles.append((float(m.group(1)), float(m.group(2)), float(m.group(3))))

print(f"Total circles: {len(circles)}")

for target in ['C', 'D']:
    matches = list(re.finditer(rf'>\s*{target}\s*<', text))
    print(f"\nTarget '{target}' matches: {len(matches)}")
    for m in matches:
        # find tag
        start = text.rfind('<text', 0, m.start())
        end = text.find('</text>', m.end()) + 7
        tag = text[start:end]
        xm = re.search(r'x="([^"]+)"', tag)
        ym = re.search(r'y="([^"]+)"', tag)
        if xm and ym:
            x, y = float(xm.group(1)), float(ym.group(1))
            # Find closest circle
            closest_circle = min(circles, key=lambda c: math.hypot(c[0]-x, c[1]-y))
            dist = math.hypot(closest_circle[0]-x, closest_circle[1]-y)
            if dist < 50:
                print(f"  Axis {target} at ({x:.1f}, {y:.1f}), Circle at ({closest_circle[0]:.1f}, {closest_circle[1]:.1f}, r={closest_circle[2]:.1f})")
