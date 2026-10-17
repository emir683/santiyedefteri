import sys
import ezdxf

dxf_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/test_5fe.dxf'
print(f"Reading {dxf_file}...")
doc = ezdxf.readfile(dxf_file)
msp = doc.modelspace()
print(f"Entities: {len(msp)}")

xs = []
ys = []
for e in msp:
    dxftype = e.dxftype()
    if dxftype == 'INSERT':
        xs.append(e.dxf.insert.x)
        ys.append(e.dxf.insert.y)
    elif dxftype == 'LINE':
        xs.extend([e.dxf.start.x, e.dxf.end.x])
        ys.extend([e.dxf.start.y, e.dxf.end.y])

if xs:
    print(f"X: {min(xs):.1f} to {max(xs):.1f}")
    print(f"Y: {min(ys):.1f} to {max(ys):.1f}")

# Group by pafta/sheets
import numpy as np
xs_arr = np.array(xs)
print("X percentiles [1%, 5%, 50%, 95%, 99%]:", np.percentile(xs_arr, [1, 5, 50, 95, 99]))
