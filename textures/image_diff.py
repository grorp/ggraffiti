import sys
from PIL import Image, ImageChops

a = Image.open(sys.argv[1])
b = Image.open(sys.argv[2])
c = ImageChops.difference(b.convert("RGBA"), a.convert("RGBA")).convert("RGB")
c.save("./diff.png")
