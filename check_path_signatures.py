import re
from collections import Counter

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]

# Check all element tags in ModelSpace
all_tags = Counter(re.findall(r'<([a-zA-Z0-9_\-]+)[\s>]', model_text))
print("All tags in ModelSpace:")
for t, cnt in all_tags.most_common():
    print(f"  <{t}>: {cnt}")

# Check all paths in ModelSpace: how many match M...L... vs other formats?
all_paths = re.findall(r'<path[^>]+d="([^"]+)"', model_text)
print(f"\nTotal paths in ModelSpace: {len(all_paths)}")

types = Counter()
for d in all_paths:
    # Get sequence of command letters
    cmds = re.findall(r'[a-zA-Z]', d)
    types[' '.join(cmds[:5])] += 1

print("\nPath command signatures (top 15):")
for s, cnt in types.most_common(15):
    print(f"  {s}: {cnt}")

# Check polylines, lines, polygons
for el in ['line', 'polyline', 'polygon', 'ellipse']:
    matches = len(re.findall(rf'<{el}[\s>]', model_text))
    print(f"<{el}> in ModelSpace: {matches}")
