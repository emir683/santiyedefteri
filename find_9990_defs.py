import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
defs_text = text[defs_idx:]

matches = list(re.finditer(r'9990\.2', defs_text))
print("Total 9990.2 in defs:", len(matches))
for m in matches[:5]:
    pos = m.start()
    tag_start = defs_text.rfind('<', 0, pos)
    tag_end = defs_text.find('>', pos) + 1
    # Find symbol
    sym_start = defs_text.rfind('<g id="', 0, pos)
    sym_end = defs_text.find('"', sym_start + 7)
    sym_id = defs_text[sym_start+7:sym_end]
    print(f"In symbol '{sym_id}': {defs_text[tag_start:tag_end]}")
