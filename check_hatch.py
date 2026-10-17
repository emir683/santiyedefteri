import ezdxf

doc = ezdxf.readfile("/home/ubuntu/cad-service/uploads/bc00f9c7-d593-49d7-9f4e-ceefb57f27b8.dxf")
msp = doc.modelspace()
msp_hatches = list(msp.query("HATCH"))
print(f"MSP Hatches: {len(msp_hatches)}")

block_hatches = []
for b in doc.blocks:
    if b.name.startswith('*'): continue # skip model/paper space blocks
    bh = list(b.query("HATCH"))
    if bh:
        print(f"Block '{b.name}' has {len(bh)} hatches")
        block_hatches.extend(bh)

print(f"Total Block Hatches: {len(block_hatches)}")
