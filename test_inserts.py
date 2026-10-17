import ezdxf

doc = ezdxf.readfile("/home/ubuntu/cad-service/uploads/bc00f9c7-d593-49d7-9f4e-ceefb57f27b8.dxf")
msp = doc.modelspace()

BASE_X = 47599.4
BASE_Y = -28187.4

def to_svg(x, y):
    return (x + BASE_X, -y + BASE_Y)

msp_in_view = 0
for h in msp.query("HATCH"):
    layer = h.dxf.layer.lower() if h.dxf.hasattr('layer') else ''
    for p in h.paths:
        pts = []
        if hasattr(p, 'vertices'): pts = [(v[0], v[1]) for v in p.vertices]
        elif hasattr(p, 'edges'):
            for e in p.edges:
                if hasattr(e, 'start'): pts.append((e.start[0], e.start[1]))
        if not pts: continue
        svg_pts = [to_svg(pt[0], pt[1]) for pt in pts]
        avg_x = sum(p[0] for p in svg_pts) / len(svg_pts)
        avg_y = sum(p[1] for p in svg_pts) / len(svg_pts)
        if 16000 <= avg_x <= 23000 and 1500 <= avg_y <= 6000:
            msp_in_view += 1
            print(f"MSP Hatch in view! Layer: {layer:20} at SVG ({avg_x:.1f}, {avg_y:.1f})")

print(f"Total MSP hatches in user view: {msp_in_view}")
