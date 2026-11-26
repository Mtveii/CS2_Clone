extends SceneTree
## Проверка исправления «взрыва» камеры из-за знакового int32 snapshot,
##движение по карте, работу R/F/B и загрузку высокополигональных агентов.

const SNAPSHOT: int = 2
const AgentData = preload("res://client/agents.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255])


func _i32(v: int) -> PackedByteArray:
	return _u32(v)


func _u16(v: int) -> PackedByteArray:
	return PackedByteArray([v & 255, (v >> 8) & 255])


func _count_meshes(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if c is MeshInstance3D and c.mesh != null:
			n += 1
		n += _count_meshes(c)
	return n


func _count_tris(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if c is MeshInstance3D and c.mesh != null:
			var mesh: Mesh = c.mesh
			for s in range(mesh.get_surface_count()):
				var arr: Array = mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				n += (idx.size() if idx != null and idx.size() > 0 else verts.size()) / 3
		n += _count_tris(c)
	return n


func _init() -> void:
	root.size = Vector2(1280, 720)
	var c = load("res://scenes/client.tscn").instantiate()
	c.server_url = "ws://127.0.0.1:1"
	root.add_child(c)
	await process_frame
	await process_frame

	# --- знаковый int32 ---
	_check(c._i32(PackedByteArray([255, 255, 255, 255]), 0) == -1,
		"int32 -1 не превращается в 4294967295")

	# --- отрицательный Y сервера не телепортирует игрока ---
	var pkt := PackedByteArray()
	pkt.append(SNAPSHOT)
	pkt.append_array(_u32(1))
	pkt.append_array(_u16(1))
	pkt.append_array(_u32(7))
	pkt.append_array(_i32(0))
	pkt.append_array(_i32(-1600))
	pkt.append_array(_i32(0))
	pkt.append_array(_i32(0))
	pkt.append_array(_i32(0))
	pkt.append_array(_u16(0))
	pkt.append_array(_u16(100))
	var before: Vector3 = c.movement.pos_u
	c._parse_snapshot(pkt)
	_check(c.movement.pos_u.distance_to(before) < 0.01,
		"snapshot с отрицательной Y не двигает игрока")
	_check(absf(c.last_server_pos_u.y - (-1600.0 / 19.05)) < 0.01,
		"серверная позиция разобрана со знаком")

	# --- перемещение по карте ---
	_key(KEY_W)
	for i in range(70):
		await process_frame
	_check(c.movement.pos_u.z < -5.0,
		"W двигает вперёд (z=%.1f u)" % c.movement.pos_u.z)
	_check(absf(c.movement.pos_u.y - c.ground_u_at(c.movement.pos_u)) < 5.0,
		"игрок остаётся на полу (y=%.1f u)" % c.movement.pos_u.y)
	var aabb := AABB()
	var have := false
	for mi in c.map_meshes:
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		if not have:
			aabb = a
			have = true
		else:
			aabb = aabb.merge(a)
	_check(have and aabb.has_point(c.camera.global_position),
		"камера остаётся внутри карты после движения")
	_check(c.camera.global_position.distance_to(c.movement.to_meters() + Vector3(0, 1.55, 0)) < 0.5,
		"камера следует за игроком")

	# --- R / F / B ---
	c.anim.state = 0
	c.anim.timer = 0.0
	c.loadout.active().mag = 10
	_key(KEY_R)
	await process_frame
	_check(c.anim.state == 2, "R запускает перезарядку")
	_check(c.loadout.active().mag == 10,
		"патроны не пополняются до окончания таймера")
	for i in range(30):
		c._process(0.1)
	_check(c.loadout.active().mag == 30 and c.anim.state == 0,
		"после таймера магазин полон и состояние IDLE")
	c.anim.state = 0
	c.anim.timer = 0.0
	_key(KEY_F)
	await process_frame
	_check(c.anim.state == 4, "F запускает осмотр оружия")
	_key(KEY_B)
	await process_frame
	_check(c.hud.buy_open, "B открывает меню закупки")
	_key(KEY_B)
	await process_frame
	_check(not c.hud.buy_open, "B закрывает меню закупки")

	# --- руки не убегают при резком движении мыши ---
	c.vm_look += Vector2(5000, 5000)
	for i in range(20):
		await process_frame
	var base := Vector3(0.28, -0.25, -0.55)
	_check(c.viewmodel.position.distance_to(base) < 0.2,
		"viewmodel остаётся рядом с руками (%.3f)" % c.viewmodel.position.distance_to(base))
	_check(absf(c.viewmodel.rotation.x) < 0.25 and absf(c.viewmodel.rotation.y) < 0.25,
		"нет бешеной тряски рук")

	# --- высокополигональные агенты из CC0 ---
	for pair in [["attacker", 7], ["defender", 7]]:
		var path: String = "res://assets/agents/" + String(pair[0]) + ".glb"
		_check(FileAccess.file_exists(path), "GLB найден: " + String(pair[0]))
		var packed: PackedScene = load(path)
		_check(packed != null, "GLB импортирован: " + String(pair[0]))
		if packed != null:
			var inst := packed.instantiate()
			root.add_child(inst)
			await process_frame
			_check(_count_meshes(inst) >= int(pair[1]),
				"%s: %d мешей" % [String(pair[0]), _count_meshes(inst)])
			var tris: int = _count_tris(inst)
			_check(tris > 20000, "%s: %d tris (high-poly витрина)" % [String(pair[0]), tris])
			inst.queue_free()

	# --- low-poly LOD для геймплея ---
	var agents := AgentData.new()
	var lod := agents.build_lod_model(agents.find("t_pro"))
	root.add_child(lod)
	await process_frame
	var lod_tris: int = _count_tris(lod)
	_check(lod_tris > 0 and lod_tris <= 3000,
		"LOD агента в бюджете 1000-3000 tris (%d)" % lod_tris)

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
