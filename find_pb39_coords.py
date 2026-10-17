import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find PB39
pb_matches = list(re.finditer(r'PB39', text))
print("PB39 matches:", len(pb_matches))

for m in pb_matches:
    start = max(0, m.start() - 100)
    end = min(len(text), m.end() + 100)
    print("PB39 snippet:", text[start:end])

# Also search for '170' near PB39 or 235
# Where are 235 and 170?
t_235 = list(re.finditer(r'>\s*235\s*<', text))
print("\n'235' occurrences:", len(t_235))
for m in t_235[:5]:
    start = max(0, m.start() - 150)
    end = min(len(text), m.end() + 150)
    print("235 tag snippet:", text[start:end])
