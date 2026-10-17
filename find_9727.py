import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')

for m in re.finditer(r'9727\.0', text):
    pos = m.start()
    in_defs = pos > defs_idx
    print(f"9727.0 at {pos}: in_defs={in_defs}")
    tag_start = text.rfind('<', 0, pos)
    tag_end = text.find('>', pos) + 1
    print("Tag:", text[tag_start:tag_end])
    break
