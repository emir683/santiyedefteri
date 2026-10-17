import re
from collections import Counter

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

defs_idx = text.find('<defs>')
model_text = text[:defs_idx]
defs_text = text[defs_idx:]

# Find all uses in ModelSpace
uses = re.findall(r'<use[^>]+xlink:href="#([^"]+)"', model_text)
print(f"Total <use> tags in ModelSpace: {len(uses)}")
used_symbol_ids = set(uses)
print(f"Unique symbol IDs used in ModelSpace: {len(used_symbol_ids)}")

# In defs, let's parse each symbol
sym_pattern = re.compile(r'<g\s+id="([^"]+)"[^>]*>(.*?)</g>', re.DOTALL)
symbols_dict = {}
for m in sym_pattern.finditer(defs_text):
    sym_id = m.group(1)
    sym_content = m.group(2)
    symbols_dict[sym_id] = sym_content

print(f"Total symbols found in defs: {len(symbols_dict)}")

# For symbols used in ModelSpace, what do they contain?
sym_element_counts = Counter()
for s_id in used_symbol_ids:
    content = symbols_dict.get(s_id, '')
    tags = re.findall(r'<([a-zA-Z0-9_\-]+)[\s>]', content)
    for t in tags:
        sym_element_counts[t] += 1

print("\nElements inside symbols referenced by ModelSpace:")
for t, cnt in sym_element_counts.most_common():
    print(f"  <{t}>: {cnt}")

# Let's see some sample contents of used symbols
print("\nSample symbols:")
for s_id in list(used_symbol_ids)[:5]:
    c = symbols_dict.get(s_id, '')
    print(f"Symbol {s_id} (len {len(c)}): {c[:150]}...")
