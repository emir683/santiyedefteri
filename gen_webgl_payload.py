import re
import json
import time

t0 = time.time()
svg_path = "/home/ubuntu/cad-service/uploads/b3c9291a-7f7a-4bf4-a40f-fd5f8ae51327.svg"
out_json = "/home/ubuntu/cad-service/public/cad_data.json"

print("Reading SVG...")
with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# Color mapping to integers/hex
color_map = {
    '#ffffff': 0xffffff,
    'white': 0xffffff,
    'yellow': 0xffe600,
    'red': 0xff3b30,
    'cyan': 0x00f0ff,
    '#38bdf8': 0x38bdf8,
    'green': 0x34c759,
    'magenta': 0xff2d55,
    '#414141': 0x666666,
    'blue': 0x007aff,
    '#007fff': 0x007fff,
    '#ff7f00': 0xff9500,
    '#566845': 0x8a9a5b
}

def parse_color(c_str):
    c = c_str.strip().lower()
    if c in color_map:
        return color_map[c]
    if c.startswith('#') and len(c) == 7:
        try:
            return int(c[1:], 16)
        except:
            pass
    return 0xffffff

# 1. Parse all paths in ModelSpace:
# Line paths: M x1,y1 L x2,y2
# We can collect flat float arrays: [x1, y1, x2, y2, color, ...]
lines_data = []

# Quick regex for M x1,y1 L x2,y2
print("Extracting line paths...")
path_regex = re.compile(r'<path[^>]+d="M\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)\s*L\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)"[^>]*style="([^"]*)"')

for m in path_regex.finditer(text):
    x1 = float(m.group(1))
    y1 = float(m.group(2))
    x2 = float(m.group(3))
    y2 = float(m.group(4))
    style = m.group(5)
    
    # Extract stroke color
    stroke_m = re.search(r'stroke:([^;"]+)', style)
    c_int = parse_color(stroke_m.group(1)) if stroke_m else 0xffffff
    
    lines_data.extend([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), c_int])

print(f"Total lines extracted: {len(lines_data) // 5}")

# 2. Extract texts
print("Extracting texts...")
texts_data = []
text_regex = re.compile(r'<text[^>]+x="([+-]?\d+\.?\d*)"\s+y="([+-]?\d+\.?\d*)"[^>]*font-size="([+-]?\d+\.?\d*)"[^>]*fill="([^"]*)"[^>]*>([^<]+)</text>')

for m in text_regex.finditer(text):
    x = float(m.group(1))
    y = float(m.group(2))
    size = float(m.group(3))
    fill = m.group(4)
    content = m.group(5).strip()
    c_int = parse_color(fill)
    
    # Clean formatting codes
    content = re.sub(r'\\f[^;]+;', '', content)
    content = re.sub(r'\\F[^;]+;', '', content)
    content = re.sub(r'\\[WwHhQqTtAaPp][^;]*;?', '', content)
    content = content.replace('&#x192;', 'Ø').replace('%%c', 'Ø').replace('%%C', 'Ø')
    
    if content:
        texts_data.append({
            'x': round(x, 1),
            'y': round(y, 1),
            's': round(size, 1),
            'c': f"#{c_int:06x}",
            't': content
        })

print(f"Total texts extracted: {len(texts_data)}")

# ViewBox bounds
vb_m = re.search(r'viewBox="([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)"', text)
bounds = {
    'minX': float(vb_m.group(1)) if vb_m else -4000,
    'minY': float(vb_m.group(2)) if vb_m else -700,
    'w': float(vb_m.group(3)) if vb_m else 208000,
    'h': float(vb_m.group(4)) if vb_m else 16000
}

payload = {
    'bounds': bounds,
    'lines': lines_data,
    'texts': texts_data
}

print(f"Writing JSON to {out_json}...")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(payload, f)

import os
sz = os.path.getsize(out_json)
print(f"Done in {time.time()-t0:.2f}s! JSON size: {sz / (1024*1024):.2f} MB")
