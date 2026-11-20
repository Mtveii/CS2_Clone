extends Node3D
## Web client entry point (Phase 0/1).
## Renders a voxel chunk and connects to the WSS server.

const VoxelConstDefs = preload("res://shared/voxel/voxel_constants.gd")
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")
const NetProtocol = preload("res://shared/protocol/net_protocol.gd")
const MovementModel = preload("res://shared/gameplay/movement.gd")
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const AudioManager = preload("res://client/audio_manager.gd")
const GameSettings = preload("res://client/settings.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")

@export var server_url: String = "ws://127.0.0.1:7777"

var world: VoxelWorldStore
var mesh_instance: MeshInstance3D
var ws: WebSocketPeer
var connected: bool = false
var movement: MovementModel
var yaw: float = 0.0
var pitch: float = 0.0
var seq: int = 0
var anim: WeaponAnimController
var audio: AudioManager
var settings: GameSettings
var loadout: Loadout
var viewmodel: MeshInstance3D
var camera: Camera3D
var fire_bit: bool = false
var reload_bit: bool = false


func _ready() -> void:
	_setup_world()
	_setup_mesh()
	_setup_camera()
	movement = MovementModel.new()
	movement.reset(Vector3(0, 2, 0))
	settings = GameSettings.new()
	settings.load_settings()
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	audio.update_settings(settings)
	loadout = Loadout.new(WeaponData.Team.T, 16000)
	loadout.give(WeaponData.WeaponId.AK47)
	anim = WeaponAnimController.new()
	anim.set_weapon(WeaponData.WeaponId.AK47)
	anim.reset()
	_setup_viewmodel()
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(server_url)
	if err != OK:
		push_error("ws connect error: " + str(err))
	else:
		print("client connecting to ", server_url)


func _setup_world() -> void:
	world = VoxelWorldStore.new()
	world.bounds_min = Vector3i(-8, -8, -8)
	world.bounds_max = Vector3i(8, 8, 8)
	# solid box in the middle
	world.edit_box(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000), 100000)
	# carve a hole
	world.edit_sphere(Vector3(0, 0, 0), 600, 100000)


func _setup_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	var mesh = VoxelMeshGen.build(world, Vector3i(0, 0, 0), VoxelMeshGen.SURFACE_NETS)
	mesh_instance.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.75)
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3, 6)
	add_child(camera)


func _setup_viewmodel() -> void:
	if camera == null:
		return
	viewmodel = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.10, 0.55)
	viewmodel.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.19, 0.22)
	viewmodel.material_override = mat
	viewmodel.position = Vector3(0.28, -0.25, -0.55)
	camera.add_child(viewmodel)


func _process(delta: float) -> void:
	# анимации + звук
	if anim != null:
		anim.tick(delta)
		if anim.events.size() > 0:
			audio.handle_anim_events(anim.events, anim.weapon_id)
		if viewmodel != null:
			viewmodel.position = Vector3(0.28, -0.25, -0.55) + anim.pos_offset
			viewmodel.rotation = anim.rot_offset
	if ws == null:
		return
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("client connected")
		var hello = NetProtocol.encode_hello("web-client", 0)
		ws.send(hello)
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var pkt = ws.get_packet()
			# handle snapshots (type 2) — log only
			if pkt.size() > 0 and pkt[0] == 2:
				pass
	# movement input
	var move_x = 0.0
	var move_z = 0.0
	if Input.is_action_pressed("ui_left"):
		move_x -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_x += 1.0
	if Input.is_action_pressed("ui_up"):
		move_z -= 1.0
	if Input.is_action_pressed("ui_down"):
		move_z += 1.0
	# send input periodically
	seq += 1
	if connected and seq % 3 == 0:
		var buttons: int = 0
		if fire_bit:
			buttons |= NetProtocol.Buttons.FIRE
		if reload_bit:
			buttons |= NetProtocol.Buttons.RELOAD
		var inp = NetProtocol.encode_input(seq, buttons, int(move_x * 32767), int(move_z * 32767), int(yaw * 100), int(pitch * 100), 16)
		ws.send(inp)
		fire_bit = false
		reload_bit = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.005
		pitch -= event.relative.y * 0.005
		pitch = clamp(pitch, -1.2, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and anim != null:
			if anim.request_fire():
				fire_bit = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and anim != null:
			if anim.request_reload():
				reload_bit = true
		elif event.keycode == KEY_F and anim != null:
			anim.request_inspect()
		elif event.keycode == KEY_Q and anim != null:
			anim.request_melee()
