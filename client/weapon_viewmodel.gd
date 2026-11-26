extends Node3D
## Процедурная модель оружия от первого лица: корпус, ствол, магазин,
## прицел + руки в перчатках. Собирается по слоту оружия, поэтому дробовик
## не выглядит как винтовка, а нож — как автомат.
## Все меши — примитивы Godot, никаких чужих/копирайтных моделей.

const WeaponData = preload("res://shared/gameplay/weapons.gd")

const GUNMETAL := Color(0.085, 0.09, 0.10)
const POLYMER := Color(0.12, 0.13, 0.14)
const WOOD := Color(0.34, 0.19, 0.09)
const ACCENT := Color(0.42, 0.34, 0.16)
const GLOVE := Color(0.14, 0.13, 0.12)
const SLEEVE := Color(0.15, 0.19, 0.24)

var weapon_id: int = WeaponData.WeaponId.AK47
var model_root: Node3D
var hands: Array = []
var model_name: String = ""
var muzzle_pos: Vector3 = Vector3(0, 0.012, -0.46)


func _ready() -> void:
	_ensure_root()


func _ensure_root() -> void:
	if model_root != null:
		return
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)


## Пересобрать модель под оружие. Вызывается при покупке/смене слота.
func set_weapon(id: int) -> void:
	weapon_id = id
	_ensure_root()
	for c in model_root.get_children():
		model_root.remove_child(c)
		c.free()
	hands.clear()

	var w: Dictionary = WeaponData.get_weapon(id)
	var slot: String = String(w.get("slot", "rifle"))
	var pellets: int = int(w.get("pellets", 1))
	match slot:
		"pistol":
			_build_pistol()
		"smg":
			_build_rifle(0.8, false)
		"rifle":
			_build_rifle(1.0, false, id == WeaponData.WeaponId.AK47 or id == WeaponData.WeaponId.GALIL)
		"sniper":
			_build_sniper()
		"heavy":
			if pellets > 1:
				_build_shotgun()
			else:
				_build_lmg()
		"melee":
			_build_knife()
		"grenade":
			_build_grenade(id)
		"objective":
			_build_c4()
		_:
			_build_rifle(1.0, false)
	model_name = String(w.get("name", "Weapon"))
	add_muzzle_marker()


func add_muzzle_marker() -> Node3D:
	var m := Node3D.new()
	m.name = "Muzzle"
	m.position = muzzle_pos
	model_root.add_child(m)
	return m


# --- Конструкторы моделей -------------------------------------------------

func _build_rifle(body_scale: float, long_barrel: bool, wooden: bool = false) -> void:
	var accent: Color = WOOD if wooden else POLYMER
	muzzle_pos = Vector3(0, 0.010, -0.40 - (0.34 if long_barrel else 0.30) * 0.5)
	var s: float = body_scale
	_box(Vector3(0.062, 0.078, 0.30) * s, Vector3(0, -0.005, -0.12), GUNMETAL)
	_box(Vector3(0.055, 0.048, 0.18) * s, Vector3(0, 0.034, -0.18), accent)
	_cyl(0.011, 0.34 if long_barrel else 0.30, Vector3(0, 0.010, -0.40), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.050, 0.078, 0.14) * s, Vector3(0, 0.0, 0.13), accent)
	_box(Vector3(0.066, 0.016, 0.13), Vector3(0, 0.062, -0.06), GUNMETAL)
	_box(Vector3(0.012, 0.050, 0.012), Vector3(0, 0.020, -0.38), GUNMETAL)
	_box(Vector3(0.034, 0.105, 0.055), Vector3(0, -0.078, 0.015), POLYMER, Vector3(-12, 0, 0))
	_box(Vector3(0.050, 0.135, 0.090), Vector3(0, -0.105, -0.095), GUNMETAL, Vector3(-8, 0, 0))
	_box(Vector3(0.026, 0.030, 0.060), Vector3(0.026, 0.010, -0.10), POLYMER)
	_hand(Vector3(0.028, -0.082, 0.030))
	_hand(Vector3(-0.004, -0.062, -0.175))
	_arm(Vector3(0.22, -0.38, 0.26), Vector3(0.028, -0.082, 0.030))
	_arm(Vector3(-0.20, -0.40, 0.18), Vector3(-0.004, -0.062, -0.175))


