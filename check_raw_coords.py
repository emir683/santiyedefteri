import re

svg_path = '/tmp/raw_5fe.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_part = text[:defs_idx] if defs_idx != -1 else text
defs_part = text[defs_idx:] if defs_idx != -1 else ""

# In raw_5fe.svg, what are the coordinate bounds of ModelSpace paths?
coords = re.findall(r'[ML]\s*([+-]?\d+\.?\d*)[, ]\s*([+-]?\d+\.?\d*)', model_part)
xs = [float(x) for x, y in coords]
ys = [float(y) for x, y in coords]

print(f"Direct ModelSpace Paths count: {len(coords)}")
print(f"X min: {min(xs):.1f}, max: {max(xs):.1f}")
print(f"Y min: {min(ys):.1f}, max: {max(ys):.1f}")

# And what about <use> tags?
uses = re.findall(r'<use[^>]+transform="translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)"', model_part)
print(f"ModelSpace <use> count: {len(uses)}")
uxs = [float(x) for x, y in uses]
uys = [float(y) for x, y in uses]
print(f"<use> translate X min: {min(uxs):.1f}, max: {max(uxs):.1f}")
print(f"<use> translate Y min: {min(uys):.1f}, max: {max(uys):.1f}")
