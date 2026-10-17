import re
import math

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

# Find symbols in defs
sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)
symbols = {}
for m in sym_regex.finditer(defs_text):
    sym_id = m.group(1)
    attrs = m.group(2)
    body = m.group(3)
    t_match = re.search(r'transform="([^"]+)"', attrs)
    symbols[sym_id] = (t_match.group(1) if t_match else "", body)

print(f"Total symbols in defs: {len(symbols)}")

# Trace first 20 <use> in ModelSpace
use_matches = list(re.finditer(r'<use[^>]+(?:xlink:href|href)="#([^"]+)"([^>]*)>', model_text))
print(f"Total <use> in ModelSpace: {len(use_matches)}")

for i, m in enumerate(use_matches[:20]):
    sym_id = m.group(1)
    attrs = m.group(2)
    use_tr = re.search(r'transform="([^"]+)"', attrs)
    use_tr_str = use_tr.group(1) if use_tr else "none"
    sym_tr_str, body = symbols.get(sym_id, ("not found", ""))
    
    # Check some coordinates in body
    pts = re.findall(r'([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', body[:500])
    print(f"[{i}] Use {sym_id}:")
    print(f"     use_transform: {use_tr_str}")
    print(f"     sym_transform: {sym_tr_str}")
    print(f"     sample pts in body (first 3): {pts[:3]}")
