#!/usr/bin/env python3
"""
Primary **AppIcon** is the hand-tuned master (minimal matte depth — see `AppIcon.appiconset/AppIcon.png`).

To refresh after replacing the master asset:
  python3 scripts/build_alternate_app_icons.py

That script recolors only the top (accent) pill for each alternate palette to match in-app accents.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
ALT = ROOT / "build_alternate_app_icons.py"

if __name__ == "__main__":
    import runpy

    runpy.run_path(str(ALT), run_name="__main__")
