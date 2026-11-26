extends Node3D
## 3D-сцена главного меню: ванильные карты-фоны, агенты CT/T, подиум, частицы.

const AgentData = preload("res://client/agents.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

# Декоративные версии карт (без геймплея) — только фон меню.
const BACKGROUNDS: Array = [
	{"name": "Янтарный двор", "floor": Color(0.32, 0.26, 0.18), "wall": Color(0.45, 0.36, 0.24), "neon": Color(0.95, 0.70, 0.30), "sky": Color(0.20, 0.16, 0.12)},
	{"name": "Песчаный двор", "floor": Color(0.38, 0.33, 0.25), "wall": Color(0.65, 0.55, 0.38), "neon": Color(0.95, 0.82, 0.45), "sky": Color(0.28, 0.24, 0.18)},
	{"name": "Холодный ангар", "floor": Color(0.18, 0.20, 0.22), "wall": Color(0.30, 0.34, 0.38), "neon": Color(0.30, 0.70, 0.95), "sky": Color(0.10, 0.12, 0.16)},
	{"name": "Городской мост", "floor": Color(0.25, 0.28, 0.30), "wall": Color(0.38, 0.42, 0.45), "neon": Color(0.40, 0.85, 0.90), "sky": Color(0.14, 0.18, 0.20)},
	{"name": "Кирпичный двор", "floor": Color(0.35, 0.28, 0.20), "wall": Color(0.58, 0.42, 0.28), "neon": Color(1.0, 0.55, 0.20), "sky": Color(0.26, 0.18, 0.12)},
	{"name": "Зелёный храм", "floor": Color(0.20, 0.30, 0.22), "wall": Color(0.32, 0.45, 0.32), "neon": Color(0.40, 0.95, 0.55), "sky": Color(0.10, 0.20, 0.14)},
	{"name": "Древний дворец", "floor": Color(0.36, 0.30, 0.24), "wall": Color(0.68, 0.55, 0.38), "neon": Color(1.0, 0.80, 0.40), "sky": Color(0.30, 0.22, 0.16)},
	{"name": "Высотка", "floor": Color(0.20, 0.22, 0.26), "wall": Color(0.32, 0.36, 0.42), "neon": Color(0.35, 0.65, 1.0), "sky": Color(0.08, 0.10, 0.16)},
	{"name": "Офисный холл", "floor": Color(0.28, 0.28, 0.30), "wall": Color(0.45, 0.46, 0.50), "neon": Color(0.70, 0.80, 0.95), "sky": Color(0.16, 0.17, 0.20)},
	{"name": "Средиземный двор", "floor": Color(0.42, 0.35, 0.25), "wall": Color(0.72, 0.60, 0.42), "neon": Color(1.0, 0.85, 0.50), "sky": Color(0.32, 0.26, 0.18)},
	{"name": "Багажный терминал", "floor": Color(0.24, 0.26, 0.30), "wall": Color(0.38, 0.42, 0.48), "neon": Color(0.45, 0.75, 0.95), "sky": Color(0.12, 0.14, 0.18)},
	{"name": "Склад", "floor": Color(0.26, 0.25, 0.24), "wall": Color(0.40, 0.38, 0.36), "neon": Color(0.95, 0.60, 0.30), "sky": Color(0.16, 0.15, 0.14)},
	{"name": "Ночной храм", "floor": Color(0.12, 0.18, 0.16), "wall": Color(0.18, 0.28, 0.24), "neon": Color(0.30, 0.80, 0.60), "sky": Color(0.04, 0.07, 0.10)},
]

var agent_view: Node3D
var agent_display: Node3D
var pedestal: Node3D
var camera: Camera3D
var time_sec: float = 0.0

var agent_data: AgentData
var current_agent_index: int = 0
var current_team: int = WeaponData.Team.T
var bg_index: int = 0
var bg_root: Node3D
var lights: Array = []
var detail_texture: NoiseTexture2D


func _ready() -> void:
	agent_data = AgentData.new()
	detail_texture = _make_detail_texture()
	bg_root = Node3D.new()
	bg_root.name = "Background"
	add_child(bg_root)
	_setup_pedestal()
	_setup_camera()
	_setup_particles()
	set_background(0)
	set_team(WeaponData.Team.T)


func set_background(index: int) -> void:
	bg_index = posmod(index, BACKGROUNDS.size())
	for c in bg_root.get_children():
		c.queue_free()
	for l in lights:
		if is_instance_valid(l):
			l.queue_free()
	lights.clear()
	var cfg: Dictionary = BACKGROUNDS[bg_index]
	var mat_floor := _detail_material(cfg.floor, 0.9, 8.0)
	_add_bg_box("Floor", Vector3(0, -0.2, 0), Vector3(40, 0.4, 40), mat_floor)
	var mat_wall := _detail_material(cfg.wall, 0.95, 5.0)
	_add_bg_box("Wall", Vector3(0, 4, -6), Vector3(40, 10, 0.5), mat_wall)
	var mat_pillar := _detail_material(cfg.wall.darkened(0.35), 0.9, 2.0)
	for x in [-8, -4, 4, 8]:
		_add_bg_box("Pillar_%d" % int(x), Vector3(x, 3, -4), Vector3(1.2, 6, 1.2), mat_pillar)
		_add_bg_box("PillarCap_%d" % int(x), Vector3(x, 6.1, -4), Vector3(1.6, 0.3, 1.6), mat_pillar)
	var mat_neon := StandardMaterial3D.new()
	mat_neon.albedo_color = cfg.neon
	mat_neon.emission = cfg.neon
	mat_neon.emission_energy = 1.8
	for x in [-8, -4, 4, 8]:
		_add_bg_box("Neon_%d" % int(x), Vector3(x, 3, -3.35), Vector3(0.15, 5.5, 0.05), mat_neon)
	for z in [-4, 0, 4]:
		_add_bg_box("FloorLine_%d" % int(z), Vector3(0, 0.01, z), Vector3(30, 0.02, 0.08), mat_neon)
	_add_bg_box("Logo", Vector3(0, 6, -5.7), Vector3(6, 1.2, 0.1), mat_neon)
	# архитектурный рельеф: ящики, перила, балки и ступени
	var mat_crate := _detail_material(cfg.wall.darkened(0.2), 0.85, 1.5)
	var crate_positions := [Vector3(-6, 0.5, 1), Vector3(-5.2, 1.35, 1), Vector3(6, 0.5, 2),
		Vector3(5.2, 0.5, 2), Vector3(7, 0.5, -1), Vector3(-7, 0.5, -1)]
	for i in range(crate_positions.size()):
		_add_bg_box("Crate_%d" % i, crate_positions[i], Vector3(1.2, 1.0, 1.2), mat_crate)
	for i in range(4):
		_add_bg_box("Step_%d" % i, Vector3(0, 0.05 + i * 0.08, 3.6 - i * 0.45),
			Vector3(5.0, 0.1 + i * 0.16, 0.5), mat_pillar)
	for x in [-10, 10]:
		_add_bg_box("RailPost_%d" % int(x), Vector3(x, 0.8, -2), Vector3(0.14, 1.6, 0.14), mat_neon)
		_add_bg_box("RailTop_%d" % int(x), Vector3(x * 0.7, 1.6, -2), Vector3(7.0, 0.08, 0.08), mat_neon)
	for x in [-6, 0, 6]:
		_add_bg_box("Beam_%d" % int(x), Vector3(x, 6.6, -3), Vector3(0.3, 0.3, 8), mat_pillar)
	# свет под цвет карты
	var sun := DirectionalLight3D.new()
	sun.light_color = cfg.neon.lerp(Color.WHITE, 0.5)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	lights.append(sun)
	var key := OmniLight3D.new()
	key.light_color = cfg.neon
	key.light_energy = 28.0
	key.omni_range = 14.0
	key.position = Vector3(0, 4, 2)
	add_child(key)
	lights.append(key)
	var rim := OmniLight3D.new()
	rim.light_color = cfg.neon.darkened(0.4)
	rim.light_energy = 16.0
	rim.omni_range = 10.0
	rim.position = Vector3(-4, 3, -2)
	add_child(rim)
	lights.append(rim)
	if camera != null:
		camera.environment = null


func next_background() -> void:
	set_background(bg_index + 1)


func prev_background() -> void:
	set_background(bg_index - 1)


func background_name() -> String:
	return String(BACKGROUNDS[bg_index].name)


func _setup_pedestal() -> void:
	pedestal = Node3D.new()
	pedestal.name = "Pedestal"
	pedestal.position = Vector3(0, 0, 0)
	add_child(pedestal)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.22)
	mat.metallic = 0.4
	_add_child_box(pedestal, "Base", Vector3(0, 0.1, 0), Vector3(2.4, 0.2, 2.4), mat)
	var mat_ring := StandardMaterial3D.new()
	mat_ring.albedo_color = Color(0.2, 0.8, 1.0)
	mat_ring.emission = Color(0.1, 0.6, 1.0)
	mat_ring.emission_energy = 2.0
	_add_child_box(pedestal, "Ring", Vector3(0, 0.21, 0), Vector3(2.5, 0.04, 2.5), mat_ring)
	agent_display = Node3D.new()
	agent_display.name = "AgentDisplay"
	agent_display.position = Vector3(0, 0.22, 0)
	pedestal.add_child(agent_display)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "LobbyCamera"
	camera.fov = 42.0
	camera.look_at_from_position(Vector3(0, 1.9, 6.2), Vector3(0, 1.1, 0), Vector3.UP)
	add_child(camera)


