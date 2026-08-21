#!/usr/bin/env python3
"""Build SwiftTemp AppIcon.icns from IconSource.png on the 824@100 grid.

IconSource.png is a 1024×1024 RGB export with a light-gray backdrop. The navy
squircle is isolated, scaled onto the shared 824×824 macOS icon grid, and
re-shadowed to match Looper / MetaBurn / L!bra.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "IconSource.png"
RESOURCE_ICNS = ROOT / "Sources/SwiftTemp/Resources/AppIcon.icns"
LEGACY_ICNS = ROOT / "Resources/AppIcon.icns"

CANVAS = 1024
BODY = 824
MARGIN = (CANVAS - BODY) // 2  # 100
SHADOW_BLUR = 5
SHADOW_OFFSET = 10
SHADOW_ALPHA = 80
SQUIRCLE_N = 5.0
LUMA_CUTOFF = 145
CHROMA_CUTOFF = 28
NAVY_FILL = (15, 28, 48, 255)
GRAY_LUMA = 200
GRAY_CHROMA = 18

ICONSET_SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def solid_mask(im: Image.Image) -> Image.Image:
    """White over the navy squircle and amber glyph; gray backdrop stays black."""
    src = im.convert("RGB")
    w, h = src.size
    px = src.load()
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            luma = 0.299 * r + 0.587 * g + 0.114 * b
            chroma = max(r, g, b) - min(r, g, b)
            if luma < LUMA_CUTOFF or chroma > CHROMA_CUTOFF:
                mp[x, y] = 255

    filled = mask.copy()
    ImageDraw.floodfill(filled, (w // 2, h // 2), 100, thresh=0)
    solid = filled.point(lambda v: 255 if v == 100 else 0)
    return solid.filter(ImageFilter.MinFilter(3))


def squircle_mask(size: int, n: float = SQUIRCLE_N) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    pixels = mask.load()
    radius = (size - 1) / 2.0
    for y in range(size):
        yn = abs(y - radius) / radius
        yn_n = yn**n
        for x in range(size):
            xn = abs(x - radius) / radius
            if xn**n + yn_n <= 1.0:
                pixels[x, y] = 255
    return mask.filter(ImageFilter.GaussianBlur(0.7))


def fill_gray_backdrop(im: Image.Image) -> Image.Image:
    """Turn leftover export-gray into navy so fringe cannot halo the Dock."""
    out = im.convert("RGBA")
    px = out.load()
    w, h = out.size
    nr, ng, nb, na = NAVY_FILL
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            luma = 0.299 * r + 0.587 * g + 0.114 * b
            chroma = max(r, g, b) - min(r, g, b)
            if luma >= GRAY_LUMA and chroma <= GRAY_CHROMA:
                px[x, y] = (nr, ng, nb, na)
    return out


def master_from_source(path: Path) -> Image.Image:
    src = Image.open(path).convert("RGB")
    mask = solid_mask(src)
    box = mask.getbbox()
    if box is None:
        raise ValueError("icon artwork is empty after background cleanup")

    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    side = max(x1 - x0, y1 - y0)
    sx0 = max(0, int(round(cx - side / 2)))
    sy0 = max(0, int(round(cy - side / 2)))
    sx1 = min(src.width, sx0 + side)
    sy1 = min(src.height, sy0 + side)

    art = src.crop((sx0, sy0, sx1, sy1)).resize((BODY, BODY), Image.Resampling.LANCZOS)
    art = fill_gray_backdrop(art)
    base = Image.new("RGBA", (BODY, BODY), NAVY_FILL)
    art = Image.alpha_composite(base, art)
    art.putalpha(squircle_mask(BODY))

    alpha = art.split()[3]
    shadow = Image.new("L", (CANVAS, CANVAS), 0)
    shadow.paste(
        alpha.point(lambda v: v * SHADOW_ALPHA // 255),
        (MARGIN, MARGIN + SHADOW_OFFSET),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    below = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    below.putalpha(shadow)

    above = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    above.paste(art, (MARGIN, MARGIN), art)
    return Image.alpha_composite(below, above)


def write_iconset(master: Image.Image, iconset: Path) -> None:
    if iconset.exists():
        for child in iconset.iterdir():
            child.unlink()
    iconset.mkdir(parents=True, exist_ok=True)
    for name, px in ICONSET_SIZES.items():
        out = master if master.width == px else master.resize((px, px), Image.Resampling.LANCZOS)
        out.save(iconset / name, optimize=True)


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing {SOURCE}")

    master = master_from_source(SOURCE)
    iconset = ROOT / "build" / "AppIcon.iconset"
    write_iconset(master, iconset)
    RESOURCE_ICNS.parent.mkdir(parents=True, exist_ok=True)
    LEGACY_ICNS.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["iconutil", "-c", "icns", str(iconset), "-o", str(RESOURCE_ICNS)],
        check=True,
    )
    LEGACY_ICNS.write_bytes(RESOURCE_ICNS.read_bytes())
    print(f"Generated {RESOURCE_ICNS}")
    print(f"Copied {LEGACY_ICNS}")


if __name__ == "__main__":
    main()
