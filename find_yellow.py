import ezdxf

doc = ezdxf.readfile('/tmp/test_5fe.dxf')
msp = doc.modelspace()

print("Searching for YELLOW entities and sheet frames...")
yellow_boxes = []

for e in msp:
    color = e.dxf.color if e.dxf.hasattr('color') else 256
    if color == 256:
        try:
            color = doc.layers.get(e.dxf.layer).dxf.color
        except:
            color = 7
    if color == 2:  # YELLOW
        if e.dxftype() == 'LWPOLYLINE':
            pts = list(e.get_points(format='xy'))
            if len(pts) in (4, 5) and e.is_closed:
                w = max(p[0] for p in pts) - min(p[0] for p in pts)
                h = max(p[1] for p in pts) - min(p[1] for p in pts)
                if w > 3000 and h > 1000:
                    yellow_boxes.append((min(p[0] for p in pts), min(p[1] for p in pts), w, h, e.dxf.layer))

print(f"Yellow closed polyline boxes: {len(yellow_boxes)}")
yellow_boxes.sort(key=lambda b: (b[1], b[0]))
for b in yellow_boxes:
    print(f"  Box: X={b[0]:.1f}, Y={b[1]:.1f}, W={b[2]:.1f}, H={b[3]:.1f}, Layer={b[4]}")
