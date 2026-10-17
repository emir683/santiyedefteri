import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Search for "90 LIK" or "1/50"
for m in re.finditer(r'90\s*L[Iİ]K', text, re.IGNORECASE):
    snippet = text[max(0, m.start()-100):min(len(text), m.end()+100)]
    print("90 LIK snippet:", snippet)

for m in re.finditer(r'1/50', text):
    snippet = text[max(0, m.start()-100):min(len(text), m.end()+100)]
    print("1/50 snippet:", snippet)
