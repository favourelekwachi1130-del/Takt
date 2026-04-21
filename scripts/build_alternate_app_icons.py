#!/usr/bin/env python3
"""
Build alternate 1024 App Icons from the master `AppIcon.png` by recoloring the top (accent) pill.
Run after updating the master asset. Toned-down matte look is preserved via HSV (hue shift, keep S/V).
"""

from __future__ import annotations

import colorsys
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "PresentationTimer" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
ASSETS = ROOT / "PresentationTimer" / "Assets.xcassets"

# Top accent region (from analysis of shipped minimalist icon)
BBOX = (208, 303, 577, 406)


def is_accent_bar(r: int, g: int, b: int) -> bool:
    if r > 160 and g > 70 and b < 150 and r > g:
        return True
    return False


def recolor_accent(im: Image.Image, target_rgb: tuple[float, float, float]) -> Image.Image:
    """Replace hue of accent bar pixels; preserve saturation/value for shading."""
    im = im.convert("RGB")
    px = im.load()
    tr, tg, tb = target_rgb
    th, _, _ = colorsys.rgb_to_hsv(tr, tg, tb)
    w, h = im.size
    x0, y0, x1, y1 = BBOX
    out = im.copy()
    op = out.load()
    for y in range(y0, min(y1, h)):
        for x in range(x0, min(x1, w)):
            r, g, b = [v / 255.0 for v in px[x, y]]
            ri, gi, bi = int(r * 255), int(g * 255), int(b * 255)
            if not is_accent_bar(ri, gi, bi):
                continue
            _, cs, cv = colorsys.rgb_to_hsv(r, g, b)
            nr, ng, nb = colorsys.hsv_to_rgb(th, cs, cv)
            op[x, y] = (
                min(255, int(nr * 255)),
                min(255, int(ng * 255)),
                min(255, int(nb * 255)),
            )
    return out


def write_alt(name: str, rgb: tuple[float, float, float]) -> None:
    base = Image.open(MASTER).convert("RGB")
    alt = recolor_accent(base, rgb)
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    png = folder / f"{name}.png"
    alt.save(png, "PNG", optimize=True)
    contents = {
        "images": [
            {
                "filename": png.name,
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2), encoding="utf-8")
    print(f"Wrote {png}")


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"Missing master icon: {MASTER}")

    alts = [
        ("AppIconCoral", (0.96, 0.36, 0.31)),
        ("AppIconMint", (0.15, 0.78, 0.56)),
        ("AppIconSky", (0.22, 0.52, 0.98)),
        ("AppIconViolet", (0.55, 0.38, 0.98)),
        ("AppIconRose", (0.98, 0.32, 0.52)),
    ]
    for name, rgb in alts:
        write_alt(name, rgb)


if __name__ == "__main__":
    main()
