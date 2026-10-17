import json

with open('/home/ubuntu/cad-service/public/cad_data.json') as f:
    d = json.load(f)

lines = d['lines']
texts = d['texts']

pile_lines = []
for i in range(0, len(lines), 5):
    x1, y1, x2, y2, c = lines[i:i+5]
    if -2000 <= x1 <= 15000 and -2000 <= y1 <= 15000:
        pile_lines.append((x1, y1, x2, y2, c))

print(f"Pile lines count: {len(pile_lines)}")
for pl in pile_lines[:15]:
    print(" ", pl)
