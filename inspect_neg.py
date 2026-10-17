import ezdxf

doc = ezdxf.readfile('/tmp/bahar.dxf')
msp = doc.modelspace()
neg_inserts = [e for e in msp if e.dxftype() == 'INSERT' and e.dxf.insert.x < 0]
print(f"Negative X inserts: {len(neg_inserts)}")
for e in neg_inserts[:10]:
    print(f"  {e.dxf.name}: X={e.dxf.insert.x:.1f}, Y={e.dxf.insert.y:.1f}")

pos_inserts = [e for e in msp if e.dxftype() == 'INSERT' and e.dxf.insert.x >= 0]
print(f"Positive X inserts: {len(pos_inserts)}")
print(f"Positive X range: {min(e.dxf.insert.x for e in pos_inserts):.1f} to {max(e.dxf.insert.x for e in pos_inserts):.1f}")
