import subprocess

# Convert PDF points at (4300, 3000)
# viewBox: -3995.78 -709.16 207780.37 15601.60
# width: 24000, height: 1704
x = 4300.0
y = 3000.0

pt_x = (x - (-3995.78)) * (24000.0 / 207780.37)
pt_y = (y - (-709.16)) * (1704.0 / 15601.60)
px_x = int(pt_x * 150.0 / 72.0)
px_y = int(pt_y * 150.0 / 72.0)

print(f"Rendering crop around ({x}, {y}) -> px: ({px_x}, {px_y})...")

crop_cmd = [
    "pdftoppm", "-png", "-r", "150",
    "-x", str(max(0, px_x - 400)),
    "-y", str(max(0, px_y - 400)),
    "-W", "800",
    "-H", "800",
    "/home/ubuntu/cad-service/uploads/9378453d-1530-4262-985a-eaced10b368a.pdf",
    "/home/ubuntu/cad-service/public/crop_legend_pdf"
]
subprocess.run(crop_cmd, check=True)
print("Crop rendered to public/crop_legend_pdf-1.png!")
