import json
import numpy as np

with open('/tmp/test_raw_webgl.json', 'r') as f:
    d = json.load(f)

lines = d['lines']
xs = []
ys = []
for i in range(0, len(lines), 5):
    xs.extend([lines[i], lines[i+2]])
    ys.extend([lines[i+1], lines[i+3]])

xs = np.array(xs)
ys = np.array(ys)

# Percentile bounding box (ignoring 0.5% extreme outliers like GIS/cadastral marks at -285M)
p_min_x = float(np.percentile(xs, 1.0))
p_max_x = float(np.percentile(xs, 99.0))
p_min_y = float(np.percentile(ys, 1.0))
p_max_y = float(np.percentile(ys, 99.0))

print(f"98% Density Bounds:")
print(f"X: [{p_min_x:.1f}, {p_max_x:.1f}], width: {p_max_x - p_min_x:.1f}")
print(f"Y: [{p_min_y:.1f}, {p_max_y:.1f}], height: {p_max_y - p_min_y:.1f}")

# Check how many points are within [p_min_x - pad, p_max_x + pad]:
pad_x = (p_max_x - p_min_x) * 0.1
pad_y = (p_max_y - p_min_y) * 0.1

smart_bounds = {
    'minX': round(p_min_x - pad_x, 1),
    'minY': round(p_min_y - pad_y, 1),
    'w': round((p_max_x - p_min_x) + pad_x * 2, 1),
    'h': round((p_max_y - p_min_y) + pad_y * 2, 1)
}

print(f"Smart Bounds: {smart_bounds}")
d['bounds'] = smart_bounds

with open('/home/ubuntu/cad-service/uploads/5fe1b241-24de-4e1e-aada-f0bf681dfe09_cad_data.json', 'w') as f:
    json.dump(d, f)

print("Updated 5fe1b241_cad_data.json with Smart Density Bounds!")
