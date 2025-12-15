#!/usr/bin/env python3
"""Generate placeholder app icons for CI builds.

The repository avoids tracking binary PNG assets, so this script
recreates the icon set that Xcode expects before building.
"""
from __future__ import annotations

import json
import pathlib
from typing import Dict, Iterable

try:
    from PIL import Image, ImageDraw
except ImportError as exc:  # pragma: no cover - imported in CI
    raise SystemExit(
        "Pillow is required to generate the app icons. Install it with 'pip install pillow'."
    ) from exc

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICONSET_PATH = ROOT / "ChatGPTWebView/ChatGPTWebView/Assets.xcassets/AppIcon.appiconset"
CONTENTS_PATH = ICONSET_PATH / "Contents.json"

BASE_COLOR = (19, 43, 71)
ACCENT_COLOR = (0, 212, 255)


def load_images() -> Iterable[Dict[str, str]]:
    if not CONTENTS_PATH.exists():
        raise SystemExit(f"Missing Contents.json at {CONTENTS_PATH}")
    data = json.loads(CONTENTS_PATH.read_text())
    return data.get("images", [])


def generate_icon(size: int, destination: pathlib.Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (size, size), BASE_COLOR)
    draw = ImageDraw.Draw(image)
    padding = max(4, size // 16)
    draw.rounded_rectangle(
        (padding, padding, size - padding, size - padding),
        radius=max(6, size // 10),
        outline=ACCENT_COLOR,
        width=max(2, size // 24),
    )
    draw.line(
        (padding, size - padding, size - padding, padding),
        fill=ACCENT_COLOR,
        width=max(2, size // 20),
    )
    image.save(destination, format="PNG")


def main() -> None:
    for entry in load_images():
        filename = entry.get("filename")
        size_value = entry.get("size")
        scale = entry.get("scale", "1x")
        if not filename or not size_value:
            continue
        base_size = float(size_value.split("x")[0])
        scale_factor = int(scale.rstrip("x"))
        pixel_size = int(base_size * scale_factor)
        generate_icon(pixel_size, ICONSET_PATH / filename)


if __name__ == "__main__":
    main()
