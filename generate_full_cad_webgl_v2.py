import re
import json
import math
import time
import gzip
import os
import sys
import subprocess
from collections import Counter
import numpy as np

t0 = time.time()
svg_path = sys.argv[1] if len(sys.argv) > 1 else "/home/ubuntu/cad-service/uploads/87b6f0bc-dc50-4fbc-959b-e1302122afd0.svg"
out_json = sys.argv[2] if len(sys.argv) > 2 else "/home/ubuntu/cad-service/public/cad_data.json"
out_gz = out_json + ".gz"

# AutoCAD Color Index (ACI 1-9 Vivid Palette + Full 1-255 ezdxf fallback)
ACI_PALETTE = {
    1: 0xff3b30,  # Red
    2: 0xffe600,  # Yellow
    3: 0x22c55e,  # Green
    4: 0x00f0ff,  # Cyan
    5: 0x38bdf8,  # Blue
    6: 0xff2d55,  # Magenta
    7: 0xffffff,  # White / Black -> White on dark canvas
    8: 0x94a3b8,  # Medium Gray
    9: 0xcbd5e1,  # Light Gray
}

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
    raw_t = re.sub(r'\\[WwHhQqTtAaOoLlKk][^;]*;?', '', raw_t)
    raw_t = re.sub(r'\\[Cc]\d+;', '', raw_t)
    raw_t = re.sub(r'\\S([^;^/]+)[/^]([^;]*);', r'\1/\2', raw_t)
    def repl_u(m):
        try:
            return chr(int(m.group(1), 16))
        except Exception:
            return m.group(0)
    raw_t = re.sub(r'\\[uU]\+([0-9a-fA-F]{4})', repl_u, raw_t)
    raw_t = (raw_t
             .replace('\\P', '\n').replace('\\p', '\n')
             .replace('\\~', ' ')
             .replace('{', '').replace('}', '')
             .replace('&#x192;', 'Ø')
             .replace('%%c', 'Ø').replace('%%C', 'Ø')
             .replace('%%d', '°').replace('%%D', '°')
             .replace('%%p', '±').replace('%%P', '±')
             .replace('%%u', '').replace('%%U', '')
             .replace('%%o', '').replace('%%O', '')
             .replace('&apos;', "'").replace('&#39;', "'")
             .replace('&quot;', '"').replace('&amp;', '&'))
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

def apply_transform(mat, x, y):
    return mat[0] * x + mat[2] * y + mat[4], mat[1] * x + mat[3] * y + mat[5]

