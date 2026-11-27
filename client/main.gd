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
const WeaponViewModelScript = preload("res://client/weapon_viewmodel.gd")
const GrenadeSystem = preload("res://shared/gameplay/grenades.gd")
const MapMeshCache = preload("res://shared/voxel/map_mesh_cache.gd")

const VIEWMODEL_BASE := Vector3(0.28, -0.25, -0.55)

@export var server_url: String = "ws://127.0.0.1:7777"

var world: VoxelWorldStore
var mesh_instance: MeshInstance3D
var map_meshes: Array = []
var sun: DirectionalLight3D
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
var viewmodel: Node3D
var camera: Camera3D
var fire_bit: bool = false
var reload_bit: bool = false
var hud: GameHUD
var player_state: PlayerState
var last_server_pos_u: Vector3 = Vector3.ZERO
var have_server_pos: bool = false
var vm_bob_time: float = 0.0
var vm_look: Vector2 = Vector2.ZERO
var vm_sway: Vector2 = Vector2.ZERO
var vm_pos_smooth: Vector3 = VIEWMODEL_BASE
var vm_rot_smooth: Vector3 = Vector3.ZERO
var selected_map: String = "oasis"
var grenades = null
var grenade_meshes: Dictionary = {}


func _ready() -> void:
	_setup_world()
	_setup_environment()
	_setup_mesh()
	_setup_camera()
	_resolve_server_url()
	grenades = GrenadeSystem.new()
	movement = MovementModel.new()
	var spawn_u := _spawn_u_from_config()
	if spawn_u == Vector3.ZERO:
		spawn_u = Vector3(0.0, ground_u_at(Vector3(0, 0, 0)) + 0.2, 0.0)
	else:
		spawn_u.y = ground_u_at(spawn_u) + 0.2
	movement.reset(spawn_u)
	settings = GameSettings.new()
	settings.load_settings()
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	audio.update_settings(settings)
	loadout = Loadout.new(WeaponData.Team.T, 16000)
	loadout.give(WeaponData.WeaponId.AK47)
	for grenade_id in [WeaponData.WeaponId.HE, WeaponData.WeaponId.FLASH,
			WeaponData.WeaponId.SMOKE, WeaponData.WeaponId.MOLOTOV]:
		loadout.give(grenade_id)
	loadout.select(Loadout.Slot.PRIMARY)
	anim = WeaponAnimController.new()
	var start_wi = loadout.active()
	var start_id: int = start_wi.id if start_wi != null and start_wi.id >= 0 else WeaponData.WeaponId.AK47
	movement.set_weapon_speed(float(WeaponData.get_weapon(start_id).get("move_speed", 250.0)))
	anim.set_weapon(start_id)
	anim.reset()
	_setup_viewmodel()
	player_state = PlayerState.new()
	player_state.team = loadout.team
	hud = GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.setup(loadout, func(_id): _on_weapon_bought())
	hud.apply_crosshair(settings)
	hud.set_player_state(player_state)
	hud.ui_state_changed.connect(_sync_mouse_mode)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.set_mouse_captured(false)
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
	selected_map = _read_selected_map()
	var map_file: String = "oasis.vmap"
	var wanted: String = "res://assets/maps/" + selected_map + ".vmap"
	if FileAccess.file_exists(wanted):
		map_file = selected_map + ".vmap"
	else:
		selected_map = "oasis"
	var res = VoxelMapLoader.load_map("res://assets/maps/" + map_file, world)
	set_meta("map_loaded_by_main", true)
	if not res.ok or int(res.loaded) == 0:
		# fallback: простая коробка
		world.bounds_min = Vector3i(-8, -8, -8)
		world.bounds_max = Vector3i(8, 8, 8)
		world.edit_box(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000), 100000)
		world.edit_sphere(Vector3(0, 0, 0), 600, 100000)
	else:
		print("loaded Oasis map: ", res.loaded, " voxels")