func _build_pistol() -> void:
	muzzle_pos = Vector3(0, 0.020, -0.270)
	_box(Vector3(0.050, 0.058, 0.200), Vector3(0, 0.020, -0.13), GUNMETAL)
	_box(Vector3(0.045, 0.034, 0.140), Vector3(0, -0.022, -0.10), POLYMER)
	_cyl(0.009, 0.070, Vector3(0, 0.020, -0.235), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.042, 0.105, 0.058), Vector3(0, -0.072, 0.020), POLYMER, Vector3(-15, 0, 0))
	_box(Vector3(0.036, 0.018, 0.070), Vector3(0, -0.040, -0.045), POLYMER)
	_box(Vector3(0.012, 0.028, 0.012), Vector3(0, 0.054, -0.225), GUNMETAL)
	_hand(Vector3(0.020, -0.070, 0.020))
	_hand(Vector3(-0.010, -0.072, 0.004))
	_arm(Vector3(0.21, -0.37, 0.24), Vector3(0.020, -0.070, 0.020))
	_arm(Vector3(-0.18, -0.36, 0.16), Vector3(-0.010, -0.072, 0.004))


func _build_sniper() -> void:
	muzzle_pos = Vector3(0, 0.012, -0.770)
	_box(Vector3(0.060, 0.075, 0.32), Vector3(0, -0.005, -0.10), GUNMETAL)
	_box(Vector3(0.052, 0.055, 0.20), Vector3(0, 0.0, 0.16), POLYMER)
	_box(Vector3(0.040, 0.075, 0.13), Vector3(0, 0.052, 0.02), POLYMER)
	_cyl(0.010, 0.52, Vector3(0, 0.012, -0.50), GUNMETAL, Vector3(90, 0, 0))
	_cyl(0.020, 0.18, Vector3(0, 0.075, -0.06), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.014, 0.040, 0.014), Vector3(0, 0.020, -0.72), GUNMETAL)
	_box(Vector3(0.034, 0.105, 0.055), Vector3(0, -0.078, 0.03), POLYMER, Vector3(-12, 0, 0))
	_box(Vector3(0.048, 0.100, 0.080), Vector3(0, -0.090, -0.05), GUNMETAL, Vector3(-6, 0, 0))
	_box(Vector3(0.020, 0.090, 0.020), Vector3(0, -0.13, -0.30), GUNMETAL, Vector3(0, 0, 18))
	_box(Vector3(0.020, 0.090, 0.020), Vector3(0, -0.13, -0.30), GUNMETAL, Vector3(0, 0, -18))
	_hand(Vector3(0.028, -0.080, 0.035))
	_hand(Vector3(-0.004, -0.060, -0.205))
	_arm(Vector3(0.22, -0.38, 0.26), Vector3(0.028, -0.080, 0.035))
	_arm(Vector3(-0.20, -0.40, 0.18), Vector3(-0.004, -0.060, -0.205))


func _build_shotgun() -> void:
	muzzle_pos = Vector3(0, 0.020, -0.620)
	_box(Vector3(0.060, 0.070, 0.26), Vector3(0, -0.004, -0.10), GUNMETAL)
	_cyl(0.020, 0.42, Vector3(0, 0.020, -0.40), GUNMETAL, Vector3(90, 0, 0))
	_cyl(0.014, 0.30, Vector3(0, -0.030, -0.34), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.070, 0.060, 0.16), Vector3(0, -0.018, -0.30), WOOD)
	_box(Vector3(0.052, 0.085, 0.18), Vector3(0, -0.004, 0.18), WOOD)
	_box(Vector3(0.034, 0.095, 0.050), Vector3(0, -0.065, 0.02), WOOD, Vector3(-14, 0, 0))
	_hand(Vector3(0.025, -0.075, 0.030))
	_hand(Vector3(-0.006, -0.058, -0.285))
	_arm(Vector3(0.22, -0.38, 0.26), Vector3(0.025, -0.075, 0.030))
	_arm(Vector3(-0.20, -0.40, 0.18), Vector3(-0.006, -0.058, -0.285))


func _build_lmg() -> void:
	muzzle_pos = Vector3(0, 0.012, -0.670)
	_box(Vector3(0.075, 0.090, 0.38), Vector3(0, -0.005, -0.10), GUNMETAL)
	_box(Vector3(0.060, 0.060, 0.20), Vector3(0, 0.040, -0.22), POLYMER)
	_cyl(0.012, 0.40, Vector3(0, 0.012, -0.46), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.060, 0.090, 0.16), Vector3(0, 0.0, 0.20), POLYMER)
	_cyl(0.075, 0.055, Vector3(0, -0.100, -0.10), GUNMETAL, Vector3(0, 0, 90))
	_box(Vector3(0.036, 0.110, 0.055), Vector3(0, -0.080, 0.045), POLYMER, Vector3(-12, 0, 0))
	_hand(Vector3(0.030, -0.085, 0.050))
	_hand(Vector3(-0.008, -0.060, -0.230))
	_arm(Vector3(0.23, -0.39, 0.27), Vector3(0.030, -0.085, 0.050))
	_arm(Vector3(-0.21, -0.41, 0.19), Vector3(-0.008, -0.060, -0.230))


