import re

with open('/tmp/raw_5fe.svg', 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx] if defs_idx != -1 else text

uses = re.findall(r'<use[^>]+transform="([^"]+)"[^>]*xlink:href="#([^"]+)"', model_text)
print('Total uses in ModelSpace:', len(uses))

# Check the transforms:
trans_x = []
trans_y = []
for t, href in uses:
    m = re.search(r'translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)', t)
    if m:
        trans_x.append(float(m.group(1)))
        trans_y.append(float(m.group(2)))

print(f"Translate X min: {min(trans_x):.1f}, max: {max(trans_x):.1f}")
print(f"Translate Y min: {min(trans_y):.1f}, max: {max(trans_y):.1f}")

# Histogram of translate Y
y_buckets = {}
for y in trans_y:
    bucket = round(y / 10000) * 10000
    y_buckets[bucket] = y_buckets.get(bucket, 0) + 1
print('Translate Y buckets:', sorted(y_buckets.items()))

# Now check definitions in defs:
defs_part = text[defs_idx:] if defs_idx != -1 else ""
print('defs length:', len(defs_part))

# Check symbol transforms in raw_5fe.svg
raw_sym_trans = re.findall(r'<g\s+id="([^"]+)"[^>]*transform="([^"]+)"', defs_part)
print('Symbols with transform in raw SVG:', len(raw_sym_trans))
for sid, tr in raw_sym_trans[:10]:
    print(f"Raw symbol {sid}: {tr}")