func _setup_mesh() -> void:
	# Цвета приходят из мешера (бетон/дерево/...), шум-текстура добавляет
	# микродетали, чтобы карта не выглядела плоским «коричневым ничем».
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.15, 1.15, 1.15)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var detail := NoiseTexture2D.new()
	detail.noise = noise
	detail.width = 256
	detail.height = 256
	detail.seamless = true
	detail.generate_mipmaps = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.74, 0.74, 0.74))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	detail.color_ramp = ramp
	mat.albedo_texture = detail
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	map_meshes.clear()
	for cc in world.all_chunk_coords():
		var mesh = MapMeshCache.get_or_build(world, cc, selected_map)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "MapChunk_%d_%d_%d" % [cc.x, cc.y, cc.z]
		mi.mesh = mesh
		mi.material_override = mat
		add_child(mi)
		map_meshes.append(mi)
		if mesh_instance == null:
			mesh_instance = mi


func _current_grenade_type() -> int:
	if loadout == null:
		return -1
	var wi = loadout.active()
	if wi == null or wi.mag <= 0:
		return -1
	match loadout.selected:
		Loadout.Slot.GRENADE_FLASH_1, Loadout.Slot.GRENADE_FLASH_2:
			return GrenadeSystem.Type.FLASH
		Loadout.Slot.GRENADE_SMOKE:
			return GrenadeSystem.Type.SMOKE
		Loadout.Slot.GRENADE_FIRE:
			return GrenadeSystem.Type.MOLOTOV if loadout.team == WeaponData.Team.T 				else GrenadeSystem.Type.INCENDIARY
		Loadout.Slot.GRENADE_HE_DECOY:
			if wi.id == WeaponData.WeaponId.DECOY:
				return GrenadeSystem.Type.DECOY
			return GrenadeSystem.Type.HE
	return -1


func _throw_grenade(throw_type: int) -> void:
	if grenades == null or loadout == null or movement == null:
		return
	if hud != null and hud.is_ui_open():
		return
	var gtype: int = _current_grenade_type()
	if gtype < 0:
		if hud != null:
			hud.message("Нет гранаты — выберите 4")
		return
	var wi = loadout.active()
	wi.mag -= 1
	var dir: Vector3 = Vector3.FORWARD if camera == null else -camera.global_transform.basis.z
	var origin_u: Vector3 = movement.pos_u + Vector3(0, 75.0, 0) + dir * 12.0
	grenades.throw_grenade(gtype, origin_u, dir, throw_type, 0, loadout.team,
			movement.vel_u, not movement.on_ground)
	if hud != null:
		hud.message("Бросок гранаты")


func _sync_grenade_meshes() -> void:
	if grenades == null:
		return
	var alive: Dictionary = {}
	for g in grenades.active:
		alive[g] = true
		var mi: MeshInstance3D = grenade_meshes.get(g) as MeshInstance3D
		if mi == null:
			var sphere := SphereMesh.new()
			sphere.radius = 0.045
			sphere.height = 0.09
			sphere.radial_segments = 12
			sphere.rings = 8
			mi = MeshInstance3D.new()
			mi.name = "Grenade"
			mi.mesh = sphere
			add_child(mi)
			grenade_meshes[g] = mi
		mi.position = g.pos * 0.01905
	for g in grenade_meshes.keys():
		if not alive.has(g):
			var old: MeshInstance3D = grenade_meshes[g] as MeshInstance3D
			if is_instance_valid(old):
				old.queue_free()
			grenade_meshes.erase(g)


func _spawn_u_from_config() -> Vector3:
	var path: String = "res://assets/maps/" + selected_map + "_spawns.json"
	if not FileAccess.file_exists(path):
		return Vector3.ZERO
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector3.ZERO
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		f.close()
		return Vector3.ZERO
	f.close()
	var raw = json.data.get("CT", [])
	if not (raw is Array) or (raw as Array).size() < 3:
		return Vector3.ZERO
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2])) / 19.05


func _read_selected_map() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://selected_map.cfg") != OK:
		return "oasis"
	var id := String(cfg.get_value("map", "id", "oasis"))
	match id:
		"Oasis", "oasis": return "oasis"
		"Training Arena", "training_arena": return "training_arena"
		"Voxel Buildings", "buildings_12": return "buildings_12"
		"Medieval Voxels", "medieval_prop_0": return "medieval_prop_0"
	return "oasis"