func _build_knife() -> void:
	muzzle_pos = Vector3(0, 0.010, -0.310)
	_box(Vector3(0.012, 0.032, 0.220), Vector3(0, 0.010, -0.20), Color(0.62, 0.64, 0.66))
	_box(Vector3(0.014, 0.012, 0.180), Vector3(0.006, 0.026, -0.21), Color(0.80, 0.82, 0.84))
	_box(Vector3(0.030, 0.040, 0.110), Vector3(0, -0.006, 0.010), Color(0.10, 0.10, 0.11))
	_box(Vector3(0.040, 0.012, 0.030), Vector3(0, 0.010, -0.035), GUNMETAL)
	_hand(Vector3(0.004, -0.028, 0.020))
	_arm(Vector3(0.20, -0.35, 0.24), Vector3(0.004, -0.028, 0.020))


func _build_grenade(id: int) -> void:
	muzzle_pos = Vector3(0, -0.030, -0.100)
	var col := Color(0.22, 0.30, 0.18)
	if id == WeaponData.WeaponId.FLASH:
		col = Color(0.55, 0.55, 0.50)
	elif id == WeaponData.WeaponId.SMOKE:
		col = Color(0.30, 0.34, 0.36)
	elif id == WeaponData.WeaponId.MOLOTOV or id == WeaponData.WeaponId.INCENDIARY:
		col = Color(0.45, 0.18, 0.10)
	_sphere(0.040, Vector3(0, -0.030, -0.06), col)
	_box(Vector3(0.030, 0.018, 0.050), Vector3(0, 0.012, -0.06), GUNMETAL)
	_box(Vector3(0.010, 0.045, 0.010), Vector3(0.020, 0.020, -0.06), Color(0.55, 0.55, 0.58))
	_hand(Vector3(0.010, -0.050, -0.02))
	_arm(Vector3(0.21, -0.37, 0.24), Vector3(0.010, -0.050, -0.02))


func _build_c4() -> void:
	muzzle_pos = Vector3(0, 0.012, -0.150)
	_box(Vector3(0.130, 0.075, 0.090), Vector3(0, -0.030, -0.10), Color(0.30, 0.28, 0.22))
	_box(Vector3(0.060, 0.020, 0.050), Vector3(0, 0.010, -0.10), Color(0.12, 0.13, 0.12))
	_box(Vector3(0.020, 0.010, 0.020), Vector3(-0.015, 0.022, -0.10), Color(0.30, 0.80, 0.35))
	_box(Vector3(0.012, 0.012, 0.012), Vector3(0.015, 0.022, -0.10), Color(0.85, 0.20, 0.15))
	_cyl(0.003, 0.060, Vector3(0.040, 0.020, -0.10), Color(0.55, 0.55, 0.58), Vector3(90, 0, 0))
	_hand(Vector3(0.030, -0.035, 0.000))
	_arm(Vector3(0.22, -0.37, 0.24), Vector3(0.030, -0.035, 0.000))


# --- Примитивы ------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _mesh_instance(mesh, color)
	mi.name = "Part"
	mi.position = pos
	mi.rotation_degrees = rot_deg
	model_root.add_child(mi)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 2
	var mi := _mesh_instance(mesh, color)
	mi.name = "Barrel"
	mi.position = pos
	mi.rotation_degrees = rot_deg
	model_root.add_child(mi)
	return mi


func _sphere(radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _mesh_instance(mesh, color)
	mi.name = "GrenadeBody"
	mi.position = pos
	model_root.add_child(mi)
	return mi


func _hand(pos: Vector3) -> void:
	var h := _box(Vector3(0.052, 0.062, 0.078), pos, GLOVE, Vector3(-10, 0, 0))
	h.name = "RightHand" if hands.is_empty() else "LeftHand"
	hands.append(h)
	# Большой палец, чтобы кисть не выглядела кубиком.
	_box(Vector3(0.018, 0.020, 0.050), pos + Vector3(0.028, 0.012, -0.010), GLOVE,
			Vector3(-10, 0, -18))


func _arm(from: Vector3, to: Vector3) -> void:
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.001:
		return
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.036
	mesh.height = length + 0.04
	mesh.radial_segments = 12
	mesh.rings = 4
	var mi := _mesh_instance(mesh, SLEEVE)
	mi.name = "Arm"
	mi.position = (from + to) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	model_root.add_child(mi)


func _mesh_instance(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55 if color == GUNMETAL else 0.85
	mat.metallic = 0.6 if color == GUNMETAL else 0.0
	mi.material_override = mat
	return mi
