import re
import math
import time

svg_path = "/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.svg"

with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

defs_start = text.find("<defs>")
defs_end = text.find("</defs>")
model_part = text[:defs_start] + text[defs_end + 7:]
defs_part = text[defs_start:defs_end + 7]

color_map = {
    '#ffffff': 0xffffff,
    'white': 0xffffff,
    'yellow': 0xffe600,
    'red': 0xff3b30,
    '#ff0000': 0xff3b30,
    '#ff2d55': 0xff2d55,
    '#ff3b30': 0xff3b30,
    'cyan': 0x00f0ff,
    '#38bdf8': 0x38bdf8,
    '#38BDF8': 0x38bdf8,
    'green': 0x22c55e,
    'magenta': 0xff2d55,
    '#414141': 0xff3b30,
    '#666666': 0x94a3b8,
    'blue': 0x38bdf8,
    '#007fff': 0x38bdf8,
    '#007aff': 0x38bdf8,
    '#ff7f00': 0xff9500,
    '#566845': 0x8a9a5b
}

def parse_color(c_str):
    if not c_str:
        return 0xffffff
    c = c_str.strip().lower()
    if c in color_map:
        return color_map[c]
    if c.startswith('#') and len(c) == 7:
        try:
            return int(c[1:], 16)
        except:
            pass
    return 0xffffff

def identity_matrix():
    return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]

def multiply_matrices(m1, m2):
    a1, b1, c1, d1, e1, f1 = m1
    a2, b2, c2, d2, e2, f2 = m2
    return [
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1
    ]

def parse_transform(trans_str):
    if not trans_str:
        return identity_matrix()
    mat = identity_matrix()
    commands = re.findall(r'(translate|rotate|scale|matrix)\s*\(([^)]+)\)', trans_str)
    for cmd, args_str in commands:
        args = [float(x) for x in re.findall(r'[-+]?\d*\.\d+|\d+', args_str)]
        if cmd == 'translate':
            tx = args[0] if len(args) > 0 else 0.0
            ty = args[1] if len(args) > 1 else 0.0
            t_mat = [1.0, 0.0, 0.0, 1.0, tx, ty]
            mat = multiply_matrices(mat, t_mat)
        elif cmd == 'scale':
            sx = args[0] if len(args) > 0 else 1.0
            sy = args[1] if len(args) > 1 else sx
            s_mat = [sx, 0.0, 0.0, sy, 0.0, 0.0]
            mat = multiply_matrices(mat, s_mat)
        elif cmd == 'rotate':
            deg = args[0] if len(args) > 0 else 0.0
            rad = math.radians(deg)
            cos_a = math.cos(rad)
            sin_a = math.sin(rad)
            if len(args) >= 3:
                cx, cy = args[1], args[2]
                r_mat = multiply_matrices([1,0,0,1,cx,cy], [cos_a, sin_a, -sin_a, cos_a, 0, 0])
                r_mat = multiply_matrices(r_mat, [1,0,0,1,-cx,-cy])
            else:
                r_mat = [cos_a, sin_a, -sin_a, cos_a, 0.0, 0.0]
            mat = multiply_matrices(mat, r_mat)
        elif cmd == 'matrix' and len(args) >= 6:
            mat = multiply_matrices(mat, args[:6])
    return mat

def apply_transform(mat, x, y):
    return mat[0]*x + mat[2]*y + mat[4], mat[1]*x + mat[3]*y + mat[5]

