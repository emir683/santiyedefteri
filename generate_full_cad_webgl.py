import re
import json
import math
import time
import gzip
import os
import sys
import numpy as np

t0 = time.time()
svg_path = sys.argv[1] if len(sys.argv) > 1 else "/home/ubuntu/cad-service/uploads/87b6f0bc-dc50-4fbc-959b-e1302122afd0.svg"
out_json = sys.argv[2] if len(sys.argv) > 2 else "/home/ubuntu/cad-service/public/cad_data.json"
out_gz = out_json + ".gz"

print(f"Reading {svg_path}...")
with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# Fix legacy monochrome blue injection
text = text.replace('stroke:black', 'stroke:#FFFFFF')

defs_start = text.find("<defs>")
defs_end = text.find("</defs>")

if defs_start != -1 and defs_end != -1:
    model_part = text[:defs_start] + text[defs_end + 7:]
    defs_part = text[defs_start:defs_end + 7]
else:
    model_part = text
    defs_part = ""

vb_match = re.search(r'viewBox="([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)\s+([+-]?\d+\.?\d*)"', text)
if vb_match:
    bounds = {
        'minX': float(vb_match.group(1)),
        'minY': float(vb_match.group(2)),
        'w': float(vb_match.group(3)),
        'h': float(vb_match.group(4))
    }
else:
    bounds = {'minX': -5048.34, 'minY': -1034.74, 'w': 262513.69, 'h': 22764.35}

BOUNDS_MIN_X = bounds['minX'] - 15000.0
BOUNDS_MAX_X = bounds['minX'] + bounds['w'] + 15000.0
BOUNDS_MIN_Y = bounds['minY'] - 15000.0
BOUNDS_MAX_Y = bounds['minY'] + bounds['h'] + 15000.0

color_map = {
    '#ffffff': 0xffffff, 'white': 0xffffff,
    'yellow': 0xffe600, '#ffeaaa': 0xffe600, '#ffffaa': 0xffe600, '#ffbf00': 0xffe600,
    'red': 0xff3b30, '#ff0000': 0xff3b30, '#ff3b30': 0xff3b30,
    '#414141': 0xff3b30,  # VM Aks dash-dot centerlines -> Vivid RED
    'cyan': 0x00f0ff, '#00f0ff': 0x00f0ff, '#00bfff': 0x00f0ff,
    '#7eadbd': 0x00f0ff,  # Architectural dimension lines -> bright cyan
    'green': 0x22c55e, '#22c55e': 0x22c55e, '#00ff3f': 0x22c55e,
    'magenta': 0xff2d55, '#ff2d55': 0xff2d55, '#ffaaea': 0xff2d55, '#ff007f': 0xff2d55,
    'blue': 0x38bdf8, '#38bdf8': 0x38bdf8, '#007fff': 0x38bdf8, '#007aff': 0x38bdf8,
    '#666666': 0x64748b, '#808080': 0x64748b, '#505050': 0x64748b, '#333333': 0x64748b,
    '#ff7f00': 0xff9500, '#566845': 0x8a9a5b
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
            mat = multiply_matrices(mat, [1.0, 0.0, 0.0, 1.0, tx, ty])
        elif cmd == 'scale':
            sx = args[0] if len(args) > 0 else 1.0
            sy = args[1] if len(args) > 1 else sx
            mat = multiply_matrices(mat, [sx, 0.0, 0.0, sy, 0.0, 0.0])
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
    return mat[0] * x + mat[2] * y + mat[4], mat[1] * x + mat[3] * y + mat[5]

all_sym_min_x = []
all_sym_max_y = []
for m in re.finditer(r'<path[^>]+d="M\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', defs_part):
    px = float(m.group(1))
    py = float(m.group(2))
    if px > 1000 and py < -1000:
        all_sym_min_x.append(round(px, 1))
        all_sym_max_y.append(round(py, 1))

def most_frequent(arr):
    if not arr: return 0.0
    c = {}
    for v in arr: c[v] = c.get(v, 0) + 1
    return max(c.items(), key=lambda x: x[1])[0]

BASE_X = most_frequent(all_sym_min_x) or 47599.4
BASE_Y = most_frequent(all_sym_max_y) or -28187.4
print(f"Detected global block base point: ({BASE_X}, {BASE_Y})")
OFFSET_SHIFT_MAT = [1.0, 0.0, 0.0, 1.0, -BASE_X, -BASE_Y]

symbols = {}
sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)
for m in sym_regex.finditer(defs_part):
    sid = m.group(1)
    attrs = m.group(2)
    body = m.group(3)
    ys = [float(cy) for cy in re.findall(r'cy="([+-]?\d+\.?\d*)"', body)]
    ys += [float(ty) for ty in re.findall(r'\by="([+-]?\d+\.?\d*)"', body)]
    ys += [float(py) for py in re.findall(r'[ML]\s*[+-]?\d+\.?\d*[, ]\s*([+-]?\d+\.?\d*)', body)]
    avg_y = sum(ys[:20]) / min(len(ys), 20) if ys else None
    t_match = re.search(r'transform="([^"]+)"', attrs)
    base_trans = t_match.group(1) if t_match else ""
    if avg_y is not None and avg_y > -1000 and base_trans:
        base_trans = ""
    has_own_trans = bool(base_trans)
    needs_base_shift = (avg_y is not None and avg_y < -10000 and not has_own_trans)
    child_uses = re.findall(r'(?:xlink:href|href)="#([^"]+)"', body)
    symbols[sid] = {
        'mat': parse_transform(base_trans),
        'body': body,
        'child_uses': child_uses,
        'needs_base_shift': needs_base_shift
    }