func _setup_environment() -> void:
	# Небо + окружающий свет, иначе карта рендерится чёрной (в сцене не было света).
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.34, 0.52)
	sky_mat.sky_horizon_color = Color(0.66, 0.73, 0.80)
	sky_mat.ground_bottom_color = Color(0.16, 0.15, 0.13)
	sky_mat.ground_horizon_color = Color(0.58, 0.55, 0.47)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	# Солнце (основной свет) + заполняющий свет, чтобы тени не были чёрными.
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.66, 0.86)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	add_child(fill)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 3, 6)
	camera.current = true
	add_child(camera)


func _setup_viewmodel() -> void:
	if camera == null:
		return
	viewmodel = WeaponViewModelScript.new()
	viewmodel.name = "ViewModel"
	viewmodel.position = VIEWMODEL_BASE
	camera.add_child(viewmodel)
	if anim != null:
		viewmodel.set_weapon(anim.weapon_id)
	vm_pos_smooth = VIEWMODEL_BASE
	vm_rot_smooth = Vector3.ZERO


func _process(delta: float) -> void:
	# анимации + звук
	if anim != null:
		anim.update_motion(movement.speed_u() if movement != null else 0.0)
		anim.tick(delta)
		if anim.events.size() > 0:
			audio.handle_anim_events(anim.events, anim.weapon_id)
			if anim.events.has("defuse_done") and hud != null:
				hud.message("Бомба обезврежена")
			# Таймер первичен: патронташ наполняется только по завершении
			# reload_duration(), а не в момент нажатия R.
			if anim.events.has("reload_done") and loadout != null:
				loadout.reload(Time.get_ticks_msec())
				if hud != null:
					hud.refresh()
					hud.message("Магазин готов")
		# Позиция/тряска оружия применяются после шага движения (см. ниже).

	# автоматический огонь, пока зажата ЛКМ (винтовки/ПП как в CS2)
	if hud != null and not hud.is_ui_open() \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire()

	# движение (локальное предсказание); на паузе замирает
	var move_x: float = 0.0
	var move_z: float = 0.0
	var buttons: int = 0
	var paused: bool = hud != null and hud.pause_open
	if not paused:
		if Input.is_key_pressed(KEY_A): move_x -= 1.0
		if Input.is_key_pressed(KEY_D): move_x += 1.0
		if Input.is_key_pressed(KEY_W): move_z += 1.0
		if Input.is_key_pressed(KEY_S): move_z -= 1.0
		if Input.is_key_pressed(KEY_SPACE): buttons |= MovementModel.Buttons.JUMP
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
			buttons |= MovementModel.Buttons.CROUCH
		if Input.is_key_pressed(KEY_SHIFT): buttons |= MovementModel.Buttons.WALK
	var yaw_units: int = int(posmod(yaw / TAU, 1.0) * 65536.0) % 65536
	var pitch_units: int = int(clampf(pitch / 1.2, -1.0, 1.0) * 32767.0)
	var no_ladder := func(_p): return false
	if not paused:
		movement.step(buttons, move_x, move_z, yaw_units, pitch_units, delta,
				Callable(self, "ground_u_at"), no_ladder)
	if grenades != null:
		grenades.step(delta, Callable(self, "ground_u_at"))
		_sync_grenade_meshes()

	# камера
	if camera != null:
		camera.position = movement.to_meters() + Vector3(0, 1.55, 0)
		camera.rotation_order = EULER_ORDER_YXZ
		camera.rotation = Vector3(pitch, yaw, 0.0)
	_update_viewmodel(delta)

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
			elif pkt.size() >= 13 and pkt[0] == NetProtocol.MsgType.DAMAGE:
				_parse_damage(pkt)
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


