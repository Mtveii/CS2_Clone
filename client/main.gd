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
const VoxelMapLoader = preload("res://shared/voxel/voxel_map_loader.gd")
const GameHUD = preload("res://client/game_hud.gd")
const PlayerState = preload("res://shared/gameplay/player_state.gd")

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
var hud: GameHUD
var player_state: PlayerState
var last_server_pos_u: Vector3 = Vector3.ZERO
var have_server_pos: bool = false


func _ready() -> void:
	_setup_world()
	_setup_mesh()
	_setup_camera()
	_resolve_server_url()
	movement = MovementModel.new()
	var spawn_u := Vector3(0.0, ground_u_at(Vector3(0, 0, 0)) + 0.2, 0.0)
	movement.reset(spawn_u)
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
	player_state = PlayerState.new()
	player_state.team = loadout.team
	hud = GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.setup(loadout, func(_id): _on_weapon_bought())
	hud.set_player_state(player_state)
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(server_url)
	if err != OK:
		push_error("ws connect error: " + str(err))
	else:
		print("client connecting to ", server_url)


func _setup_world() -> void:
	world = VoxelWorldStore.new()
	world.bounds_min = Vector3i(-128, -8, -128)
	world.bounds_max = Vector3i(128, 64, 128)
	# CC0-карта Oasis (Hard Cover), сконвертированная в VMAP
	var res = VoxelMapLoader.load_map("res://assets/maps/oasis.vmap", world)
	if not res.ok or int(res.loaded) == 0:
		# fallback: простая коробка
		world.bounds_min = Vector3i(-8, -8, -8)
		world.bounds_max = Vector3i(8, 8, 8)
		world.edit_box(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000), 100000)
		world.edit_sphere(Vector3(0, 0, 0), 600, 100000)
	else:
		print("loaded Oasis map: ", res.loaded, " voxels")


func _setup_mesh() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.75)
	for cc in world.all_chunk_coords():
		var mesh = VoxelMeshGen.build(world, cc, VoxelMeshGen.SURFACE_NETS)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		add_child(mi)
		if mesh_instance == null:
			mesh_instance = mi


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
			if anim.events.has("defuse_done") and hud != null:
				hud.message("Бомба обезврежена")
		if viewmodel != null:
			viewmodel.position = Vector3(0.28, -0.25, -0.55) + anim.pos_offset
			viewmodel.rotation = anim.rot_offset

	# движение (локальное предсказание)
	var move_x: float = 0.0
	var move_z: float = 0.0
	if Input.is_key_pressed(KEY_A): move_x -= 1.0
	if Input.is_key_pressed(KEY_D): move_x += 1.0
	if Input.is_key_pressed(KEY_W): move_z += 1.0
	if Input.is_key_pressed(KEY_S): move_z -= 1.0
	var buttons: int = 0
	if Input.is_key_pressed(KEY_SPACE): buttons |= MovementModel.Buttons.JUMP
	if Input.is_key_pressed(KEY_CTRL): buttons |= MovementModel.Buttons.CROUCH
	if Input.is_key_pressed(KEY_SHIFT): buttons |= MovementModel.Buttons.WALK
	var yaw_units: int = int(posmod(yaw / TAU, 1.0) * 65536.0) % 65536
	var pitch_units: int = int(clampf(pitch / 1.2, -1.0, 1.0) * 32767.0)
	var no_ladder := func(_p): return false
	movement.step(buttons, move_x, move_z, yaw_units, pitch_units, delta,
			Callable(self, "ground_u_at"), no_ladder)

	# камера
	if camera != null:
		camera.position = movement.to_meters() + Vector3(0, 1.55, 0)
		camera.rotation_order = EULER_ORDER_YXZ
		camera.rotation = Vector3(pitch, yaw, 0.0)

	if ws == null:
		return
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("client connected")
		ws.send(NetProtocol.encode_hello("web-client", 0))
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var pkt = ws.get_packet()
			if pkt.size() > 3 and pkt[0] == NetProtocol.MsgType.SNAPSHOT:
				_parse_snapshot(pkt)
	# отправка ввода
	seq += 1
	if connected and seq % 3 == 0:
		var net_buttons: int = 0
		if (buttons & MovementModel.Buttons.JUMP) != 0: net_buttons |= NetProtocol.Buttons.JUMP
		if (buttons & MovementModel.Buttons.CROUCH) != 0: net_buttons |= NetProtocol.Buttons.CROUCH
		if fire_bit: net_buttons |= NetProtocol.Buttons.FIRE
		if reload_bit: net_buttons |= NetProtocol.Buttons.RELOAD
		ws.send(NetProtocol.encode_input(seq, net_buttons, int(move_x * 32767), int(move_z * 32767), yaw_units, pitch_units, 16))
		fire_bit = false
		reload_bit = false


