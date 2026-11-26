extends SceneTree
## Тест игрового клиента: движение, камера, HUD, меню закупки, выстрелы.
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const MovementModel = preload("res://shared/gameplay/movement.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	var packed = load("res://scenes/client.tscn")
	_check(packed != null, "client.tscn загружается")
	var inst = packed.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	_check(inst.movement != null, "модель движения создана")
	_check(inst.world != null, "воксельный мир создан")
	_check(inst.loadout != null, "инвентарь создан")
	_check(inst.hud != null, "HUD создан")

	# карта и освещение (иначе 3D-мир выглядит пустым/чёрным)
	_check(FileAccess.file_exists("res://assets/maps/oasis.vmap"), "файл карты oasis.vmap есть")
	_check(inst.map_meshes.size() > 0, "карта построена: %d чанков" % inst.map_meshes.size())
	var total_aabb := AABB()
	var has_geo := false
	for mi in inst.map_meshes:
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var a: AABB = mi.mesh.get_aabb()
		total_aabb = a if not has_geo else total_aabb.merge(a)
		has_geo = true
	_check(has_geo and total_aabb.size.length() > 1.0,
			"геометрия карты не пустая: %s" % str(total_aabb.size))
	_check(inst.get_node_or_null("WorldEnvironment") != null, "WorldEnvironment (небо/ambient)")
	_check(inst.sun != null and inst.sun.light_energy > 0.0, "солнце освещает карту")
	_check(inst.camera != null and inst.camera.current, "игровая камера активна")

	# материалы карты: вершинные цвета + детальная текстура
	var map_mat = inst.map_meshes[0].material_override if inst.map_meshes.size() > 0 else null
	_check(map_mat is StandardMaterial3D and map_mat.vertex_color_use_as_albedo,
			"карта использует вершинные цвета материалов")
	_check(map_mat != null and map_mat.albedo_texture != null, "у карты есть детальная текстура")
	var found_color := false
	var color_min := 1.0
	var color_max := 0.0
	for mi in inst.map_meshes:
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if cols == null or cols.size() == 0:
			continue
		found_color = true
		var n := mini(cols.size(), 400)
		for ci in range(n):
			var lum: float = cols[ci].get_luminance()
			color_min = minf(color_min, lum)
			color_max = maxf(color_max, lum)
	_check(found_color, "мешер выдаёт цвета вершин")
	_check(color_max - color_min > 0.03, "цвета карты различаются (%.2f..%.2f)" % [color_min, color_max])

	# viewmodel: модель оружия + руки, а не одинокий куб
	_check(inst.viewmodel != null, "viewmodel создан")
	var vm_model = inst.viewmodel.get_node_or_null("Model") if inst.viewmodel != null else null
	_check(vm_model != null and vm_model.get_child_count() >= 8,
			"viewmodel собран из деталей (%d)" % (vm_model.get_child_count() if vm_model else 0))
	_check(vm_model != null and vm_model.get_node_or_null("RightHand") != null
			and vm_model.get_node_or_null("LeftHand") != null, "у viewmodel есть обе руки")
	_check(vm_model != null and vm_model.get_node_or_null("Muzzle") != null, "есть точка вылета пули")
	_check(inst.viewmodel.model_name != "", "модель оружия: %s" % inst.viewmodel.model_name)

	# земля и спавн
	var g = inst.ground_u_at(Vector3(0, 0, 0))
	_check(g >= 0.0, "высота пола найдена: %.2f" % g)
	inst.movement.reset(Vector3(0, g + 0.2, 0))

	# движение вперёд через модель
	var before = inst.movement.pos_u
	var no_ladder := func(_p): return false
	for i in range(30):
		inst.movement.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT,
				Callable(inst, "ground_u_at"), no_ladder)
	_check(inst.movement.pos_u.distance_to(before) > 0.1, "игрок движется (%.2f u)" % inst.movement.pos_u.distance_to(before))
	_check(inst.movement.speed_u() > 0.0, "скорость > 0")
	# прыжок
	inst.movement.step(MovementModel.Buttons.JUMP, 0, 0, 0, 0, MovementModel.TICK_DT,
			Callable(inst, "ground_u_at"), no_ladder)
	_check(not inst.movement.on_ground, "прыжок работает")

	# камера следует за позицией
	await process_frame
	var cam: Camera3D = inst.camera
	_check(cam != null, "камера есть")
	_check(cam.position.distance_to(inst.movement.to_meters() + Vector3(0, 1.55, 0)) < 0.5,
			"камера следует за игроком")
	_check(total_aabb.has_point(cam.global_position), "камера внутри границ карты")
	var fwd: Vector3 = -cam.global_transform.basis.z
	_check(total_aabb.intersects_ray(cam.global_position, fwd) != null,
			"перед камерой есть геометрия карты")

	# HUD
	var hud = inst.hud
	_check(hud.get_node_or_null("GameHUD") != null, "HUD root")
	_check(hud.weapon_label.text != "", "HUD оружие: %s" % hud.weapon_label.text)
	_check(hud.ammo_label.text != "", "HUD патроны: %s" % hud.ammo_label.text)
	# меню закупки
	hud.toggle_buy()
	_check(hud.buy_open and hud.buy_panel.visible, "меню закупки открывается")
	var money_before = inst.loadout.money
	hud._buy(WeaponData.WeaponId.AK47)
	_check(inst.loadout.money < money_before, "покупка списывает деньги")
	_check(hud.weapon_label.text == "AK-47", "купенное оружие активно: %s" % hud.weapon_label.text)
	_check(inst.anim.weapon_id == WeaponData.WeaponId.AK47, "анимации переключены на AK")
	hud.toggle_buy()
	_check(not hud.buy_panel.visible, "меню закрывается")
	# выстрел расходует патрон
	var mag_before = inst.loadout.active().mag
	var shot = inst.loadout.fire(Time.get_ticks_msec())
	_check(shot.fired, "выстрел разрешён")
	_check(inst.loadout.active().mag == mag_before - 1, "патрон израсходован")
	hud.refresh()
	_check(hud.ammo_label.text.begins_with(str(inst.loadout.active().mag)), "HUD обновил патроны")
	# броня видна в HUD
	hud._buy_armor(false)
	_check(inst.loadout.armor == 100, "броня куплена в меню")
	_check("ARMOR 100" in hud.armor_label.text, "HUD показывает броню: %s" % hud.armor_label.text)
	# E запускает дефьюз
	inst.anim.reset(); inst.anim.tick(1.0)
	var ev_e := InputEventKey.new()
	ev_e.keycode = KEY_E
	ev_e.pressed = true
	inst._input(ev_e)
	_check(inst.anim.state == 8, "E запускает дефьюз (state=%d)" % inst.anim.state)
	inst.movement.reset(Vector3(0, 32, 0))
	# реальные клавиши: B открывает закупку, ЛКМ стреляет
	var ev_b := InputEventKey.new()
	ev_b.keycode = KEY_B
	ev_b.pressed = true
	inst._input(ev_b)
	_check(inst.hud.buy_open, "клавиша B открывает закупку")
	inst._input(ev_b)
	OS.delay_msec(150)
	var mag2 = inst.loadout.active().mag
	var ev_m := InputEventMouseButton.new()
	ev_m.button_index = MOUSE_BUTTON_LEFT
	ev_m.pressed = true
	inst._input(ev_m)
	_check(inst.loadout.active().mag == mag2 - 1, "ЛКМ расходует патрон")
	# граната покупается и кладётся в слот
	hud._buy(WeaponData.WeaponId.SMOKE)
	var has_smoke = false
	for wi in inst.loadout.slots.values():
		if wi.id == WeaponData.WeaponId.SMOKE:
			has_smoke = true
	_check(has_smoke, "дымовая куплена")
	# разбор снапшота не падает
	var pkt := PackedByteArray()
	pkt.resize(32)
	pkt[0] = 2
	pkt[5] = 1; pkt[6] = 0
	pkt[7] = 1; pkt[8] = 0
	inst._parse_snapshot(pkt)
	_check(true, "снапшот обработан")
	# смена оружия цифрами
	var ev_1 := InputEventKey.new()
	ev_1.keycode = KEY_1
	ev_1.pressed = true
	inst._input(ev_1)
	_check(inst.loadout.selected == Loadout.Slot.PRIMARY, "1 выбирает основное оружие")
	var ev_2 := InputEventKey.new()
	ev_2.keycode = KEY_2
	ev_2.pressed = true
	inst._input(ev_2)
	_check(inst.loadout.selected == Loadout.Slot.SECONDARY, "2 выбирает пистолет")
	# пауза и выход из неё
	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.pressed = true
	inst._input(ev_esc)
	_check(inst.hud.pause_open and inst.hud.pause_panel.visible, "Esc открывает паузу")
	inst._input(ev_esc)
	_check(not inst.hud.pause_open, "Esc закрывает паузу")

	# стабильность viewmodel: без тряски/дрейфа, отдача возвращается
	var vm_base := Vector3(0.28, -0.25, -0.55)
	inst.movement.reset(Vector3(0, 32, 0))
	inst.loadout.select(Loadout.Slot.PRIMARY)
	inst.anim.set_weapon(WeaponData.WeaponId.AK47)
	inst.anim.reset()
	for i in range(120):
		inst.anim.tick(1.0 / 60.0)
		inst._update_viewmodel(1.0 / 60.0)
	var idle_dist: float = inst.viewmodel.position.distance_to(vm_base)
	_check(idle_dist < 0.02, "viewmodel в покое у базовой точки (%.3f)" % idle_dist)
	var p: Vector3 = inst.viewmodel.position
	_check(not (is_nan(p.x) or is_nan(p.y) or is_nan(p.z)), "позиция viewmodel конечна")
	inst.anim.request_fire()
	inst.anim.tick(0.001)
	inst._update_viewmodel(1.0 / 60.0)
	var kick_dist: float = inst.viewmodel.position.distance_to(vm_base)
	_check(kick_dist > 0.0005, "выстрел даёт короткий кик (%.4f)" % kick_dist)
	for i in range(120):
		inst.anim.tick(1.0 / 60.0)
		inst._update_viewmodel(1.0 / 60.0)
	var back_dist: float = inst.viewmodel.position.distance_to(vm_base)
	_check(back_dist < 0.02, "после отдачи viewmodel возвращается (%.3f)" % back_dist)
	_check(inst.anim.pos_offset.length() < 0.01 and inst.anim.rot_offset.length() < 0.05,
			"анимация не накапливает смещение")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
