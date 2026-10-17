import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
defs_text = text[defs_idx:]

sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)

sym_stats = []
for m in sym_regex.finditer(defs_text):
    sym_id = m.group(1)
    body = m.group(3)
    pts = re.findall(r'([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', body)
    if pts:
        ys = [float(p[1]) for p in pts[:20]]
        avg_y = sum(ys) / len(ys)
        sym_stats.append((sym_id, avg_y, len(pts)))

negative_y = [s for s in sym_stats if s[1] < -10000]
positive_y = [s for s in sym_stats if s[1] >= -10000]

print(f"Total symbols with points: {len(sym_stats)}")
print(f"Symbols with Y < -10000 (offset block definitions): {len(negative_y)}")
print(f"Symbols with Y >= -10000 (already in ModelSpace): {len(positive_y)}")
