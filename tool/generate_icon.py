"""Растрирует SVG Delta с помощью Pillow, сохраняя исходные координаты."""
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parents[1]
ROOT = ElementTree.parse(APP / "assets/branding/delta.svg").getroot()
RES = APP / "android/app/src/main/res"
SCALE = 10
SIDE = int(ROOT.attrib["width"])


def rasterize(adaptive=False):
    canvas = Image.new("RGBA", (SIDE * SCALE, SIDE * SCALE))
    draw = ImageDraw.Draw(canvas)
    for shape in ROOT:
        attributes = shape.attrib
        if shape.tag.endswith("rect"):
            if not adaptive:
                draw.rectangle((0, 0, SIDE * SCALE, SIDE * SCALE), fill=attributes["fill"])
        elif shape.tag.endswith("polygon"):
            points = [tuple(int(n) * SCALE for n in p.split(",")) for p in attributes["points"].split()]
            draw.polygon(points, fill=attributes["fill"])
        else:
            raise ValueError("Элемент SVG не поддерживается")
    return canvas


for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    for suffix, adaptive, edge in (("", False, size), ("_foreground", True, size * 9 // 4)):
        icon = rasterize(adaptive).resize((edge, edge), Image.Resampling.LANCZOS)
        icon.save(RES / f"mipmap-{density}/ic_launcher{suffix}.png")

sizes = [(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
rasterize().resize((256, 256), Image.Resampling.LANCZOS).save(
    APP / "windows/runner/resources/app_icon.ico", sizes=sizes
)
