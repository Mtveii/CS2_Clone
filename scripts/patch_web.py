#!/usr/bin/env python3
"""Post-process Godot's generated web shell.

Godot's default HTML does not force the canvas to fill the viewport and
provides no fullscreen control. Different browsers then disagree about the
game size (address bar, devicePixelRatio, letterboxing). We add one canonical
set of CSS rules and a small fullscreen controller; the patch is idempotent.
"""
import shutil
import sys
from pathlib import Path

MARK = "<!-- tactical-voxel-web-patch -->"
BRAND = Path(__file__).resolve().parent.parent / "assets" / "brand"

CSS = """
/* --- tactical-voxel fullscreen patch --- */
html, body {
	width: 100%;
	height: 100%;
	height: 100dvh;
	min-height: 100%;
	overflow: hidden;
	background: #05070b;
}
#canvas {
	width: 100vw !important;
	height: 100vh !important;
	height: 100dvh !important;
	max-width: none !important;
	max-height: none !important;
	display: block;
	touch-action: none;
	image-rendering: auto;
}
#status-splash {
	max-width: 100vw;
	max-height: 100dvh;
}
#fs-toggle {
	position: fixed;
	right: 12px;
	top: 56px;
	z-index: 10;
	width: 34px;
	height: 34px;
	padding: 0;
	border: 1px solid rgba(120, 190, 230, 0.55);
	border-radius: 8px;
	background: rgba(8, 16, 24, 0.72);
	color: #e6f4ff;
	font: 18px/34px sans-serif;
	text-align: center;
	cursor: pointer;
	opacity: 0.45;
	transition: opacity 120ms ease;
}
#fs-toggle:hover, #fs-toggle:focus-visible { opacity: 1; outline: none; }
#browser-notice {
	position: fixed;
	left: 50%;
	top: 12px;
	transform: translateX(-50%);
	z-index: 11;
	max-width: 80vw;
	padding: 8px 14px;
	border: 1px solid #a86432;
	border-radius: 8px;
	background: rgba(28, 14, 8, 0.92);
	color: #ffd9a8;
	font: 13px/1.4 sans-serif;
	display: none;
}
"""

HTML = """
<!-- tactical-voxel-web-patch -->
<button id="fs-toggle" type="button" title="Fullscreen (F11)" aria-label="Fullscreen">&#9974;</button>
<div id="browser-notice" role="status"></div>
<script>
(function () {
	const btn = document.getElementById('fs-toggle');
	const notice = document.getElementById('browser-notice');
	function fullscreenElement() {
		return document.fullscreenElement || document.webkitFullscreenElement;
	}
	function updateButton() {
		if (btn) btn.textContent = fullscreenElement() ? '\u2715' : '\u26f6';
	}
	function toggleFullscreen() {
		if (fullscreenElement()) {
			const exit = document.exitFullscreen || document.webkitExitFullscreen;
			if (exit) exit.call(document);
		} else {
			const el = document.documentElement;
			const req = el.requestFullscreen || el.webkitRequestFullscreen;
			if (req) req.call(el);
		}
	}
	if (btn) btn.addEventListener('click', toggleFullscreen);
	window.addEventListener('keydown', function (e) {
		if (e.key === 'F11' || (e.altKey && e.key === 'Enter')) {
			e.preventDefault();
			toggleFullscreen();
		}
	}, true);
	['fullscreenchange', 'webkitfullscreenchange'].forEach(function (name) {
		document.addEventListener(name, updateButton);
	});
	updateButton();

	// Клавиши W/A/S/D, B, R, F, G и Space доходят до Godot только когда
	// canvas в фокусе. Возвращаем фокус при любом input на странице.
	var canvas = document.getElementById('canvas');
	function focusCanvas() { if (canvas) canvas.focus(); }
	document.addEventListener('keydown', focusCanvas, true);
	document.addEventListener('pointerdown', focusCanvas, true);

	// Одинаковое поведение в браузерах с разной поддержкой WebGL2.
	function hasWebGL2() {
		try {
			return !!document.createElement('canvas').getContext('webgl2');
		} catch (e) { return false; }
	}
	if (!hasWebGL2() && notice) {
		notice.textContent = 'WebGL2 недоступен: откройте игру в Chrome/Edge/Firefox последней версии и включите аппаратное ускорение.';
		notice.style.display = 'block';
	}
}());
</script>
"""


def copy_brand(path: Path) -> None:
    assets = {
        "splash.png": ["index.png"],
        "icon_192.png": ["index.icon.png", "index.apple-touch-icon.png"],
        "icon_512.png": ["index.icon-512.png"],
    }
    for source_name, targets in assets.items():
        source = BRAND / source_name
        if not source.exists():
            continue
        for target_name in targets:
            target = path.parent / target_name
            if not target.exists() or source.stat().st_size != target.stat().st_size:
                shutil.copyfile(source, target)


def patch(path: Path) -> int:
    copy_brand(path)
    text = path.read_text(encoding="utf-8")
    if MARK in text:
        return 0
    if "</style>" not in text or "</body>" not in text:
        raise SystemExit(f"unexpected Godot shell: {path}")
    text = text.replace("</style>", CSS + "\n\t\t</style>", 1)
    text = text.replace("</body>", HTML + "\n\t</body>", 1)
    text = text.replace(
        '<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">',
        '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">\n'
        '\t\t<meta name="color-scheme" content="dark">\n'
        '\t\t<meta name="theme-color" content="#05070b">', 1,
    )
    path.write_text(text, encoding="utf-8")
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_web.py <build/index.html>")
    changed = patch(Path(sys.argv[1]))
    print("web shell patched" if changed else "web shell already patched")
