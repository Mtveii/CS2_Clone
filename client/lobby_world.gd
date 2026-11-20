extends Node3D
## 3D-фон лобби: воксельная платформа, колонны, неоновые полосы, пыль, подиум с агентом.

const AgentData = preload("res://client/agents.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

var agent_view: Node3D
var agent_display: Node3D
var pedestal: Node3D
var camera: Camera3D
var time_sec: float = 0.0

var agent_data: AgentData
var current_agent_index: int = 0
var current_team: int = 0


func _ready() -> void:
	agent_data = AgentData.new()
	_setup_world()
	_setup_lights()
	_setup_pedestal()
	_setup_camera()
	_setup_particles()
	set_team(WeaponData.Team.T)


func _setup_world() -> void:
	# пол
	var mat_floor := StandardMaterial3D.new()
	mat_floor.albedo_color = Color(0.10, 0.11, 0.14)
	mat_floor.roughness = 0.9
	_add_box("Floor", Vector3(0, -0.2, 0), Vector3(40, 0.4, 40), mat_floor)
	# задняя стена
	var mat_wall := StandardMaterial3D.new()
	mat_wall.albedo_color = Color(0.07, 0.08, 0.11)
	mat_wall.roughness = 0.95
	_add_box("Wall", Vector3(0, 4, -6), Vector3(40, 10, 0.5), mat_wall)
	# боковые колонны (воксельный стиль)
	var mat_pillar := StandardMaterial3D.new()
	mat_pillar.albedo_color = Color(0.14, 0.16, 0.20)
	for x in [-8, -4, 4, 8]:
		_add_box("Pillar_%d" % int(x), Vector3(x, 3, -4), Vector3(1.2, 6, 1.2), mat_pillar)
	# неоновые полосы
	var mat_neon := StandardMaterial3D.new()
	mat_neon.albedo_color = Color(0.2, 0.8, 1.0)
	mat_neon.emission = Color(0.1, 0.6, 1.0)
	mat_neon.emission_energy = 2.0
	for x in [-8, -4, 4, 8]:
		_add_box("Neon_%d" % int(x), Vector3(x, 3, -3.35), Vector3(0.15, 5.5, 0.05), mat_neon)
	# полосы на полу
	for z in [-4, 0, 4]:
		_add_box("FloorLine_%d" % int(z), Vector3(0, 0.01, z), Vector3(30, 0.02, 0.08), mat_neon)
	# логотип-блок в стене
	var mat_logo := StandardMaterial3D.new()
	mat_logo.albedo_color = Color(0.15, 0.65, 0.9)
	mat_logo.emission = Color(0.1, 0.4, 0.8)
	mat_logo.emission_energy = 1.5
	_add_box("Logo", Vector3(0, 6, -5.7), Vector3(6, 1.2, 0.1), mat_logo)


func _setup_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.8, 0.85, 1.0)
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var key := OmniLight3D.new()
	key.light_color = Color(0.3, 0.7, 1.0)
	key.light_energy = 30.0
	key.omni_range = 14.0
	key.position = Vector3(0, 4, 2)
	add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.5, 0.2)
	rim.light_energy = 18.0
	rim.omni_range = 10.0
	rim.position = Vector3(-4, 3, -2)
	add_child(rim)


func _setup_pedestal() -> void:
	pedestal = Node3D.new()
	pedestal.name = "Pedestal"
	pedestal.position = Vector3(0, 0, 0)
	add_child(pedestal)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.22)
	mat.metallic = 0.4
	_add_box_child(pedestal, "Base", Vector3(0, 0.1, 0), Vector3(2.4, 0.2, 2.4), mat)
	var mat_ring := StandardMaterial3D.new()
	mat_ring.albedo_color = Color(0.2, 0.8, 1.0)
	mat_ring.emission = Color(0.1, 0.6, 1.0)
	mat_ring.emission_energy = 2.0
	_add_box_child(pedestal, "Ring", Vector3(0, 0.21, 0), Vector3(2.5, 0.04, 2.5), mat_ring)
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
	dust.amount = 120
	dust.lifetime = 8.0
	dust.emitting = true
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 45.0
	dust.gravity = Vector3(0, -0.05, 0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.scale_amount_min = 0.02
	dust.scale_amount_max = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.8, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	dust.mesh = quad
	dust.material_override = mat
	var box_shape := BoxMesh.new()
	box_shape.size = Vector3(14, 6, 10)
	dust.emission_box_extents = box_shape.size * 0.5
	add_child(dust)


func set_team(team: int) -> void:
	current_team = team
	var list: Array = agent_data.by_team(team)
	if list.is_empty():
		return
	current_agent_index = 0
	_show_agent(list[0])


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


func _add_box(name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	_add_box_child(self, name, pos, size, mat)


func _add_box_child(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
