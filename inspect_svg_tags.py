import re
from collections import Counter

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
print("Reading SVG...")
with open(svg_path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

print("Length:", len(text))
defs_idx = text.find('</defs>')
print("defs_idx:", defs_idx)

# Search for red
red_matches = [m.start() for m in re.finditer(r'stroke:(red|#ff0000|#ff2d55|#ff3b30)', text, re.IGNORECASE)]
print("Total red stroke matches:", len(red_matches))

in_defs = sum(1 for pos in red_matches if pos < defs_idx)
in_body = sum(1 for pos in red_matches if pos >= defs_idx)
print(f"Red strokes in defs: {in_defs}, in body: {in_body}")

# Sample 10 tags
print("\n--- Sample 10 Red Tags ---")
for idx in red_matches[:10]:
    start = max(0, text.rfind('<', 0, idx))
    end = min(len(text), text.find('>', idx) + 1)
    tag_sample = text[start:end]
    print(tag_sample[:150])

# Check what other colors or elements are in body
tags_in_body = Counter(re.findall(r'<([a-zA-Z0-9]+)[\s>]', text[defs_idx:]))
print("\nTags in body (ModelSpace):", tags_in_body)

# Check all path types in body
paths = re.findall(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]+)"', text[defs_idx:])
print(f"\nTotal paths in body: {len(paths)}")
d_types = Counter()
for d, s in paths:
    cmd_types = ''.join(c for c in d if c.isalpha())
    d_types[cmd_types[:4]] += 1
print("Path command patterns in body (top 10):", d_types.most_common(10))

# Check circles in body
circles = re.findall(r'<circle[^>]+>', text[defs_idx:])
print(f"Total circles in body: {len(circles)}")
if circles:
    print("Sample circle:", circles[0])

# Check lines in body
lines = re.findall(r'<line[^>]+>', text[defs_idx:])
print(f"Total lines in body: {len(lines)}")
if lines:
    print("Sample line:", lines[0])

# Check polylines in body
polylines = re.findall(r'<polyline[^>]+>', text[defs_idx:])
print(f"Total polylines in body: {len(polylines)}")

# Check use elements in body
uses = re.findall(r'<use[^>]+>', text[defs_idx:])
print(f"Total <use> elements in body: {len(uses)}")
if uses:
    print("Sample use:", uses[0])
