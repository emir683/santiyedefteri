import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')

# Search for 9990.2
matches = list(re.finditer(r'9990\.2', text))
print("Total 9990.2 matches in SVG:", len(matches))
for m in matches[:5]:
    pos = m.start()
    in_defs = pos > defs_idx
    tag_start = text.rfind('<', 0, pos)
    tag_end = text.find('>', pos) + 1
    print(f"Pos {pos} (in_defs={in_defs}): {text[tag_start:tag_end]}")
