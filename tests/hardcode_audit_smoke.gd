extends SceneTree
## Хардкод/конфигурация: ключевые параметры вынесены в константы/JSON/тему,
## а боевые пути не содержат «плавающих» чисел и случайности.

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
	var anim := _text("res://shared/gameplay/weapon_anim.gd")
	_check(anim.contains("const RELOAD_TIMES"), "тайминги перезарядки в константе")
	_check(anim.contains("const RECOVERY"), "recovery в константе")
	_check(not anim.contains("randomize()") and not anim.contains("randf()"),
		"отдача детерминирована, без случайности")

	var movement := _text("res://shared/gameplay/movement.gd")
	for token in ["SV_ACCELERATE", "SV_FRICTION", "JUMP_VELOCITY", "GRAVITY"]:
		_check(movement.contains("const " + token), "movement: " + token + " — константа")

	var lobby := _text("res://client/lobby_ui.gd")
	var hud := _text("res://client/game_hud.gd")
	_check(lobby.contains('preload("res://client/ui_theme.gd")'), "лобби использует UiTheme")
	_check(hud.contains('preload("res://client/ui_theme.gd")'), "HUD использует UiTheme")
	_check(lobby.contains('"user://selected_map.cfg"'), "выбор карты в конфиге")
	_check(lobby.contains("source_only"), "CC BY-ND карты помечены в конфиге")

	var catalog := _text("res://assets/maps/catalog.json")
	_check(catalog.contains('"id": "training_arena"'), "каталог карт подключён")
	_check(catalog.contains('"collisions"'), "коллизии описаны в каталоге")
	for name in ["training_arena", "buildings_12", "medieval_prop_0"]:
		_check(FileAccess.file_exists("res://assets/maps/" + name + "_spawns.json"),
			"спавн-конфиг: " + name)
	_check(FileAccess.file_exists("res://assets/voxel_sources/LICENSES.md"),
		"лицензии voxel-источников сохранены")

	var main := _text("res://client/main.gd")
	_check(main.contains("MapMeshCache"), "кэш мешей подключён")
	_check(main.contains("ground_u_at(spawn_u)"), "спавн берётся из конфига и земли")
	_check(not main.contains("loadout.reload(Time.get_ticks_msec())")
			or main.contains("events.has(\"reload_done\")"),
			"перезарядка привязана к событию таймера")

	var project := _text("res://project.godot")
	_check(project.contains('window/stretch/aspect="expand"'), "fullscreen stretch=expand")
	_check(project.contains('renderer/rendering_method="gl_compatibility"'), "web renderer")
	_check(project.contains('MapModule="*res://client/map_module.gd"'), "MapModule autoload")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
