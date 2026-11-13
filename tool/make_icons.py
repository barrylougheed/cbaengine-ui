"""Makes the web favicon and app icons (web/favicon.png and web/icons/*.png).

    python tool/make_icons.py                 # the placeholder mark, until the logo exists
    python tool/make_icons.py path/to/logo.png  # from the real logo

The placeholder is the same mark as lib/widgets/logo_mark.dart: a logo-olive
disc (#748264) with a white envelope outline. When the real logo is supplied
(a PNG with a transparent background, at least 512 x 512 pixels and roughly
square), pass it here and every icon is rebuilt from it; then swap the mark in
lib/widgets/logo_mark.dart for the same file (see the UI README, "Logo").

Needs Pillow (`pip install pillow`). Run it from the cbaengine-ui folder.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

LOGO_OLIVE = (0x74, 0x82, 0x64, 255)  # #748264
WHITE = (255, 255, 255, 255)
SUPERSAMPLE = 4  # draw 4 times larger and shrink, for smooth edges

WEB = Path(__file__).resolve().parent.parent / "web"


def placeholder(size: int, *, full_bleed: bool) -> Image.Image:
    """The placeholder mark at [size] pixels square.

    With [full_bleed] the olive fills the whole square (maskable icons are
    cropped to a shape by the phone, so the colour must reach the edges) and the
    envelope is kept inside the middle 60%, which is always visible. Otherwise
    the olive is a disc on a transparent square.
    """
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    if full_bleed:
        draw.rectangle((0, 0, big, big), fill=LOGO_OLIVE)
        envelope_width = big * 0.5
    else:
        draw.ellipse((0, 0, big - 1, big - 1), fill=LOGO_OLIVE)
        envelope_width = big * 0.52

    # An envelope outline: a rounded rectangle with a V from the top corners.
    envelope_height = envelope_width * 0.72
    left = (big - envelope_width) / 2
    top = (big - envelope_height) / 2
    right = left + envelope_width
    bottom = top + envelope_height
    stroke = max(2, int(big * 0.045))
    draw.rounded_rectangle((left, top, right, bottom), radius=big * 0.05, outline=WHITE, width=stroke)
    middle = (left + right) / 2
    flap_bottom = top + envelope_height * 0.58
    draw.line([(left + stroke / 2, top + stroke / 2), (middle, flap_bottom), (right - stroke / 2, top + stroke / 2)],
              fill=WHITE, width=stroke, joint="curve")

    return image.resize((size, size), Image.LANCZOS)


def from_logo(logo: Image.Image, size: int, *, full_bleed: bool) -> Image.Image:
    """The real logo at [size] pixels square.

    Regular icons: the logo centred on a transparent square, with a little
    margin. Maskable icons: the logo on white, kept inside the middle 70%.
    """
    logo = logo.convert("RGBA")
    scale = 0.7 if full_bleed else 0.9
    longest = max(logo.size)
    fitted = logo.resize((round(logo.width * size * scale / longest), round(logo.height * size * scale / longest)), Image.LANCZOS)
    background = (255, 255, 255, 255) if full_bleed else (0, 0, 0, 0)
    image = Image.new("RGBA", (size, size), background)
    image.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return image


def main() -> int:
    logo = None
    if len(sys.argv) > 1:
        logo = Image.open(sys.argv[1])
        if min(logo.size) < 512:
            print(f"The logo is {logo.width} x {logo.height}; it needs to be at least 512 pixels each way.")
            return 1

    def make(size: int, *, full_bleed: bool) -> Image.Image:
        return from_logo(logo, size, full_bleed=full_bleed) if logo else placeholder(size, full_bleed=full_bleed)

    (WEB / "icons").mkdir(parents=True, exist_ok=True)
    make(48, full_bleed=False).save(WEB / "favicon.png")
    for size in (192, 512):
        make(size, full_bleed=False).save(WEB / "icons" / f"Icon-{size}.png")
        make(size, full_bleed=True).save(WEB / "icons" / f"Icon-maskable-{size}.png")
    print("Wrote web/favicon.png and web/icons/Icon-{192,512}.png and Icon-maskable-{192,512}.png "
          + ("from the logo." if logo else "(placeholder mark)."))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