def parse_path_d(d_str, mat):
    segments = []
    tokens = re.findall(r'([a-zA-Z])|([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', d_str)
    current_x = 0.0
    current_y = 0.0
    start_x = 0.0
    start_y = 0.0
    current_cmd = 'M'
    i = 0
    num_tokens = len(tokens)
    
    while i < num_tokens:
        cmd_char, num_str = tokens[i]
        if cmd_char:
            current_cmd = cmd_char
            i += 1
            if i >= num_tokens:
                break
        
        if current_cmd in ('M', 'm'):
            x = float(tokens[i][1])
            y = float(tokens[i+1][1])
            i += 2
            if current_cmd == 'm':
                x += current_x
                y += current_y
            current_x, current_y = x, y
            start_x, start_y = x, y
            current_cmd = 'L' if current_cmd == 'M' else 'l'
            
        elif current_cmd in ('L', 'l'):
            x = float(tokens[i][1])
            y = float(tokens[i+1][1])
            i += 2
            if current_cmd == 'l':
                x += current_x
                y += current_y
            wx1, wy1 = apply_transform(mat, current_x, current_y)
            wx2, wy2 = apply_transform(mat, x, y)
            segments.append((round(wx1, 1), round(wy1, 1), round(wx2, 1), round(wy2, 1)))
            current_x, current_y = x, y
            
        elif current_cmd in ('H', 'h'):
            x = float(tokens[i][1])
            i += 1
            if current_cmd == 'h':
                x += current_x
            wx1, wy1 = apply_transform(mat, current_x, current_y)
            wx2, wy2 = apply_transform(mat, x, current_y)
            segments.append((round(wx1, 1), round(wy1, 1), round(wx2, 1), round(wy2, 1)))
            current_x = x
            
        elif current_cmd in ('V', 'v'):
            y = float(tokens[i][1])
            i += 1
            if current_cmd == 'v':
                y += current_y
            wx1, wy1 = apply_transform(mat, current_x, current_y)
            wx2, wy2 = apply_transform(mat, current_x, y)
            segments.append((round(wx1, 1), round(wy1, 1), round(wx2, 1), round(wy2, 1)))
            current_y = y
            
        elif current_cmd in ('A', 'a'):
            rx = abs(float(tokens[i][1]))
            ry = abs(float(tokens[i+1][1]))
            x = float(tokens[i+5][1])
            y = float(tokens[i+6][1])
            i += 7
            if current_cmd == 'a':
                x += current_x
                y += current_y
            wx1, wy1 = apply_transform(mat, current_x, current_y)
            wx2, wy2 = apply_transform(mat, x, y)
            segments.append((round(wx1, 1), round(wy1, 1), round(wx2, 1), round(wy2, 1)))
            current_x, current_y = x, y
            
        elif current_cmd in ('Z', 'z'):
            wx1, wy1 = apply_transform(mat, current_x, current_y)
            wx2, wy2 = apply_transform(mat, start_x, start_y)
            segments.append((round(wx1, 1), round(wy1, 1), round(wx2, 1), round(wy2, 1)))
            current_x, current_y = start_x, start_y
            i += 1
        else:
            i += 1
            
    return segments

def circle_to_segments(cx, cy, r, mat):
    segments = []
    steps = 24 if r >= 10 else (16 if r >= 2 else 8)
    d_theta = 2.0 * math.pi / steps
    prev_wx, prev_wy = None, None
    first_wx, first_wy = None, None
    
    for s in range(steps + 1):
        theta = s * d_theta
        lx = cx + r * math.cos(theta)
        ly = cy + r * math.sin(theta)
        wx, wy = apply_transform(mat, lx, ly)
        wx = round(wx, 1)
        wy = round(wy, 1)
        if prev_wx is not None:
            segments.append((prev_wx, prev_wy, wx, wy))
        else:
            first_wx, first_wy = wx, wy
        prev_wx, prev_wy = wx, wy
    return segments

# Parse symbols
sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)
symbols = {}