func _setup_particles() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.position = Vector3(0, 3, 0)
	dust.amount = 90
	dust.lifetime = 8.0
	dust.emitting = true
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 45.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.scale_amount_min = 0.02
	dust.scale_amount_max = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.8, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var alpha: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	var tex := ImageTexture.create_from_image(img)
	mat.albedo_texture = tex
	dust.mesh = quad
	dust.material_override = mat
	var shape := BoxMesh.new()
	shape.size = Vector3(14, 6, 10)
	dust.emission_box_extents = shape.size * 0.5
	add_child(dust)


func _make_detail_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	return tex


func _detail_material(base: Color, roughness: float, uv_scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.albedo_texture = detail_texture
	mat.roughness = roughness
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return mat


func set_team(team: int) -> void:
	current_team = team
	var list: Array = agent_data.by_team(team)
	if list.is_empty():
		return
	# показывать экипированного агента, если он есть
	var eq = agent_data.equipped(team)
	current_agent_index = 0
	for i in range(list.size()):
		if list[i].id == eq.id:
			current_agent_index = i
			break
	_show_agent(list[current_agent_index])


func next_agent() -> void:
	var list: Array = agent_data.by_team(current_team)
	if list.is_empty():
		return
	current_agent_index = (current_agent_index + 1) % list.size()
	_show_agent(list[current_agent_index])


func prev_agent() -> void:
	var list: Array = agent_data.by_team(current_team)
	if list.is_empty():
		return
	current_agent_index = (current_agent_index - 1 + list.size()) % list.size()
	_show_agent(list[current_agent_index])


func current_agent():
	var list: Array = agent_data.by_team(current_team)
	if list.is_empty():
		return null
	return list[current_agent_index]


func _show_agent(agent) -> void:
	if agent_view != null and is_instance_valid(agent_view):
		agent_view.queue_free()
	var path: String = "res://assets/agents/attacker.glb" if agent.team == WeaponData.Team.T 		else "res://assets/agents/defender.glb"
	var packed: PackedScene = load(path) if FileAccess.file_exists(path) else null
	if packed != null:
		agent_view = packed.instantiate()
		agent_view.name = "AgentGLB_" + String(agent.id)
	else:
		agent_view = agent_data.build_voxel_model(agent)
	agent_display.add_child(agent_view)
	agent_view.rotation.y = 0.0


func _process(delta: float) -> void:
	time_sec += delta
	if agent_view != null and is_instance_valid(agent_view):
		agent_view.rotation.y += delta * 0.35
		agent_view.position.y = sin(time_sec * 1.5) * 0.02
	if camera != null:
		var target := Vector3(sin(time_sec * 0.18) * 0.35, 1.9 + sin(time_sec * 0.3) * 0.04, 6.2)
		camera.position = camera.position.lerp(target, delta * 1.5)
		camera.look_at(Vector3(0, 1.1, 0), Vector3.UP)


func _add_bg_box(name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	_add_child_box(bg_root, name, pos, size, mat)


func _add_child_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