func _parse_snapshot(pkt: PackedByteArray) -> void:
	# u8 type, u32 tick, u16 count, перый игрок: u32 id, i32 x,y,z(mm), i32 yaw,pitch, u16 flags, u16 hp
	if pkt.size() < 23:
		return
	var o: int = 5
	var count: int = pkt[o] | (pkt[o + 1] << 8)
	o += 2
	if count == 0:
		return
	o += 4  # player id
	var x_mm: int = _i32(pkt, o); o += 4
	var y_mm: int = _i32(pkt, o); o += 4
	var z_mm: int = _i32(pkt, o); o += 4
	var server_u := Vector3(float(x_mm), float(y_mm), float(z_mm)) / 19.05
	if o + 12 <= pkt.size() and player_state != null:
		var hp: int = pkt[o + 10] | (pkt[o + 11] << 8)
		if hp > 0 and hp != player_state.hp:
			player_state.hp = hp
			if hp <= 0:
				player_state.alive = false
			hud.refresh()
	if not have_server_pos:
		last_server_pos_u = server_u
		have_server_pos = true
	else:
		last_server_pos_u = last_server_pos_u.lerp(server_u, 0.5)
	# мягкая корректировка только при сильном расхождении
	var d: float = movement.pos_u.distance_to(last_server_pos_u)
	if d > 6.0:
		movement.pos_u = movement.pos_u.lerp(last_server_pos_u, 0.15)


func _i32(buf: PackedByteArray, o: int) -> int:
	return buf[o] | (buf[o + 1] << 8) | (buf[o + 2] << 16) | (buf[o + 3] << 24)


func ground_u_at(p_u: Vector3) -> float:
	if world == null:
		return 0.0
	var p_mm: Vector3 = p_u * 19.05
	var v: Vector3i = world.world_mm_to_voxel(p_mm)
	for yy in range(v.y + 2, int(world.bounds_min.y) - 1, -1):
		if world.get_sdf_voxel(Vector3i(v.x, yy, v.z)) <= 0:
			return float(yy + 1) * float(world.voxel_size_mm) / 19.05
	return 0.0


func _on_weapon_bought() -> void:
	var wi = loadout.active()
	if wi != null and wi.id >= 0:
		anim.set_weapon(wi.id)
	hud.refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.005
		pitch -= event.relative.y * 0.005
		pitch = clamp(pitch, -1.2, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if hud != null and hud.buy_open:
				return
			var shot = loadout.fire(Time.get_ticks_msec())
			if shot.fired:
				if anim.request_fire():
					fire_bit = true
				if hud != null:
					hud.refresh()
			elif hud != null:
				hud.message("Нет патронов — нажмите R")
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			if hud != null:
				hud.toggle_buy()
		elif event.keycode == KEY_R and anim != null:
			if loadout.reload(Time.get_ticks_msec()):
				if anim.request_reload():
					reload_bit = true
				if hud != null:
					hud.refresh()
		elif event.keycode == KEY_F and anim != null:
			anim.request_inspect()
		elif event.keycode == KEY_Q and anim != null:
			anim.request_melee()
		elif event.keycode == KEY_E and anim != null:
			if anim.request_defuse() and hud != null:
				hud.message("Обезвреживание бомбы...")


func _resolve_server_url() -> void:
	## В web подключаемся к тому же origin (прокси -> игровой сервер),
	## иначе mixed content блокирует ws:// со страницы https://.
	if not OS.has_feature("web"):
		return
	var proto: String = String(JavaScriptBridge.eval("window.location.protocol"))
	var host: String = String(JavaScriptBridge.eval("window.location.host"))
	if host.is_empty():
		host = "127.0.0.1:8080"
	server_url = "wss://" + host + "/ws" if proto == "https:" else "ws://" + host + "/ws"
