import sys
import time
import json
import ezdxf
import numpy as np

if len(sys.argv) < 3:
    print("Usage: python3 dxf_pipeline.py <input.dxf> <output.json>")
    sys.exit(1)

dxf_path = sys.argv[1]
out_json = sys.argv[2]

t0 = time.time()
print(f"Loading {dxf_path} with ezdxf...")

doc = ezdxf.readfile(dxf_path)
msp = doc.modelspace()
print(f"Loaded in {time.time() - t0:.2f}s. ModelSpace entities: {len(msp)}")

# ACI Colors to RGB integer
ACI_COLORS = {
    1: 0xff3b30,   # Red
    2: 0xffe600,   # Yellow
    3: 0x22c55e,   # Green
    4: 0x00f0ff,   # Cyan
    5: 0x38bdf8,   # Blue
    6: 0xff2d55,   # Magenta
    7: 0xffffff,   # White
    8: 0x94a3b8,   # Dark Grey
    9: 0xcfd8dc,   # Light Grey
}

def get_color(entity):
    c = entity.dxf.color if entity.dxf.hasattr('color') else 256
    if c == 256 or c == 0:  # ByLayer or ByBlock
        try:
            layer = doc.layers.get(entity.dxf.layer)
            c = layer.dxf.color
        except:
            c = 7
    return ACI_COLORS.get(c, 0xffffff)

raw_lines = [] # [(x1, y1, x2, y2, color), ...]
raw_texts = [] # [(x, y, s, color, text), ...]

def add_line(x1, y1, x2, y2, color):
    # Ignore invalid / NaN
    if not (np.isfinite(x1) and np.isfinite(y1) and np.isfinite(x2) and np.isfinite(y2)):
        return
    raw_lines.append((round(x1, 2), round(y1, 2), round(x2, 2), round(y2, 2), color))

def process_entity(e):
    dxftype = e.dxftype()
    color = get_color(e)
    
    if dxftype == 'LINE':
        start = e.dxf.start
        end = e.dxf.end
        add_line(start.x, start.y, end.x, end.y, color)
        
    elif dxftype == 'LWPOLYLINE':
        points = list(e.get_points(format='xy'))
        closed = e.is_closed
        for i in range(len(points) - 1):
            add_line(points[i][0], points[i][1], points[i+1][0], points[i+1][1], color)
        if closed and len(points) > 2:
            add_line(points[-1][0], points[-1][1], points[0][0], points[0][1], color)
            
    elif dxftype == 'POLYLINE':
        points = [v.dxf.location for v in e.vertices]
        for i in range(len(points) - 1):
            add_line(points[i].x, points[i].y, points[i+1].x, points[i+1].y, color)
        if e.is_closed and len(points) > 2:
            add_line(points[-1].x, points[-1].y, points[0].x, points[0].y, color)
            
    elif dxftype in ('CIRCLE', 'ARC'):
        center = e.dxf.center
        r = e.dxf.radius
        start_angle = e.dxf.start_angle if dxftype == 'ARC' else 0.0
        end_angle = e.dxf.end_angle if dxftype == 'ARC' else 360.0
        if end_angle < start_angle:
            end_angle += 360.0
            
        steps = max(12, int(abs(end_angle - start_angle) / 15.0))
        angles = np.linspace(np.radians(start_angle), np.radians(end_angle), steps)
        pts = [(center.x + r * np.cos(a), center.y + r * np.sin(a)) for a in angles]
        for i in range(len(pts) - 1):
            add_line(pts[i][0], pts[i][1], pts[i+1][0], pts[i+1][1], color)
            
    elif dxftype in ('TEXT', 'MTEXT'):
        text_str = e.plain_text() if hasattr(e, 'plain_text') else (e.dxf.text if e.dxf.hasattr('text') else '')
        if text_str and text_str.strip():
            insert = e.dxf.insert
            height = e.dxf.height if e.dxf.hasattr('height') else 20.0
            raw_texts.append((
                round(insert.x, 2),
                round(insert.y, 2),
                round(height, 2),
                color,
                text_str.strip()
            ))
            
    elif dxftype == 'INSERT':
        try:
            for sub_e in e.virtual_entities():
                process_entity(sub_e)
        except Exception:
            pass

print("Extracting entities...")
for entity in msp:
    process_entity(entity)

print(f"Extracted {len(raw_lines)} raw lines and {len(raw_texts)} texts in {time.time() - t0:.2f}s!")

# Outlier rejection and bounding box computation
if raw_lines:
    all_xs = np.array([l[0] for l in raw_lines] + [l[2] for l in raw_lines])
    all_ys = np.array([l[1] for l in raw_lines] + [l[3] for l in raw_lines])
    
    # Use 1.0% and 99.5% to find true architectural bounding box
    p_min_x = float(np.percentile(all_xs, 1.0))
    p_max_x = float(np.percentile(all_xs, 99.5))
    p_min_y = float(np.percentile(all_ys, 1.0))
    p_max_y = float(np.percentile(all_ys, 99.5))
    
    span_x = p_max_x - p_min_x
    span_y = p_max_y - p_min_y
    
    # Allowed zone: entities within 50% margin of the main cluster
    margin_x = max(span_x * 0.5, 5000)
    margin_y = max(span_y * 0.5, 5000)
    
    valid_min_x = p_min_x - margin_x
    valid_max_x = p_max_x + margin_x
    valid_min_y = p_min_y - margin_y
    valid_max_y = p_max_y + margin_y
    
    # Filter lines
    filtered_lines = []
    final_xs = []
    final_ys = []
    for l in raw_lines:
        if valid_min_x <= l[0] <= valid_max_x and valid_min_y <= l[1] <= valid_max_y:
            filtered_lines.extend([l[0], l[1], l[2], l[3], l[4]])
            final_xs.extend([l[0], l[2]])
            final_ys.extend([l[1], l[3]])
            
    # Filter texts
    filtered_texts = []
    for t in raw_texts:
        if valid_min_x <= t[0] <= valid_max_x and valid_min_y <= t[1] <= valid_max_y:
            filtered_texts.append({
                'x': t[0],
                'y': t[1],
                's': t[2],
                'c': f"#{t[3]:06x}",
                't': t[4]
            })
            
    if final_xs and final_ys:
        true_min_x = float(min(final_xs))
        true_max_x = float(max(final_xs))
        true_min_y = float(min(final_ys))
        true_max_y = float(max(final_ys))
        bounds = {
            'minX': round(true_min_x, 1),
            'minY': round(true_min_y, 1),
            'w': round(true_max_x - true_min_x, 1),
            'h': round(true_max_y - true_min_y, 1)
        }
    else:
        bounds = {'minX': round(p_min_x, 1), 'minY': round(p_min_y, 1), 'w': round(span_x, 1), 'h': round(span_y, 1)}
else:
    filtered_lines = []
    filtered_texts = []
    bounds = {'minX': 0, 'minY': 0, 'w': 1000, 'h': 1000}

print("Final Bounds:", bounds)
print(f"Final Lines: {len(filtered_lines)//5}, Final Texts: {len(filtered_texts)}")

with open(out_json, 'w', encoding='utf-8') as f:
    json.dump({'bounds': bounds, 'lines': filtered_lines, 'texts': filtered_texts}, f)

print(f"Saved to {out_json} successfully in {time.time() - t0:.2f}s!")
