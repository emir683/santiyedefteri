import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', errors='ignore') as f:
    text = f.read()

# Find symbol-101C3F3A7
m = re.search(r'<g\s+id="symbol-101C3F3A7"[^>]*>(.*?)</g>', text, re.DOTALL)
if m:
    body = m.group(1)
    print("symbol-101C3F3A7 len:", len(body))
    # Extract texts
    texts = re.findall(r'<text[^>]*>([^<]+)</text>', body)
    print("Texts in symbol-101C3F3A7:", texts[:10])
    # Extract comments or ids
    comments = re.findall(r'<!--\s*([^*]+)\s*-->', body)
    print("Comments in symbol-101C3F3A7:", comments[:10])
