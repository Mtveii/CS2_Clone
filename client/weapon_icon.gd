extends Control
## Простой дефолтный 2D-силуэт оружия (без скинов) для инвентаря лобби.
## Рисуется процедурно по типу оружия из WeaponData.

const WeaponData = preload("res://shared/gameplay/weapons.gd")

@export var weapon_id: int = -1
@export var icon_color: Color = Color(0.75, 0.78, 0.82)


func _draw() -> void:
	if weapon_id < 0:
		return
	var w: Dictionary = WeaponData.get_weapon(weapon_id)
	var slot: String = String(w.get("slot", ""))
	var s := size
	var center := Vector2(s.x * 0.5, s.y * 0.5)
	match slot:
		"pistol", "utility":
			_draw_pistol(center)
		"smg":
			_draw_smg(center)
		"rifle", "sniper", "heavy":
			_draw_long(center, slot)
		"melee":
			_draw_knife(center)
		"grenade":
			_draw_grenade(center)
		"objective":
			_draw_bomb(center)


func _draw_pistol(c: Vector2) -> void:
	var w := size.x * 0.5
	var h := size.y * 0.5
	draw_rect(Rect2(c.x - w * 0.45, c.y - h * 0.12, w * 0.7, h * 0.18), icon_color)
	draw_rect(Rect2(c.x - w * 0.15, c.y + h * 0.04, w * 0.18, h * 0.45), icon_color.darkened(0.25))


func _draw_smg(c: Vector2) -> void:
	var w := size.x * 0.46
	var h := size.y * 0.46
	draw_rect(Rect2(c.x - w * 0.85, c.y - h * 0.12, w * 1.4, h * 0.18), icon_color)
	draw_rect(Rect2(c.x - w * 0.2, c.y + h * 0.05, w * 0.2, h * 0.4), icon_color.darkened(0.25))
	draw_rect(Rect2(c.x + w * 0.2, c.y - h * 0.3, w * 0.12, h * 0.2), icon_color)


func _draw_long(c: Vector2, slot: String) -> void:
	var w := size.x * 0.46
	var h := size.y * 0.46
	var barrel := w * 1.55 if slot == "sniper" else w * 1.35
	draw_rect(Rect2(c.x - barrel * 0.5, c.y - h * 0.1, barrel, h * 0.14), icon_color)
	draw_rect(Rect2(c.x - w * 0.1, c.y - h * 0.22, w * 0.5, h * 0.22), icon_color.darkened(0.15))
	draw_rect(Rect2(c.x - w * 0.15, c.y + h * 0.02, w * 0.18, h * 0.42), icon_color.darkened(0.3))
	draw_rect(Rect2(c.x + w * 0.28, c.y - h * 0.32, w * 0.1, h * 0.22), icon_color)
	if slot == "heavy":
		draw_rect(Rect2(c.x + w * 0.05, c.y - h * 0.05, w * 0.5, h * 0.12), icon_color.darkened(0.1))


func _draw_knife(c: Vector2) -> void:
	var w := size.x * 0.4
	draw_rect(Rect2(c.x - w * 0.6, c.y - 2, w * 0.8, 4), icon_color.darkened(0.3))
	var blade := PackedVector2Array([
		c + Vector2(w * 0.2, -3), c + Vector2(w * 0.9, 0), c + Vector2(w * 0.2, 3),
	])
	draw_colored_polygon(blade, icon_color)


func _draw_grenade(c: Vector2) -> void:
	var r: float = minf(size.x, size.y) * 0.28
	draw_circle(c, r, icon_color)
	draw_rect(Rect2(c.x - r * 0.25, c.y - r * 1.5, r * 0.5, r * 0.5), icon_color.darkened(0.3))


func _draw_bomb(c: Vector2) -> void:
	var r: float = minf(size.x, size.y) * 0.3
	draw_rect(Rect2(c.x - r, c.y - r * 0.6, r * 2, r * 1.2), icon_color.darkened(0.2))
	draw_circle(c, r * 0.3, Color(1, 0.2, 0.2))
