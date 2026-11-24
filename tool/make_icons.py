"""Makes the web favicon and app icons (web/favicon.png and web/icons/*.png)
from the sloth icon.

    python tool/make_icons.py                   # from assets/brand/sloth_icon_green.png
    python tool/make_icons.py path/to/logo.png  # from another logo (see below)

The sloth is drawn in the brand green on a cream tile (#F6F3E9), not on a
transparent background: a green logo on transparent vanishes on a dark browser
tab and on a phone's dark home screen, and iOS fills transparent icons with
black. The tiles are:

    web/favicon.png                  48 x 48, a rounded square (for the browser tab)
    web/icons/Icon-192.png, -512.png  a full cream square, the sloth filling about
                                      three quarters of it (also the iOS home screen icon)
    web/icons/Icon-maskable-*.png     a full cream square with the sloth smaller, inside
                                      the middle 80% that Android never crops away

The logo passed in must have a transparent background and be at least 256 pixels
tall; it is cropped to its artwork first, so a logo on a big canvas still fills
its tile. assets/brand/sloth_icon_green.png is made from the brand folder by
tool/make_brand_assets.py: run that first if the artwork changes.

Needs Pillow (`pip install pillow`). Run it from the cbaengine-ui folder.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

CREAM = (246, 243, 233, 255)  # #F6F3E9
SUPERSAMPLE = 4  # draw 4 times larger and shrink, for smooth edges

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
DEFAULT_LOGO = ROOT / "assets" / "brand" / "sloth_icon_green.png"


def crop_to_artwork(logo: Image.Image) -> Image.Image:
    """The logo without its transparent margin."""
    logo = logo.convert("RGBA")
    box = logo.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    return logo.crop(box) if box else logo


def tile(logo: Image.Image, size: int, *, fill: float, rounded: bool) -> Image.Image:
    """A cream tile `size` pixels square with the logo centred on it, its longest
    side `fill` of the tile. With `rounded` the corners are rounded (and
    transparent), as for a favicon; otherwise the cream goes right to the edge."""
    big = size * SUPERSAMPLE
    tile_image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile_image)
    if rounded:
        draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.22, fill=CREAM)
    else:
        draw.rectangle((0, 0, big, big), fill=CREAM)

    scale = big * fill / max(logo.size)
    fitted = logo.resize((round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS)
    tile_image.alpha_composite(fitted, ((big - fitted.width) // 2, (big - fitted.height) // 2))
    return tile_image.resize((size, size), Image.LANCZOS)


def main() -> int:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOGO
    if not source.is_file():
        print(f"Not found: {source}")
        return 1
    logo = crop_to_artwork(Image.open(source))
    if logo.height < 256:
        print(f"The logo is only {logo.height} pixels tall once cropped; it needs to be at least 256.")
        return 1

    (WEB / "icons").mkdir(parents=True, exist_ok=True)
    tile(logo, 48, fill=0.80, rounded=True).save(WEB / "favicon.png")
    for size in (192, 512):
        tile(logo, size, fill=0.74, rounded=False).save(WEB / "icons" / f"Icon-{size}.png")
        tile(logo, size, fill=0.56, rounded=False).save(WEB / "icons" / f"Icon-maskable-{size}.png")
    print(f"Wrote web/favicon.png and web/icons/ from {source.name}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
