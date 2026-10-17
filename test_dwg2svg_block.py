import re

with open('/tmp/raw_5fe.svg', 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_part = text[:defs_idx] if defs_idx != -1 else text
defs_part = text[defs_idx:] if defs_idx != -1 else ""

uses = list(re.finditer(r'<use[^>]+id="([^"]+)"[^>]*transform="([^"]+)"[^>]*xlink:href="#([^"]+)"', model_part))
print('Total <use> tags with transform in ModelSpace:', len(uses))

for u in uses[:8]:
    uid = u.group(1)
    trans = u.group(2)
    sym_id = u.group(3)
    
    # Find symbol definition in defs
    sym_pattern = r'<g\s+id="' + re.escape(sym_id) + r'"[^>]*>(.*?)</g>'
    sym_m = re.search(sym_pattern, defs_part, re.DOTALL)
    if sym_m:
        body = sym_m.group(1)
        # Find coordinates inside body
        coords = re.findall(r'[ML]\s*([+-]?\d+\.?\d*)[, ]\s*([+-]?\d+\.?\d*)', body)
        texts = re.findall(r'<text[^>]+x="([+-]?\d+\.?\d*)"[^>]+y="([+-]?\d+\.?\d*)"[^>]*>([^<]+)</text>', body)
        print(f"\n--- USE {uid} -> {sym_id} ---")
        print(f"Transform: {trans}")
        if coords:
            xs = [float(x) for x, y in coords]
            ys = [float(y) for x, y in coords]
            print(f"Symbol {len(coords)} path coords: X in [{min(xs):.1f}, {max(xs):.1f}], Y in [{min(ys):.1f}, {max(ys):.1f}]")
        if texts:
            print(f"Symbol {len(texts)} texts: first text '{texts[0][2]}' at ({texts[0][0]}, {texts[0][1]})")
