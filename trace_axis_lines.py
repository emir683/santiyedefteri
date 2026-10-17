import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Axis bubble A is at (96217.6, 11633.3)
# Axis bubble B is at (94467.6, 11633.3)
# Axis bubble C is at (93620.1, 11633.3)

print("Tracing lines near Axis A, B, C...")
# Search all paths within distance 100 of these points
paths = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', text)
for ax_name, (ax, ay) in [('A', (96217.6, 11633.3)), ('B', (94467.6, 11633.3)), ('C', (93620.1, 11633.3))]:
    print(f"\n--- AXIS {ax_name} at ({ax}, {ay}) ---")
    connected = []
    for d, s in paths:
        coords = [float(c) for c in re.findall(r'[-+]?\d*\.\d+|\d+', d)]
        for i in range(0, len(coords)-1, 2):
            if math.hypot(coords[i]-ax, coords[i+1]-ay) < 60:
                connected.append((d, s))
                break
    print(f"Connected path count: {len(connected)}")
    for d, s in connected[:10]:
        print(f"  d='{d}' | style='{s}'")
