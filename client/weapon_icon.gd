extends Control
## Процедурные 2D-силуэты оружия. КаждыйWeaponId даёт свою форму:
## длина ствола, тип магазина, прицел и цвет команды. Никаких extern png,
## поэтому иконки одинаково выглядят в web и не зависят от шрифта.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const UiTheme = preload("res://client/ui_theme.gd")

@export var weapon_id: int = -1
@export var icon_color: Color = Color(0.78, 0.82, 0.86)

var _c := Vector2.ZERO
var _s := 1.0
var _metal := Color(0.72, 0.76, 0.80)
var _poly := Color(0.16, 0.19, 0.23)
var _accent := Color(0.40, 0.68, 0.88)


func _draw() -> void:
	if weapon_id < 0:
		return
	var w: Dictionary = WeaponData.get_weapon(weapon_id)
	var slot: String = String(w.get("slot", ""))
	_setup(w)
	match slot:
		"pistol", "utility":
			_draw_pistol(w)
		"smg":
			_draw_smg(w)
		"rifle":
			_draw_rifle(w)
		"sniper":
			_draw_sniper(w)
		"heavy":
			_draw_heavy(w)
		"melee":
			_draw_knife()
		"grenade":
			_draw_grenade(w)
		"objective":
			_draw_bomb()
		_:
			_draw_pistol(w)


func _setup(w: Dictionary) -> void:
	_c = size * 0.5
	_s = minf(size.x / 150.0, size.y / 56.0)
	_metal = icon_color
	_poly = icon_color.darkened(0.55)
	var team: int = int(w.get("team", 0))
	_accent = UiTheme.TEAM_T if team == WeaponData.Team.T else UiTheme.TEAM_CT
	if team == WeaponData.Team.ANY:
		_accent = UiTheme.ACCENT
	_accent.a = 0.95


func _pt(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _s


func _fill(points: Array, color: Color) -> void:
	var arr := PackedVector2Array()
	for p in points:
		arr.append(_pt(float(p[0]), float(p[1])))
	draw_colored_polygon(arr, color)


func _line(a: Array, b: Array, color: Color, width: float = 2.0) -> void:
	draw_line(_pt(float(a[0]), float(a[1])), _pt(float(b[0]), float(b[1])), color, max(1.0, width * _s))


func _polyline(points: Array, color: Color, width: float = 1.5) -> void:
	var arr := PackedVector2Array()
	for p in points:
		arr.append(_pt(float(p[0]), float(p[1])))
	draw_polyline(arr, color, max(1.0, width * _s), true)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(_pt(x, y), Vector2(w * _s, h * _s)), color)


func _draw_pistol(w: Dictionary) -> void:
	var long: float = 34.0 + float(weapon_id % 3) * 2.0
	if weapon_id == WeaponData.WeaponId.DEAGLE or weapon_id == WeaponData.WeaponId.R8:
		long += 6.0
	_fill([[-long, -7], [long, -7], [long, 3], [-long, 3]], _metal)
	_fill([[-long, -7], [-long + 4, -11], [long - 3, -11], [long, -7]], _metal.lightened(0.12))
	_fill([[-7, 3], [10, 3], [5, 21], [-9, 21]], _poly)
	_polyline([[0, 3], [2, 10], [9, 10], [10, 4]], _poly, 2.0)
	_rect(-long + 3, -13, 5, 3, _accent)
	if weapon_id == WeaponData.WeaponId.DUAL_BERETTAS:
		_fill([[-36, -12], [-42, 8], [-34, 21], [-26, 21], [-25, 3]], _metal.darkened(0.15))
	if weapon_id == WeaponData.WeaponId.USP or weapon_id == WeaponData.WeaponId.M4A1S:
		_line([long - 6, -11], [long + 4, -11], _accent, 2.0)


func _draw_smg(w: Dictionary) -> void:
	var long: float = 42.0 + float(weapon_id % 4) * 2.5
	_fill([[-long * 0.7, -9], [long * 0.75, -9], [long * 0.85, 2], [-long * 0.8, 2]], _metal)
	_fill([[-long * 0.7, -9], [-long, -6], [-long, 9], [-long * 0.65, 9]], _poly)
	_rect(long * 0.7, -5, long * 0.5, 4, _metal.darkened(0.15))
	_fill([[-10, 2], [8, 2], [4, 24], [-14, 24]], _poly)
	_rect(-4, -15, 10, 5, _accent)
	if weapon_id == WeaponData.WeaponId.P90:
		_fill([[-long * 0.8, 2], [long * 0.3, 2], [long * 0.1, 18], [-long * 0.6, 18]], _poly)
	if weapon_id == WeaponData.WeaponId.MP7:
		_rect(-2, -16, 16, 4, _metal.lightened(0.1))


