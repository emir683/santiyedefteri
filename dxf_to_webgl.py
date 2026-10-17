import ezdxf
import time
import json
import numpy as np

t0 = time.time()
dxf_path = '/tmp/test_5fe.dxf'
print(f"Loading {dxf_path} with ezdxf...")

doc = ezdxf.readfile(dxf_path)
msp = doc.modelspace()
print(f"Loaded in {time.time() - t0:.2f}s. Total entities in ModelSpace: {len(msp)}")

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
        # Check layer color
        try:
            layer = doc.layers.get(entity.dxf.layer)
            c = layer.dxf.color
        except:
            c = 7
    return ACI_COLORS.get(c, 0xffffff)

lines_data = [] # [x1, y1, x2, y2, color, ...]
texts_data = [] # [{x, y, s, c, t}, ...]

def add_line(x1, y1, x2, y2, color):
    lines_data.extend([round(x1, 2), round(y1, 2), round(x2, 2), round(y2, 2), color])

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
            add_line(points[-1][0], points[-1][0], points[0][0], points[0][1], color)
            
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
            texts_data.append({
                'x': round(insert.x, 2),
                'y': round(insert.y, 2),
                's': round(height, 2),
                'c': f"#{color:06x}",
                't': text_str.strip()
            })
            
    elif dxftype == 'INSERT':
        try:
            for sub_e in e.virtual_entities():
                process_entity(sub_e)
        except Exception as err:
            pass

print("Extracting entities and expanding blocks...")
for entity in msp:
    process_entity(entity)

print(f"Extraction done in {time.time() - t0:.2f}s!")
print(f"Total Lines: {len(lines_data)//5}")
print(f"Total Texts: {len(texts_data)}")

# Coordinates and bounds
xs = [lines_data[i] for i in range(0, len(lines_data), 5)]
ys = [lines_data[i+1] for i in range(0, len(lines_data), 5)]

if xs and ys:
    xs_arr = np.array(xs)
    ys_arr = np.array(ys)
    
    # 99.5% Density filter to remove extreme single-point survey markers if any:
    p_min_x = float(np.percentile(xs_arr, 0.5))
    p_max_x = float(np.percentile(xs_arr, 99.5))
    p_min_y = float(np.percentile(ys_arr, 0.5))
    p_max_y = float(np.percentile(ys_arr, 99.5))
    
    bounds = {
        'minX': round(p_min_x, 1),
        'minY': round(p_min_y, 1),
        'w': round(p_max_x - p_min_x, 1),
        'h': round(p_max_y - p_min_y, 1)
    }
else:
    bounds = {'minX': 0, 'minY': 0, 'w': 1000, 'h': 1000}

print("Bounds:", bounds)

out_json = '/home/ubuntu/cad-service/uploads/5fe1b241-24de-4e1e-aada-f0bf681dfe09_cad_data.json'
with open(out_json, 'w', encoding='utf-8') as f:
    json.dump({'bounds': bounds, 'lines': lines_data, 'texts': texts_data}, f)

print(f"Saved to {out_json} successfully!")
