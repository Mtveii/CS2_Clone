extends SceneTree
## Целостность контента: каталог карт, конфиги, аудио, лицензии и fallback.

const MapModuleLoader = preload("res://shared/map/map_module_loader.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _init() -> void:
	root.size = Vector2(1280, 720)
	var catalog := MapModuleLoader.load_catalog()
	_check(catalog.maps.size() == 3, "каталог: 3 изолированные карты")
	var ids: Dictionary = {}
	for def in catalog.maps:
		var id: String = String(def.get("id", ""))
		_check(not id.is_empty() and not ids.has(id), "уникальный id карты: " + id)
		ids[id] = true
		_check(FileAccess.file_exists("res://assets/maps/" + String(def.get("file", ""))),
			"VMAP существует: " + id)
		if def.has("spawns"):
			_check(FileAccess.file_exists("res://assets/maps/" + String(def.spawns)),
				"спавн существует: " + id)
		if def.has("collisions"):
			var json := JSON.new()
			_check(json.parse(_text("res://assets/maps/" + String(def.collisions))) == OK,
				"коллизии валидны: " + id)
			if json.data is Dictionary:
				for box in json.data.get("boxes", []):
					var size = box.get("size", [])
					_check(size.size() == 3 and float(size[0]) > 0 and float(size[1]) > 0
							and float(size[2]) > 0, "размер коллайдера > 0: " + id)

	# играбельные карты в лобби
	var lobby_script := _text("res://client/lobby_ui.gd")
	for file in ["oasis.vmap", "training_arena.vmap", "buildings_12.vmap", "medieval_prop_0.vmap"]:
		_check(FileAccess.file_exists("res://assets/maps/" + file), "меню/игра: " + file)
	_check(lobby_script.contains("source_only"), "CC BY-ND источники не запускаются")
	_check(lobby_script.contains("user://selected_map.cfg"), "выбор сохраняется")

	# аудио и лицензии
	var audio_dir := DirAccess.open("res://assets/audio")
	var wav_count: int = 0
	for name in audio_dir.get_files():
		if name.ends_with(".wav"):
			wav_count += 1
			_check(FileAccess.get_size("res://assets/audio/" + name) > 100,
				"WAV не пустой: " + name)
	_check(wav_count >= 27, "27+ звуковых файлов (%d)" % wav_count)
	_check(FileAccess.file_exists("res://assets/voxel_sources/LICENSES.md"),
		"лицензии voxel-источников")
	_check(FileAccess.file_exists("res://assets/agents/LICENSE.txt"),
		"лицензии high-poly агентов")

	# битое значение карты → Oasis
	var cfg := ConfigFile.new()
	cfg.set_value("map", "id", "desert_town")
	cfg.save("user://selected_map.cfg")
	var c = load("res://scenes/client.tscn").instantiate()
	c.server_url = "ws://127.0.0.1:1"
	root.add_child(c)
	await process_frame
	_check(c.selected_map == "oasis", "source-only карта не становится игровой")
	cfg.set_value("map", "id", "Oasis")
	cfg.save("user://selected_map.cfg")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
