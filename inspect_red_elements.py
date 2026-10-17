import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

print(f"Model space text: {len(model_text)} bytes")

# Find all red elements in ModelSpace
red_paths = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="[^"]*stroke:red[^"]*"', model_text)
print(f"Red paths in ModelSpace: {len(red_paths)}")

# Check path commands of red paths in ModelSpace
cmd_types = {}
for p in red_paths:
    letters = ''.join(c for c in p if c.isalpha())
    cmd_types[letters] = cmd_types.get(letters, 0) + 1

print("\nRed path command types in ModelSpace:")
for k, v in sorted(cmd_types.items(), key=lambda x: -x[1])[:10]:
    print(f"  {k}: {v}")

# Are there red circles in ModelSpace?
red_circles = re.findall(r'<circle[^>]+style="[^"]*stroke:red[^"]*"', model_text)
print(f"\nRed circles in ModelSpace: {len(red_circles)}")

# Are there red texts in ModelSpace?
red_texts = re.findall(r'<text[^>]+fill="red"[^>]*>([^<]+)</text>', model_text)
print(f"\nRed texts in ModelSpace: {len(red_texts)}")
print("Sample red texts:", red_texts[:10])

# What about axes letters? E.g. A, B, C, 1, 2, 3 in ModelSpace
axis_letters = [t for t in red_texts if len(t.strip()) <= 3]
print(f"Short red texts (probable axis names): {len(axis_letters)}")
print("Sample short red texts:", axis_letters[:20])

# Now what about defs?
red_paths_defs = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="[^"]*stroke:red[^"]*"', defs_text)
print(f"\nRed paths in Defs: {len(red_paths_defs)}")
red_circles_defs = re.findall(r'<circle[^>]+style="[^"]*stroke:red[^"]*"', defs_text)
print(f"Red circles in Defs: {len(red_circles_defs)}")
red_texts_defs = re.findall(r'<text[^>]+fill="red"[^>]*>([^<]+)</text>', defs_text)
print(f"Red texts in Defs: {len(red_texts_defs)}")
