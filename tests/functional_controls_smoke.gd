extends SceneTree
## Реальные UI/ввод: покупка кнопкой, осмотр, прыжок/присед/шаг, бросок гранаты.

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


func _release(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)


func _init() -> void:
	root.size = Vector2(1280, 720)
	var cfg := ConfigFile.new()
	cfg.set_value("map", "id", "oasis")
	cfg.save("user://selected_map.cfg")
	var c = load("res://scenes/client.tscn").instantiate()
	c.server_url = "ws://127.0.0.1:1"
	root.add_child(c)
	await process_frame
	await process_frame

	# покупка через реальную кнопку в меню закупки
	_key(KEY_B)
	await process_frame
	_check(c.hud.buy_open, "B открыл меню закупки")
	var buy_btn: Button = null
	for card in c.hud.buy_grid.get_children():
		var vb := card.get_child(0) as VBoxContainer
		if vb == null:
			continue
		var name_label: Label = vb.get_child(1) as Label
		if name_label != null and name_label.text.contains("Galil AR"):
			for child in vb.get_children():
				if child is Button:
					buy_btn = child
			break
	_check(buy_btn != null, "в меню есть кнопка КУПИТЬ для Galil AR")
	if buy_btn != null:
		var money_before: int = c.loadout.money
		buy_btn.pressed.emit()
		await process_frame
		_check(c.loadout.money < money_before or c.loadout.active().id == c.WeaponData.WeaponId.AWP,
			"покупка кнопкой списала деньги/сменила оружие")
	_key(KEY_B)
	await process_frame

	# осмотр по F и I
	c.anim.state = 0
	c.anim.timer = 0.0
	_key(KEY_F)
	await process_frame
	_check(c.anim.state == 4, "F запустил осмотр")
	c.anim.state = 0
	c.anim.timer = 0.0
	_key(KEY_I)
	await process_frame
	_check(c.anim.state == 4, "I тоже запустил осмотр")
	c.anim.state = 0
	c.anim.timer = 0.0

	# прыжок / присед / медленный шаг
	_key(KEY_SPACE)
	await process_frame
	await process_frame
	_check(not c.movement.on_ground and c.movement.vel_u.y > 0,
		"прыжок работает")
	_release(KEY_SPACE)
	for i in range(40):
		await process_frame
	_key(KEY_C)
	await process_frame
	await process_frame
	_check(c.movement.crouching, "присед по C работает")
	_release(KEY_C)
	_key(KEY_SHIFT)
	await process_frame
	await process_frame
	_check(c.movement.walking, "медленный шаг по Shift работает")
	_release(KEY_SHIFT)

	# бросок гранаты
	_check(c.loadout.select(c.Loadout.Slot.GRENADE_HE_DECOY), "grenade slot выбран")
	var before: int = c.grenades.active.size()
	_key(KEY_G)
	await process_frame
	_check(c.grenades.active.size() == before + 1,
		"G бросает гранату (%d)" % c.grenades.active.size())
	await process_frame
	var meshes: int = 0
	for child in c.get_children():
		if child.name == "Grenade":
			meshes += 1
	_check(meshes > 0, "граната видна в сцене (%d)" % meshes)

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
