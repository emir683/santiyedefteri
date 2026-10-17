import ezdxf

doc = ezdxf.readfile('/tmp/test_5fe.dxf')
msp = doc.modelspace()

print("Searching for blocks with ANTET or sheet frames...")
for b in doc.blocks:
    if 'ANTET' in b.name.upper() or 'PAFTA' in b.name.upper():
        print(f"Block def: {b.name}, entities: {len(b)}")

inserts = [e for e in msp if e.dxftype() == 'INSERT']
print(f"Total inserts: {len(inserts)}")

# Print all inserts and their positions
antet_inserts = []
for e in inserts:
    name = e.dxf.name.upper()
    # Check bounding box of virtual entities if possible
    try:
        pts = []
        for ve in e.virtual_entities():
            if ve.dxftype() == 'LWPOLYLINE':
                pts.extend(ve.get_points(format='xy'))
            elif ve.dxftype() == 'LINE':
                pts.extend([(ve.dxf.start.x, ve.dxf.start.y), (ve.dxf.end.x, ve.dxf.end.y)])
        if pts:
            min_x = min(p[0] for p in pts)
            max_x = max(p[0] for p in pts)
            min_y = min(p[1] for p in pts)
            max_y = max(p[1] for p in pts)
            w = max_x - min_x
            h = max_y - min_y
            if w > 8000 and h > 4000:
                antet_inserts.append((e.dxf.name, min_x, min_y, max_x, max_y, w, h))
    except:
        pass

print(f"Large block inserts ({len(antet_inserts)}):")
antet_inserts.sort(key=lambda s: (s[2], s[1]))
for b in antet_inserts:
    print(f"  {b[0]}: X=[{b[1]:.1f}, {b[3]:.1f}], Y=[{b[2]:.1f}, {b[4]:.1f}], W={b[5]:.1f}, H={b[6]:.1f}")
