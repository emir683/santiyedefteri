import ezdxf

doc = ezdxf.readfile('/tmp/test_5fe.dxf')
msp = doc.modelspace()

print("Searching for sheet borders and paftas in /tmp/test_5fe.dxf...")

# Look for large polylines or inserts that represent sheets
sheets = []
for e in msp:
    if e.dxftype() == 'LWPOLYLINE':
        pts = list(e.get_points(format='xy'))
        if len(pts) in (4, 5) and e.is_closed:
            min_x = min(p[0] for p in pts)
            max_x = max(p[0] for p in pts)
            min_y = min(p[1] for p in pts)
            max_y = max(p[1] for p in pts)
            w = max_x - min_x
            h = max_y - min_y
            if 10000 < w < 40000 and 5000 < h < 30000:
                sheets.append((min_x, min_y, max_x, max_y, w, h, e.dxf.layer))

print(f"Found {len(sheets)} sheet-like rectangles:")
# Sort by X then Y
sheets.sort(key=lambda s: (s[1], s[0]))
for i, s in enumerate(sheets):
    print(f"  Sheet {i+1}: X=[{s[0]:.1f}, {s[2]:.1f}], Y=[{s[1]:.1f}, {s[3]:.1f}], W={s[4]:.1f}, H={s[5]:.1f}, Layer={s[6]}")