for m in sym_regex.finditer(defs_part):
    sid = m.group(1)
    attrs = m.group(2)
    body = m.group(3)
    
    y_vals = []
    for cy in re.findall(r'cy="([+-]?\d+\.?\d*)"', body):
        y_vals.append(float(cy))
    for ty in re.findall(r'\by="([+-]?\d+\.?\d*)"', body):
        y_vals.append(float(ty))
    for py in re.findall(r'[ML]\s*[+-]?\d+\.?\d*[, ]\s*([+-]?\d+\.?\d*)', body):
        y_vals.append(float(py))
        
    child_uses = re.findall(r'(?:xlink:href|href)="#([^"]+)"', body)
    t_match = re.search(r'transform="([^"]+)"', attrs)
    base_trans = t_match.group(1) if t_match else ""
    
    symbols[sid] = {
        'mat': parse_transform(base_trans),
        'body': body,
        'y_vals': y_vals,
        'child_uses': child_uses
    }

def get_avg_y(sid, visited=None):
    if visited is None:
        visited = set()
    if sid in visited or sid not in symbols:
        return None
    visited.add(sid)
    s = symbols[sid]
    if s['y_vals']:
        return sum(s['y_vals'][:20]) / min(len(s['y_vals']), 20)
    for cu in s['child_uses']:
        cy = get_avg_y(cu, visited)
        if cy is not None:
            return cy
    return None

for sid in symbols:
    avg_y = get_avg_y(sid)
    symbols[sid]['is_offset'] = (avg_y is not None and avg_y < -10000)

lines_data = []
texts_data = []

