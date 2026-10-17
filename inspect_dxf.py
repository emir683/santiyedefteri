import ezdxf

doc = ezdxf.readfile('/tmp/test_5fe.dxf')
print("Layouts:")
for l in doc.layouts:
    print(f"  {l.name}: {len(l)} entities")

msp = doc.modelspace()
print(f"Modelspace: {len(msp)} entities")

# Let's inspect bounding boxes of entities in modelspace
inserts = [e for e in msp if e.dxftype() == 'INSERT']
print(f"Total INSERT blocks in modelspace: {len(inserts)}")
block_names = set(e.dxf.name for e in inserts)
print(f"Unique block names: {len(block_names)}")
for b in sorted(list(block_names))[:20]:
    print(f"  Block: {b}")

# Inspect coordinates of entities
xs = []
ys = []
for e in msp:
    if e.dxftype() == 'INSERT':
        xs.append(e.dxf.insert.x)
        ys.append(e.dxf.insert.y)

print(f"Insert X range: min={min(xs):.1f}, max={max(xs):.1f}")
print(f"Insert Y range: min={min(ys):.1f}, max={max(ys):.1f}")
