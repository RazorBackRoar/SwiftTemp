#!/usr/bin/env python3
"""Build SwiftTemp AppIcon.icns from SwiftTemp.png on the standard macOS icon grid."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "SwiftTemp.png"
RESOURCE_ICNS = ROOT / "Sources/SwiftTemp/Resources/AppIcon.icns"
LEGACY_ICNS = ROOT / "Resources/AppIcon.icns"
ROOT_ICNS = ROOT / "SwiftTemp.icns"

def main() -> None:
    if not SOURCE.exists():
        SOURCE_FALLBACK = ROOT / "IconSource.png"
        if not SOURCE_FALLBACK.exists():
            raise SystemExit(f"Missing {SOURCE}")
        master = Image.open(SOURCE_FALLBACK).convert("RGBA")
    else:
        master = Image.open(SOURCE).convert("RGBA")

    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        r = master.resize((s, s), Image.Resampling.LANCZOS)
        r.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        if s <= 512:
            r2 = master.resize((s*2, s*2), Image.Resampling.LANCZOS)
            r2.save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    RESOURCE_ICNS.parent.mkdir(parents=True, exist_ok=True)
    LEGACY_ICNS.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", str(RESOURCE_ICNS)],
        check=True,
    )
    import shutil
    shutil.copy2(str(RESOURCE_ICNS), str(LEGACY_ICNS))
    shutil.copy2(str(RESOURCE_ICNS), str(ROOT_ICNS))
    print(f"Generated {RESOURCE_ICNS}")

if __name__ == "__main__":
    main()
