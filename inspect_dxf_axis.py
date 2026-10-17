import ezdxf

# Let's inspect the DWG/DXF
dxf_path = '/home/ubuntu/cad-service/uploads/test_dxf.dxf'
doc = ezdxf.readfile(dxf_path)
msp = doc.modelspace()

print("Searching entities on Axis C (X ~ 93620)...")
# Let's search all LINE entities with X near 93620
near_lines = []
for e in msp.query('LINE'):
    start = e.dxf.start
    end = e.dxf.end
    if (abs(start.x - 93620) < 10 or abs(end.x - 93620) < 10) and (11000 <= start.y <= 12500 or 11000 <= end.y <= 12500):
        near_lines.append(e)

print(f"Found {len(near_lines)} lines in DXF:")
for line in near_lines[:15]:
    start = line.dxf.start
    end = line.dxf.end
    layer = line.dxf.layer
    color = line.dxf.color
    linetype = line.dxf.linetype
    print(f"  Line: ({start.x:.1f}, {start.y:.1f}) -> ({end.x:.1f}, {end.y:.1f}) | layer='{layer}', color={color}, linetype='{linetype}'")

# Check layers table
print("\nLayers in DXF:")
for lay in doc.layers:
    print(f"  Layer: '{lay.dxf.name}', color={lay.dxf.color}, linetype='{lay.dxf.linetype}'")