func _update_viewmodel(delta: float) -> void:
	if viewmodel == null or anim == null:
		return
	var speed: float = movement.speed_u() if movement != null else 0.0
	var moving: float = clampf(speed / 250.0, 0.0, 1.0)
	var grounded: bool = movement == null or movement.on_ground
	var bob_mult: float = (settings.viewmodel_bob if settings != null else 1.0)
	var sway_mult: float = (settings.viewmodel_sway if settings != null else 1.0)
	# Покачивание при ходьбе: непрерывная фаза, не зависит от состояния анимации.
	vm_bob_time += delta * (2.0 + moving * 8.0)
	var amp: float = (moving * 0.010 * bob_mult) if grounded else 0.0
	var bob := Vector3(sin(vm_bob_time) * amp,
			-absf(cos(vm_bob_time)) * amp * 0.8, 0.0)
	# Инерция от мыши, сглаженная — убирает дёрганье камеры/оружия.
	var sway_k: float = 0.00045 * maxf(sway_mult, 0.1)
	var target_sway := Vector2(
			clampf(-vm_look.x * sway_k, -0.025, 0.025),
			clampf(-vm_look.y * sway_k, -0.020, 0.020))
	vm_look = Vector2.ZERO
	vm_sway = vm_sway.lerp(target_sway, 1.0 - exp(-delta * 12.0))

	var base: Vector3 = VIEWMODEL_BASE
	if not grounded:
		base.y -= 0.015
	var target_pos: Vector3 = base + anim.pos_offset + bob + Vector3(vm_sway.x, vm_sway.y, 0.0)
	var target_rot: Vector3 = anim.rot_offset + Vector3(vm_sway.y * 0.9, vm_sway.x * 0.9, 0.0)
	target_pos.x = clampf(target_pos.x, VIEWMODEL_BASE.x - 0.09, VIEWMODEL_BASE.x + 0.09)
	target_pos.y = clampf(target_pos.y, VIEWMODEL_BASE.y - 0.09, VIEWMODEL_BASE.y + 0.09)
	target_pos.z = clampf(target_pos.z, VIEWMODEL_BASE.z - 0.12, VIEWMODEL_BASE.z + 0.12)
	target_rot.x = clampf(target_rot.x, -0.18, 0.18)
	target_rot.y = clampf(target_rot.y, -0.18, 0.18)
	target_rot.z = clampf(target_rot.z, -0.18, 0.18)
	# Сглаживание убирает одно-кадровые скачки отдачи.
	var k: float = 1.0 - exp(-delta * 25.0)
	vm_pos_smooth = vm_pos_smooth.lerp(target_pos, k)
	vm_rot_smooth = vm_rot_smooth.lerp(target_rot, k)
	viewmodel.position = vm_pos_smooth
	viewmodel.rotation = vm_rot_smooth


func _parse_damage(pkt: PackedByteArray) -> void:
	# u8 type, u32 attacker, u32 target, u16 hp, u16 armor
	var hp: int = pkt[9] | (pkt[10] << 8)
	var armor: int = pkt[11] | (pkt[12] << 8)
	if player_state != null:
		player_state.hp = hp
		if hp <= 0:
			player_state.alive = false
	loadout.armor = armor
	if hud != null:
		hud.message("Получен урон! HP " + str(hp))
		hud.refresh()


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
	# Smoke-сервер не загружает карту Oasis и его физика не авторитетна для
	# позиции. Раньше здесь был lerp к серверу: из-за отсутствия знакового
	# расширения в _i32 отрицательная Y превращалась в ~225 млн юнитов,
	# камера улетала за карту, движение и прицел «взрывались».
	last_server_pos_u = server_u
	have_server_pos = true


func _i32(buf: PackedByteArray, o: int) -> int:
	var v: int = buf[o] | (buf[o + 1] << 8) | (buf[o + 2] << 16) | (buf[o + 3] << 24)
	if v >= (1 << 31):
		v -= 1 << 32
	return v


