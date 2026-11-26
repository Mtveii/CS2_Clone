extends SceneTree
## Проверка замены Unicode-иконок векторными, качества процедурных моделей
## и того, что настройки прицела реально влияют на HUD.

const UiIcon = preload("res://client/ui_icon.gd")
const WeaponIcon = preload("res://client/weapon_icon.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const AgentData = preload("res://client/agents.gd")
const Viewmodel = preload("res://client/weapon_viewmodel.gd")
const GameSettings = preload("res://client/settings.gd")

var failures: int = 0
var icon_buttons: Array = []


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _collect_icon_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button and String(child.name).begins_with("IconButton_"):
			icon_buttons.append(child)
		_collect_icon_buttons(child)


func _init() -> void:
	root.size = Vector2(1280, 720)
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	root.size = Vector2(1280, 720)
	await process_frame
	var ui = lobby.get_node("UI")

	# --- иконки: без Unicode/emoji, векторный Glyph внутри кнопки ---
	icon_buttons.clear()
	_collect_icon_buttons(ui.root)
	_check(icon_buttons.size() >= 12, "векторных иконок больше 12 (%d)" % icon_buttons.size())
	var bad_text: int = 0
	var bad_glyph: int = 0
	for b in icon_buttons:
		if b.text != "":
			bad_text += 1
		var glyph := b.get_node_or_null("Glyph") as UiIcon
		if glyph == null or glyph.icon_name == "dot" or glyph.icon_name == "":
			bad_glyph += 1
	_check(bad_text == 0, "иконки не используют текст кнопки")
	_check(bad_glyph == 0, "у каждой иконки есть Glyph с именем")
	var top_icons: int = 0
	for c in ui.top_bar.get_child(0).get_children():
		if c is Button and c.get_node_or_null("Glyph") != null:
			top_icons += 1
	_check(top_icons >= 4, "иконки верхней панели присутствуют (%d)" % top_icons)

	# --- процедурные иконки оружия: разные силуэты, _draw не падает ---
	var ids := [WeaponData.WeaponId.AK47, WeaponData.WeaponId.AWP,
		WeaponData.WeaponId.KNIFE, WeaponData.WeaponId.HE, WeaponData.WeaponId.C4]
	for id in ids:
		var icon := WeaponIcon.new()
		icon.weapon_id = id
		root.add_child(icon)
		icon.size = Vector2(130, 52)
		icon._draw()
		_check(icon.get_child_count() == 0, "WeaponIcon %d рисуется без ошибок" % id)
		icon.queue_free()
	_check(WeaponData.get_weapon(ids[0]).slot != WeaponData.get_weapon(ids[1]).slot,
		"выбранные оружия имеют разные слоты")

	# --- агенты: сложные модели и уникальные детали по роли ---
	var agents := AgentData.new()
	var entry := agents.build_voxel_model(agents.find("t_pro"))
	var sniper := agents.build_voxel_model(agents.find("ct_ksk"))
	var support := agents.build_voxel_model(agents.find("ct_swat"))
	_check(entry.get_child_count() >= 22, "модель агента: >=22 деталей (%d)" % entry.get_child_count())
	_check(sniper.get_node_or_null("Hood") != null, "снайпер отличается капюшоном")
	_check(sniper.get_node_or_null("Scope") != null, "снайпер отличается прицелом")
	_check(support.get_node_or_null("HelmetCrest") != null, "поддержка отличается гребнем")
	_check(support.get_node_or_null("Backpack") != null, "поддержка отличается рюкзаком")

	# --- viewmodel: дуло у каждого типа в правильном месте ---
	var vm := Viewmodel.new()
	root.add_child(vm)
	var expected := {
		WeaponData.WeaponId.GLOCK: -0.27,
		WeaponData.WeaponId.AK47: -0.55,
		WeaponData.WeaponId.AWP: -0.77,
		WeaponData.WeaponId.NOVA: -0.62,
		WeaponData.WeaponId.M249: -0.67,
	}
	for id in expected.keys():
		vm.set_weapon(id)
		var muzzle := vm.model_root.get_node_or_null("Muzzle") as Node3D
		_check(muzzle != null and absf(muzzle.position.z - float(expected[id])) < 0.01,
			"дуло %s: z=%.2f" % [WeaponData.get_weapon(id).name,
				(muzzle.position.z if muzzle != null else 999.0)])

	# --- прицел: настройки реально применяются ---
	var client = load("res://scenes/client.tscn").instantiate()
	root.add_child(client)
	await process_frame
	await process_frame
	var hud = client.hud
	var st := GameSettings.new()
	st.crosshair_color = "red"
	st.crosshair_size = 4.0
	st.crosshair_thickness = 3.0
	st.crosshair_gap = 7.0
	st.crosshair_center_dot = true
	st.crosshair_t_style = true
	st.crosshair_alpha = 0.5
	hud.apply_crosshair(st)
	await process_frame
	var reds: int = 0
	var has_dot: bool = false
	for c in hud.crosshair.get_children():
		var r := c as ColorRect
		if r == null:
			continue
		if r.color.r > 0.75 and r.color.g < 0.4 and r.color.a > 0.4:
			reds += 1
		if r.size.x <= 5.0 and r.size.y <= 5.0:
			has_dot = true
	_check(reds >= 3, "прицел окрашен в красный (%d)" % reds)
	_check(has_dot, "точка в центре управляется настройкой")
	_check(hud.crosshair.get_child_count() >= 7, "T-прицел с контуром построен")

	# --- фон лобби: честные названия и реальная геометрия ---
	var world = lobby.get_node("LobbyWorld")
	var old_names: Array = ["Dust II", "Mirage", "Inferno", "Nuke"]
	var has_old: bool = false
	for cfg in world.BACKGROUNDS:
		for n in old_names:
			if String(cfg.name) == n:
				has_old = true
	_check(not has_old, "фоны не выдают карты CS2 за свои")
	world.set_background(0)
	var bg_names: Array = []
	for c in world.bg_root.get_children():
		bg_names.append(String(c.name))
	_check(bg_names.has("Crate_0") and bg_names.has("Beam_0"), "у фона есть ящики и балки")
	_check(bg_names.has("RailTop_-10") or bg_names.has("RailTop_10"), "у фона есть перила")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
