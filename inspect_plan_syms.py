import json
import re

# 1. In defs:
svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
defs_text = text[defs_idx:]

for sym_id in ['symbol-101ED3CD2', 'symbol-101CA72B2', 'symbol-101E5BFDD']:
    m = re.search(rf'<g\s+id="{sym_id}"([^>]*)>(.*?)</g>', defs_text, re.DOTALL)
    if m:
        attrs = m.group(1)
        body = m.group(2)
        pts = re.findall(r'([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', body[:300])
        print(f"\n{sym_id}:")
        print("  attrs:", attrs)
        print("  first 5 pts:", pts[:5])
        texts = re.findall(r'<text[^>]*>([^<]+)</text>', body)
        print("  texts:", texts[:10])
        # Find nested uses
        nested = re.findall(r'<use[^>]+(?:xlink:href|href)="#([^"]+)"', body)
        print(f"  nested uses ({len(nested)}):", nested[:5])

# 2. In cad_data.json:
with open('/home/ubuntu/cad-service/public/cad_data.json') as f:
    d = json.load(f)

# Where are circles with r >= 10 in cad_data.json?
# Remember we turned circles into line segments!
# Axis circles have radius 20, so diameter ~40, circumference ~125.
# Let's find texts that are single letters (A, B, C, D...) or numbers (1, 2, 3...) in the range X in [35000, 52000]!
texts = d['texts']
plan_axis_texts = [t for t in texts if 35000 <= t['x'] <= 55000 and 8000 <= t['y'] <= 16000 and t['t'] in ['1','2','3','4','5','6','A','B','C','D','E','F']]
print(f"\nAxis texts in plan area [35000..55000] in cad_data.json: {len(plan_axis_texts)}")
for t in plan_axis_texts:
    print("  ", t)
