from PIL import Image

im = Image.open(r"C:\Users\emirc\.gemini\antigravity-ide\brain\3d8bd3d6-c811-492b-85c0-58e529884eb0\fastview_ready.png")
w, h = im.size
print('FastView size:', w, h)

# Crop the middle drawing strip:
# It is around y: 1300 to 1420
crop_im = im.crop((0, int(h * 0.55), w, int(h * 0.62)))
crop_im.save(r"C:\Users\emirc\.gemini\antigravity-ide\brain\3d8bd3d6-c811-492b-85c0-58e529884eb0\fastview_strip_crop.png")
print('Cropped successfully!')