func ground_u_at(p_u: Vector3) -> float:
	if world == null:
		return 0.0
	var p_mm: Vector3 = p_u * 19.05
	var v: Vector3i = world.world_mm_to_voxel(p_mm)
	for yy in range(v.y + 2, int(world.bounds_min.y) - 1, -1):
		if world.get_sdf_voxel(Vector3i(v.x, yy, v.z)) <= 0:
			var surface_u: float = float(yy + 1) * float(world.voxel_size_mm) / 19.05
			if surface_u <= p_u.y + 18.0:
				return surface_u
	return 0.0


func _on_weapon_bought() -> void:
	var wi = loadout.active()
	if wi != null and wi.id >= 0:
		anim.equip(wi.id)
		if viewmodel != null:
			viewmodel.set_weapon(wi.id)
	hud.refresh()


func _sync_mouse_mode() -> void:
	if hud == null:
		return
	if hud.is_ui_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		hud.set_mouse_captured(false)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hud.set_mouse_captured(true)


func _try_fire() -> void:
	if loadout == null:
		return
	var shot = loadout.fire(Time.get_ticks_msec())
	if shot.fired:
		if anim != null and anim.request_fire():
			fire_bit = true
		if hud != null:
			hud.refresh()
	elif String(shot.get("reason", "")) == "empty_mag":
		_start_reload()


func _start_reload() -> void:
	if loadout == null or anim == null:
		return
	if anim.state != WeaponAnimController.State.IDLE:
		return
	var wi = loadout.active()
	if wi == null or wi.mag >= int(WeaponData.get_weapon(wi.id).get("mag", 0)) or wi.reserve <= 0:
		return
	if not anim.request_reload():
		return
	reload_bit = true
	if hud != null:
		hud.message("Перезарядка...")


func _select_slot(slot: int) -> void:
	if loadout == null or not loadout.select(slot):
		return
	var wi = loadout.active()
	if wi != null and wi.id >= 0 and anim != null:
		anim.equip(wi.id)
		if viewmodel != null:
			viewmodel.set_weapon(wi.id)
	if hud != null:
		hud.refresh()


func _cycle_grenade() -> void:
	if loadout == null:
		return
	for slot in [Loadout.Slot.GRENADE_FLASH_1, Loadout.Slot.GRENADE_FLASH_2,
			Loadout.Slot.GRENADE_SMOKE, Loadout.Slot.GRENADE_FIRE,
			Loadout.Slot.GRENADE_HE_DECOY]:
		if loadout.slots.has(slot):
			_select_slot(slot)
			return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (hud == null or not hud.pause_open) \
				and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			yaw -= event.relative.x * 0.005
			pitch -= event.relative.y * 0.005
			pitch = clamp(pitch, -1.2, 1.2)
			vm_look += event.relative
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if hud == null or not hud.is_ui_open():
				_throw_grenade(GrenadeSystem.ThrowType.SHORT)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if hud != null and hud.is_ui_open():
				return
			# Первый клик в web захватывает мышь (pointer lock), затем стреляем.
			if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				if hud != null:
					hud.set_mouse_captured(true)
			_try_fire()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if hud != null:
					if hud.buy_open:
						hud.toggle_buy()
					else:
						hud.toggle_pause()
			KEY_B:
				if hud != null and not hud.pause_open:
					hud.toggle_buy()
			KEY_R:
				if hud == null or not hud.pause_open:
					_start_reload()
			KEY_F, KEY_I:
				if anim != null and (hud == null or not hud.pause_open):
					anim.request_inspect()
			KEY_G:
				_throw_grenade(GrenadeSystem.ThrowType.LONG)
			KEY_Q:
				if anim != null and (hud == null or not hud.pause_open):
					anim.request_melee()
			KEY_E:
				if anim != null and (hud == null or not hud.pause_open):
					if anim.request_defuse() and hud != null:
						hud.message("Обезвреживание бомбы...")
			KEY_1:
				_select_slot(Loadout.Slot.PRIMARY)
			KEY_2:
				_select_slot(Loadout.Slot.SECONDARY)
			KEY_3:
				_select_slot(Loadout.Slot.KNIFE)
			KEY_4:
				_cycle_grenade()
			KEY_5:
				_select_slot(Loadout.Slot.C4)


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
