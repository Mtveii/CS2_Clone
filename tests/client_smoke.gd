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
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
