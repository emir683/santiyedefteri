import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]

# Parse <use> tags properly
proper_uses = []
for m in re.finditer(r'<use\s+([^>]+)>', model_text):
    tag = m.group(1)
    href = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag)
    tr = re.search(r'transform="([^"]+)"', tag)
    if href:
        proper_uses.append({
            'sym': href.group(1),
            'trans': tr.group(1) if tr else 'none'
        })

print(f"Total proper uses parsed: {len(proper_uses)}")
with_trans = [u for u in proper_uses if u['trans'] != 'none']
print(f"Uses WITH transform: {len(with_trans)}")
print("Sample uses with transform:")
for u in with_trans[:10]:
    print(" ", u)
