extends SceneTree
## Минимальная проверка: каждая выбранная карта реально открывается в игре.

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _select(name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("map", "id", name)
	cfg.save("user://selected_map.cfg")


func _init() -> void:
	for pair in [["Oasis", "oasis"], ["Training Arena", "training_arena"],
			["Voxel Buildings", "buildings_12"], ["Medieval Voxels", "medieval_prop_0"]]:
		var display: String = pair[0]
		var id: String = pair[1]
		_select(display)
		var c = load("res://scenes/client.tscn").instantiate()
		c.server_url = "ws://127.0.0.1:1"
		root.add_child(c)
		await process_frame
		await process_frame
		_check(c.selected_map == id, "%s: карта загружена" % display)
		_check(FileAccess.file_exists("res://assets/maps/" + id + "_spawns.json"),
			"%s: спавн-конфиг есть" % display)
		_check(c.map_meshes.size() > 0, "%s: чанки есть (%d)" % [display, c.map_meshes.size()])
		var aabb := AABB()
		var have := false
		for mi in c.map_meshes:
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var a: AABB = mi.mesh.get_aabb()
			if not have:
				aabb = a
				have = true
			else:
				aabb = aabb.merge(a)
		_check(have and aabb.grow(4.0).has_point(c.camera.global_position),
			"%s: камера в зоне карты" % display)
		root.remove_child(c)
		c.free()
	_select("Oasis")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
