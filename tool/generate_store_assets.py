#!/usr/bin/env python3
"""Generates the app icons and store graphics, all drawn from code.

Usage: python3 tool/generate_store_assets.py  (needs Pillow; run from the repo root).
Screenshots are made separately: see docs/PUBBLICAZIONE.md.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
APP_NAME = "Mio Cartellino"
NAVY = (0x24, 0x43, 0x63, 255)
WHITE = (255, 255, 255, 255)
HANDS = (0x8F, 0xD3, 0xE8, 255)
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SCALE = 4  # supersampling, for smooth edges


def mark(size):
    """The C with clock hands, on transparency. Its content spans 712/1024 of the size."""
    u = size * SCALE / 1024
    image = Image.new("RGBA", (size * SCALE,) * 2, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def dot(x, y, radius, fill):
        draw.ellipse([(x - radius) * u, (y - radius) * u, (x + radius) * u, (y + radius) * u], fill=fill)

    center, radius, stroke, opening = 512, 304, 104, 38.8
    outer = radius + stroke / 2
    box = [(center - outer) * u, (center - outer) * u, (center + outer) * u, (center + outer) * u]
    draw.arc(box, opening, 360 - opening, fill=WHITE, width=round(stroke * u))
    dx, dy = radius * math.cos(math.radians(opening)), radius * math.sin(math.radians(opening))
    dot(center + dx, center - dy, stroke / 2, WHITE)
    dot(center + dx, center + dy, stroke / 2, WHITE)

    for x, y in ((512, 352), (656, 512)):
        draw.line([(512 * u, 512 * u), (x * u, y * u)], fill=HANDS, width=round(52 * u))
        dot(x, y, 26, HANDS)
    dot(512, 512, 38, HANDS)
    return image.resize((size, size), Image.LANCZOS)


def icon(size):
    """Opaque square icon: App Store icons can't have transparency."""
    canvas = Image.new("RGBA", (size, size), NAVY)
    canvas.alpha_composite(mark(size))
    return canvas.convert("RGB")


def rounded(size):
    """The icon as a rounded square on transparency, for launch and feature images."""
    scale = size * SCALE
    mask = Image.new("L", (scale, scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, scale - 1, scale - 1), radius=scale * 0.224, fill=255)
    out = icon(size).convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def main():
    master = icon(1024)

    icons = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for image in json.loads((icons / "Contents.json").read_text())["images"]:
        points = float(image["size"].split("x")[0])
        pixels = round(points * int(image["scale"][0]))
        master.resize((pixels, pixels), Image.LANCZOS).save(icons / image["filename"])

    launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for suffix, factor in (("", 1), ("@2x", 2), ("@3x", 3)):
        rounded(120 * factor).save(launch / f"LaunchImage{suffix}.png")

    for density, factor in DENSITIES.items():
        master.resize((round(48 * factor),) * 2, Image.LANCZOS).save(
            RES / f"mipmap-{density}/ic_launcher.png"
        )
        # Adaptive icon: 108 dp canvas, content inside the central safe zone (66 dp).
        canvas_px = round(108 * factor)
        content = mark(round(66 * factor * 1024 / 712))
        foreground = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        offset = (canvas_px - content.width) // 2
        foreground.alpha_composite(content, (offset, offset))
        drawable = RES / f"drawable-{density}"
        drawable.mkdir(exist_ok=True)
        foreground.save(drawable / "ic_launcher_foreground.png")

    values = RES / "values"
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#244363</color>\n</resources>\n'
    )
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )

    out = ROOT / "store/graphics"
    out.mkdir(parents=True, exist_ok=True)
    master.save(out / "icon-app-store-1024.png")
    master.resize((512, 512), Image.LANCZOS).save(out / "icon-google-play-512.png")

    # Google Play feature graphic: 1024 x 500, no alpha.
    feature = Image.new("RGBA", (1024, 500), NAVY)
    feature.alpha_composite(mark(420), (40, 40))
    draw = ImageDraw.Draw(feature)
    title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 62, index=1)
    subtitle = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 32)
    draw.text((470, 168), APP_NAME, font=title, fill=WHITE)
    draw.text((472, 256), "Riepilogo presenze", font=subtitle, fill=WHITE)
    draw.text((472, 298), "e orario di uscita previsto", font=subtitle, fill=WHITE)
    feature.convert("RGB").save(out / "feature-graphic-google-play-1024x500.png")


if __name__ == "__main__":
    main()
