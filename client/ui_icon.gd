extends Control
## Векторные иконки интерфейса. Не использует Unicode/emoji: системный шрифт
## на web не работает, а стандартный шрифт Godot не содержит большинства символов.
## Рисуем каждой иконке фиксированную форму линиями и многоугольниками.

@export var icon_name: String = "dot"
@export var icon_color: Color = Color(0.90, 0.92, 0.95)
@export var icon_width: float = 2.0


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.36
	var a := 0.785398
	match icon_name:
		"home":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 0.9), c + Vector2(r, 0), c + Vector2(r * 0.75, 0),
				c + Vector2(r * 0.75, r * 0.8), c + Vector2(-r * 0.75, r * 0.8),
				c + Vector2(-r * 0.75, 0), c + Vector2(-r, 0),
			]), icon_color)
			draw_rect(Rect2(c.x - r * 0.22, c.y + r * 0.2, r * 0.44, r * 0.6), Color(0.05, 0.07, 0.10, 1))
		"inventory", "grid":
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), icon_color, false, icon_width)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), icon_color, icon_width)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), icon_color, icon_width)
		"settings", "gear":
			draw_circle(c, r * 0.55, icon_color, false, icon_width)
			for i in range(8):
				var t := TAU * float(i) / 8.0
				var d := Vector2(cos(t), sin(t))
				draw_line(c + d * r * 0.62, c + d * r, icon_color, icon_width)
		"power":
			draw_arc(c, -a + 0.2, a + PI - 0.2, 20, r * 0.8, icon_color, icon_width, true)
			draw_line(c + Vector2(0, -r), c + Vector2(0, 0), icon_color, icon_width)
		"friends", "pawn":
			draw_circle(c + Vector2(0, -r * 0.45), r * 0.35, icon_color)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.65, r), c + Vector2(r * 0.65, r),
				c + Vector2(r * 0.4, -r * 0.1), c + Vector2(-r * 0.4, -r * 0.1),
			]), icon_color)
		"mic", "voice":
			draw_rect(Rect2(c.x - r * 0.35, c.y - r, r * 0.7, r * 1.2), icon_color, false, icon_width)
			draw_arc(c + Vector2(0, r * 0.1), 0.0, PI, 12, r * 0.65, icon_color, icon_width, true)
			draw_line(c + Vector2(0, r * 0.75), c + Vector2(0, r), icon_color, icon_width)
			draw_line(c + Vector2(-r * 0.4, r), c + Vector2(r * 0.4, r), icon_color, icon_width)
		"history", "refresh":
			draw_arc(c, 0.4, TAU - 0.4, 24, r * 0.85, icon_color, icon_width, true)
			var tip := c + Vector2(r * 0.85, -r * 0.3)
			draw_colored_polygon(PackedVector2Array([
				tip, tip + Vector2(-r * 0.35, -r * 0.15), tip + Vector2(-r * 0.15, r * 0.35),
			]), icon_color)
		"add", "plus":
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), icon_color, icon_width + 1)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), icon_color, icon_width + 1)
		"close", "cross":
			draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.7), icon_color, icon_width)
			draw_line(c + Vector2(r * 0.7, -r * 0.7), c + Vector2(-r * 0.7, r * 0.7), icon_color, icon_width)
		"back", "prev", "left":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.5, -r * 0.75),
				c + Vector2(r * 0.5, r * 0.75),
			]), icon_color)
			if icon_name == "back":
				draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.2, 0), icon_color, icon_width)
		"next", "right":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 0.3, 0), c + Vector2(-r * 0.5, -r * 0.75),
				c + Vector2(-r * 0.5, r * 0.75),
			]), icon_color)
		"share":
			draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.5, -r * 0.5), icon_color, icon_width)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 0.7, -r * 0.7), c + Vector2(r * 0.1, -r * 0.7),
				c + Vector2(r * 0.7, -r * 0.1),
			]), icon_color)
		"delete", "trash":
			draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.4, r * 1.2, r * 1.3), icon_color, false, icon_width)
			draw_line(c + Vector2(-r * 0.8, -r * 0.4), c + Vector2(r * 0.8, -r * 0.4), icon_color, icon_width)
			draw_line(c + Vector2(-r * 0.3, -r * 0.7), c + Vector2(r * 0.3, -r * 0.7), icon_color, icon_width)
			for x in [-0.3, 0.0, 0.3]:
				draw_line(c + Vector2(r * x, -r * 0.2), c + Vector2(r * x, r * 0.7), icon_color, icon_width)
		"server", "globe":
			draw_circle(c, r, icon_color, false, icon_width)
			var ellipse := PackedVector2Array()
			for i in range(32):
				var t := TAU * float(i) / 32.0
				ellipse.append(c + Vector2(cos(t) * r * 0.45, sin(t) * r))
			draw_polyline(ellipse, icon_color, icon_width, true)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), icon_color, icon_width)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), icon_color, icon_width)
		"search":
			draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.6, icon_color, false, icon_width)
			draw_line(c + Vector2(r * 0.3, r * 0.3), c + Vector2(r, r), icon_color, icon_width + 1)
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var t := -PI * 0.5 + PI * float(i) / 5.0
				var rad: float = r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(t), sin(t)) * rad)
			draw_colored_polygon(pts, icon_color)
		_:
			draw_circle(c, r * 0.5, icon_color)
