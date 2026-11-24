"""Prepares the brand logos for the app: assets/brand/*.png.

    python tool/make_brand_assets.py "C:\\...\\CBA_BrandAssets"

The supplied files are A4-sized canvases (3508 x 2481 pixels) with a wide
transparent margin round the artwork, about 100 KB each. The app needs the
artwork alone, and not at that size, so each logo is cropped to its artwork and
shrunk:

    01_Sloth_Icon/CBA_Sloth_Green.png            -> sloth_icon_green.png      (384 px tall)
    01_Sloth_Icon/CBA_Sloth_Cream.png            -> sloth_icon_cream.png
    02_Sloth_Wordmark/CBA_SlothWordmark_Green.png -> sloth_wordmark_green.png (800 px wide)
    02_Sloth_Wordmark/CBA_SlothWordmark_Cream.png -> sloth_wordmark_cream.png

Only green and cream are used: green on the white header, cream on the deep
olive footer. (The brand folder also holds black and white versions and the
"CBA" wordmark and hand icon without the sloth; they are not needed yet.) The
originals stay in the brand folder: this keeps the app's copies small, and can
be run again if the artwork changes. Run `python tool/make_icons.py` afterwards
to rebuild the favicon and install icons from the sloth.

Needs Pillow (`pip install pillow`). Run it from the cbaengine-ui folder.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parent.parent / "assets" / "brand"

# (folder, file in the brand folder, file in the app, which side is set, size in pixels)
LOGOS = [
    ("01_Sloth_Icon", "CBA_Sloth_Green.png", "sloth_icon_green.png", "height", 384),
    ("01_Sloth_Icon", "CBA_Sloth_Cream.png", "sloth_icon_cream.png", "height", 384),
    ("02_Sloth_Wordmark", "CBA_SlothWordmark_Green.png", "sloth_wordmark_green.png", "width", 800),
    ("02_Sloth_Wordmark", "CBA_SlothWordmark_Cream.png", "sloth_wordmark_cream.png", "width", 800),
]


def prepare(source: Path, side: str, size: int) -> Image.Image:
    """The logo cropped to its artwork (the area that is not transparent), and
    scaled so that its `side` ("height" or "width") is `size` pixels."""
    logo = Image.open(source).convert("RGBA")
    # Pixels that are nearly transparent count as margin (soft edges of the artwork stay).
    box = logo.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if box is None:
        raise SystemExit(f"{source.name} has no artwork (it is entirely transparent)")
    logo = logo.crop(box)
    scale = size / (logo.height if side == "height" else logo.width)
    return logo.resize((round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    brand = Path(sys.argv[1])
    ASSETS.mkdir(parents=True, exist_ok=True)
    for folder, name, target, side, size in LOGOS:
        source = brand / folder / name
        if not source.is_file():
            print(f"Not found: {source}")
            return 1
        image = prepare(source, side, size)
        image.save(ASSETS / target, optimize=True)
        print(f"{target}: {image.width} x {image.height}, {(ASSETS / target).stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