func _draw_rifle(w: Dictionary) -> void:
	var long: float = 54.0 + float(int(w.get("recoil", 2.0)) * 2.0)
	_fill([[-long * 0.7, -9], [long * 0.7, -9], [long * 0.8, 4], [-long * 0.75, 4]], _metal)
	_fill([[-long * 0.7, -9], [-long, -5], [-long - 3, 10], [-long * 0.6, 10]], _poly)
	_rect(long * 0.65, -5, long * 0.7, 5, _metal.darkened(0.2))
	_fill([[-14, 4], [8, 4], [3, 27], [-20, 24]], _poly)
	_rect(-6, -15, 14, 5, _accent)
	_line([long * 0.2, -9], [long * 0.2, -15], _poly, 2.0)
	_line([long * 0.45, -9], [long * 0.45, -15], _poly, 2.0)
	if weapon_id == WeaponData.WeaponId.AK47:
		_polyline([[-long * 0.75, 4], [-long * 0.4, 14], [-long * 0.1, 10]], _accent, 2.0)
	if weapon_id == WeaponData.WeaponId.AUG or weapon_id == WeaponData.WeaponId.SG553:
		_rect(8, -19, 20, 7, _poly)
		draw_circle(_pt(28, -15), 4 * _s, _metal)


func _draw_sniper(w: Dictionary) -> void:
	var long: float = 66.0 + (10.0 if weapon_id == WeaponData.WeaponId.AWP else 0.0)
	_fill([[-long * 0.6, -6], [long * 0.75, -6], [long * 0.8, 3], [-long * 0.65, 3]], _metal)
	_rect(long * 0.6, -3, long * 0.65, 3, _metal.darkened(0.2))
	_fill([[-long * 0.6, -6], [-long, -3], [-long - 2, 10], [-long * 0.5, 10]], _poly)
	_rect(-16, -14, 44, 7, _poly)
	draw_circle(_pt(-16, -10), 5 * _s, _metal)
	draw_circle(_pt(28, -10), 5 * _s, _metal)
	_fill([[-8, 3], [8, 3], [5, 22], [-12, 22]], _poly)
	_line([22, -6], [31, -17], _accent, 2.0)


func _draw_heavy(w: Dictionary) -> void:
	var lmg: bool = weapon_id == WeaponData.WeaponId.M249 or weapon_id == WeaponData.WeaponId.NEGEV
	var long: float = 52.0 if lmg else 44.0
	_fill([[-long * 0.7, -9], [long * 0.7, -9], [long * 0.8, 4], [-long * 0.75, 4]], _metal)
	_rect(long * 0.55, -5, long * 0.6, 5, _metal.darkened(0.2))
	_fill([[-long * 0.7, -9], [-long, -4], [-long, 9], [-long * 0.6, 9]], _poly)
	if lmg:
		draw_circle(_pt(-2, 14), 13 * _s, _poly)
		draw_circle(_pt(-2, 14), 8 * _s, _accent)
		_line([20, 4], [26, 18], _poly, 2.0)
		_line([34, 4], [40, 18], _poly, 2.0)
	else:
		_rect(-4, 3, 28, 5, _poly)
		_fill([[-14, 4], [6, 4], [1, 22], [-18, 22]], _poly)
		_rect(long * 0.2, -6, long * 0.55, 4, _metal.darkened(0.3))
	_rect(-8, -14, 16, 5, _accent)


func _draw_knife() -> void:
	_fill([[-34, 3], [-12, 3], [-10, 8], [-36, 8]], _poly)
	_fill([[-10, -4], [34, 0], [-10, 4]], _metal.lightened(0.16))
	_line([-8, 0], [26, 0], _metal.darkened(0.25), 1.0)
	_rect(-20, -5, 10, 10, _accent)


func _draw_grenade(w: Dictionary) -> void:
	var r: float = 16.0
	draw_circle(_c, r * _s, _metal.darkened(0.15))
	draw_circle(_c, r * 0.8 * _s, _metal)
	_rect(-5, -24, 10, 7, _poly)
	_polyline([[-r, -r], [-r + 5, -r - 8], [r - 5, -r - 8], [r, -r]], _metal, 2.0)
	var tint := _accent
	if weapon_id == WeaponData.WeaponId.HE:
		tint = UiTheme.DANGER
	elif weapon_id == WeaponData.WeaponId.FLASH:
		tint = Color(0.90, 0.90, 0.75)
	elif weapon_id == WeaponData.WeaponId.SMOKE:
		tint = Color(0.55, 0.60, 0.65)
	elif weapon_id == WeaponData.WeaponId.MOLOTOV or weapon_id == WeaponData.WeaponId.INCENDIARY:
		tint = UiTheme.WARN
	_rect(-7, -7, 14, 14, tint)


func _draw_bomb() -> void:
	_fill([[-24, -18], [24, -18], [24, 18], [-24, 18]], _poly)
	_fill([[-20, -14], [20, -14], [20, 14], [-20, 14]], _metal.darkened(0.25))
	_rect(-8, -8, 16, 16, UiTheme.DANGER)
	_line([-20, 0], [-8, 0], _accent, 2.0)
	_line([8, 0], [20, 0], _accent, 2.0)
