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

# AutoCAD Color Index (ACI 1-255) to Hex Lookup
ACI_TABLE = [
    0x000000, 0xFF3B30, 0xFFE600, 0x22C55E, 0x00F0FF, 0x38BDF8, 0xFF2D55, 0xFFFFFF,
    0x808080, 0xC0C0C0, 0xFF0000, 0xFF7F7F, 0xCC0000, 0xCC6666, 0x990000, 0x994C4C,
    0x7F0000, 0x7F3F3F, 0x4C0000, 0x4C2626, 0xFF3F00, 0xFF9F7F, 0xCC3300, 0xCC7F66,
    0x992600, 0x995F4C, 0x7F1F00, 0x7F4F3F, 0x4C1300, 0x4C2F26, 0xFF7F00, 0xFFBF7F,
    0xCC6600, 0xCC9966, 0x994C00, 0x99734C, 0x7F3F00, 0x7F5F3F, 0x4C2600, 0x4C3926,
    0xFFBF00, 0xFFDF7F, 0xCC9900, 0xCCB366, 0x997300, 0x99864C, 0x7F5F00, 0x7F6F3F,
    0x4C3900, 0x4C4326, 0xFFFF00, 0xFFFF7F, 0xCCCC00, 0xCCCC66, 0x999900, 0x99994C,
    0x7F7F00, 0x7F7F3F, 0x4C4C00, 0x4C4C26, 0xBFFF00, 0xDFFF7F, 0x99CC00, 0xB3CC66,
    0x739900, 0x86994C, 0x5F7F00, 0x6F7F3F, 0x394C00, 0x434C26, 0x7FFF00, 0xBFFF7F,
    0x66CC00, 0x99CC66, 0x4C9900, 0x73994C, 0x3F7F00, 0x5F7F3F, 0x264C00, 0x394C26,
    0x3FFF00, 0x9FFF7F, 0x33CC00, 0x7FCC66, 0x269900, 0x5F994C, 0x1F7F00, 0x4F7F3F,
    0x134C00, 0x2F4C26, 0x00FF00, 0x7FFF7F, 0x00CC00, 0x66CC66, 0x009900, 0x4C994C,
    0x007F00, 0x3F7F3F, 0x004C00, 0x264C26, 0x00FF3F, 0x7FFF9F, 0x00CC33, 0x66CC7F,
    0x009926, 0x4C995F, 0x007F1F, 0x3F7F4F, 0x004C13, 0x264C2F, 0x00FF7F, 0x7FFFBF,
    0x00CC66, 0x66CC99, 0x00994C, 0x4C9973, 0x007F3F, 0x3F7F5F, 0x004C26, 0x264C39,
    0x00FFBF, 0x7FFFDF, 0x00CC99, 0x66CCB3, 0x009973, 0x4C9986, 0x007F5F, 0x3F7F6F,
    0x004C39, 0x264C43, 0x00FFFF, 0x7FFFFF, 0x00CCCC, 0x66CCCC, 0x009999, 0x4C9999,
    0x007F7F, 0x3F7F7F, 0x004C4C, 0x264C4C, 0x00BFFF, 0x7FDFFF, 0x0099CC, 0x66B3CC,
    0x007399, 0x4C8699, 0x005F7F, 0x3F6F7F, 0x00394C, 0x26434C, 0x007FFF, 0x7FBFFF,
    0x0066CC, 0x6699CC, 0x004C99, 0x4C7399, 0x003F7F, 0x3F5F7F, 0x00264C, 0x26394C,
    0x003FFF, 0x7F9FFF, 0x0033CC, 0x667FCC, 0x002699, 0x4C5F99, 0x001F7F, 0x3F4F7F,
    0x00134C, 0x262F4C, 0x0000FF, 0x7F7FFF, 0x0000CC, 0x6666CC, 0x000099, 0x4C4C99,
    0x00007F, 0x3F3F7F, 0x00004C, 0x26264C, 0x3F00FF, 0x9F7FFF, 0x3300CC, 0x7F66CC,
    0x260099, 0x5F4C99, 0x1F007F, 0x4F3F7F, 0x13004C, 0x2F264C, 0x7F00FF, 0xBF7FFF,
    0x6600CC, 0x9966CC, 0x4C0099, 0x734C99, 0x3F007F, 0x5F3F7F, 0x26004C, 0x39264C,
    0xBF00FF, 0xDF7FFF, 0x9900CC, 0xB366CC, 0x730099, 0x864C99, 0x5F007F, 0x6F3F7F,
    0x39004C, 0x43264C, 0xFF00FF, 0xFF7FFF, 0xCC00CC, 0xCC66CC, 0x990099, 0x994C99,
    0x7F007F, 0x7F3F7F, 0x4C004C, 0x4C264C, 0xFF00BF, 0xFF7FDF, 0xCC0099, 0xCC66B3,
    0x990073, 0x994C86, 0x7F005F, 0x7F3F6F, 0x4C0039, 0x4C2643, 0xFF007F, 0xFF7FBF,
    0xCC0066, 0xCC6699, 0x99004C, 0x994C73, 0x7F003F, 0x7F3F5F, 0x4C0026, 0x4C2639,
    0xFF003F, 0xFF7F9F, 0xCC0033, 0xCC667F, 0x990026, 0x994C5F, 0x7F001F, 0x7F3F4F,
    0x4C0013, 0x4C262F, 0x333333, 0x505050, 0x696969, 0x828282, 0xBEBEBE, 0xFFFFFF
]

def aci_to_rgb(aci):
    if aci is None:
        return 0xFFFFFF
    aci = abs(int(aci))
    if aci == 7 or aci == 0 or aci >= 256:
        return 0xFFFFFF
    return ACI_TABLE[aci]

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

# SHX ve eski AutoCAD Türkçe karakter / format temizleyici
SHX_TR_MAP = str.maketrans({
    'Ý': 'İ', 'Þ': 'Ş', 'Ð': 'Ğ',
    'ý': 'ı', 'þ': 'ş', 'ð': 'ğ',
})

