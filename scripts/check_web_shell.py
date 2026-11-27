#!/usr/bin/env python3
"""Verify the web shell fills the browser and the brand assets are present."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    errors = []
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'window/stretch/mode="canvas_items"' not in project:
        errors.append("stretch mode must be canvas_items")
    if 'window/stretch/aspect="expand"' not in project:
        errors.append("stretch aspect must be expand")
    if 'renderer/rendering_method="gl_compatibility"' not in project:
        errors.append("web renderer must be gl_compatibility")

    html_path = ROOT / "build" / "index.html"
    if not html_path.exists():
        return 1
    html = html_path.read_text(encoding="utf-8")
    checks = {
        "fullscreen patch": "tactical-voxel-web-patch" in html,
        "canvas 100vw": "width: 100vw !important" in html,
        "canvas 100dvh": "height: 100dvh !important" in html,
        "fullscreen button": 'id="fs-toggle"' in html,
        "WebGL2 notice": 'id="browser-notice"' in html,
        "dark color-scheme": 'name="color-scheme" content="dark"' in html,
    }
    errors += [name for name, ok in checks.items() if not ok]
    if not re.search(r'"canvasResizePolicy":2', html):
        errors.append("canvasResizePolicy must be 2")

    for name in ("index.png", "index.icon.png", "index.apple-touch-icon.png",
                 "index.icon-512.png", "index.pck", "index.wasm", "index.js"):
        p = ROOT / "build" / name
        if not p.exists() or p.stat().st_size == 0:
            errors.append(f"missing/empty build/{name}")

    if errors:
        print("FAIL:", *errors, sep="\n  - ")
        return 1
    print("Web shell OK: fullscreen canvas, stretch=expand, brand assets present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
