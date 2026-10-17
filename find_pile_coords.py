import json

with open('/home/ubuntu/cad-service/public/cad_data.json', 'r') as f:
    d = json.load(f)

texts = d.get('texts', [])

# Find texts containing "90" or "KA" or "EK"
target_texts = []
for t in texts:
    if '90' in t['t'] or 'KA' in t['t'] or 'EK:1' in t['t']:
        target_texts.append(t)

print(f"Target texts found: {len(target_texts)}")
for t in target_texts[:10]:
    print(" ", t)

# What are the lines around this text's coordinates?
if target_texts:
    cx, cy = target_texts[0]['x'], target_texts[0]['y']
    print(f"\nChecking lines near ({cx}, {cy})...")
    lines = d['lines']
    near_lines_count = 0
    for i in range(0, len(lines), 5):
        x1, y1, x2, y2, c = lines[i:i+5]
        if abs(x1 - cx) < 3000 and abs(y1 - cy) < 3000:
            near_lines_count += 1
    print(f"Total line segments within 3000 units of ({cx}, {cy}): {near_lines_count}")
