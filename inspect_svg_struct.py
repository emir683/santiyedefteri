import re

svg_path = '/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg'
with open(svg_path, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

print("File size:", len(text))

# Find defs positions
defs_start = text.find('<defs>')
defs_end = text.find('</defs>')
print(f"<defs> at: {defs_start}, </defs> at: {defs_end}")

# Find symbols
symbols = re.findall(r'<g\s+id="([^"]+)"', text)
print(f"Total <g id='...'> elements: {len(symbols)}")
print("Sample g ids:", symbols[:10])

# Find uses
uses = re.findall(r'<use\s+href="#([^"]+)"\s+x="([^"]*)"\s+y="([^"]*)"', text)
print(f"Total <use> elements with href, x, y: {len(uses)}")
if not uses:
    uses = re.findall(r'<use[^>]+>', text)
    print(f"Total <use ...> raw elements: {len(uses)}")
    if uses:
        print("Sample use:", uses[0])

# Check what elements have stroke:red
red_elements = []
for m in re.finditer(r'<([a-zA-Z0-9]+)[^>]*stroke:(red|#ff0000|#ff2d55|#ff3b30)[^>]*>', text, re.I):
    tag = m.group(0)
    red_elements.append(tag)

print(f"Total red stroke elements: {len(red_elements)}")
for r in red_elements[:10]:
    print("Red element:", r[:120])