def clean_cad_text(raw_t):
    if not raw_t:
        return ""
    # HTML entity ve AutoCAD özel kodları
    raw_t = (raw_t
             .replace('&#x192;', 'Ø')
             .replace('&apos;', "'")
             .replace('&#39;', "'")
             .replace('&quot;', '"')
             .replace('&amp;', '&')
             .replace('&lt;', '<')
             .replace('&gt;', '>'))
    raw_t = re.sub(r'%%[cC]', 'Ø', raw_t)
    raw_t = re.sub(r'%%[dD]', '°', raw_t)
    raw_t = re.sub(r'%%[pP]', '±', raw_t)
    raw_t = re.sub(r'%%[uU]', '', raw_t)
    # \U+XXXX Unicode dizilerini çöz
    def repl_unicode(m):
        try:
            return chr(int(m.group(1), 16))
        except Exception:
            return m.group(0)
    raw_t = re.sub(r'\\[uU]\+([0-9a-fA-F]{4})', repl_unicode, raw_t)
    # MTEXT kesir ve format kodları
    raw_t = re.sub(r'\\S([^;^]+)\^([^;]*);', r'\1/\2', raw_t)
    raw_t = re.sub(r'\\[fF][^;]+;', '', raw_t)
    raw_t = re.sub(r'\\P', '\n', raw_t)
    raw_t = re.sub(r'\\[WwHhQqTtAaCcOoKkLl][^;]*;', '', raw_t)
    raw_t = raw_t.replace('{', '').replace('}', '')
    raw_t = raw_t.translate(SHX_TR_MAP)
    return raw_t.strip()

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

def extract_rotation_deg(mat):
    return round(math.degrees(math.atan2(mat[1], mat[0])), 1)

# SVG Elliptical Arc (A/a) -> Line Segments Tessellation
def arc_to_segments(x1, y1, rx, ry, phi_deg, large_arc, sweep, x2, y2, num_segs=18):
    if (x1 == x2 and y1 == y2) or rx == 0 or ry == 0:
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

    steps = max(6, min(num_segs, int(abs(dtheta) * 10) + 4))
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

