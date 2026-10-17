import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

# The plan "BODRUM KAT KOLON APLIKASYON PLANI" is at X in [37000, 45000], Y in [9000, 14000]
print("Checking circles in X in [37000, 45000], Y in [9000, 14000]...")
circles_in_plan = []
for m in re.finditer(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"', model_text):
    cx = float(m.group(1))
    cy = float(m.group(2))
    r = float(m.group(3))
    if 37000 <= cx <= 45000 and 9000 <= cy <= 14000:
        circles_in_plan.append((cx, cy, r))

print(f"Total circles in plan area in ModelSpace: {len(circles_in_plan)}")
for c in circles_in_plan[:10]:
    print("  Circle:", c)

# Are there any circles with r >= 10 in this area?
bubbles = [c for c in circles_in_plan if c[2] >= 10]
print(f"Circles with r >= 10 (bubbles) in ModelSpace in this area: {len(bubbles)}")

# What uses are in this area?
uses_in_plan = []
for m in re.finditer(r'<use\s+([^>]+)>', model_text):
    tag = m.group(1)
    href = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag)
    tr = re.search(r'transform="([^"]+)"', tag)
    if href:
        sym_id = href.group(1)
        t_str = tr.group(1) if tr else ""
        t_xy = re.search(r'translate\(([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\)', t_str)
        if t_xy:
            tx, ty = float(t_xy.group(1)), float(t_xy.group(2))
            if 37000 <= tx <= 45000 and 9000 <= ty <= 14000:
                uses_in_plan.append((sym_id, tx, ty))

print(f"<use> tags translated into this area: {len(uses_in_plan)}")
for u in uses_in_plan:
    print("  Use:", u)

# Now check defs: do any symbols in defs contain circles or axis lines that should be placed here?
# Let's check the symbols used in this plan:
for u in uses_in_plan:
    sym_id = u[0]
    # find symbol in defs
    sym_m = re.search(rf'<g\s+id="{sym_id}"[^>]*>(.*?)</g>', defs_text, re.DOTALL)
    if sym_m:
        body = sym_m.group(1)
        c_count = len(re.findall(r'<circle', body))
        p_count = len(re.findall(r'<path', body))
        t_count = len(re.findall(r'<text', body))
        u_count = len(re.findall(r'<use', body))
        print(f"  Symbol {sym_id}: circles={c_count}, paths={p_count}, texts={t_count}, uses={u_count}")
