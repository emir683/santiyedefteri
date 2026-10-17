import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')

for val in ['10847', '9727']:
    matches = list(re.finditer(val, text))
    print(f"Matches for {val}: {len(matches)}")
    for m in matches[:3]:
        pos = m.start()
        in_defs = pos > defs_idx
        tag_start = text.rfind('<', 0, pos)
        tag_end = text.find('>', pos) + 1
        print(f"  {val} at {pos} (in_defs={in_defs}): {text[tag_start:tag_end]}")
