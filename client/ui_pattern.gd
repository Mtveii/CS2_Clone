extends Control
## Фон с топографическими контурами (как в CS2-меню). Рисуется процедурно.

@export var color: Color = Color(0.45, 0.52, 0.60, 0.10)
@export var line_count: int = 22
@export var offset: float = 0.0
@export var wobble: float = 1.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	for i in range(line_count):
		var pts := PackedVector2Array()
		var base_y: float = h * (0.12 + float(i) * 0.042) + offset
		var amp: float = (6.0 + float(i % 5) * 3.0) * wobble
		for x in range(0, int(w) + 8, 8):
			var y := base_y + sin(float(x) * 0.004 + float(i) * 0.7) * amp \
				+ sin(float(x) * 0.011 + float(i) * 1.3) * amp * 0.35
			pts.append(Vector2(x, y))
		if pts.size() > 1:
			draw_polyline(pts, color, 1.0)
	# замкнутые контуры справа
	for j in range(6):
		var cx := w * (0.82 + float(j % 3) * 0.06)
		var cy := h * (0.2 + float(j) * 0.13)
		var r0 := 24.0 + float(j) * 14.0
		for k in range(4):
			var pts2 := PackedVector2Array()
			for a in range(0, 64):
				var ang := float(a) / 64.0 * TAU
				var rr := r0 + float(k) * 16.0 + sin(ang * 4.0 + float(j)) * 8.0
				pts2.append(Vector2(cx, cy) + Vector2(cos(ang) * rr, sin(ang) * rr * 0.7))
			pts2.append(pts2[0])
			draw_polyline(pts2, color, 1.0)
