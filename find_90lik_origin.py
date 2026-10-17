import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')

for m in re.finditer(r'90\s*L[Iİ]K\s*KA', text, re.IGNORECASE):
    pos = m.start()
    in_defs = pos > defs_idx
    print(f"Match at pos {pos}: in_defs={in_defs}")
    tag_start = text.rfind('<', 0, pos)
    tag_end = text.find('>', pos) + 1
    print("Tag:", text[tag_start:tag_end])
    # Context (150 chars before and after)
    print("Context before:", text[max(0, tag_start-200):tag_start])
    print("Context after:", text[tag_end:min(len(text), tag_end+200)])