lines_data = [] # [x1, y1, x2, y2, color, ...]
texts_data = []
triangles_data = [] # [x1, y1, x2, y2, x3, y3, color, ...]

def add_line(x1, y1, x2, y2, color):
    if not (BOUNDS_MIN_X <= x1 <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= y1 <= BOUNDS_MAX_Y and
            BOUNDS_MIN_X <= x2 <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= y2 <= BOUNDS_MAX_Y):
        return
    lines_data.extend([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), color])

def add_triangle(p1, p2, p3, color):
    # Check bounds
    if not (BOUNDS_MIN_X <= p1[0] <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= p1[1] <= BOUNDS_MAX_Y):
        return
    triangles_data.extend([
        round(p1[0], 1), round(p1[1], 1),
        round(p2[0], 1), round(p2[1], 1),
        round(p3[0], 1), round(p3[1], 1),
        color
    ])

def add_text(wx, wy, size, fill, raw_t):
    if not (BOUNDS_MIN_X <= wx <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= wy <= BOUNDS_MAX_Y):
        return
    raw_t = re.sub(r'\\f[^;]+;', '', raw_t)
    raw_t = re.sub(r'\\F[^;]+;', '', raw_t)
    raw_t = re.sub(r'\\[WwHhQqTtAaPp][^;]*;?', '', raw_t)
    raw_t = raw_t.replace('&#x192;', 'Ø').replace('%%c', 'Ø').replace('%%C', 'Ø').replace('%%d', '°').replace('%%p', '±').replace('&apos;', "'").replace('&#39;', "'")
    c_int = parse_color(fill)
    texts_data.append({
        'x': round(wx, 1),
        'y': round(wy, 1),
        's': round(size, 1),
        'c': f"#{c_int:06x}",
        't': raw_t.strip()
    })

def parse_path_d(d_str, mat):
    tokens = re.findall(r'([a-zA-Z])|([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', d_str)
    current_x = current_y = start_x = start_y = 0.0
    current_cmd = 'M'
    i = 0
    num_tokens = len(tokens)
    while i < num_tokens:
        cmd_char, num_str = tokens[i]
        if cmd_char:
            current_cmd = cmd_char
            i += 1
            if i >= num_tokens: break
        if current_cmd in ('M', 'm'):
            x = float(tokens[i][1]); y = float(tokens[i+1][1]); i += 2
            if current_cmd == 'm': current_x += x; current_y += y
            else: current_x, current_y = x, y
            start_x, start_y = current_x, current_y
            current_cmd = 'L' if current_cmd == 'M' else 'l'
        elif current_cmd in ('L', 'l'):
            x = float(tokens[i][1]); y = float(tokens[i+1][1]); i += 2
            prev_x, prev_y = current_x, current_y
            if current_cmd == 'l': current_x += x; current_y += y
            else: current_x, current_y = x, y
            wx1, wy1 = apply_transform(mat, prev_x, prev_y)
            wx2, wy2 = apply_transform(mat, current_x, current_y)
            yield wx1, wy1, wx2, wy2
        elif current_cmd in ('H', 'h'):
            x = float(tokens[i][1]); i += 1
            prev_x = current_x
            if current_cmd == 'h': current_x += x
            else: current_x = x
            wx1, wy1 = apply_transform(mat, prev_x, current_y)
            wx2, wy2 = apply_transform(mat, current_x, current_y)
            yield wx1, wy1, wx2, wy2
        elif current_cmd in ('V', 'v'):
            y = float(tokens[i][1]); i += 1
            prev_y = current_y
            if current_cmd == 'v': current_y += y
            else: current_y = y
            wx1, wy1 = apply_transform(mat, current_x, prev_y)
            wx2, wy2 = apply_transform(mat, current_x, current_y)
            yield wx1, wy1, wx2, wy2
        elif current_cmd in ('Z', 'z'):
            if current_x != start_x or current_y != start_y:
                wx1, wy1 = apply_transform(mat, current_x, current_y)
                wx2, wy2 = apply_transform(mat, start_x, start_y)
                yield wx1, wy1, wx2, wy2
                current_x, current_y = start_x, start_y
        else:
            i += 1

