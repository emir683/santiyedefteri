import json
from collections import Counter

with open("/home/ubuntu/cad-service/public/cad_data.json", "r") as f:
    d = json.load(f)

lines = d["lines"]
total_lines = len(lines) // 5
print("Total lines in JSON:", total_lines)

colors = Counter()
for i in range(4, len(lines), 5):
    c = lines[i]
    colors[f"0x{c:06x}"] += 1

print("\nLine colors:")
for c, cnt in colors.most_common(20):
    print(f"  {c}: {cnt}")

texts = d.get("texts", [])
print(f"\nTotal texts: {len(texts)}")
text_colors = Counter(t["c"] for t in texts)
print("Text colors:")
for c, cnt in text_colors.most_common(10):
    print(f"  {c}: {cnt}")

# Check sample texts: do we have "235"?
sample_235 = [t for t in texts if "235" in t["t"]]
print(f"\nTexts containing '235': {len(sample_235)}")
for t in sample_235[:5]:
    print(" ", t)

# Check axis labels (e.g. A, B, C, 1, 2, 3...)
# Where are axis lines?
print("\nChecking bounds in JSON:", d["bounds"])