# Robust Polygon Triangulation for Solid Hatches & Polygons
def triangulate_polygon(pts):
    cleaned = []
    for p in pts:
        if not cleaned or math.hypot(p[0] - cleaned[-1][0], p[1] - cleaned[-1][1]) > 1e-3:
            cleaned.append(p)
    if len(cleaned) >= 2 and math.hypot(cleaned[0][0] - cleaned[-1][0], cleaned[0][1] - cleaned[-1][1]) <= 1e-3:
        cleaned.pop()

    n = len(cleaned)
    if n < 3:
        return []
    if n == 3:
        return [(cleaned[0], cleaned[1], cleaned[2])]
    if n == 4:
        return [(cleaned[0], cleaned[1], cleaned[2]), (cleaned[0], cleaned[2], cleaned[3])]
    if n > 180:
        step = max(1, n // 150)
        cleaned = cleaned[::step]
        n = len(cleaned)

    def area2(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def is_point_in_tri(p, a, b, c):
        d1 = area2(p, a, b); d2 = area2(p, b, c); d3 = area2(p, c, a)
        return not (((d1 < 0) or (d2 < 0) or (d3 < 0)) and ((d1 > 0) or (d2 > 0) or (d3 > 0)))

    indices = list(range(n))
    total_area = sum((cleaned[(i + 1) % n][0] - cleaned[i][0]) * (cleaned[(i + 1) % n][1] + cleaned[i][1]) for i in range(n))
    if total_area > 0:
        indices.reverse()
    triangles = []
    attempts = 0
    max_attempts = n * 2 + 40
    while len(indices) > 3 and attempts < max_attempts:
        attempts += 1
        found_ear = False
        m_len = len(indices)
        for i in range(m_len):
            prev_i = indices[i - 1]; curr_i = indices[i]; next_i = indices[(i + 1) % m_len]
            a = cleaned[prev_i]; b = cleaned[curr_i]; c = cleaned[next_i]
            if area2(a, b, c) <= 1e-6:
                continue
            is_ear = True
            for k in indices:
                if k not in (prev_i, curr_i, next_i) and is_point_in_tri(cleaned[k], a, b, c):
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
        triangles.append((cleaned[indices[0]], cleaned[indices[1]], cleaned[indices[2]]))
    elif len(indices) > 3:
        for i in range(1, len(indices) - 1):
            triangles.append((cleaned[indices[0]], cleaned[indices[i]], cleaned[indices[i + 1]]))
    return triangles

# Locate or generate DXF from DWG
base_no_ext = os.path.splitext(svg_path)[0]
dxf_candidate = base_no_ext + '.dxf'
dwg_candidate = base_no_ext + '.dwg'

if not os.path.exists(dxf_candidate) and os.path.exists(dwg_candidate):
    print(f"Generating DXF from DWG: {dwg_candidate}...")
    subprocess.run(['dwg2dxf', '-y', dwg_candidate, '-o', dxf_candidate], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

dxf_doc = None
dxf_block_base_pts = {}
dxf_layer_colors = {}
dxf_layer_visible = {}
layer_counts = Counter()
insunits = 5
meters_per_unit = 0.01

if os.path.exists(dxf_candidate):
    try:
        import ezdxf
        try:
            dxf_doc = ezdxf.readfile(dxf_candidate)
        except Exception:
            from ezdxf import recover
            dxf_doc, _ = recover.readfile(dxf_candidate)
        try:
            insunits = int(dxf_doc.header.get('$INSUNITS', 5))
            u_map = {1: 0.0254, 2: 0.3048, 4: 0.001, 5: 0.01, 6: 1.0}
            meters_per_unit = u_map.get(insunits, 0.01)
        except Exception:
            pass
        for lyr in dxf_doc.layers:
            lname = lyr.dxf.name if lyr.dxf.hasattr('name') else '0'
            try:
                raw_aci = int(lyr.dxf.color) if lyr.dxf.hasattr('color') else 7
                flags = int(lyr.dxf.flags) if lyr.dxf.hasattr('flags') else 0
                is_vis = (raw_aci >= 0) and ((flags & 1) == 0)
                dxf_layer_visible[lname] = is_vis
                aci = abs(raw_aci)
                if lyr.dxf.hasattr('true_color') and lyr.dxf.true_color:
                    val = int(lyr.dxf.true_color) & 0xffffff
                    dxf_layer_colors[lname] = 0xffffff if val == 0 else val
                elif aci in ACI_PALETTE:
                    dxf_layer_colors[lname] = ACI_PALETTE[aci]
                else:
                    rgb = ezdxf.colors.aci2rgb(aci if 1 <= aci <= 255 else 7)
                    val = (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
                    dxf_layer_colors[lname] = 0xffffff if val == 0 else val
            except Exception:
                dxf_layer_colors[lname] = 0xffffff
                dxf_layer_visible[lname] = True
        for b in dxf_doc.blocks:
            if b.block and b.block.dxf.hasattr('base_point'):
                bp = b.block.dxf.base_point
                if abs(bp.x) > 1e-3 or abs(bp.y) > 1e-3:
                    dxf_block_base_pts[b.name] = (float(bp.x), float(bp.y))
    except Exception as e:
        print(f"DXF pre-read note: {e}")

def get_dxf_entity_color(ent, effective_layer='0', parent_color=0xffffff):
    try:
        if ent.dxf.hasattr('true_color') and ent.dxf.true_color:
            val = int(ent.dxf.true_color) & 0xffffff
            return 0xffffff if val == 0 else val
        aci = int(ent.dxf.color) if ent.dxf.hasattr('color') else 256
        if aci == 256:  # ByLayer
            return dxf_layer_colors.get(effective_layer, parent_color)
        if aci == 0:    # ByBlock
            return parent_color
        aci = abs(aci)
        if aci in ACI_PALETTE:
            return ACI_PALETTE[aci]
        import ezdxf
        rgb = ezdxf.colors.aci2rgb(aci if 1 <= aci <= 255 else 7)
        val = (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
        return 0xffffff if val == 0 else val
    except Exception:
        return dxf_layer_colors.get(effective_layer, parent_color)

lines_data = []      # [x1, y1, x2, y2, color, ...]
texts_data = []
triangles_data = []  # [x1, y1, x2, y2, x3, y3, color, ...]

MAX_COORD_LIMIT = 1e9

def add_line(x1, y1, x2, y2, color, layer_name='0'):
    if not (math.isfinite(x1) and math.isfinite(y1) and math.isfinite(x2) and math.isfinite(y2)):
        return
    if abs(x1) > MAX_COORD_LIMIT or abs(y1) > MAX_COORD_LIMIT or abs(x2) > MAX_COORD_LIMIT or abs(y2) > MAX_COORD_LIMIT:
        return
    if abs(x1 - x2) < 1e-3 and abs(y1 - y2) < 1e-3:
        return
    lines_data.extend([round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1), int(color)])
    layer_counts[layer_name] += 1

def add_triangle(p1, p2, p3, color, layer_name='0'):
    if not (math.isfinite(p1[0]) and math.isfinite(p1[1]) and
            math.isfinite(p2[0]) and math.isfinite(p2[1]) and
            math.isfinite(p3[0]) and math.isfinite(p3[1])):
        return
    if abs(p1[0]) > MAX_COORD_LIMIT or abs(p1[1]) > MAX_COORD_LIMIT:
        return
    triangles_data.extend([
        round(p1[0], 1), round(p1[1], 1),
        round(p2[0], 1), round(p2[1], 1),
        round(p3[0], 1), round(p3[1], 1),
        int(color)
    ])
    layer_counts[layer_name] += 1

def add_text(wx, wy, size, fill_or_int, raw_t, rot_deg=0.0, layer_name='0', halign=0):
    if not (math.isfinite(wx) and math.isfinite(wy)):
        return
    if abs(wx) > MAX_COORD_LIMIT or abs(wy) > MAX_COORD_LIMIT:
        return
    cleaned = clean_cad_text(raw_t)
    if not cleaned:
        return
    c_int = fill_or_int if isinstance(fill_or_int, int) else parse_color(fill_or_int)
    lines = [ln.strip() for ln in cleaned.split('\n') if ln.strip()]
    if not lines:
        return
    font_s = round(max(size, 1.0), 1)
    line_step = font_s * 1.28
    rad = math.radians(rot_deg)
    sin_r = math.sin(rad)
    cos_r = math.cos(rad)
    for idx, ln in enumerate(lines):
        # Y-down uzayında alt satıra geçiş (+Y yönü)
        lx = wx - idx * line_step * sin_r
        ly = wy + idx * line_step * cos_r
        item = {
            'x': round(lx, 1),
            'y': round(ly, 1),
            's': font_s,
            'c': f"#{c_int:06x}",
            't': ln,
            'l': layer_name
        }
        if abs(rot_deg) > 0.1:
            item['r'] = round(rot_deg, 1)
        if halign:
            item['a'] = int(halign)
        texts_data.append(item)
        layer_counts[layer_name] += 1

# ==============================================================================
# BİRİNCİL MOTOR: DOĞRUDAN DXF TAM VEKTÖR & BLOK MOTORU (DWG FastView Kalitesi)
# dwg2SVG'nin ByLayer renk kaybı, bulge yay eksikliği ve MTEXT/DIMENSION/HATCH
# kayıplarını %100 ortadan kaldırır.
# ==============================================================================
def extract_directly_from_dxf(doc):
    msp = doc.modelspace()
    block_map = {b.name: b for b in doc.blocks}

    def dxf_to_world(x, y):
        # WebGL tuvalinde flipY=true (Kuzey Yukarı) standardı ile tam uyumlu Y-aşağı eşlemesi
        return (x, -y)

    def make_insert_matrix(ins, base_pt=(0.0, 0.0), gx=0.0, gy=0.0):
        sx = float(ins.dxf.xscale) if ins.dxf.hasattr('xscale') else 1.0
        sy = float(ins.dxf.yscale) if ins.dxf.hasattr('yscale') else 1.0
        rot_deg = float(ins.dxf.rotation) if ins.dxf.hasattr('rotation') else 0.0
        rot = math.radians(rot_deg)
        cos_r = math.cos(rot)
        sin_r = math.sin(rot)
        bx, by = base_pt
        m0 = sx * cos_r
        m1 = sx * sin_r
        m2 = -sy * sin_r
        m3 = sy * cos_r
        ins_x = float(ins.dxf.insert.x) + gx * cos_r - gy * sin_r
        ins_y = float(ins.dxf.insert.y) + gx * sin_r + gy * cos_r
        ix = ins_x - m0 * bx - m2 * by
        iy = ins_y - m1 * bx - m3 * by
        return [m0, m1, m2, m3, ix, iy]

    def emit_bulge_arc(x1, y1, x2, y2, bulge, mat, c_int, lyr):
        dx = x2 - x1
        dy = y2 - y1
        chord = math.hypot(dx, dy)
        if chord < 1e-4:
            return []
        if abs(bulge) < 1e-4:
            p1 = dxf_to_world(*apply_transform(mat, x1, y1))
            p2 = dxf_to_world(*apply_transform(mat, x2, y2))
            add_line(p1[0], p1[1], p2[0], p2[1], c_int, lyr)
            return [p1, p2]

        theta = 4.0 * math.atan(bulge)
        sin_half = math.sin(theta * 0.5)
        if abs(sin_half) < 1e-6:
            p1 = dxf_to_world(*apply_transform(mat, x1, y1))
            p2 = dxf_to_world(*apply_transform(mat, x2, y2))
            add_line(p1[0], p1[1], p2[0], p2[1], c_int, lyr)
            return [p1, p2]

        radius = chord / (2.0 * sin_half)
        abs_r = abs(radius)
        mid_x = (x1 + x2) * 0.5
        mid_y = (y1 + y2) * 0.5
        dist_c = math.sqrt(max(0.0, abs_r * abs_r - (chord * 0.5) ** 2))
        nx = -dy / chord
        ny = dx / chord
        sign = 1.0 if bulge > 0 else -1.0
        dir_f = sign * (1.0 if radius >= 0 else -1.0)
        cx = mid_x + dir_f * dist_c * nx
        cy = mid_y + dir_f * dist_c * ny

        sa = math.atan2(y1 - cy, x1 - cx)
        ea = math.atan2(y2 - cy, x2 - cx)
        if bulge > 0 and ea < sa:
            ea += 2.0 * math.pi
        elif bulge < 0 and ea > sa:
            ea -= 2.0 * math.pi

        segs = max(6, min(28, int(abs(theta) * 8) + 2))
        arc_pts = []
        prev_w = dxf_to_world(*apply_transform(mat, x1, y1))
        arc_pts.append(prev_w)
        for s in range(1, segs + 1):
            ang = sa + (s / segs) * (ea - sa)
            ax = cx + abs_r * math.cos(ang)
            ay = cy + abs_r * math.sin(ang)
            cur_w = dxf_to_world(*apply_transform(mat, ax, ay))
            add_line(prev_w[0], prev_w[1], cur_w[0], cur_w[1], c_int, lyr)
            arc_pts.append(cur_w)
            prev_w = cur_w
        return arc_pts

    def process_dxf_entity(ent, mat, depth=0, parent_layer='0', parent_color=0xffffff, suppress_attdef=False):
        if depth > 8:
            return
        try:
            if ent.dxf.hasattr('invisible') and ent.dxf.invisible:
                return
        except Exception:
            pass

        etype = ent.dxftype()
        if etype == 'ATTDEF' and suppress_attdef:
            return

        raw_layer = ent.dxf.layer if ent.dxf.hasattr('layer') else '0'
        eff_layer = parent_layer if (raw_layer == '0' and parent_layer != '0') else raw_layer
        if not dxf_layer_visible.get(eff_layer, True):
            return

        c_int = get_dxf_entity_color(ent, eff_layer, parent_color)

        if etype == 'LINE':
            s = ent.dxf.start
            e = ent.dxf.end
            p1 = dxf_to_world(*apply_transform(mat, float(s.x), float(s.y)))
            p2 = dxf_to_world(*apply_transform(mat, float(e.x), float(e.y)))
            add_line(p1[0], p1[1], p2[0], p2[1], c_int, eff_layer)

        elif etype == 'LWPOLYLINE':
            pts = list(ent.get_points('xyb'))
            if len(pts) < 2:
                return
            is_closed = bool(ent.closed)
            count = len(pts) if is_closed else len(pts) - 1
            for i in range(count):
                x1, y1, b1 = pts[i]
                x2, y2, _ = pts[(i + 1) % len(pts)]
                emit_bulge_arc(float(x1), float(y1), float(x2), float(y2), float(b1), mat, c_int, eff_layer)

        elif etype == 'POLYLINE':
            verts = list(ent.vertices)
            if len(verts) < 2:
                return
            is_closed = bool(ent.is_closed)
            count = len(verts) if is_closed else len(verts) - 1
            for i in range(count):
                v1 = verts[i]
                v2 = verts[(i + 1) % len(verts)]
                p1_loc = v1.dxf.location
                p2_loc = v2.dxf.location
                b1 = float(v1.dxf.bulge) if v1.dxf.hasattr('bulge') else 0.0
                emit_bulge_arc(float(p1_loc.x), float(p1_loc.y), float(p2_loc.x), float(p2_loc.y), b1, mat, c_int, eff_layer)

        elif etype == 'CIRCLE':
            center = ent.dxf.center
            cx, cy = float(center.x), float(center.y)
            r = float(ent.dxf.radius)
            if r <= 1e-4:
                return
            segs = max(20, min(48, int(r * 0.6) + 16))
            pts = [
                dxf_to_world(*apply_transform(mat, cx + r * math.cos(2.0 * math.pi * i / segs), cy + r * math.sin(2.0 * math.pi * i / segs)))
                for i in range(segs)
            ]
            for i in range(segs):
                p1 = pts[i]
                p2 = pts[(i + 1) % segs]
                add_line(p1[0], p1[1], p2[0], p2[1], c_int, eff_layer)

        elif etype == 'ARC':
            center = ent.dxf.center
            cx, cy = float(center.x), float(center.y)
            r = float(ent.dxf.radius)
            if r <= 1e-4:
                return
            sa = math.radians(float(ent.dxf.start_angle))
            ea = math.radians(float(ent.dxf.end_angle))
            # OCS Z ekstrüzyon kontrolü (Z = -1 ise açılar aynalanır)
            ocs_z = 1.0
            if ent.dxf.hasattr('extrusion'):
                ocs_z = float(ent.dxf.extrusion.z)
            if ea < sa:
                ea += 2.0 * math.pi
            span = ea - sa
            segs = max(8, min(40, int(span * 10) + 4))
            prev_w = None
            for i in range(segs + 1):
                ang = sa + (i / segs) * span
                lx = cx + r * math.cos(ang) * (-1.0 if ocs_z < 0 else 1.0)
                ly = cy + r * math.sin(ang)
                cur_w = dxf_to_world(*apply_transform(mat, lx, ly))
                if prev_w is not None:
                    add_line(prev_w[0], prev_w[1], cur_w[0], cur_w[1], c_int, eff_layer)
                prev_w = cur_w

        elif etype == 'ELLIPSE':
            center = ent.dxf.center
            cx, cy = float(center.x), float(center.y)
            maj = ent.dxf.major_axis
            mx, my = float(maj.x), float(maj.y)
            maj_len = math.hypot(mx, my)
            if maj_len <= 1e-4:
                return
            ratio = float(ent.dxf.ratio) if ent.dxf.hasattr('ratio') else 1.0
            min_len = maj_len * ratio
            maj_ang = math.atan2(my, mx)
            cos_m = math.cos(maj_ang)
            sin_m = math.sin(maj_ang)
            sp = float(ent.dxf.start_param) if ent.dxf.hasattr('start_param') else 0.0
            ep = float(ent.dxf.end_param) if ent.dxf.hasattr('end_param') else (2.0 * math.pi)
            if ep <= sp:
                ep += 2.0 * math.pi
            segs = 32
            prev_w = None
            for i in range(segs + 1):
                t = sp + (i / segs) * (ep - sp)
                ex = maj_len * math.cos(t)
                ey = min_len * math.sin(t)
                rx = cx + ex * cos_m - ey * sin_m
                ry = cy + ex * sin_m + ey * cos_m
                cur_w = dxf_to_world(*apply_transform(mat, rx, ry))
                if prev_w is not None:
                    add_line(prev_w[0], prev_w[1], cur_w[0], cur_w[1], c_int, eff_layer)
                prev_w = cur_w

        elif etype == 'SPLINE':
            try:
                pts = list(ent.flattening(distance=1.5))
            except Exception:
                pts = list(ent.fit_points) if hasattr(ent, 'fit_points') and len(ent.fit_points) >= 2 else list(ent.control_points)
            if len(pts) >= 2:
                prev_w = dxf_to_world(*apply_transform(mat, float(pts[0][0]), float(pts[0][1])))
                for k in range(1, len(pts)):
                    cur_w = dxf_to_world(*apply_transform(mat, float(pts[k][0]), float(pts[k][1])))
                    add_line(prev_w[0], prev_w[1], cur_w[0], cur_w[1], c_int, eff_layer)
                    prev_w = cur_w

        elif etype in ('SOLID', 'TRACE', '3DFACE'):
            v0 = ent.dxf.vtx0; v1 = ent.dxf.vtx1; v2 = ent.dxf.vtx2
            v3 = ent.dxf.vtx3 if ent.dxf.hasattr('vtx3') else v2
            p0 = dxf_to_world(*apply_transform(mat, float(v0.x), float(v0.y)))
            p1 = dxf_to_world(*apply_transform(mat, float(v1.x), float(v1.y)))
            p2 = dxf_to_world(*apply_transform(mat, float(v2.x), float(v2.y)))
            p3 = dxf_to_world(*apply_transform(mat, float(v3.x), float(v3.y)))
            add_triangle(p0, p1, p2, c_int, eff_layer)
            if abs(v3.x - v2.x) > 1e-4 or abs(v3.y - v2.y) > 1e-4:
                if etype == '3DFACE':
                    add_triangle(p0, p2, p3, c_int, eff_layer)
                else:
                    add_triangle(p1, p3, p2, c_int, eff_layer)

        elif etype in ('LEADER', 'MLEADER'):
            verts = list(ent.vertices) if hasattr(ent, 'vertices') else []
            if len(verts) >= 2:
                w_pts = [dxf_to_world(*apply_transform(mat, float(v[0]), float(v[1]))) for v in verts]
                for k in range(len(w_pts) - 1):
                    add_line(w_pts[k][0], w_pts[k][1], w_pts[k + 1][0], w_pts[k + 1][1], c_int, eff_layer)
                # Ok ucu (Arrowhead)
                dx = w_pts[1][0] - w_pts[0][0]
                dy = w_pts[1][1] - w_pts[0][1]
                l_len = math.hypot(dx, dy)
                if l_len > 1e-3:
                    alen = min(l_len * 0.25, 10.0)
                    ux, uy = dx / l_len, dy / l_len
                    px, py = -uy * (alen * 0.35), ux * (alen * 0.35)
                    bx, by = w_pts[0][0] + ux * alen, w_pts[0][1] + uy * alen
                    add_triangle(w_pts[0], (bx + px, by + py), (bx - px, by - py), c_int, eff_layer)

        elif etype == 'HATCH':
            lyr_low = eff_layer.lower()
            pat = ent.dxf.pattern_name.upper() if ent.dxf.hasattr('pattern_name') else ''
            is_solid = (ent.dxf.solid_fill == 1) if ent.dxf.hasattr('solid_fill') else (pat == 'SOLID')

            is_excluded = any(ex in lyr_low for ex in [
                'temel', 'temal', 'doseme', 'döşeme', 'pafta', 'tarif', 'olcu', 'ölçü',
                'saft', 'şaft', 'aks', 'yazi', 'yazı', 'text', 'donati', 'donatı',
                'demir', 'kot', 'drenaj', 'cati', 'çatı', 'tefris', 'tefriş', 'buhar', 'asansör', 'asansor', 'parapet'
            ])
            is_col = any(k in lyr_low for k in ['kolon', 'column', 'sutun', 'sütun', 'col'])
            is_wall = any(w in lyr_low for w in ['perde', 'kiris', 'kiriş', 'beam', 'wall', 'duvar'])
            is_sec = ('kesit' in lyr_low and 'tarama' in lyr_low)
            is_generic_tar = lyr_low in ['tar', 'tarama']

            if is_wall:
                c_fill = 0xa05252
                c_outline = 0xb85d5d
            elif is_col:
                c_fill = 0x527273
                c_outline = 0x709293
            else:
                c_fill = 0x527273
                c_outline = c_int

            allow_solid_fill = is_solid and not is_excluded and (is_col or is_wall or is_sec or is_generic_tar)

            for path_obj in ent.paths:
                pts = []
                if hasattr(path_obj, 'vertices') and len(path_obj.vertices) >= 3:
                    vlist = path_obj.vertices
                    for idx_v in range(len(vlist)):
                        v1 = vlist[idx_v]
                        v2 = vlist[(idx_v + 1) % len(vlist)]
                        b_val = float(v1[2]) if len(v1) > 2 else 0.0
                        if abs(b_val) > 1e-4:
                            seg_pts = emit_bulge_arc(float(v1[0]), float(v1[1]), float(v2[0]), float(v2[1]), b_val, mat, c_outline, eff_layer)
                            pts.extend(seg_pts[:-1])
                        else:
                            w_p1 = dxf_to_world(*apply_transform(mat, float(v1[0]), float(v1[1])))
                            w_p2 = dxf_to_world(*apply_transform(mat, float(v2[0]), float(v2[1])))
                            add_line(w_p1[0], w_p1[1], w_p2[0], w_p2[1], c_outline, eff_layer)
                            pts.append(w_p1)
                elif hasattr(path_obj, 'edges'):
                    for edge in path_obj.edges:
                        ED_TYPE = type(edge).__name__
                        if ED_TYPE == 'LineEdge' or hasattr(edge, 'start'):
                            s_pt = edge.start; e_pt = edge.end
                            w_p1 = dxf_to_world(*apply_transform(mat, float(s_pt[0]), float(s_pt[1])))
                            w_p2 = dxf_to_world(*apply_transform(mat, float(e_pt[0]), float(e_pt[1])))
                            add_line(w_p1[0], w_p1[1], w_p2[0], w_p2[1], c_outline, eff_layer)
                            pts.append(w_p1)
                        elif ED_TYPE == 'ArcEdge' or hasattr(edge, 'center'):
                            c_pt = edge.center
                            rad_e = float(edge.radius)
                            sa_e = math.radians(float(edge.start_angle))
                            ea_e = math.radians(float(edge.end_angle))
                            ccw_e = bool(getattr(edge, 'ccw', True))
                            if ccw_e and ea_e < sa_e:
                                ea_e += 2.0 * math.pi
                            elif not ccw_e and ea_e > sa_e:
                                ea_e -= 2.0 * math.pi
                            prev_e = None
                            for s_i in range(9):
                                a_i = sa_e + (s_i / 8.0) * (ea_e - sa_e)
                                w_pi = dxf_to_world(*apply_transform(mat, float(c_pt[0]) + rad_e * math.cos(a_i), float(c_pt[1]) + rad_e * math.sin(a_i)))
                                pts.append(w_pi)
                                if prev_e is not None:
                                    add_line(prev_e[0], prev_e[1], w_pi[0], w_pi[1], c_outline, eff_layer)
                                prev_e = w_pi

                if allow_solid_fill and len(pts) >= 3:
                    for t1, t2, t3 in triangulate_polygon(pts):
                        add_triangle(t1, t2, t3, c_fill, eff_layer)

        elif etype in ('TEXT', 'MTEXT', 'ATTRIB', 'ATTDEF'):
            if etype in ('ATTRIB', 'ATTDEF') and ent.dxf.hasattr('flags') and (int(ent.dxf.flags) & 1):
                return
            if etype == 'MTEXT':
                raw_val = ent.text if hasattr(ent, 'text') else (ent.dxf.text if ent.dxf.hasattr('text') else '')
                ch_h = float(ent.dxf.char_height) if ent.dxf.hasattr('char_height') else 12.0
                halign = 0
            else:
                raw_val = ent.dxf.text if ent.dxf.hasattr('text') else ''
                ch_h = float(ent.dxf.height) if ent.dxf.hasattr('height') else 12.0
                halign = int(ent.dxf.halign) if ent.dxf.hasattr('halign') else 0

            if not raw_val:
                return

            use_align = (
                etype != 'MTEXT' and halign > 0 and
                ent.dxf.hasattr('align_point') and ent.dxf.align_point is not None and
                (abs(float(ent.dxf.align_point.x)) > 1e-4 or abs(float(ent.dxf.align_point.y)) > 1e-4)
            )
            ins_pt = ent.dxf.align_point if use_align else (ent.dxf.insert if ent.dxf.hasattr('insert') else None)
            if ins_pt is None:
                return

            wx, wy = dxf_to_world(*apply_transform(mat, float(ins_pt.x), float(ins_pt.y)))
            scale_mag = math.hypot(mat[0], mat[1]) or 1.0
            block_rot = math.degrees(math.atan2(mat[1], mat[0]))
            ent_rot = float(ent.dxf.rotation) if ent.dxf.hasattr('rotation') else 0.0
            total_rot = -(ent_rot + block_rot)
            add_text(wx, wy, ch_h * scale_mag, c_int, raw_val, total_rot, eff_layer, halign)

        elif etype == 'DIMENSION':
            bname = ent.dxf.geometry if ent.dxf.hasattr('geometry') else ''
            if bname and bname in block_map:
                blk = block_map[bname]
                for sub_ent in blk:
                    process_dxf_entity(sub_ent, mat, depth + 1, eff_layer, c_int)
            elif ent.dxf.hasattr('text') and ent.dxf.text and ent.dxf.text != '<>' and ent.dxf.hasattr('text_midpoint'):
                mp = ent.dxf.text_midpoint
                wx, wy = dxf_to_world(*apply_transform(mat, float(mp.x), float(mp.y)))
                add_text(wx, wy, 12.0, c_int, ent.dxf.text, 0.0, eff_layer)

        elif etype == 'INSERT':
            # 1. INSERT üzerindeki ATTRIB etiketleri (Aks balonları, kot ve antet yazıları)
            has_attribs = False
            if hasattr(ent, 'attribs') and len(ent.attribs) > 0:
                has_attribs = True
                for attr in ent.attribs:
                    # ATTRIB koordinatları DXF'te zaten dünya/ebeveyn uzayındadır
                    process_dxf_entity(attr, mat, depth + 1, eff_layer, c_int)

            # 2. Blok içeriği (MINSERT satır/sütun çoğaltması dahil)
            bname = ent.dxf.name if ent.dxf.hasattr('name') else ''
            if not bname or bname not in block_map:
                return
            blk = block_map[bname]
            bp = dxf_block_base_pts.get(bname, (0.0, 0.0))
            cols = max(1, int(ent.dxf.column_count) if ent.dxf.hasattr('column_count') else 1)
            rows = max(1, int(ent.dxf.row_count) if ent.dxf.hasattr('row_count') else 1)
            col_sp = float(ent.dxf.column_spacing) if ent.dxf.hasattr('column_spacing') else 0.0
            row_sp = float(ent.dxf.row_spacing) if ent.dxf.hasattr('row_spacing') else 0.0

            for r_idx in range(rows):
                for c_idx in range(cols):
                    ins_mat = make_insert_matrix(ent, bp, c_idx * col_sp, r_idx * row_sp)
                    comb_mat = multiply_matrices(mat, ins_mat)
                    for sub_ent in blk:
                        process_dxf_entity(sub_ent, comb_mat, depth + 1, eff_layer, c_int, suppress_attdef=has_attribs)

    root_mat = identity_matrix()
    for entity in msp:
        try:
            process_dxf_entity(entity, root_mat, depth=0)
        except Exception:
            pass

# Çalıştır: Önce doğrudan DXF motorunu dene
used_direct_dxf = False
if dxf_doc is not None:
    print(f"Running Direct High-Fidelity DXF Vector Engine on {dxf_candidate}...")
    extract_directly_from_dxf(dxf_doc)
    if len(lines_data) >= 50:
        used_direct_dxf = True
        print(f"Direct DXF Engine succeeded: {len(lines_data)//5} lines, {len(triangles_data)//7} triangles, {len(texts_data)} texts.")

# YEDEK (FALLBACK) MOTOR: Eğer DXF yoksa veya boşsa kalibre edilmiş SVG + DXF hibrit motorunu çalıştır
if not used_direct_dxf and os.path.exists(svg_path):
    print(f"Fallback: Reading SVG {svg_path}...")
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

    def parse_transform(trans_str, invert_rotate=False):
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
                if invert_rotate:
                    deg = -deg
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

    def arc_to_segments(x1, y1, rx, ry, phi_deg, large_arc, sweep, x2, y2, num_segs=16):
        if (abs(x1 - x2) < 1e-4 and abs(y1 - y2) < 1e-4) or rx <= 0 or ry <= 0:
            return []
        chord = math.hypot(x2 - x1, y2 - y1)
        if chord < 1e-3 or rx > 1e7:
            return [(x1, y1, x2, y2)]
        rx = abs(rx); ry = abs(ry)
        phi = math.radians(phi_deg % 360.0)
        cos_phi = math.cos(phi); sin_phi = math.sin(phi)
        dx2 = (x1 - x2) / 2.0; dy2 = (y1 - y2) / 2.0
        x1p = cos_phi * dx2 + sin_phi * dy2
        y1p = -sin_phi * dx2 + cos_phi * dy2
        lam = (x1p ** 2) / (rx ** 2) + (y1p ** 2) / (ry ** 2)
        if lam > 1.0:
            sqrt_lam = math.sqrt(lam)
            rx *= sqrt_lam; ry *= sqrt_lam
        rx2 = rx ** 2; ry2 = ry ** 2; x1p2 = x1p ** 2; y1p2 = y1p ** 2
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
        ux = (x1p - cxp) / rx; uy = (y1p - cyp) / ry
        vx = (-x1p - cxp) / rx; vy = (-y1p - cyp) / ry
        theta1 = vec_angle(1.0, 0.0, ux, uy)
        dtheta = vec_angle(ux, uy, vx, vy)
        if not sweep and dtheta > 0:
            dtheta -= 2.0 * math.pi
        elif sweep and dtheta < 0:
            dtheta += 2.0 * math.pi
        if not large_arc and abs(dtheta) > math.pi + 1e-3:
            dtheta = dtheta - 2.0 * math.pi if dtheta > 0 else dtheta + 2.0 * math.pi
        steps = max(6, min(num_segs, int(abs(dtheta) * 8) + 4))
        segs = []
        px, py = x1, y1
        for s in range(1, steps + 1):
            t = theta1 + (s / steps) * dtheta
            ct = math.cos(t); st = math.sin(t)
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
                else:
                    i += 1
            except (IndexError, ValueError):
                break

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
            pts = [apply_transform(current_mat, cx + r * math.cos(2 * math.pi * i / 24), cy + r * math.sin(2 * math.pi * i / 24)) for i in range(24)]
            for i in range(24):
                add_line(pts[i][0], pts[i][1], pts[(i + 1) % 24][0], pts[(i + 1) % 24][1], c_int)
        for m in re.finditer(r'<text[^>]+x="([^"]+)"\s+y="([^"]+)"[^>]*font-size="([^"]+)"[^>]*fill="([^"]+)"[^>]*>([^<]+)</text>', content):
            x = float(m.group(1)); y = float(m.group(2)); size = float(m.group(3))
            fill = m.group(4); raw_t = m.group(5).strip()
            wx, wy = apply_transform(current_mat, x, y)
            add_text(wx, wy, size * scale_mag, fill, raw_t, base_rot)

    process_elements(model_part, identity_matrix())

    sym_min_x = []; sym_max_y = []
    for sm in re.finditer(r'<g\s+id="symbol-[^"]+"[^>]*>(.*?)</g>', defs_part, re.DOTALL):
        pts = [(float(xm.group(1)), float(xm.group(2))) for xm in re.finditer(r'([+-]?\d+\.\d+),([+-]?\d+\.\d+)', sm.group(1))]
        if len(pts) >= 4:
            sym_min_x.append(round(min(p[0] for p in pts), 0))
            sym_max_y.append(round(max(p[1] for p in pts), 0))
    BASE_X = float(Counter(sym_min_x).most_common(1)[0][0]) if sym_min_x else 0.0
    BASE_Y = float(Counter(sym_max_y).most_common(1)[0][0]) if sym_max_y else 0.0

    symbols = {}
    for m in re.finditer(r'<g\s+id="([^"]+)"([^>]*)>(.*?)</g>', defs_part, re.DOTALL):
        sid = m.group(1); body = m.group(3)
        symbols[sid] = {'shift_mat': [1.0, 0.0, 0.0, 1.0, -BASE_X, -BASE_Y], 'body': body}

    def render_symbol(sid, current_mat, depth=0):
        if depth > 8 or sid not in symbols:
            return
        sym = symbols[sid]
        elem_mat = multiply_matrices(current_mat, sym['shift_mat'])
        process_elements(sym['body'], elem_mat)
        for child_m in re.finditer(r'<use\s+([^>]+)>', sym['body']):
            c_attrs = child_m.group(1)
            href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', c_attrs)
            if not href_m or href_m.group(1) not in symbols:
                continue
            t_m = re.search(r'transform="([^"]+)"', c_attrs)
            child_mat = multiply_matrices(elem_mat, parse_transform(t_m.group(1) if t_m else "", invert_rotate=True))
            render_symbol(href_m.group(1), child_mat, depth + 1)

    for m in re.finditer(r'<use\s+([^>]+)>', model_part):
        tag_attrs = m.group(1)
        href_m = re.search(r'(?:xlink:href|href)="#([^"]+)"', tag_attrs)
        if not href_m or href_m.group(1) not in symbols:
            continue
        t_m = re.search(r'transform="([^"]+)"', tag_attrs)
        use_mat = parse_transform(t_m.group(1) if t_m else "", invert_rotate=True)
        render_symbol(href_m.group(1), use_mat, depth=0)

# Aykırı Koordinat Filtresi (Outlier Rejection) ve Sıkı Pafta Sınırı (Tight Sheet Bounds)
bounds = {'minX': 0.0, 'minY': 0.0, 'w': 1000.0, 'h': 1000.0}
if lines_data:
    arr_all = np.array(lines_data, dtype=np.float64).reshape(-1, 5)
    all_x = np.concatenate([arr_all[:, 0], arr_all[:, 2]])
    all_y = np.concatenate([arr_all[:, 1], arr_all[:, 3]])

    q_min_x, q_max_x = np.percentile(all_x, [2.0, 98.0])
    q_min_y, q_max_y = np.percentile(all_y, [2.0, 98.0])
    span_x = max(float(q_max_x - q_min_x), 5000.0)
    span_y = max(float(q_max_y - q_min_y), 5000.0)

    valid_min_x = float(q_min_x) - max(span_x * 1.5, 100000.0)
    valid_max_x = float(q_max_x) + max(span_x * 1.5, 100000.0)
    valid_min_y = float(q_min_y) - max(span_y * 2.0, 80000.0)
    valid_max_y = float(q_max_y) + max(span_y * 2.0, 80000.0)

    mask = (
        (arr_all[:, 0] >= valid_min_x) & (arr_all[:, 0] <= valid_max_x) &
        (arr_all[:, 1] >= valid_min_y) & (arr_all[:, 1] <= valid_max_y) &
        (arr_all[:, 2] >= valid_min_x) & (arr_all[:, 2] <= valid_max_x) &
        (arr_all[:, 3] >= valid_min_y) & (arr_all[:, 3] <= valid_max_y)
    )
    kept = arr_all[mask]
    if len(kept) > 0:
        if len(kept) < len(arr_all):
            print(f"Filtered {len(arr_all) - len(kept)} extreme outlier line segments.")
            lines_data = []
            for row in kept:
                lines_data.extend([round(float(row[0]), 1), round(float(row[1]), 1), round(float(row[2]), 1), round(float(row[3]), 1), int(row[4])])

        real_min_x = float(np.min(np.concatenate([kept[:, 0], kept[:, 2]])))
        real_max_x = float(np.max(np.concatenate([kept[:, 0], kept[:, 2]])))
        real_min_y = float(np.min(np.concatenate([kept[:, 1], kept[:, 3]])))
        real_max_y = float(np.max(np.concatenate([kept[:, 1], kept[:, 3]])))

        bounds = {
            'minX': round(real_min_x, 2),
            'minY': round(real_min_y, 2),
            'w': round(max(real_max_x - real_min_x, 100.0), 2),
            'h': round(max(real_max_y - real_min_y, 100.0), 2)
        }
        print(f"Computed tight sheet bounds: {bounds}")

        if triangles_data:
            tri_arr = np.array(triangles_data, dtype=np.float64).reshape(-1, 7)
            t_mask = (
                (tri_arr[:, 0] >= valid_min_x) & (tri_arr[:, 0] <= valid_max_x) &
                (tri_arr[:, 1] >= valid_min_y) & (tri_arr[:, 1] <= valid_max_y)
            )
            if not np.all(t_mask):
                kept_t = tri_arr[t_mask]
                triangles_data = []
                for r in kept_t:
                    triangles_data.extend([round(float(r[0]), 1), round(float(r[1]), 1), round(float(r[2]), 1), round(float(r[3]), 1), round(float(r[4]), 1), round(float(r[5]), 1), int(r[6])])

        texts_data = [
            t for t in texts_data
            if valid_min_x <= t['x'] <= valid_max_x and valid_min_y <= t['y'] <= valid_max_y
        ]

# Katman (Layer) özet listesi
layers_list = [
    {
        'name': lname,
        'color': dxf_layer_colors.get(lname, 0xffffff),
        'count': int(cnt),
        'visible': True
    }
    for lname, cnt in layer_counts.most_common()
    if cnt > 0
]

total_lines_count = len(lines_data) // 5
total_triangles_count = len(triangles_data) // 7
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

# High-Performance Binary Buffers (Zero-Copy WebGL Loading for both Lines and Triangles)
try:
    if 'cad_data.json' in out_json:
        out_meta = out_json.replace('cad_data.json', 'cad_meta.json')
        out_bin = out_json.replace('cad_data.json', 'cad_vertices.bin')
        out_tri_bin = out_json.replace('cad_data.json', 'cad_triangles.bin')
    else:
        out_meta = out_json.replace('.json', '_meta.json')
        out_bin = out_json.replace('.json', '_vertices.bin')
        out_tri_bin = out_json.replace('.json', '_triangles.bin')
        alt_meta = out_json.replace('_cad_data.json', '_cad_meta.json')
        alt_bin = out_json.replace('_cad_data.json', '_cad_vertices.bin')
        alt_tri_bin = out_json.replace('_cad_data.json', '_cad_triangles.bin')

    out_meta_gz = out_meta + '.gz'
    out_bin_gz = out_bin + '.gz'
    out_tri_bin_gz = out_tri_bin + '.gz'

    meta_payload = {
        'bounds': bounds,
        'insunits': insunits,
        'metersPerUnit': meters_per_unit,
        'totalLines': total_lines_count,
        'totalTriangles': total_triangles_count,
        'hasBinaryTriangles': total_triangles_count > 0,
        'layers': layers_list,
        'triangles': triangles_data,
        'texts': texts_data
    }
    with open(out_meta, 'w', encoding='utf-8') as f:
        json.dump(meta_payload, f)
    with open(out_meta, 'rb') as f_in, gzip.open(out_meta_gz, 'wb', compresslevel=6) as f_out:
        f_out.writelines(f_in)

    if 'alt_meta' in locals() and alt_meta not in (out_meta, out_json):
        try:
            with open(alt_meta, 'w', encoding='utf-8') as f:
                json.dump(meta_payload, f)
            with open(alt_meta, 'rb') as f_in, gzip.open(alt_meta + '.gz', 'wb', compresslevel=6) as f_out:
                f_out.writelines(f_in)
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

        if 'alt_bin' in locals() and alt_bin not in (out_bin, out_json):
            try:
                vertices.tofile(alt_bin)
                with open(alt_bin, 'rb') as f_in, gzip.open(alt_bin + '.gz', 'wb', compresslevel=6) as f_out:
                    f_out.write(f_in.read())
            except Exception:
                pass

    if triangles_data:
        t_arr = np.array(triangles_data, dtype=np.float32).reshape(-1, 7)
        tx1 = t_arr[:, 0]; ty1 = t_arr[:, 1]
        tx2 = t_arr[:, 2]; ty2 = t_arr[:, 3]
        tx3 = t_arr[:, 4]; ty3 = t_arr[:, 5]
        tc = t_arr[:, 6].astype(np.uint32)
        tr = ((tc >> 16) & 255).astype(np.float32) / 255.0
        tg = ((tc >> 8) & 255).astype(np.float32) / 255.0
        tb = (tc & 255).astype(np.float32) / 255.0
        tv1 = np.column_stack([tx1, ty1, tr, tg, tb])
        tv2 = np.column_stack([tx2, ty2, tr, tg, tb])
        tv3 = np.column_stack([tx3, ty3, tr, tg, tb])
        t_vertices = np.empty((len(t_arr) * 3, 5), dtype=np.float32)
        t_vertices[0::3] = tv1
        t_vertices[1::3] = tv2
        t_vertices[2::3] = tv3
        t_vertices.tofile(out_tri_bin)
        with open(out_tri_bin, 'rb') as f_in, gzip.open(out_tri_bin_gz, 'wb', compresslevel=6) as f_out:
            f_out.write(f_in.read())

        if 'alt_tri_bin' in locals() and alt_tri_bin not in (out_tri_bin, out_json):
            try:
                t_vertices.tofile(alt_tri_bin)
                with open(alt_tri_bin, 'rb') as f_in, gzip.open(alt_tri_bin + '.gz', 'wb', compresslevel=6) as f_out:
                    f_out.write(f_in.read())
            except Exception:
                pass

    bin_sz = os.path.getsize(out_bin) if os.path.exists(out_bin) else 0
    bin_gz_sz = os.path.getsize(out_bin_gz) if os.path.exists(out_bin_gz) else 0
    print(f"High-Speed Binary created: Raw {bin_sz / (1024 * 1024):.2f} MB, Gzip {bin_gz_sz / (1024 * 1024):.2f} MB")
except Exception as e:
    print(f"Binary export error: {e}")

sz = os.path.getsize(out_json)
sz_gz = os.path.getsize(out_gz)
print(f"SUCCESS in {time.time() - t0:.2f}s! Raw JSON: {sz / (1024 * 1024):.2f} MB, Gzip: {sz_gz / (1024 * 1024):.2f} MB")
