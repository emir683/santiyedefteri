import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')

# Find all texts with PLAN or PLANI or APLIKASYON
print("Searching all PLAN titles in SVG...")
for m in re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*font-size="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]*(?:PLAN|APL[Iİ]KASYON|KAT)[^<]*)</text>', text, re.IGNORECASE):
    x, y, sz, f, t = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    pos = m.start()
    in_defs = pos > defs_idx
    print(f"X={float(x):.1f}, Y={float(y):.1f}, in_defs={in_defs}, size={sz}: '{t.strip()}'")
