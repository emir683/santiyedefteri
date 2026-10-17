import json

with open('/tmp/test_raw_webgl.json', 'r') as f:
    d = json.load(f)

lines = d['lines']
texts = d['texts']
print('Total lines:', len(lines)//5)
print('Total texts:', len(texts))

xs = []
ys = []
for i in range(0, len(lines), 5):
    xs.extend([lines[i], lines[i+2]])
    ys.extend([lines[i+1], lines[i+3]])

print(f"X range: min={min(xs):.1f}, max={max(xs):.1f}")
print(f"Y range: min={min(ys):.1f}, max={max(ys):.1f}")

# Find density buckets to see where the REAL drawing is vs stray elements:
import collections
x_buckets = collections.defaultdict(int)
y_buckets = collections.defaultdict(int)

for x in xs[::10]:
    x_buckets[round(x / 5000) * 5000] += 1
for y in ys[::10]:
    y_buckets[round(y / 5000) * 5000] += 1

print("\nX distribution (every 5000 units):")
for k in sorted(x_buckets):
    print(f"X ~ {k}: {x_buckets[k]} pts")

print("\nY distribution (every 5000 units):")
for k in sorted(y_buckets):
    print(f"Y ~ {k}: {y_buckets[k]} pts")
