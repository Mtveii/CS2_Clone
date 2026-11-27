extends SceneTree
## Изолированная карта: геометрия + коллизии добавляются без правок боевых файлов.
## Проверяем, что combat-состояние не меняется от подключения карты.

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _init() -> void:
	root.size = Vector2(1280, 720)
	var project_file := FileAccess.open("res://project.godot", FileAccess.READ)
	var project_text: String = project_file.get_as_text() if project_file != null else ""
	project_file.close()
	_check(project_text.contains('MapModule="*res://client/map_module.gd"'),
		"MapModule зарегистрирован как autoload")
	var mm = load("res://client/map_module.gd").new()
	mm.name = "MapModule"
	root.add_child(mm)
	var client = load("res://scenes/client.tscn").instantiate()
	client.server_url = "ws://127.0.0.1:1"
	root.add_child(client)
	await process_frame
	await process_frame

	# combat-состояние ДО карты
	var state_before: int = client.anim.state
	var mag_before: int = client.loadout.active().mag
	var weapon_before: int = client.loadout.active().id
	var buy_before: bool = client.hud.buy_open

	# шаг 3: только геометрия + коллизии
	mm.attach_to(client)
	await process_frame
	var container := client.get_node_or_null("IsolatedMap") as Node3D
	_check(container != null, "узел IsolatedMap добавлен в игровую сцену")
	var chunks: int = 0
	var walls: int = 0
	var geo_train := container.get_node_or_null("MapGeometry_training_arena") as Node3D
	var col_train := container.get_node_or_null("MapCollision_training_arena") as Node3D
	if geo_train != null:
		for g in geo_train.get_children():
			if g is MeshInstance3D and g.mesh != null:
				chunks += 1
	if col_train != null:
		for w in col_train.get_children():
			if w is StaticBody3D:
				walls += 1
	_check(chunks > 0, "геометрия training_arena из VMAP: %d чанков" % chunks)
	_check(walls == 10, "невидимые коллизии training_arena: %d" % walls)
	_check(container.get_node_or_null("MapGeometry_buildings_12") != null,
		"скачанный Voxel Buildings добавлен как отдельная карта")
	_check(container.get_node_or_null("MapGeometry_medieval_prop_0") != null,
		"скачанный Medieval Voxels добавлен как отдельная карта")

	# шаг 5/7: спавны и метки бомбсайтов — отдельные конфиги, без игровой логики
	var spawns: int = 0
	var sites: int = 0
	for c in container.get_children():
		if String(c.name).begins_with("MapSpawns_"):
			for m in c.get_children():
				if m is Marker3D:
					spawns += 1
		if String(c.name).begins_with("MapSites_"):
			for m in c.get_children():
				if m is Marker3D:
					sites += 1
	_check(spawns == 2, "точки спавна из spawn_points.json: %d" % spawns)
	_check(sites == 2, "метки бомбсайтов из objectives.json: %d" % sites)

	# боевые файлы не тронуты: состояние осталось прежним
	_check(client.anim.state == state_before, "state machine не изменена")
	_check(client.loadout.active().mag == mag_before, "патроны не изменены")
	_check(client.loadout.active().id == weapon_before, "оружие не изменено")
	_check(client.hud.buy_open == buy_before, "HUD/закупка не изменены")

	# шаг 4: боевые действия после добавления карты
	client.anim.state = 0
	client.anim.timer = 0.0
	_check(client.anim.request_fire(), "стрельба работает после карты")
	client.anim.state = 0
	client.anim.timer = 0.0
	client.loadout.active().mag = 10
	_check(client.anim.request_reload(), "reload работает после карты")
	client.anim.equip(21)
	_check(client.anim.state == 3 and client.anim.weapon_id == 21,
		"weapon switch/equip работает после карты")

	# повторное подключение не дублирует карту
	mm.attach_to(client)
	_check(client.get_node_or_null("IsolatedMap") == container,
		"карта не дублируется при повторном вызове")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
