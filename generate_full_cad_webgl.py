import re
import json
import math
import time
import gzip
import os
import sys
from collections import Counter
import numpy as np

t0 = time.time()
svg_path = sys.argv[1] if len(sys.argv) > 1 else "/home/ubuntu/cad-service/uploads/87b6f0bc-dc50-4fbc-959b-e1302122afd0.svg"
out_json = sys.argv[2] if len(sys.argv) > 2 else "/home/ubuntu/cad-service/public/cad_data.json"
out_gz = out_json + ".gz"

print(f"Reading {svg_path}...")
with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

# Fix legacy monochrome blue/black injection
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

# Genişletilmiş pafta sınırları (Aykırı/bozuk koordinatları filtrelerken tüm paftaları korur)
pad_x = max(bounds['w'] * 0.25, 25000.0)
pad_y = max(bounds['h'] * 0.50, 25000.0)
BOUNDS_MIN_X = bounds['minX'] - pad_x
BOUNDS_MAX_X = bounds['minX'] + bounds['w'] + pad_x
BOUNDS_MIN_Y = bounds['minY'] - pad_y
BOUNDS_MAX_Y = bounds['minY'] + bounds['h'] + pad_y

color_map = {
    '#ffffff': 0xffffff, 'white': 0xffffff, '#000000': 0xffffff, 'black': 0xffffff,
    'yellow': 0xffe600, '#ffeaaa': 0xffe600, '#ffffaa': 0xffe600, '#ffbf00': 0xffe600, '#ffff00': 0xffe600,
    'red': 0xff3b30, '#ff0000': 0xff3b30, '#ff3b30': 0xff3b30,
    '#414141': 0xff3b30,  # Aks dash-dot centerlines -> Vivid RED
    'cyan': 0x00f0ff, '#00f0ff': 0x00f0ff, '#00bfff': 0x00f0ff, '#00ffff': 0x00f0ff,
    '#7eadbd': 0x00f0ff,  # Architectural dimension lines -> bright cyan
    'green': 0x22c55e, '#22c55e': 0x22c55e, '#00ff3f': 0x22c55e, '#00ff00': 0x22c55e,
    'magenta': 0xff2d55, '#ff2d55': 0xff2d55, '#ffaaea': 0xff2d55, '#ff007f': 0xff2d55, '#ff00ff': 0xff2d55,
    'blue': 0x38bdf8, '#38bdf8': 0x38bdf8, '#007fff': 0x38bdf8, '#007aff': 0x38bdf8, '#0000ff': 0x38bdf8,
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
            val = int(c[1:], 16)
            return 0xffffff if val == 0x000000 else val
        except Exception:
            pass
    return 0xffffff

SHX_TR_MAP = str.maketrans({
    'Ý': 'İ', 'Þ': 'Ş', 'Ð': 'Ğ',
    'ý': 'ı', 'þ': 'ş', 'ð': 'ğ',
})

def clean_cad_text(raw_t):
    if not raw_t:
        return ""
    raw_t = re.sub(r'\\[fF][^;]+;', '', raw_t)
    raw_t = re.sub(r'\\[WwHhQqTtAaPp][^;]*;?', '', raw_t)
    raw_t = re.sub(r'\\S([^;^]+)\^([^;]*);', r'\1/\2', raw_t)
    def repl_u(m):
        try:
            return chr(int(m.group(1), 16))
        except Exception:
            return m.group(0)
    raw_t = re.sub(r'\\[uU]\+([0-9a-fA-F]{4})', repl_u, raw_t)
    raw_t = (raw_t
             .replace('&#x192;', 'Ø')
             .replace('%%c', 'Ø').replace('%%C', 'Ø')
             .replace('%%d', '°').replace('%%D', '°')
             .replace('%%p', '±').replace('%%P', '±')
             .replace('&apos;', "'").replace('&#39;', "'"))
    return raw_t.translate(SHX_TR_MAP).strip()

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
        args = [float(x) for x in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', args_str)]
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
                r_mat = multiply_matrices([1, 0, 0, 1, cx, cy], [cos_a, sin_a, -sin_a, cos_a, 0, 0])
                r_mat = multiply_matrices(r_mat, [1, 0, 0, 1, -cx, -cy])
            else:
                r_mat = [cos_a, sin_a, -sin_a, cos_a, 0.0, 0.0]
            mat = multiply_matrices(mat, r_mat)
        elif cmd == 'matrix' and len(args) >= 6:
            mat = multiply_matrices(mat, args[:6])
    return mat

def apply_transform(mat, x, y):
    return mat[0] * x + mat[2] * y + mat[4], mat[1] * x + mat[3] * y + mat[5]

# dwg2SVG'nin <defs> içindeki sembollere uyguladığı (transform_X(0), transform_Y(0)) = (-model_xmin, model_ymax) ofsetini tespit et
all_sym_min_x = []
all_sym_max_y = []
for m in re.finditer(r'<path[^>]+d="M\s*([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)', defs_part):
    px = float(m.group(1))
    py = float(m.group(2))
    if px > 1000 and py < -1000:
        all_sym_min_x.append(round(px, 1))
        all_sym_max_y.append(round(py, 1))

def most_frequent(arr):
    if not arr:
        return 0.0
    return Counter(arr).most_common(1)[0][0]

BASE_X = most_frequent(all_sym_min_x) or 47599.4
BASE_Y = most_frequent(all_sym_max_y) or -28187.4
print(f"Detected global block base point: ({BASE_X}, {BASE_Y})")
OFFSET_SHIFT_MAT = [1.0, 0.0, 0.0, 1.0, -BASE_X, -BASE_Y]

# DXF varsa blokların kendi taban noktalarını (base_point) ve $INSUNITS birimini oku
dxf_candidate = svg_path.replace('.svg', '.dxf')
dwg_candidate = svg_path.replace('.svg', '.dwg')
if not os.path.exists(dxf_candidate) and os.path.exists(dwg_candidate):
    print(f"Generating DXF from DWG: {dwg_candidate}...")
    import subprocess
    subprocess.run(['dwg2dxf', '-y', dwg_candidate, '-o', dxf_candidate], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

dxf_doc = None
dxf_block_base_pts = {}
insunits = 5
meters_per_unit = 0.01

if os.path.exists(dxf_candidate):
    try:
        import ezdxf
        dxf_doc = ezdxf.readfile(dxf_candidate)
        try:
            insunits = int(dxf_doc.header.get('$INSUNITS', 5))
            u_map = {1: 0.0254, 2: 0.3048, 4: 0.001, 5: 0.01, 6: 1.0}
            meters_per_unit = u_map.get(insunits, 0.01)
        except Exception:
            pass
        for b in dxf_doc.blocks:
            if b.block and b.block.dxf.hasattr('base_point'):
                bp = b.block.dxf.base_point
                if abs(bp.x) > 1e-3 or abs(bp.y) > 1e-3:
                    dxf_block_base_pts[b.name] = (float(bp.x), float(bp.y))
    except Exception as e:
        print(f"DXF pre-read note: {e}")

# Sembolleri (<g id="symbol-...">) analiz et:
# KRİTİK DÜZELTME:
# 1. smartFixSvg yalnızca üst düzey (depth=0) sembollere transform="translate(-baseX, -baseY)" ekliyordu.
#    Alt sembollerde (depth>=1) ve hem üst hem alt düzeyde kullanılan sembollerde (Reason 1, 2, 3)
#    çift kayma veya sıfır kayma oluşmasını önlemek için her sembolün ham koordinatlarını doğrudan kontrol ediyoruz.
# 2. <polygon>, <circle>, <path> ve alt <use> koordinatlarının tamamı kontrol edilerek sembolün
#    dwg2SVG taban ofsetine sahip olup olmadığı tespit edilir ve her derinlikte (depth=0, 1, 2...)
#    tutarlı şekilde ТЕК KEZ uygulanır.
symbols = {}
sym_regex = re.compile(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', re.DOTALL)
for m in sym_regex.finditer(defs_part):
    sid = m.group(1)
    attrs = m.group(2)
    body = m.group(3)

    # Sembol içindeki tüm ham Y koordinatlarını topla (<circle>, <text>, <path>, <polygon>, <use>)
    ys = [float(cy) for cy in re.findall(r'cy="([+-]?\d+\.?\d*)"', body)]
    ys += [float(ty) for ty in re.findall(r'\by="([+-]?\d+\.?\d*)"', body)]
    ys += [float(py) for py in re.findall(r'[ML]\s*[+-]?\d+\.?\d*[, ]\s*([+-]?\d+\.?\d*)', body)]
    for poly_m in re.finditer(r'points="([^"]+)"', body):
        p_nums = [float(v) for v in re.findall(r'[-+]?\d*\.?\d+', poly_m.group(1))]
        ys += p_nums[1::2]
    for use_m in re.finditer(r'translate\(\s*[+-]?\d+\.?\d*[\s,]+([+-]?\d+\.?\d*)', body):
        ys.append(float(use_m.group(1)))

    avg_y = sum(ys[:30]) / min(len(ys), 30) if ys else None

    # Sembolün kendi içinde (smartFixSvg dışında) özel bir dönüşümü var mı?
    # Not: smartFixSvg tarafından eklenen translate(-baseX, -baseY) değerini sıfırlayıp
    # shift_mat üzerinden her derinlikte (depth=0, 1, 2...) tek tip uyguluyoruz.
    needs_shift = (avg_y is not None and avg_y < -2000)

    # Eğer DXF'te bu bloğun özel bir base_point'i varsa onu da hesaba kat
    comment_m = re.search(r'<!--\s*([^\s].*?)\s*-->', body)
    blk_name = comment_m.group(1).strip() if comment_m else ""
    bx, by = dxf_block_base_pts.get(blk_name, (0.0, 0.0))

    if needs_shift:
        shift_mat = [1.0, 0.0, 0.0, 1.0, -(BASE_X + bx), -(BASE_Y - by)]
    else:
        shift_mat = identity_matrix()

    symbols[sid] = {
        'shift_mat': shift_mat,
        'body': body,
        'needs_base_shift': needs_shift
    }

lines_data = []      # [x1, y1, x2, y2, color, ...]
texts_data = []
triangles_data = []  # [x1, y1, x2, y2, x3, y3, color, ...]

def add_line(x1, y1, x2, y2, color):
    if not (BOUNDS_MIN_X <= x1 <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= y1 <= BOUNDS_MAX_Y and
            BOUNDS_MIN_X <= x2 <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= y2 <= BOUNDS_MAX_Y):
        return
    if abs(x1 - x2) < 1e-3 and abs(y1 - y2) < 1e-3:
        return
    lines_data.extend([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), int(color)])

def add_triangle(p1, p2, p3, color):
    if not (BOUNDS_MIN_X <= p1[0] <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= p1[1] <= BOUNDS_MAX_Y):
        return
    triangles_data.extend([
        round(p1[0], 1), round(p1[1], 1),
        round(p2[0], 1), round(p2[1], 1),
        round(p3[0], 1), round(p3[1], 1),
        int(color)
    ])

def add_text(wx, wy, size, fill, raw_t, rot_deg=0.0):
    if not (BOUNDS_MIN_X <= wx <= BOUNDS_MAX_X and BOUNDS_MIN_Y <= wy <= BOUNDS_MAX_Y):
        return
    cleaned = clean_cad_text(raw_t)
    if not cleaned:
        return
    c_int = parse_color(fill)
    item = {
        'x': round(wx, 1),
        'y': round(wy, 1),
        's': round(max(size, 1.0), 1),
        'c': f"#{c_int:06x}",
        't': cleaned
    }
    if abs(rot_deg) > 0.1:
        item['r'] = round(rot_deg, 1)
    texts_data.append(item)

# SVG Elliptical Arc (A/a) -> Çizgi Segmentleri (dwg2SVG output_ARC formatıyla %100 uyumlu)
def arc_to_segments(x1, y1, rx, ry, phi_deg, large_arc, sweep, x2, y2, num_segs=16):
    if (abs(x1 - x2) < 1e-4 and abs(y1 - y2) < 1e-4) or rx <= 0 or ry <= 0:
        return []
    # Çok büyük yarıçaplı bozuk yayların çizimi dağıtmasını önle
    chord = math.hypot(x2 - x1, y2 - y1)
    if chord < 1e-3 or rx > max(bounds['w'], bounds['h']) * 2:
        return [(x1, y1, x2, y2)]

    rx = abs(rx)
    ry = abs(ry)
    phi = math.radians(phi_deg % 360.0)
    cos_phi = math.cos(phi)
    sin_phi = math.sin(phi)

    dx2 = (x1 - x2) / 2.0
    dy2 = (y1 - y2) / 2.0
    x1p = cos_phi * dx2 + sin_phi * dy2
    y1p = -sin_phi * dx2 + cos_phi * dy2

    lam = (x1p ** 2) / (rx ** 2) + (y1p ** 2) / (ry ** 2)
    if lam > 1.0:
        sqrt_lam = math.sqrt(lam)
        rx *= sqrt_lam
        ry *= sqrt_lam

    rx2 = rx ** 2
    ry2 = ry ** 2
    x1p2 = x1p ** 2
    y1p2 = y1p ** 2

    denom = rx2 * y1p2 + ry2 * x1p2
    if denom <= 1e-12:
        return [(x1, y1, x2, y2)]
    num = max(0.0, rx2 * ry2 - denom)
    sign = -1.0 if bool(large_arc) == bool(sweep) else 1.0
    coef = sign * math.sqrt(num / denom)
    cxp = coef * ((rx * y1p) / ry)
    cyp = coef * (-(ry * x1p) / rx)

    cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
    cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0

    def vec_angle(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        mag = math.hypot(ux, uy) * math.hypot(vx, vy)
        if mag == 0:
            return 0.0
        cos_v = max(-1.0, min(1.0, dot / mag))
        ang = math.acos(cos_v)
        return -ang if (ux * vy - uy * vx) < 0 else ang

    ux = (x1p - cxp) / rx
    uy = (y1p - cyp) / ry
    vx = (-x1p - cxp) / rx
    vy = (-y1p - cyp) / ry

    theta1 = vec_angle(1.0, 0.0, ux, uy)
    dtheta = vec_angle(ux, uy, vx, vy)
    if not sweep and dtheta > 0:
        dtheta -= 2.0 * math.pi
    elif sweep and dtheta < 0:
        dtheta += 2.0 * math.pi

    # dwg2SVG.c satır 347'de end_angle < start_angle olduğunda (0 dereceden geçen yaylar)
    # large_arc yanlışlıkla 0 hesaplandığı için yay ters yönde (>180 derece) dönebiliyor;
    # Eğer large_arc==0 olduğu halde hesaplanan açı > pi ise tamamlayıcı kısa yayı seç:
    if not large_arc and abs(dtheta) > math.pi + 1e-3:
        if dtheta > 0:
            dtheta -= 2.0 * math.pi
        else:
            dtheta += 2.0 * math.pi

    steps = max(6, min(num_segs, int(abs(dtheta) * 8) + 4))
    segs = []
    px, py = x1, y1
    for s in range(1, steps + 1):
        t = theta1 + (s / steps) * dtheta
        ct = math.cos(t)
        st = math.sin(t)
        nx = cos_phi * rx * ct - sin_phi * ry * st + cx
        ny = sin_phi * rx * ct + cos_phi * ry * st + cy
        segs.append((px, py, nx, ny))
        px, py = nx, ny
    return segs

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
            if current_cmd in ('Z', 'z'):
                if current_x != start_x or current_y != start_y:
                    wx1, wy1 = apply_transform(mat, current_x, current_y)
                    wx2, wy2 = apply_transform(mat, start_x, start_y)
                    yield wx1, wy1, wx2, wy2
                    current_x, current_y = start_x, start_y
                continue
            if i >= num_tokens:
                break
        try:
            if current_cmd in ('M', 'm'):
                x = float(tokens[i][1]); y = float(tokens[i + 1][1]); i += 2
                if current_cmd == 'm':
                    current_x += x; current_y += y
                else:
                    current_x, current_y = x, y
                start_x, start_y = current_x, current_y
                current_cmd = 'L' if current_cmd == 'M' else 'l'
            elif current_cmd in ('L', 'l'):
                x = float(tokens[i][1]); y = float(tokens[i + 1][1]); i += 2
                prev_x, prev_y = current_x, current_y
                if current_cmd == 'l':
                    current_x += x; current_y += y
                else:
                    current_x, current_y = x, y
                wx1, wy1 = apply_transform(mat, prev_x, prev_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
            elif current_cmd in ('H', 'h'):
                x = float(tokens[i][1]); i += 1
                prev_x = current_x
                if current_cmd == 'h':
                    current_x += x
                else:
                    current_x = x
                wx1, wy1 = apply_transform(mat, prev_x, current_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
            elif current_cmd in ('V', 'v'):
                y = float(tokens[i][1]); i += 1
                prev_y = current_y
                if current_cmd == 'v':
                    current_y += y
                else:
                    current_y = y
                wx1, wy1 = apply_transform(mat, current_x, prev_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
            elif current_cmd in ('A', 'a'):
                rx = float(tokens[i][1]); ry = float(tokens[i + 1][1])
                x_rot = float(tokens[i + 2][1])
                large_arc = int(float(tokens[i + 3][1])) != 0
                sweep = int(float(tokens[i + 4][1])) != 0
                x = float(tokens[i + 5][1]); y = float(tokens[i + 6][1])
                i += 7
                if current_cmd == 'a':
                    x += current_x; y += current_y
                for ax1, ay1, ax2, ay2 in arc_to_segments(current_x, current_y, rx, ry, x_rot, large_arc, sweep, x, y):
                    wx1, wy1 = apply_transform(mat, ax1, ay1)
                    wx2, wy2 = apply_transform(mat, ax2, ay2)
                    yield wx1, wy1, wx2, wy2
                current_x, current_y = x, y
            elif current_cmd in ('C', 'c'):
                x1 = float(tokens[i][1]); y1 = float(tokens[i + 1][1])
                x2 = float(tokens[i + 2][1]); y2 = float(tokens[i + 3][1])
                x = float(tokens[i + 4][1]); y = float(tokens[i + 5][1])
                i += 6
                if current_cmd == 'c':
                    x1 += current_x; y1 += current_y
                    x2 += current_x; y2 += current_y
                    x += current_x; y += current_y
                p0x, p0y = current_x, current_y
                px, py = p0x, p0y
                for s in range(1, 11):
                    t = s / 10.0; mt = 1.0 - t
                    nx = (mt**3)*p0x + 3*(mt**2)*t*x1 + 3*mt*(t**2)*x2 + (t**3)*x
                    ny = (mt**3)*p0y + 3*(mt**2)*t*y1 + 3*mt*(t**2)*y2 + (t**3)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
            elif current_cmd in ('Q', 'q'):
                x1 = float(tokens[i][1]); y1 = float(tokens[i + 1][1])
                x = float(tokens[i + 2][1]); y = float(tokens[i + 3][1])
                i += 4
                if current_cmd == 'q':
                    x1 += current_x; y1 += current_y
                    x += current_x; y += current_y
                p0x, p0y = current_x, current_y
                px, py = p0x, p0y
                for s in range(1, 9):
                    t = s / 8.0; mt = 1.0 - t
                    nx = (mt**2)*p0x + 2*mt*t*x1 + (t**2)*x
                    ny = (mt**2)*p0y + 2*mt*t*y1 + (t**2)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
            else:
                i += 1
        except (IndexError, ValueError):
            break

def circle_to_segments(cx, cy, r, mat, num_segs=24):
    pts = [apply_transform(mat, cx + r * math.cos(2 * math.pi * i / num_segs), cy + r * math.sin(2 * math.pi * i / num_segs)) for i in range(num_segs)]
    return [(pts[i][0], pts[i][1], pts[(i + 1) % num_segs][0], pts[(i + 1) % num_segs][1]) for i in range(num_segs)]

def ellipse_to_segments(cx, cy, rx, ry, mat, num_segs=24):
    pts = [apply_transform(mat, cx + rx * math.cos(2 * math.pi * i / num_segs), cy + ry * math.sin(2 * math.pi * i / num_segs)) for i in range(num_segs)]
    return [(pts[i][0], pts[i][1], pts[(i + 1) % num_segs][0], pts[(i + 1) % num_segs][1]) for i in range(num_segs)]

def process_elements(content, current_mat):
    scale_mag = math.hypot(current_mat[0], current_mat[1]) or 1.0
    base_rot = round(math.degrees(math.atan2(current_mat[1], current_mat[0])), 1)

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

    for m in re.finditer(r'<ellipse[^>]+cx="([^"]+)"\s+cy="([^"]+)"\s+rx="([^"]+)"\s+ry="([^"]+)"([^>]*)>', content):
        cx = float(m.group(1)); cy = float(m.group(2)); rx = float(m.group(3)); ry = float(m.group(4))
        tail = m.group(5)
        tm = re.search(r'transform="([^"]+)"', tail)
        elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
        sm = re.search(r'stroke:([^;"]+)', tail)
        c_int = parse_color(sm.group(1)) if sm else 0xffffff
        for x1, y1, x2, y2 in ellipse_to_segments(cx, cy, rx, ry, elem_mat):
            add_line(x1, y1, x2, y2, c_int)

    for m in re.finditer(r'<polygon[^>]+points="([^"]+)"[^>]*style="([^"]*)"', content):
        pts_raw = [float(v) for v in re.findall(r'[-+]?\d*\.\d+|\d+', m.group(1))]
        style = m.group(2)
        sm = re.search(r'stroke:([^;"]+)', style)
        c_int = parse_color(sm.group(1)) if sm else 0xffffff
        if len(pts_raw) >= 4:
            pts = [(pts_raw[k], pts_raw[k + 1]) for k in range(0, len(pts_raw) - 1, 2)]
            for k in range(len(pts)):
                p1 = apply_transform(current_mat, pts[k][0], pts[k][1])
                p2 = apply_transform(current_mat, pts[(k + 1) % len(pts)][0], pts[(k + 1) % len(pts)][1])
                add_line(p1[0], p1[1], p2[0], p2[1], c_int)

    for m in re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*font-size="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', content):
        x = float(m.group(1)); y = float(m.group(2)); size = float(m.group(3))
        fill = m.group(4); raw_t = m.group(5).strip()
        wx, wy = apply_transform(current_mat, x, y)
        add_text(wx, wy, size * scale_mag, fill, raw_t, base_rot)

process_elements(model_part, identity_matrix())

# Hiyerarşik Sembol Render Motoru:
# KRİTİK DÜZELTME:
# Alt sembollere (depth + 1) geçerken `current_mat` yerine `elem_mat` (yani ebeveynin shift_mat uygulanmış matrisi!)
# aktarılır. Böylece:
# 1) Ebeveynin (-BASE_X, -BASE_Y) kaydırması, alt <use> etiketindeki translate(cx + BASE_X, -cy + BASE_Y) ofsetini
#    tam olarak sıfırlar (geriye saf yerel (cx, -cy) kalır).
# 2) Alt sembol kendi içine girdiğinde kendi `sym['shift_mat']` matrisiyle kendi elemanlarını (-BASE_X, -BASE_Y)
#    kadar kaydırır.
# Bu sayede ne depth=1'de ne de depth=2,3,4,5'te hiçbir sembol (47599, -28187) noktasında kümelenmez,
# her sembol pafta üzerindeki gerçek koordinatına oturur!
def render_symbol(sid, current_mat, depth=0, max_depth=6):
    if depth > max_depth or sid not in symbols:
        return
    sym = symbols[sid]
    elem_mat = multiply_matrices(current_mat, sym['shift_mat'])
    process_elements(sym['body'], elem_mat)
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
        xm = re.search(r'\bx="([+-]?\d+\.?\d*)"', c_attrs)
        ym = re.search(r'\by="([+-]?\d+\.?\d*)"', c_attrs)
        if xm or ym:
            ax = float(xm.group(1)) if xm else 0.0
            ay = float(ym.group(1)) if ym else 0.0
            child_trans_mat = multiply_matrices([1, 0, 0, 1, ax, ay], child_trans_mat)
        # current_mat yerine elem_mat kullan!
        child_mat = multiply_matrices(elem_mat, child_trans_mat)
        render_symbol(c_id, child_mat, depth + 1, max_depth)

for m in re.finditer(r'<use\s+([^>]+)>', model_part):
    tag_attrs = m.group(1)
    href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag_attrs)
    if not href_m:
        continue
    sym_id = href_m.group(1)
    if sym_id not in symbols:
        continue
    t_m = re.search(r'transform="([^"]+)"', tag_attrs)
    use_mat = parse_transform(t_m.group(1) if t_m else "")
    xm = re.search(r'\bx="([+-]?\d+\.?\d*)"', tag_attrs)
    ym = re.search(r'\by="([+-]?\d+\.?\d*)"', tag_attrs)
    if xm or ym:
        ax = float(xm.group(1)) if xm else 0.0
        ay = float(ym.group(1)) if ym else 0.0
        use_mat = multiply_matrices([1.0, 0.0, 0.0, 1.0, ax, ay], use_mat)
    # sym['shift_mat'] zaten render_symbol içinde uygulanıyor
    render_symbol(sym_id, use_mat, depth=0)

# Robust Polygon Triangulation for Solid Hatches
def triangulate_polygon(pts):
    n = len(pts)
    if n < 3:
        return []
    if n == 3:
        return [(pts[0], pts[1], pts[2])]
    if n == 4:
        return [(pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])]

    def area2(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def is_point_in_tri(p, a, b, c):
        d1 = area2(p, a, b); d2 = area2(p, b, c); d3 = area2(p, c, a)
        return not (((d1 < 0) or (d2 < 0) or (d3 < 0)) and ((d1 > 0) or (d2 > 0) or (d3 > 0)))

    indices = list(range(n))
    total_area = sum((pts[(i + 1) % n][0] - pts[i][0]) * (pts[(i + 1) % n][1] + pts[i][1]) for i in range(n))
    if total_area > 0:
        indices.reverse()
    triangles = []
    attempts = 0
    while len(indices) > 3 and attempts < 150:
        attempts += 1
        found_ear = False
        for i in range(len(indices)):
            prev_i = indices[i - 1]; curr_i = indices[i]; next_i = indices[(i + 1) % len(indices)]
            a = pts[prev_i]; b = pts[curr_i]; c = pts[next_i]
            if area2(a, b, c) <= 1e-6:
                continue
            is_ear = True
            for k in indices:
                if k not in (prev_i, curr_i, next_i) and is_point_in_tri(pts[k], a, b, c):
                    is_ear = False
                    break
            if is_ear:
                triangles.append((a, b, c))
                indices.pop(i)
                found_ear = True
                break
        if not found_ear:
            break
    if len(indices) == 3:
        triangles.append((pts[indices[0]], pts[indices[1]], pts[indices[2]]))
    elif len(indices) > 3:
        for i in range(1, len(indices) - 1):
            triangles.append((pts[indices[0]], pts[indices[i]], pts[indices[i + 1]]))
    return triangles

# EXTRACT SOLID HATCHES FROM DXF (Columns, Beams, Walls, Foundations)
if dxf_doc is not None:
    print(f"Extracting solid architectural hatches and fills from {dxf_candidate}...")
    try:
        msp = dxf_doc.modelspace()
        block_map = {b.name: b for b in dxf_doc.blocks}
        solid_tri_count = 0

        # Calculate exact DXF to SVG offset using text matching across all projects
        CALC_BASE_X = BASE_X
        CALC_BASE_Y = BASE_Y
        try:
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
                c_fill = 0xa05252
                c_outline = 0xb85d5d
            elif is_col:
                c_fill = 0x527273
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
                if len(pts) < 3:
                    continue

                if ins is not None:
                    msp_pts = [transform_pt_by_insert(pt[0], pt[1], ins) for pt in pts]
                else:
                    msp_pts = pts

                svg_pts = [dxf_to_svg(pt[0], pt[1]) for pt in msp_pts]

                tris = triangulate_polygon(svg_pts)
                for t1, t2, t3 in tris:
                    add_triangle(t1, t2, t3, c_fill)
                    solid_tri_count += 1

                for i in range(len(svg_pts)):
                    p1 = svg_pts[i]
                    p2 = svg_pts[(i + 1) % len(svg_pts)]
                    add_line(p1[0], p1[1], p2[0], p2[1], c_outline)

        print(f"Successfully generated {solid_tri_count} solid fill triangles from DXF!")
    except Exception as e:
        print(f"Hatch triangulation note: {e}")

total_lines_count = len(lines_data) // 5
total_triangles_count = len(triangles_data) // 7
print(f"Extraction COMPLETE! Lines: {total_lines_count}, Solid Triangles: {total_triangles_count}, Texts: {len(texts_data)}")

payload = {
    'bounds': bounds,
    'insunits': insunits,
    'metersPerUnit': meters_per_unit,
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
        alt_meta = out_json.replace('_cad_data.json', '_cad_meta.json')
        alt_bin = out_json.replace('_cad_data.json', '_cad_vertices.bin')

    out_meta_gz = out_meta + '.gz'
    out_bin_gz = out_bin + '.gz'

    meta_payload = {
        'bounds': bounds,
        'insunits': insunits,
        'metersPerUnit': meters_per_unit,
        'totalLines': total_lines_count,
        'totalTriangles': total_triangles_count,
        'triangles': triangles_data,
        'texts': texts_data
    }
    with open(out_meta, 'w', encoding='utf-8') as f:
        json.dump(meta_payload, f)
    with open(out_meta, 'rb') as f_in, gzip.open(out_meta_gz, 'wb', compresslevel=6) as f_out:
        f_out.writelines(f_in)

    if 'alt_meta' in locals() and alt_meta != out_meta:
        try:
            with open(alt_meta, 'w', encoding='utf-8') as f:
                json.dump(meta_payload, f)
        except Exception:
            pass

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
        vertices[0::2] = v1
        vertices[1::2] = v2
        vertices.tofile(out_bin)
        with open(out_bin, 'rb') as f_in, gzip.open(out_bin_gz, 'wb', compresslevel=6) as f_out:
            f_out.write(f_in.read())

        if 'alt_bin' in locals() and alt_bin != out_bin:
            try:
                vertices.tofile(alt_bin)
            except Exception:
                pass

        bin_sz = os.path.getsize(out_bin)
        bin_gz_sz = os.path.getsize(out_bin_gz)
        print(f"High-Speed Binary created: Raw {bin_sz / (1024 * 1024):.2f} MB, Gzip {bin_gz_sz / (1024 * 1024):.2f} MB")
except Exception as e:
    print(f"Binary export error: {e}")

sz = os.path.getsize(out_json)
sz_gz = os.path.getsize(out_gz)
print(f"SUCCESS in {time.time() - t0:.2f}s! Raw JSON: {sz / (1024 * 1024):.2f} MB, Gzip: {sz_gz / (1024 * 1024):.2f} MB")
