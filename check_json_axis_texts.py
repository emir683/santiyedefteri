import json

with open('/home/ubuntu/cad-service/public/cad_data.json', 'r') as f:
    d = json.load(f)

texts = d.get('texts', [])
print(f"Total texts in JSON: {len(texts)}")

# Look for texts in the region X in [93000, 98000], Y in [11000, 12500]
plan_texts = [t for t in texts if 93000 <= t['x'] <= 98000 and 11000 <= t['y'] <= 12500]
print(f"Texts in plan region: {len(plan_texts)}")
for t in plan_texts[:30]:
    print("  ", t)

# Are there texts 'A', 'B', 'C', 'D'?
axis_letters = [t for t in plan_texts if t['t'] in ['A', 'B', 'C', 'D', "B'"]]
print(f"\nAxis letters in plan region: {len(axis_letters)}")
for a in axis_letters:
    print("  Axis letter:", a)
