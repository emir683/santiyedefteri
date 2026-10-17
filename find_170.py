import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find '170'
t_170 = list(re.finditer(r'>\s*170\s*<', text))
print("Total '170' occurrences:", len(t_170))
for m in t_170:
    start = max(0, m.start() - 200)
    end = min(len(text), m.end() + 200)
    print("--- 170 snippet ---")
    print(text[start:end])