def circle_to_segments(cx, cy, r, mat, num_segs=24):
    pts = [apply_transform(mat, cx + r * math.cos(2*math.pi*i/num_segs), cy + r * math.sin(2*math.pi*i/num_segs)) for i in range(num_segs)]
    return [(pts[i][0], pts[i][1], pts[(i+1)%num_segs][0], pts[(i+1)%num_segs][1]) for i in range(num_segs)]

def process_elements(content, current_mat):
    scale_mag = math.hypot(current_mat[0], current_mat[1])
    for m in re.finditer(r'<path[^>]+d="([^"]+)"[^>]*style="([^"]*)"', content):
        d_str = m.group(1); style = m.group(2)
        sm = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(sm.group(1)) if sm else 0xffffff
        for x1, y1, x2, y2 in parse_path_d(d_str, current_mat):
            add_line(x1, y1, x2, y2, c_int)
            
    for m in re.finditer(r'<circle[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+r="([^"]+)"[^>]*style="([^"]*)"', content):
        cx = float(m.group(1)); cy = float(m.group(2)); r = float(m.group(3))
        style = m.group(4)
        sm = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(sm.group(1)) if sm else 0xff3b30
        for x1, y1, x2, y2 in circle_to_segments(cx, cy, r, current_mat):
            add_line(x1, y1, x2, y2, c_int)
            
    for m in re.finditer(r'<polygon[^>]+points="([^"]+)"[^>]*style="([^"]*)"', content):
        pts_raw = [float(v) for v in re.findall(r'[-+]?\d*\.\d+|\d+', m.group(1))]
        style = m.group(2)
        sm = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(sm.group(1)) if sm else 0xffffff
        if len(pts_raw) >= 4:
            pts = [(pts_raw[k], pts_raw[k+1]) for k in range(0, len(pts_raw)-1, 2)]
            for k in range(len(pts)):
                p1 = apply_transform(current_mat, pts[k][0], pts[k][1])
                p2 = apply_transform(current_mat, pts[(k+1)%len(pts)][0], pts[(k+1)%len(pts)][1])
                add_line(p1[0], p1[1], p2[0], p2[1], c_int)
            
    for m in re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*font-size="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', content):
        x = float(m.group(1)); y = float(m.group(2)); size = float(m.group(3))
        fill = m.group(4); raw_t = m.group(5).strip()
        wx, wy = apply_transform(current_mat, x, y)
        add_text(wx, wy, size * scale_mag, fill, raw_t)

process_elements(model_part, identity_matrix())

def render_symbol(sid, current_mat, depth=0, max_depth=5):
    if depth > max_depth or sid not in symbols: return
    sym = symbols[sid]
    elem_mat = multiply_matrices(current_mat, OFFSET_SHIFT_MAT) if sym['needs_base_shift'] else current_mat
    process_elements(sym['body'], elem_mat)
    for child_m in re.finditer(r'<use\s+([^>]+)>', sym['body']):
        c_attrs = child_m.group(1)
        href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', c_attrs)
        if not href_m: continue
        c_id = href_m.group(1)
        if c_id not in symbols: continue
        t_m = re.search(r'transform="([^"]+)"', c_attrs)
        child_trans_mat = parse_transform(t_m.group(1) if t_m else "")
        xm = re.search(r'\bx="([+-]?\d+\.?\d*)"', c_attrs)
        ym = re.search(r'\by="([+-]?\d+\.?\d*)"', c_attrs)
        if xm or ym:
            ax = float(xm.group(1)) if xm else 0.0
            ay = float(ym.group(1)) if ym else 0.0
            child_trans_mat = multiply_matrices([1, 0, 0, 1, ax, ay], child_trans_mat)
        child_mat = multiply_matrices(current_mat, child_trans_mat)
        render_symbol(c_id, child_mat, depth + 1, max_depth)