def process_elements(content, current_mat):
    path_matches = re.finditer(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', content)
    for m in path_matches:
        d_str = m.group(1)
        style = m.group(2)
        stroke_m = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(stroke_m.group(1)) if stroke_m else 0xffffff
        segs = parse_path_d(d_str, current_mat)
        for x1, y1, x2, y2 in segs:
            lines_data.extend([x1, y1, x2, y2, c_int])
            
    circle_matches = re.finditer(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"[^>]*style="([^"]*)"', content)
    for m in circle_matches:
        cx = float(m.group(1))
        cy = float(m.group(2))
        r = float(m.group(3))
        style = m.group(4)
        stroke_m = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(stroke_m.group(1)) if stroke_m else 0xff3b30
        segs = circle_to_segments(cx, cy, r, current_mat)
        for x1, y1, x2, y2 in segs:
            lines_data.extend([x1, y1, x2, y2, c_int])
            
    text_matches = re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*font-size="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', content)
    for m in text_matches:
        x = float(m.group(1))
        y = float(m.group(2))
        size = float(m.group(3))
        fill = m.group(4)
        raw_t = m.group(5).strip()
        wx, wy = apply_transform(current_mat, x, y)
        raw_t = re.sub(r'\\f[^;]+;', '', raw_t)
        raw_t = re.sub(r'\\F[^;]+;', '', raw_t)
        raw_t = re.sub(r'\\[WwHhQqTtAaPp][^;]*;?', '', raw_t)
        raw_t = raw_t.replace('&#x192;', 'Ø').replace('%%c', 'Ø').replace('%%C', 'Ø').replace('&apos;', "'").replace('&#39;', "'")
        c_int = parse_color(fill)
        if raw_t:
            texts_data.append({
                'x': round(wx, 1),
                'y': round(wy, 1),
                's': round(size, 1),
                'c': f"#{c_int:06x}",
                't': raw_t
            })

# Direct ModelSpace
process_elements(model_part, identity_matrix())
print(f"Direct Model: lines={len(lines_data)//5}, texts={len(texts_data)}")

# Recursive symbol renderer
def render_symbol(sid, current_mat, depth=0, max_depth=4):
    if depth > max_depth or sid not in symbols:
        return
    sym = symbols[sid]
    process_elements(sym['body'], current_mat)
    
    # Process child uses
    for child_m in re.finditer(r'<use\s+([^>]+)>', sym['body']):
        c_attrs = child_m.group(1)
        href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', c_attrs)
        if not href_m:
            continue
        c_id = href_m.group(1)
        if c_id not in symbols:
            continue
            
        t_m = re.search(r'transform="([^"]+)"', c_attrs)
        child_trans_mat = parse_transform(t_m.group(1) if t_m else "")
        child_mat = multiply_matrices(current_mat, child_trans_mat)
        render_symbol(c_id, child_mat, depth + 1, max_depth)

# Expand ModelSpace uses
model_uses = list(re.finditer(r'<use\s+([^>]+)>', model_part))
print(f"Expanding {len(model_uses)} ModelSpace <use> instances...")

for m in model_uses:
    tag_attrs = m.group(1)
    href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag_attrs)
    if not href_m:
        continue
    sid = href_m.group(1)
    if sid not in symbols:
        continue
        
    t_m = re.search(r'transform="([^"]+)"', tag_attrs)
    use_mat = parse_transform(t_m.group(1) if t_m else "")
    
    xm = re.search(r'\bx="([+-]?\d+\.?\d*)"', tag_attrs)
    ym = re.search(r'\by="([+-]?\d+\.?\d*)"', tag_attrs)
    if xm or ym:
        ax = float(xm.group(1)) if xm else 0.0
        ay = float(ym.group(1)) if ym else 0.0
        use_mat = multiply_matrices([1.0, 0.0, 0.0, 1.0, ax, ay], use_mat)
        
    sym = symbols[sid]
    if sym['is_offset']:
        combined_mat = multiply_matrices(use_mat, sym['mat'])
    else:
        combined_mat = use_mat
        
    render_symbol(sid, combined_mat, depth=0)

tot_lines = len(lines_data) // 5
print(f"Total lines: {tot_lines}, Total texts: {len(texts_data)}")

# Verify area around Bodrum Kat: X in [43000, 48000], Y in [9500, 14000]
bodrum_lines = []
for i in range(tot_lines):
    idx = i * 5
    x1, y1, x2, y2, c = lines_data[idx:idx+5]
    if (42000 <= x1 <= 49000 and 9000 <= y1 <= 14500) or (42000 <= x2 <= 49000 and 9000 <= y2 <= 14500):
        bodrum_lines.append((x1, y1, x2, y2, c))

bodrum_texts = [t for t in texts_data if 42000 <= t['x'] <= 49000 and 9000 <= t['y'] <= 14500]

print(f"Bodrum Kat area lines: {len(bodrum_lines)}, texts: {len(bodrum_texts)}")
red_lines = [l for l in bodrum_lines if l[4] == 0xff3b30]
print(f"Bodrum Kat RED lines: {len(red_lines)}")
axis_texts = [t for t in bodrum_texts if t['t'] in ['A', 'B', 'C', 'D', 'E', '1', '2', '3', '4', '5', '6']]
print(f"Bodrum Kat AXIS texts: {len(axis_texts)} -> {[t['t'] for t in axis_texts]}")

# Verify area around Zemin Kat: X in [49000, 56000], Y in [9500, 14000]
zemin_lines = []
for i in range(tot_lines):
    idx = i * 5
    x1, y1, x2, y2, c = lines_data[idx:idx+5]
    if (49000 <= x1 <= 56000 and 9000 <= y1 <= 14500) or (49000 <= x2 <= 56000 and 9000 <= y2 <= 14500):
        zemin_lines.append((x1, y1, x2, y2, c))

zemin_texts = [t for t in texts_data if 49000 <= t['x'] <= 56000 and 9000 <= t['y'] <= 14500]
print(f"Zemin Kat area lines: {len(zemin_lines)}, texts: {len(zemin_texts)}")
z_red_lines = [l for l in zemin_lines if l[4] == 0xff3b30]
print(f"Zemin Kat RED lines: {len(z_red_lines)}")
z_axis_texts = [t for t in zemin_texts if t['t'] in ['A', 'B', 'C', 'D', 'E', '1', '2', '3', '4', '5', '6']]
print(f"Zemin Kat AXIS texts: {len(z_axis_texts)} -> {[t['t'] for t in z_axis_texts]}")