# Tam SVG Path Parser (M, L, H, V, C, S, Q, T, A, Z destekli)
def parse_path_d(d_str, mat):
    tokens = re.findall(r'([a-zA-Z])|([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', d_str)
    current_x = current_y = start_x = start_y = 0.0
    last_ctrl_x = last_ctrl_y = 0.0
    current_cmd = 'M'
    prev_cmd = ''
    i = 0
    num_tokens = len(tokens)

    def next_float():
        nonlocal i
        val = float(tokens[i][1])
        i += 1
        return val

    while i < num_tokens:
        cmd_char, _ = tokens[i]
        if cmd_char:
            current_cmd = cmd_char
            i += 1
            if current_cmd in ('Z', 'z'):
                if current_x != start_x or current_y != start_y:
                    wx1, wy1 = apply_transform(mat, current_x, current_y)
                    wx2, wy2 = apply_transform(mat, start_x, start_y)
                    yield wx1, wy1, wx2, wy2
                    current_x, current_y = start_x, start_y
                prev_cmd = current_cmd
                continue
            if i >= num_tokens:
                break

        try:
            if current_cmd in ('M', 'm'):
                x = next_float(); y = next_float()
                if current_cmd == 'm':
                    current_x += x; current_y += y
                else:
                    current_x, current_y = x, y
                start_x, start_y = current_x, current_y
                last_ctrl_x, last_ctrl_y = current_x, current_y
                prev_cmd = current_cmd
                current_cmd = 'L' if current_cmd == 'M' else 'l'
            elif current_cmd in ('L', 'l'):
                x = next_float(); y = next_float()
                prev_x, prev_y = current_x, current_y
                if current_cmd == 'l':
                    current_x += x; current_y += y
                else:
                    current_x, current_y = x, y
                wx1, wy1 = apply_transform(mat, prev_x, prev_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
                last_ctrl_x, last_ctrl_y = current_x, current_y
                prev_cmd = current_cmd
            elif current_cmd in ('H', 'h'):
                x = next_float()
                prev_x = current_x
                current_x = (current_x + x) if current_cmd == 'h' else x
                wx1, wy1 = apply_transform(mat, prev_x, current_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
                last_ctrl_x, last_ctrl_y = current_x, current_y
                prev_cmd = current_cmd
            elif current_cmd in ('V', 'v'):
                y = next_float()
                prev_y = current_y
                current_y = (current_y + y) if current_cmd == 'v' else y
                wx1, wy1 = apply_transform(mat, current_x, prev_y)
                wx2, wy2 = apply_transform(mat, current_x, current_y)
                yield wx1, wy1, wx2, wy2
                last_ctrl_x, last_ctrl_y = current_x, current_y
                prev_cmd = current_cmd
            elif current_cmd in ('C', 'c'):
                x1 = next_float(); y1 = next_float()
                x2 = next_float(); y2 = next_float()
                x = next_float(); y = next_float()
                if current_cmd == 'c':
                    x1 += current_x; y1 += current_y
                    x2 += current_x; y2 += current_y
                    x += current_x; y += current_y
                p0x, p0y = current_x, current_y
                steps = 12
                px, py = p0x, p0y
                for s in range(1, steps + 1):
                    t = s / steps
                    mt = 1.0 - t
                    nx = (mt**3)*p0x + 3*(mt**2)*t*x1 + 3*mt*(t**2)*x2 + (t**3)*x
                    ny = (mt**3)*p0y + 3*(mt**2)*t*y1 + 3*mt*(t**2)*y2 + (t**3)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
                last_ctrl_x, last_ctrl_y = x2, y2
                prev_cmd = current_cmd
            elif current_cmd in ('S', 's'):
                x2 = next_float(); y2 = next_float()
                x = next_float(); y = next_float()
                if current_cmd == 's':
                    x2 += current_x; y2 += current_y
                    x += current_x; y += current_y
                if prev_cmd in ('C', 'c', 'S', 's'):
                    x1 = 2 * current_x - last_ctrl_x
                    y1 = 2 * current_y - last_ctrl_y
                else:
                    x1, y1 = current_x, current_y
                p0x, p0y = current_x, current_y
                steps = 12
                px, py = p0x, p0y
                for s in range(1, steps + 1):
                    t = s / steps
                    mt = 1.0 - t
                    nx = (mt**3)*p0x + 3*(mt**2)*t*x1 + 3*mt*(t**2)*x2 + (t**3)*x
                    ny = (mt**3)*p0y + 3*(mt**2)*t*y1 + 3*mt*(t**2)*y2 + (t**3)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
                last_ctrl_x, last_ctrl_y = x2, y2
                prev_cmd = current_cmd
            elif current_cmd in ('Q', 'q'):
                x1 = next_float(); y1 = next_float()
                x = next_float(); y = next_float()
                if current_cmd == 'q':
                    x1 += current_x; y1 += current_y
                    x += current_x; y += current_y
                p0x, p0y = current_x, current_y
                steps = 10
                px, py = p0x, p0y
                for s in range(1, steps + 1):
                    t = s / steps
                    mt = 1.0 - t
                    nx = (mt**2)*p0x + 2*mt*t*x1 + (t**2)*x
                    ny = (mt**2)*p0y + 2*mt*t*y1 + (t**2)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
                last_ctrl_x, last_ctrl_y = x1, y1
                prev_cmd = current_cmd
            elif current_cmd in ('T', 't'):
                x = next_float(); y = next_float()
                if current_cmd == 't':
                    x += current_x; y += current_y
                if prev_cmd in ('Q', 'q', 'T', 't'):
                    x1 = 2 * current_x - last_ctrl_x
                    y1 = 2 * current_y - last_ctrl_y
                else:
                    x1, y1 = current_x, current_y
                p0x, p0y = current_x, current_y
                steps = 10
                px, py = p0x, p0y
                for s in range(1, steps + 1):
                    t = s / steps
                    mt = 1.0 - t
                    nx = (mt**2)*p0x + 2*mt*t*x1 + (t**2)*x
                    ny = (mt**2)*p0y + 2*mt*t*y1 + (t**2)*y
                    wx1, wy1 = apply_transform(mat, px, py)
                    wx2, wy2 = apply_transform(mat, nx, ny)
                    yield wx1, wy1, wx2, wy2
                    px, py = nx, ny
                current_x, current_y = x, y
                last_ctrl_x, last_ctrl_y = x1, y1
                prev_cmd = current_cmd
            elif current_cmd in ('A', 'a'):
                rx = next_float(); ry = next_float()
                x_rot = next_float()
                large_arc = int(next_float()) != 0
                sweep = int(next_float()) != 0
                x = next_float(); y = next_float()
                if current_cmd == 'a':
                    x += current_x; y += current_y
                for ax1, ay1, ax2, ay2 in arc_to_segments(current_x, current_y, rx, ry, x_rot, large_arc, sweep, x, y):
                    wx1, wy1 = apply_transform(mat, ax1, ay1)
                    wx2, wy2 = apply_transform(mat, ax2, ay2)
                    yield wx1, wy1, wx2, wy2
                current_x, current_y = x, y
                last_ctrl_x, last_ctrl_y = current_x, current_y
                prev_cmd = current_cmd
            else:
                i += 1
        except (IndexError, ValueError):
            break

def circle_to_segments(cx, cy, r, mat, num_segs=28):
    pts = [apply_transform(mat, cx + r * math.cos(2 * math.pi * i / num_segs), cy + r * math.sin(2 * math.pi * i / num_segs)) for i in range(num_segs)]
    return [(pts[i][0], pts[i][1], pts[(i + 1) % num_segs][0], pts[(i + 1) % num_segs][1]) for i in range(num_segs)]

def ellipse_to_segments(cx, cy, rx, ry, mat, num_segs=28):
    pts = [apply_transform(mat, cx + rx * math.cos(2 * math.pi * i / num_segs), cy + ry * math.sin(2 * math.pi * i / num_segs)) for i in range(num_segs)]
    return [(pts[i][0], pts[i][1], pts[(i + 1) % num_segs][0], pts[(i + 1) % num_segs][1]) for i in range(num_segs)]

lines_data = []      # [x1, y1, x2, y2, color, ...]
line_layers = []     # [layer_idx, ...]
texts_data = []
triangles_data = []  # [x1, y1, x2, y2, x3, y3, color, ...]
layers_dict = {}     # layer_name -> {'id': idx, 'name': name, 'color': color, 'count': count}

def get_or_create_layer_id(layer_name, default_color=0xffffff):
    lname = (layer_name or '0').strip() or '0'
    if lname not in layers_dict:
        lid = len(layers_dict)
        layers_dict[lname] = {
            'id': lid,
            'name': lname,
            'color': default_color,
            'count': 0,
            'visible': True
        }
    return layers_dict[lname]['id']

# Başlangıçta varsayılan katman
get_or_create_layer_id('GENEL', 0xffffff)

MAX_ABS_COORD = 1e9  # UTM/ITRF dahil tüm gerçek dünya koordinatlarını kapsar

def is_valid_coord(x, y):
    return math.isfinite(x) and math.isfinite(y) and abs(x) < MAX_ABS_COORD and abs(y) < MAX_ABS_COORD

def add_line(x1, y1, x2, y2, color, layer_name='GENEL'):
    if not (is_valid_coord(x1, y1) and is_valid_coord(x2, y2)):
        return
    if abs(x1 - x2) < 1e-4 and abs(y1 - y2) < 1e-4:
        return
    lines_data.extend([round(x1, 2), round(y1, 2), round(x2, 2), round(y2, 2), int(color)])
    lid = get_or_create_layer_id(layer_name, int(color))
    layers_dict[layer_name or 'GENEL']['count'] += 1
    line_layers.append(lid)

def add_triangle(p1, p2, p3, color, layer_name='TARAMA'):
    if not (is_valid_coord(p1[0], p1[1]) and is_valid_coord(p2[0], p2[1]) and is_valid_coord(p3[0], p3[1])):
        return
    get_or_create_layer_id(layer_name, int(color))
    triangles_data.extend([
        round(p1[0], 2), round(p1[1], 2),
        round(p2[0], 2), round(p2[1], 2),
        round(p3[0], 2), round(p3[1], 2),
        int(color)
    ])

def add_text(wx, wy, size, fill, raw_t, rot_deg=0.0, layer_name='YAZILAR'):
    if not is_valid_coord(wx, wy):
        return
    cleaned = clean_cad_text(raw_t)
    if not cleaned:
        return
    c_int = parse_color(fill) if isinstance(fill, str) else int(fill)
    get_or_create_layer_id(layer_name, c_int)
    # Çok satırlı metinleri (\n) alt alta yerleştir
    lines = [ln.strip() for ln in cleaned.split('\n') if ln.strip()]
    line_step = max(size * 1.25, 2.0)
    rad = math.radians(rot_deg)
    sin_r = math.sin(rad)
    cos_r = math.cos(rad)
    for idx, ln in enumerate(lines):
        ox = wx + idx * line_step * sin_r
        oy = wy + idx * line_step * cos_r
        item = {
            'x': round(ox, 2),
            'y': round(oy, 2),
            's': round(max(size, 1.0), 2),
            'c': f"#{c_int:06x}",
            't': ln,
            'l': layer_name
        }
        if abs(rot_deg) > 0.1:
            item['r'] = round(rot_deg, 1)
        texts_data.append(item)

# 1. AŞAMA: SVG MEVCUTSA OKU
BASE_X = 0.0
BASE_Y = 0.0
vb_bounds = None

if os.path.exists(svg_path) and os.path.getsize(svg_path) > 50:
    print(f"Reading SVG {svg_path}...")
    with open(svg_path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

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
        vb_bounds = {
            'minX': float(vb_match.group(1)),
            'minY': float(vb_match.group(2)),
            'w': float(vb_match.group(3)),
            'h': float(vb_match.group(4))
        }

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

    BASE_X = most_frequent(all_sym_min_x)
    BASE_Y = most_frequent(all_sym_max_y)
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
        needs_base_shift = (avg_y is not None and avg_y < -10000 and not has_own_trans and (BASE_X != 0.0 or BASE_Y != 0.0))
        symbols[sid] = {
            'mat': parse_transform(base_trans),
            'body': body,
            'needs_base_shift': needs_base_shift
        }

    def extract_stroke_color(tag_attrs, default_hex=0xffffff):
        sm = re.search(r'stroke\s*:\s*([^;"]+)', tag_attrs)
        if sm:
            return parse_color(sm.group(1))
        sm2 = re.search(r'stroke="([^"]+)"', tag_attrs)
        if sm2:
            return parse_color(sm2.group(1))
        return default_hex

    def extract_layer_from_color(c_int):
        if c_int == 0xff3b30:
            return 'AKSLAR_VE_KESIT'
        if c_int == 0x00f0ff:
            return 'OLCULER'
        if c_int == 0xffe600:
            return 'DONATI_VE_DETAY'
        if c_int == 0x22c55e:
            return 'MIMARI_ELEMAN'
        if c_int == 0xff2d55:
            return 'TESISAT_DETAY'
        if c_int == 0x38bdf8:
            return 'KALIP_KIRIS'
        return 'GENEL'

    def process_elements(content, current_mat):
        scale_mag = math.hypot(current_mat[0], current_mat[1]) or 1.0
        base_rot = extract_rotation_deg(current_mat)

        # 1. <path>
        for m in re.finditer(r'<path\b([^>]+)>', content):
            attrs = m.group(1)
            dm = re.search(r'\bd="([^"]+)"', attrs)
            if not dm:
                continue
            tm = re.search(r'transform="([^"]+)"', attrs)
            elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
            c_int = extract_stroke_color(attrs, 0xffffff)
            lname = extract_layer_from_color(c_int)
            for x1, y1, x2, y2 in parse_path_d(dm.group(1), elem_mat):
                add_line(x1, y1, x2, y2, c_int, lname)

        # 2. <line>
        for m in re.finditer(r'<line\b([^>]+)>', content):
            attrs = m.group(1)
            x1m = re.search(r'\bx1="([+-]?\d*\.?\d+)"', attrs)
            y1m = re.search(r'\by1="([+-]?\d*\.?\d+)"', attrs)
            x2m = re.search(r'\bx2="([+-]?\d*\.?\d+)"', attrs)
            y2m = re.search(r'\by2="([+-]?\d*\.?\d+)"', attrs)
            if x1m and y1m and x2m and y2m:
                tm = re.search(r'transform="([^"]+)"', attrs)
                elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
                c_int = extract_stroke_color(attrs, 0xffffff)
                wx1, wy1 = apply_transform(elem_mat, float(x1m.group(1)), float(y1m.group(1)))
                wx2, wy2 = apply_transform(elem_mat, float(x2m.group(1)), float(y2m.group(1)))
                add_line(wx1, wy1, wx2, wy2, c_int, extract_layer_from_color(c_int))

        # 3. <circle>
        for m in re.finditer(r'<circle\b([^>]+)>', content):
            attrs = m.group(1)
            cxm = re.search(r'\bcx="([+-]?\d*\.?\d+)"', attrs)
            cym = re.search(r'\bcy="([+-]?\d*\.?\d+)"', attrs)
            rm = re.search(r'\br="([+-]?\d*\.?\d+)"', attrs)
            if cxm and cym and rm:
                tm = re.search(r'transform="([^"]+)"', attrs)
                elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
                c_int = extract_stroke_color(attrs, 0xff3b30)
                lname = extract_layer_from_color(c_int)
                for x1, y1, x2, y2 in circle_to_segments(float(cxm.group(1)), float(cym.group(1)), float(rm.group(1)), elem_mat):
                    add_line(x1, y1, x2, y2, c_int, lname)

        # 4. <ellipse>
        for m in re.finditer(r'<ellipse\b([^>]+)>', content):
            attrs = m.group(1)
            cxm = re.search(r'\bcx="([+-]?\d*\.?\d+)"', attrs)
            cym = re.search(r'\bcy="([+-]?\d*\.?\d+)"', attrs)
            rxm = re.search(r'\brx="([+-]?\d*\.?\d+)"', attrs)
            rym = re.search(r'\bry="([+-]?\d*\.?\d+)"', attrs)
            if cxm and cym and rxm and rym:
                tm = re.search(r'transform="([^"]+)"', attrs)
                elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
                c_int = extract_stroke_color(attrs, 0xffffff)
                lname = extract_layer_from_color(c_int)
                for x1, y1, x2, y2 in ellipse_to_segments(float(cxm.group(1)), float(cym.group(1)), float(rxm.group(1)), float(rym.group(1)), elem_mat):
                    add_line(x1, y1, x2, y2, c_int, lname)

        # 5. <polygon> ve <polyline>
        for tag_name, is_closed in (('polygon', True), ('polyline', False)):
            for m in re.finditer(rf'<{tag_name}\b([^>]+)>', content):
                attrs = m.group(1)
                pm = re.search(r'\bpoints="([^"]+)"', attrs)
                if not pm:
                    continue
                pts_raw = [float(v) for v in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', pm.group(1))]
                if len(pts_raw) >= 4:
                    tm = re.search(r'transform="([^"]+)"', attrs)
                    elem_mat = multiply_matrices(current_mat, parse_transform(tm.group(1))) if tm else current_mat
                    c_int = extract_stroke_color(attrs, 0xffffff)
                    lname = extract_layer_from_color(c_int)
                    pts = [(pts_raw[k], pts_raw[k + 1]) for k in range(0, len(pts_raw) - 1, 2)]
                    limit = len(pts) if is_closed else len(pts) - 1
                    for k in range(limit):
                        p1 = apply_transform(elem_mat, pts[k][0], pts[k][1])
                        p2 = apply_transform(elem_mat, pts[(k + 1) % len(pts)][0], pts[(k + 1) % len(pts)][1])
                        add_line(p1[0], p1[1], p2[0], p2[1], c_int, lname)

        # 6. <text> (<tspan> ve transform rotasyonu destekli)
        for m in re.finditer(r'<text\b([^>]*)>(.*?)</text>', content, re.DOTALL):
            attrs = m.group(1)
            inner = re.sub(r'<[^>]+>', ' ', m.group(2)).strip()
            if not inner:
                continue
            xm = re.search(r'\bx="([+-]?\d*\.?\d+)"', attrs)
            ym = re.search(r'\by="([+-]?\d*\.?\d+)"', attrs)
            sm = re.search(r'font-size="([+-]?\d*\.?\d+)"', attrs) or re.search(r'font-size\s*:\s*([+-]?\d*\.?\d+)', attrs)
            fm = re.search(r'fill="([^"]+)"', attrs) or re.search(r'fill\s*:\s*([^;"]+)', attrs)
            tm = re.search(r'transform="([^"]+)"', attrs)

            x = float(xm.group(1)) if xm else 0.0
            y = float(ym.group(1)) if ym else 0.0
            size = float(sm.group(1)) if sm else 12.0
            fill = fm.group(1) if fm else '#ffffff'

            if tm:
                t_mat = multiply_matrices(current_mat, parse_transform(tm.group(1)))
                wx, wy = apply_transform(t_mat, x, y)
                rot_deg = extract_rotation_deg(t_mat)
                eff_scale = math.hypot(t_mat[0], t_mat[1]) or scale_mag
            else:
                wx, wy = apply_transform(current_mat, x, y)
                rot_deg = base_rot
                eff_scale = scale_mag

            add_text(wx, wy, size * eff_scale, fill, inner, rot_deg, 'YAZILAR')

    process_elements(model_part, identity_matrix())

    def render_symbol(sid, current_mat, depth=0, max_depth=8):
        if depth > max_depth or sid not in symbols:
            return
        sym = symbols[sid]
        elem_mat = multiply_matrices(current_mat, OFFSET_SHIFT_MAT) if sym['needs_base_shift'] else current_mat
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
            child_mat = multiply_matrices(current_mat, child_trans_mat)
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
        sym = symbols[sym_id]
        combined_mat = multiply_matrices(use_mat, sym['mat'])
        render_symbol(sym_id, combined_mat, depth=0)


# Poligon Üçgenleme (Yüksek Köşe Sayılı Poligonlar İçin Geliştirilmiş Ear-Clipping)
def triangulate_polygon(pts):
    # Ardışık tekrar eden noktaları temizle
    cleaned = []
    for p in pts:
        if not cleaned or math.hypot(p[0] - cleaned[-1][0], p[1] - cleaned[-1][1]) > 1e-3:
            cleaned.append(p)
    if len(cleaned) >= 2 and math.hypot(cleaned[0][0] - cleaned[-1][0], cleaned[0][1] - cleaned[-1][1]) <= 1e-3:
        cleaned.pop()
    pts = cleaned
    n = len(pts)
    if n < 3:
        return []
    if n == 3:
        return [(pts[0], pts[1], pts[2])]
    if n == 4:
        return [(pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])]

    # Çok fazla köşe varsa performans için örnekle
    if n > 250:
        step = max(1, n // 200)
        pts = pts[::step]
        n = len(pts)

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
    max_attempts = n * 3 + 50
    attempts = 0
    while len(indices) > 3 and attempts < max_attempts:
        attempts += 1
        found_ear = False
        m_len = len(indices)
        for i in range(m_len):
            prev_i = indices[i - 1]
            curr_i = indices[i]
            next_i = indices[(i + 1) % m_len]
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


# 2. AŞAMA: DXF'TEN HATCH DOLGULARI, BİRİM ($INSUNITS), KATMANLAR VE EKSİK VARLIKLARI ÇIKAR
dxf_candidate = svg_path.replace('.svg', '.dxf') if svg_path.endswith('.svg') else svg_path
dwg_candidate = svg_path.replace('.svg', '.dwg') if svg_path.endswith('.svg') else svg_path.replace('.dxf', '.dwg')

if not os.path.exists(dxf_candidate) and os.path.exists(dwg_candidate):
    print(f"Generating DXF from DWG: {dwg_candidate}...")
    import subprocess
    subprocess.run(['dwg2dxf', '-y', dwg_candidate, '-o', dxf_candidate], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

insunits = 5  # Varsayılan: cm (1:100)
meters_per_unit = 0.01

if os.path.exists(dxf_candidate):
    print(f"Processing DXF via ezdxf: {dxf_candidate}...")
    try:
        import ezdxf
        from ezdxf.math import Matrix44

        doc = ezdxf.readfile(dxf_candidate)
        msp = doc.modelspace()
        block_map = {b.name: b for b in doc.blocks}

        # $INSUNITS birim algılama
        try:
            insunits = int(doc.header.get('$INSUNITS', 5))
            units_map = {
                1: 0.0254,  # İnç
                2: 0.3048,  #ayak (Feet)
                4: 0.001,   # Milimetre (mm)
                5: 0.01,    # Santimetre (cm)
                6: 1.0,     # Metre (m)
            }
            meters_per_unit = units_map.get(insunits, 0.01)
            print(f"Detected $INSUNITS={insunits} -> metersPerUnit={meters_per_unit}")
        except Exception:
            pass

        # DXF katman renk haritası
        dxf_layer_colors = {}
        try:
            for lyr in doc.layers:
                lname = lyr.dxf.name
                aci = lyr.color
                rgb = aci_to_rgb(aci)
                if lyr.dxf.hasattr('true_color'):
                    rgb = int(lyr.dxf.true_color) & 0xFFFFFF
                dxf_layer_colors[lname] = rgb
        except Exception:
            pass

        # Eğer SVG'den hiç çizgi çıkmadıysa (ör. doğrudan DXF yüklendi veya dwg2SVG başarısız oldu),
        # TÜM ÇİZİMİ doğrudan ezdxf ile %100 kayıpsız çıkar!
        svg_had_geometry = len(lines_data) > 50

        CALC_BASE_X = BASE_X
        CALC_BASE_Y = BASE_Y
        if svg_had_geometry:
            try:
                svg_map = {}
                for st in texts_data:
                    txt = st['t'].strip()
                    if len(txt) >= 4 and not any(txt.startswith(c) for c in ['GREEN', 'RED', 'CYAN', 'YELLOW', 'ÖLÇEK', 'OLCEK']):
                        svg_map.setdefault(txt, []).append((st['x'], st['y']))

                matches = []
                for t in msp.query('TEXT MTEXT'):
                    txt = clean_cad_text(t.dxf.text if t.dxftype() == 'TEXT' else t.text)
                    if txt in svg_map and t.dxf.hasattr('insert'):
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
            except Exception as ce:
                print(f"Calibration note: {ce}")

        def dxf_to_svg(x, y):
            return (x + CALC_BASE_X, -y + CALC_BASE_Y)

        def resolve_entity_color(entity, parent_layer='0', parent_color=None):
            lyr = entity.dxf.layer if entity.dxf.hasattr('layer') else '0'
            if lyr == '0' and parent_layer != '0':
                lyr = parent_layer
            if entity.dxf.hasattr('true_color'):
                return int(entity.dxf.true_color) & 0xFFFFFF, lyr
            c = entity.dxf.color if entity.dxf.hasattr('color') else 256
            if c == 0 and parent_color is not None:  # BYBLOCK
                return parent_color, lyr
            if c == 256 or c is None:  # BYLAYER
                return dxf_layer_colors.get(lyr, 0xFFFFFF), lyr
            return aci_to_rgb(c), lyr

        # HATCH Path -> Nokta Dizisi (PolylinePath bulge ve EdgePath yay/elips/spline destekli)
        def extract_hatch_path_points(path):
            pts = []
            if hasattr(path, 'vertices') and path.vertices:
                verts = path.vertices
                n_v = len(verts)
                is_closed = getattr(path, 'is_closed', True)
                count = n_v if is_closed else max(0, n_v - 1)
                for idx in range(count):
                    v1 = verts[idx]
                    v2 = verts[(idx + 1) % n_v]
                    x1, y1 = float(v1[0]), float(v1[1])
                    x2, y2 = float(v2[0]), float(v2[1])
                    bulge = float(v1[2]) if len(v1) > 2 else 0.0
                    pts.append((x1, y1))
                    if abs(bulge) > 1e-4:
                        chord = math.hypot(x2 - x1, y2 - y1)
                        if chord > 1e-4:
                            theta = 4.0 * math.atan(bulge)
                            radius = chord / (2.0 * math.sin(theta / 2.0))
                            mid_x = (x1 + x2) * 0.5
                            mid_y = (y1 + y2) * 0.5
                            dist_c = math.sqrt(max(0.0, radius * radius - (chord * 0.5) ** 2))
                            nx = -(y2 - y1) / chord
                            ny = (x2 - x1) / chord
                            sign = 1.0 if bulge > 0 else -1.0
                            if radius < 0:
                                sign = -sign
                            cx = mid_x + sign * dist_c * nx
                            cy = mid_y + sign * dist_c * ny
                            sa = math.atan2(y1 - cy, x1 - cx)
                            ea = math.atan2(y2 - cy, x2 - cx)
                            if bulge > 0 and ea < sa:
                                ea += 2.0 * math.pi
                            elif bulge < 0 and ea > sa:
                                ea -= 2.0 * math.pi
                            segs = max(4, min(16, int(abs(theta) * 6)))
                            for s in range(1, segs):
                                ang = sa + (s / segs) * (ea - sa)
                                pts.append((cx + abs(radius) * math.cos(ang), cy + abs(radius) * math.sin(ang)))
            elif hasattr(path, 'edges'):
                for edge in path.edges:
                    etype = getattr(edge, 'EDGE_TYPE', '') or type(edge).__name__
                    if 'Line' in etype and hasattr(edge, 'start'):
                        pts.append((float(edge.start[0]), float(edge.start[1])))
                    elif 'Arc' in etype and hasattr(edge, 'center'):
                        cx, cy = float(edge.center[0]), float(edge.center[1])
                        r = float(getattr(edge, 'radius', 1.0))
                        sa = math.radians(float(getattr(edge, 'start_angle', 0.0)))
                        ea = math.radians(float(getattr(edge, 'end_angle', 360.0)))
                        ccw = getattr(edge, 'ccw', True)
                        if ccw and ea < sa:
                            ea += 2.0 * math.pi
                        elif not ccw and ea > sa:
                            ea -= 2.0 * math.pi
                        segs = max(6, min(24, int(abs(ea - sa) * 6)))
                        for s in range(segs):
                            ang = sa + (s / segs) * (ea - sa)
                            pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
                    elif hasattr(edge, 'start'):
                        pts.append((float(edge.start[0]), float(edge.start[1])))
            return pts

        # Rekürsif Blok & Hatch Tarayıcı
        hatch_items = []
        attrib_items = []

        def collect_from_container(container, current_dxf_mat=None, depth=0, parent_layer='0', parent_color=None):
            if depth > 7:
                return
            for e in container:
                dxftype = e.dxftype()
                if dxftype == 'HATCH':
                    hatch_items.append((e, current_dxf_mat, parent_layer, parent_color))
                elif dxftype == 'INSERT':
                    # Bloklara bağlı ATTRIB (Aks balonları, kot yazıları, antetler)
                    if hasattr(e, 'attribs'):
                        for attr in e.attribs:
                            attrib_items.append((attr, current_dxf_mat, parent_layer, parent_color))
                    bname = e.dxf.name if e.dxf.hasattr('name') else ''
                    if bname in block_map:
                        blk = block_map[bname]
                        bx = float(blk.block.dxf.base_point.x) if blk.block.dxf.hasattr('base_point') else 0.0
                        by = float(blk.block.dxf.base_point.y) if blk.block.dxf.hasattr('base_point') else 0.0
                        ix = float(e.dxf.insert.x) if e.dxf.hasattr('insert') else 0.0
                        iy = float(e.dxf.insert.y) if e.dxf.hasattr('insert') else 0.0
                        sx = float(e.dxf.xscale) if e.dxf.hasattr('xscale') else 1.0
                        sy = float(e.dxf.yscale) if e.dxf.hasattr('yscale') else 1.0
                        rot = math.radians(float(e.dxf.rotation) if e.dxf.hasattr('rotation') else 0.0)
                        cos_r = math.cos(rot)
                        sin_r = math.sin(rot)
                        # Doğru AutoCAD Blok Dönüşüm Matrisi: T(ix, iy) * R(rot) * S(sx, sy) * T(-bx, -by)
                        m_base = [1.0, 0.0, 0.0, 1.0, -bx, -by]
                        m_sr = [sx * cos_r, sx * sin_r, -sy * sin_r, sy * cos_r, ix, iy]
                        m_local = multiply_matrices(m_sr, m_base)
                        m_combined = multiply_matrices(current_dxf_mat, m_local) if current_dxf_mat else m_local
                        ins_color, ins_layer = resolve_entity_color(e, parent_layer, parent_color)
                        collect_from_container(blk, m_combined, depth + 1, ins_layer, ins_color)

        collect_from_container(msp)
        print(f"Processing total of {len(hatch_items)} hatch elements and {len(attrib_items)} block attributes...")

        # Eğer SVG'de ATTRIB yazıları eksik kaldıysa DXF'ten tamamla
        existing_text_coords = set((round(t['x'], -1), round(t['y'], -1)) for t in texts_data)
        for attr, dxf_mat, p_lyr, p_col in attrib_items:
            raw_txt = attr.dxf.text if attr.dxf.hasattr('text') else ''
            if not raw_txt or not attr.dxf.hasattr('insert'):
                continue
            ax, ay = float(attr.dxf.insert.x), float(attr.dxf.insert.y)
            if dxf_mat:
                ax, ay = apply_transform(dxf_mat, ax, ay)
            sx, sy = dxf_to_svg(ax, ay)
            if (round(sx, -1), round(sy, -1)) not in existing_text_coords:
                col_int, lyr_name = resolve_entity_color(attr, p_lyr, p_col)
                ht = float(attr.dxf.height) if attr.dxf.hasattr('height') else 12.0
                rot = float(attr.dxf.rotation) if attr.dxf.hasattr('rotation') else 0.0
                add_text(sx, sy, ht, col_int, raw_txt, rot, lyr_name)

        solid_tri_count = 0
        for h, dxf_mat, p_lyr, p_col in hatch_items:
            col_int, layer_raw = resolve_entity_color(h, p_lyr, p_col)
            layer = layer_raw.lower()
            pat = h.dxf.pattern_name.upper() if h.dxf.hasattr('pattern_name') else ''
            is_solid = (h.dxf.solid_fill == 1) if h.dxf.hasattr('solid_fill') else (pat == 'SOLID')

            # Devasa zemin/pafta/döşeme taramalarının çizimi kapatmasını önle, tüm yapısal ve mimari dolguları çiz
            is_excluded = any(ex in layer for ex in [
                'temel', 'temal', 'doseme', 'döşeme', 'pafta', 'tarif', 'olcu', 'ölçü',
                'saft', 'şaft', 'aks', 'yazi', 'yazı', 'text', 'donati', 'donatı',
                'demir', 'kot', 'drenaj', 'cati', 'çatı', 'tefris', 'tefriş', 'buhar', 'asansör', 'asansor', 'parapet'
            ])
            if is_excluded:
                continue

            is_col = any(k in layer for k in ['kolon', 'column', 'sutun', 'sütun', 'col'])
            is_wall = any(w in layer for w in ['perde', 'kiris', 'kiriş', 'beam', 'wall', 'duvar'])

            if is_wall:
                c_fill = 0xa05252
                c_outline = 0xb85d5d
            elif is_col:
                c_fill = 0x527273
                c_outline = 0x709293
            else:
                # Diğer mimari/statik katmanlardaki solid hatch'ler için kendi katman renginin koyu tonunu kullan
                r_c = ((col_int >> 16) & 255) // 2
                g_c = ((col_int >> 8) & 255) // 2
                b_c = (col_int & 255) // 2
                c_fill = (r_c << 16) | (g_c << 8) | b_c if col_int != 0xffffff else 0x527273
                c_outline = col_int if col_int != 0xffffff else 0x64748b

            for p in h.paths:
                pts = extract_hatch_path_points(p)
                if len(pts) < 3:
                    continue
                if dxf_mat is not None:
                    msp_pts = [apply_transform(dxf_mat, pt[0], pt[1]) for pt in pts]
                else:
                    msp_pts = pts
                svg_pts = [dxf_to_svg(pt[0], pt[1]) for pt in msp_pts]

                if is_solid:
                    tris = triangulate_polygon(svg_pts)
                    for t1, t2, t3 in tris:
                        add_triangle(t1, t2, t3, c_fill, layer_raw)
                        solid_tri_count += 1

                for i in range(len(svg_pts)):
                    p1 = svg_pts[i]
                    p2 = svg_pts[(i + 1) % len(svg_pts)]
                    add_line(p1[0], p1[1], p2[0], p2[1], c_outline, layer_raw)

        # 3. EĞER SVG HİÇ ÜRETİLEMEDİYSE (Doğrudan DXF veya dwg2SVG hatası), TÜM MODELSPACE'İ ezdxf İLE ÇIKAR
        if not svg_had_geometry:
            print("SVG geometry empty; extracting 100% of entities directly from DXF via ezdxf...")
            def extract_dxf_entity(ent, mat=None, depth=0, p_lyr='0', p_col=None):
                if depth > 7:
                    return
                etype = ent.dxftype()
                c_int, lyr = resolve_entity_color(ent, p_lyr, p_col)

                def tp(x, y):
                    if mat:
                        x, y = apply_transform(mat, x, y)
                    return dxf_to_svg(x, y)

                if etype == 'LINE':
                    p1 = tp(ent.dxf.start.x, ent.dxf.start.y)
                    p2 = tp(ent.dxf.end.x, ent.dxf.end.y)
                    add_line(p1[0], p1[1], p2[0], p2[1], c_int, lyr)
                elif etype in ('LWPOLYLINE', 'POLYLINE'):
                    try:
                        for sub in ent.virtual_entities():
                            extract_dxf_entity(sub, mat, depth + 1, lyr, c_int)
                    except Exception:
                        pass
                elif etype == 'CIRCLE':
                    cx, cy, r = ent.dxf.center.x, ent.dxf.center.y, ent.dxf.radius
                    segs = 28
                    pts = [tp(cx + r * math.cos(2 * math.pi * k / segs), cy + r * math.sin(2 * math.pi * k / segs)) for k in range(segs)]
                    for k in range(segs):
                        add_line(pts[k][0], pts[k][1], pts[(k + 1) % segs][0], pts[(k + 1) % segs][1], c_int, lyr)
                elif etype == 'ARC':
                    cx, cy, r = ent.dxf.center.x, ent.dxf.center.y, ent.dxf.radius
                    sa = math.radians(ent.dxf.start_angle)
                    ea = math.radians(ent.dxf.end_angle)
                    if ea < sa:
                        ea += 2 * math.pi
                    segs = max(8, min(36, int((ea - sa) * 10)))
                    pts = [tp(cx + r * math.cos(sa + (k / segs) * (ea - sa)), cy + r * math.sin(sa + (k / segs) * (ea - sa))) for k in range(segs + 1)]
                    for k in range(segs):
                        add_line(pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], c_int, lyr)
                elif etype in ('ELLIPSE', 'SPLINE'):
                    try:
                        pts_raw = list(ent.flattening(distance=0.5))
                        for k in range(len(pts_raw) - 1):
                            p1 = tp(pts_raw[k].x, pts_raw[k].y)
                            p2 = tp(pts_raw[k + 1].x, pts_raw[k + 1].y)
                            add_line(p1[0], p1[1], p2[0], p2[1], c_int, lyr)
                    except Exception:
                        pass
                elif etype in ('SOLID', '3DFACE'):
                    pts = [tp(ent.dxf.vtx0.x, ent.dxf.vtx0.y), tp(ent.dxf.vtx1.x, ent.dxf.vtx1.y),
                           tp(ent.dxf.vtx2.x, ent.dxf.vtx2.y), tp(ent.dxf.vtx3.x, ent.dxf.vtx3.y)]
                    add_triangle(pts[0], pts[1], pts[2], c_int, lyr)
                    if pts[2] != pts[3]:
                        add_triangle(pts[0], pts[2], pts[3], c_int, lyr)
                elif etype in ('TEXT', 'MTEXT', 'ATTRIB'):
                    raw_t = ent.dxf.text if etype in ('TEXT', 'ATTRIB') else ent.text
                    ins = ent.dxf.insert if ent.dxf.hasattr('insert') else None
                    if raw_t and ins:
                        p = tp(ins.x, ins.y)
                        ht = float(ent.dxf.height if ent.dxf.hasattr('height') else getattr(ent.dxf, 'char_height', 12.0))
                        rot = float(ent.dxf.rotation) if ent.dxf.hasattr('rotation') else 0.0
                        add_text(p[0], p[1], ht, c_int, raw_t, rot, lyr)
                elif etype in ('INSERT', 'DIMENSION', 'LEADER', 'MLEADER'):
                    try:
                        for sub in ent.virtual_entities():
                            extract_dxf_entity(sub, mat, depth + 1, lyr, c_int)
                    except Exception:
                        pass

            for e in msp:
                extract_dxf_entity(e)

        print(f"Successfully generated {solid_tri_count} solid fill triangles from DXF!")
    except Exception as e:
        print(f"DXF extraction note: {e}")

# Dinamik Sınır (Bounds) Hesaplama (Çoklu pafta ve harita koordinatlarını kessiz kapsar)
if lines_data:
    xs = lines_data[0::5] + lines_data[2::5]
    ys = lines_data[1::5] + lines_data[3::5]
    min_x = float(np.percentile(xs, 0.2)) if len(xs) > 100 else min(xs)
    max_x = float(np.percentile(xs, 99.8)) if len(xs) > 100 else max(xs)
    min_y = float(np.percentile(ys, 0.2)) if len(ys) > 100 else min(ys)
    max_y = float(np.percentile(ys, 99.8)) if len(ys) > 100 else max(ys)
    bounds = {
        'minX': round(min_x, 2),
        'minY': round(min_y, 2),
        'w': round(max(10.0, max_x - min_x), 2),
        'h': round(max(10.0, max_y - min_y), 2)
    }
elif vb_bounds:
    bounds = vb_bounds
else:
    bounds = {'minX': 0.0, 'minY': 0.0, 'w': 10000.0, 'h': 10000.0}

total_lines_count = len(lines_data) // 5
total_triangles_count = len(triangles_data) // 7
layers_list = sorted(layers_dict.values(), key=lambda x: x['id'])
print(f"Extraction COMPLETE! Lines: {total_lines_count}, Solid Triangles: {total_triangles_count}, Texts: {len(texts_data)}, Layers: {len(layers_list)}")

payload = {
    'bounds': bounds,
    'insunits': insunits,
    'metersPerUnit': meters_per_unit,
    'layers': layers_list,
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
        'layers': layers_list,
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
