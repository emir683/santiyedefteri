import re

with open('/tmp/raw_5fe.svg', 'r', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx] if defs_idx != -1 else text

# ModelSpace texts
titles = re.findall(r'<text[^>]+x="([+-]?\d+\.?\d*)"[^>]+y="([+-]?\d+\.?\d*)"[^>]*>([^<]+)</text>', model_text)
print('Direct ModelSpace texts:', len(titles))

plan_titles = [t for t in titles if any(w in t[2].upper() for w in ['PLAN', 'KİRİŞ', 'TEMEL', 'DETAY', 'DONATI', 'KESİT', 'KOLON', 'VAZİ'])]
print('Found plan title texts in direct ModelSpace:', len(plan_titles))
for pt in plan_titles[:25]:
    print(f"{pt[2].strip()}: X={float(pt[0]):.1f}, Y={float(pt[1]):.1f}")
