extends SceneTree
## Производительность/стабильность: стоимость загрузки карты, кэш чанков,
## 600 смешанных шагов FSM/движения/гранат, отсутствие NaN и unbounded-массивов.

const MapMeshCache = preload("res://shared/voxel/map_mesh_cache.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _finite(v: Vector3) -> bool:
	return not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z)


func _init() -> void:
	root.size = Vector2(1280, 720)
	var cfg := ConfigFile.new()
	cfg.set_value("map", "id", "oasis")
	cfg.save("user://selected_map.cfg")
	MapMeshCache.clear()

	var t0 := Time.get_ticks_usec()
	var c = load("res://scenes/client.tscn").instantiate()
	c.server_url = "ws://127.0.0.1:1"
	root.add_child(c)
	await process_frame
	await process_frame
	var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_check(c.map_meshes.size() == 40, "Oasis: 40 чанков (%d)" % c.map_meshes.size())
	_check(build_ms < 15000.0, "первая загрузка карты %.1f мс < 15000 (headless)" % build_ms)

	var cache_count: int = MapMeshCache.cache.size()
	_check(cache_count >= 40, "кэш мешей заполнен (%d)" % cache_count)
	var t1 := Time.get_ticks_usec()
	var c2 = load("res://scenes/client.tscn").instantiate()
	c2.server_url = "ws://127.0.0.1:1"
	root.add_child(c2)
	await process_frame
	var cached_ms := float(Time.get_ticks_usec() - t1) / 1000.0
	_check(c2.map_meshes.size() == 40, "вторая загрузка использует те же меши")
	_check(cached_ms < build_ms + 500.0,
		"повторная загрузка не дороже первой (%.1f vs %.1f мс)" % [cached_ms, build_ms])

	# смешанная нагрузка
	c.anim.state = 0
	c.anim.timer = 0.0
	var ev := InputEventKey.new()
	ev.keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	var g_ev := InputEventKey.new()
	g_ev.keycode = KEY_G
	g_ev.pressed = true
	Input.parse_input_event(g_ev)
	for i in range(600):
		if i % 150 == 0:
			c.anim.state = 0
			c.anim.timer = 0.0
			c.anim.request_reload()
		c._process(1.0 / 60.0)
	_check(_finite(c.movement.pos_u) and _finite(c.movement.vel_u),
		"позиция/скорость конечны после 600 шагов")
	_check(c.grenades.active.size() < 20,
		"активных гранат ограничено (%d)" % c.grenades.active.size())
	_check(c.grenade_meshes.size() < 20,
		"мешей гранат ограничено (%d)" % c.grenade_meshes.size())
	_check(c.anim.state >= 0 and c.anim.state <= 8,
		"FSM остаётся в допустимом состоянии (%d)" % c.anim.state)

	var tri_total: int = 0
	for mi in c.map_meshes:
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tri_total += (idx.size() if idx != null and idx.size() > 0 else verts.size()) / 3
	_check(tri_total > 0 and tri_total < 250000,
		"бюджет сцены <250k tris (%d)" % tri_total)

	root.remove_child(c)
	root.remove_child(c2)
	c.free()
	c2.free()
	MapMeshCache.clear()

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
