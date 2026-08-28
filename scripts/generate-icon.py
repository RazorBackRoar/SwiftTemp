#!/usr/bin/env python3
"""Build SwiftTemp AppIcon.icns from the canonical PNG on the standard macOS icon grid."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/SwiftTemp/Resources/AppIcon.png"
RESOURCE_ICNS = ROOT / "Sources/SwiftTemp/Resources/AppIcon.icns"


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing {SOURCE}")
    master = Image.open(SOURCE).convert("RGBA")

    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        r = master.resize((s, s), Image.Resampling.LANCZOS)
        r.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        if s <= 512:
            r2 = master.resize((s * 2, s * 2), Image.Resampling.LANCZOS)
            r2.save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    RESOURCE_ICNS.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", str(RESOURCE_ICNS)],
        check=True,
    )
    print(f"Generated {RESOURCE_ICNS}")


if __name__ == "__main__":
    main()