for m in re.finditer(r'<use\s+([^>]+)>', model_part):
    tag_attrs = m.group(1)
    href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag_attrs)
    if not href_m: continue
    sym_id = href_m.group(1)
    if sym_id not in symbols: continue
    t_m = re.search(r'transform="([^"]+)"', tag_attrs)
    use_mat = parse_transform(t_m.group(1) if t_m else "")
    xm = re.search(r'\bx="([+-]?\d+\.?\d*)"', tag_attrs)
    ym = re.search(r'\by="([+-]?\d+\.?\d*)"', tag_attrs)
    if xm or ym:
        ax = float(xm.group(1)) if xm else 0.0
        ay = float(ym.group(1)) if ym else 0.0
        use_mat = multiply_matrices([1.0, 0.0, 0.0, 1.0, ax, ay], use_mat)
    sym = symbols[sym_id]
    combined_mat = multiply_matrices(use_mat, sym['mat'])
    render_symbol(sym_id, combined_mat, depth=0)

# Robust Polygon Triangulation for Solid Hatches
def triangulate_polygon(pts):
    n = len(pts)
    if n < 3: return []
    if n == 3: return [(pts[0], pts[1], pts[2])]
    if n == 4: return [(pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])]
    def area2(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    def is_point_in_tri(p, a, b, c):
        d1 = area2(p, a, b); d2 = area2(p, b, c); d3 = area2(p, c, a)
        return not (((d1 < 0) or (d2 < 0) or (d3 < 0)) and ((d1 > 0) or (d2 > 0) or (d3 > 0)))
    indices = list(range(n))
    total_area = sum((pts[(i+1)%n][0] - pts[i][0]) * (pts[(i+1)%n][1] + pts[i][1]) for i in range(n))
    if total_area > 0: indices.reverse()
    triangles = []
    attempts = 0
    while len(indices) > 3 and attempts < 100:
        attempts += 1
        found_ear = False
        for i in range(len(indices)):
            prev_i = indices[i - 1]; curr_i = indices[i]; next_i = indices[(i + 1) % len(indices)]
            a = pts[prev_i]; b = pts[curr_i]; c = pts[next_i]
            if area2(a, b, c) <= 1e-6: continue
            is_ear = True
            for k in indices:
                if k not in (prev_i, curr_i, next_i) and is_point_in_tri(pts[k], a, b, c):
                    is_ear = False; break
            if is_ear:
                triangles.append((a, b, c))
                indices.pop(i)
                found_ear = True
                break
        if not found_ear: break
    if len(indices) == 3:
        triangles.append((pts[indices[0]], pts[indices[1]], pts[indices[2]]))
    elif len(indices) > 3:
        for i in range(1, len(indices) - 1):
            triangles.append((pts[indices[0]], pts[indices[i]], pts[indices[i+1]]))
    return triangles

# EXTRACT SOLID HATCHES FROM DXF (Columns, Beams, Walls, Foundations)
dxf_candidate = svg_path.replace('.svg', '.dxf')
dwg_candidate = svg_path.replace('.svg', '.dwg')
if not os.path.exists(dxf_candidate) and os.path.exists(dwg_candidate):
    print(f"Generating DXF from DWG: {dwg_candidate}...")
    os.system(f'dwg2dxf -y "{dwg_candidate}" -o "{dxf_candidate}" 2>/dev/null')

if os.path.exists(dxf_candidate):
    print(f"Extracting solid architectural hatches and fills from {dxf_candidate}...")
    try:
        import ezdxf
        doc = ezdxf.readfile(dxf_candidate)
        msp = doc.modelspace()
        block_map = {b.name: b for b in doc.blocks}
        solid_tri_count = 0
        
        # Calculate exact DXF to SVG offset using text matching across all projects
        CALC_BASE_X = BASE_X
        CALC_BASE_Y = BASE_Y
        try:
            from collections import Counter
            svg_map = {}
            for st in texts_data:
                txt = st['t'].strip()
                if len(txt) >= 4 and not any(txt.startswith(c) for c in ['GREEN', 'RED', 'CYAN', 'YELLOW', 'ÖLÇEK', 'OLCEK']):
                    svg_map.setdefault(txt, []).append((st['x'], st['y']))
            
            matches = []
            for t in msp.query('TEXT MTEXT'):
                txt = (t.dxf.text if t.dxftype() == 'TEXT' else t.text).strip()
                if txt in svg_map:
                    for sx, sy in svg_map[txt]:
                        diff_x = sx - t.dxf.insert.x
                        diff_y = sy + t.dxf.insert.y
                        matches.append((diff_x, diff_y))
            
            if matches:
                rx = Counter([round(m[0], -1) for m in matches])
                ry = Counter([round(m[1], -1) for m in matches])
                best_rx = rx.most_common(1)[0][0]
                best_ry = ry.most_common(1)[0][0]
                close_x = [m[0] for m in matches if abs(m[0] - best_rx) < 100]
                close_y = [m[1] for m in matches if abs(m[1] - best_ry) < 100]
                if close_x and close_y:
                    CALC_BASE_X = round(sum(close_x) / len(close_x), 1)
                    CALC_BASE_Y = round(sum(close_y) / len(close_y), 1)
                    print(f"Auto-calibrated offset from {len(matches)} text matches: ({CALC_BASE_X}, {CALC_BASE_Y})")
            else:
                print(f"Fallback to global block base point: ({CALC_BASE_X}, {CALC_BASE_Y})")
        except Exception as ce:
            print(f"Calibration note: {ce}")

        def dxf_to_svg(x, y):
            return (x + CALC_BASE_X, -y + CALC_BASE_Y)

        def transform_pt_by_insert(px, py, ins):
            sx = ins.dxf.xscale if ins.dxf.hasattr('xscale') else 1.0
            sy = ins.dxf.yscale if ins.dxf.hasattr('yscale') else 1.0
            rot = math.radians(ins.dxf.rotation if ins.dxf.hasattr('rotation') else 0.0)
            cos_r = math.cos(rot)
            sin_r = math.sin(rot)
            x_sc = px * sx
            y_sc = py * sy
            x_rot = x_sc * cos_r - y_sc * sin_r
            y_rot = x_sc * sin_r + y_sc * cos_r
            return (x_rot + ins.dxf.insert.x, y_rot + ins.dxf.insert.y)

        # Collect all hatches: both direct modelspace and from block inserts
        hatch_items = []
        for h in msp.query('HATCH'):
            hatch_items.append((h, None))

        for ins in msp.query('INSERT'):
            bname = ins.dxf.name
            if bname in block_map:
                b = block_map[bname]
                for h in b.query('HATCH'):
                    hatch_items.append((h, ins))

        print(f"Processing total of {len(hatch_items)} hatch elements...")

        for h, ins in hatch_items:
            layer = h.dxf.layer.lower() if h.dxf.hasattr('layer') else ''
            pat = h.dxf.pattern_name.upper() if h.dxf.hasattr('pattern_name') else ''
            is_solid = (h.dxf.solid_fill == 1) if h.dxf.hasattr('solid_fill') else (pat == 'SOLID')

            # Strictly only solid architectural fills for columns, shear walls / beams, and section details (FastView Standard)
            # NEVER fill foundation elevation plans (temel), slabs (doseme), paper (pafta), descriptions (tarif), dimensions, or non-solid patterns
            is_excluded = any(ex in layer for ex in [
                'temel', 'temal', 'doseme', 'döşeme', 'pafta', 'tarif', 'olcu', 'ölçü', 
                'saft', 'şaft', 'aks', 'yazi', 'yazı', 'text', 'donati', 'donatı', 
                'demir', 'kot', 'drenaj', 'cati', 'çatı', 'tefris', 'tefriş', 'buhar', 'asansör', 'asansor', 'parapet'
            ])
            if is_excluded:
                continue

            is_col = any(k in layer for k in ['kolon', 'column', 'sutun', 'sütun'])
            is_wall = any(w in layer for w in ['perde', 'kiris', 'kiriş', 'beam', 'wall'])
            is_sec = ('kesit' in layer and 'tarama' in layer)
            is_generic_tar = layer in ['tar', 'tarama']

            if not (is_solid and (is_col or is_wall or is_sec or is_generic_tar)):
                continue

            if is_wall:
                c_fill = 0xa05252 # Terracotta / Reddish-Brown (FastView beam / shear wall fill)
                c_outline = 0xb85d5d
            elif is_col:
                c_fill = 0x527273 # Slate-Teal / Gray-Cyan (FastView column fill)
                c_outline = 0x709293
            else:
                c_fill = 0x527273
                c_outline = 0x64748b

            for p in h.paths:
                pts = []
                if hasattr(p, 'vertices'):
                    pts = [(v[0], v[1]) for v in p.vertices]
                elif hasattr(p, 'edges'):
                    for edge in p.edges:
                        if hasattr(edge, 'start'):
                            pts.append((edge.start[0], edge.start[1]))
                if len(pts) < 3: continue

                # Apply block insert transform if inside a block
                if ins is not None:
                    msp_pts = [transform_pt_by_insert(pt[0], pt[1], ins) for pt in pts]
                else:
                    msp_pts = pts

                # Transform to SVG world coordinates
                svg_pts = [dxf_to_svg(pt[0], pt[1]) for pt in msp_pts]

                # 1. Add solid filled triangles
                tris = triangulate_polygon(svg_pts)
                for t1, t2, t3 in tris:
                    add_triangle(t1, t2, t3, c_fill)
                    solid_tri_count += 1

                # 2. Add outline lines to reinforce sharp edges
                for i in range(len(svg_pts)):
                    p1 = svg_pts[i]
                    p2 = svg_pts[(i+1)%len(svg_pts)]
                    add_line(p1[0], p1[1], p2[0], p2[1], c_outline)

        print(f"Successfully generated {solid_tri_count} solid fill triangles from DXF!")
    except Exception as e:
        print(f"Hatch triangulation note: {e}")

total_lines_count = len(lines_data) // 5
total_triangles_count = len(triangles_data) // 7
print(f"Extraction COMPLETE! Lines: {total_lines_count}, Solid Triangles: {total_triangles_count}, Texts: {len(texts_data)}")

payload = {
    'bounds': bounds,
    'lines': lines_data,
    'triangles': triangles_data,
    'texts': texts_data
}

print(f"Saving JSON to {out_json}...")
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(payload, f)

with open(out_json, 'rb') as f_in, gzip.open(out_gz, 'wb', compresslevel=6) as f_out:
    f_out.writelines(f_in)

# High-Performance Binary Buffers (Zero-Copy WebGL Loading)
try:
    if 'cad_data.json' in out_json:
        out_meta = out_json.replace('cad_data.json', 'cad_meta.json')
        out_bin = out_json.replace('cad_data.json', 'cad_vertices.bin')
    else:
        out_meta = out_json.replace('.json', '_meta.json')
        out_bin = out_json.replace('.json', '_vertices.bin')
        
    out_meta_gz = out_meta + '.gz'
    out_bin_gz = out_bin + '.gz'
    
    meta_payload = {
        'bounds': bounds,
        'totalLines': total_lines_count,
        'totalTriangles': total_triangles_count,
        'triangles': triangles_data, # Directly in meta for instantaneous GPU upload
        'texts': texts_data
    }
    with open(out_meta, 'w', encoding='utf-8') as f:
        json.dump(meta_payload, f)
    with open(out_meta, 'rb') as f_in, gzip.open(out_meta_gz, 'wb', compresslevel=6) as f_out:
        f_out.writelines(f_in)
        
    if lines_data:
        arr = np.array(lines_data, dtype=np.float32).reshape(-1, 5)
        x1 = arr[:, 0]; y1 = arr[:, 1]; x2 = arr[:, 2]; y2 = arr[:, 3]
        c = arr[:, 4].astype(np.uint32)
        r = ((c >> 16) & 255).astype(np.float32) / 255.0
        g = ((c >> 8) & 255).astype(np.float32) / 255.0
        b = (c & 255).astype(np.float32) / 255.0
        v1 = np.column_stack([x1, y1, r, g, b])
        v2 = np.column_stack([x2, y2, r, g, b])
        vertices = np.empty((len(arr) * 2, 5), dtype=np.float32)
        vertices[0::2] = v1; vertices[1::2] = v2
        vertices.tofile(out_bin)
        with open(out_bin, 'rb') as f_in, gzip.open(out_bin_gz, 'wb', compresslevel=6) as f_out:
            f_out.write(f_in.read())
            
        bin_sz = os.path.getsize(out_bin)
        bin_gz_sz = os.path.getsize(out_bin_gz)
        print(f"High-Speed Binary created: Raw {bin_sz/(1024*1024):.2f} MB, Gzip {bin_gz_sz/(1024*1024):.2f} MB")
except Exception as e:
    print(f"Binary export error: {e}")

sz = os.path.getsize(out_json)
sz_gz = os.path.getsize(out_gz)
print(f"SUCCESS in {time.time()-t0:.2f}s! Raw JSON: {sz/(1024*1024):.2f} MB, Gzip: {sz_gz/(1024*1024):.2f} MB")
