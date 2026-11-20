extends SceneTree
## Тест анимаций (deploy/fire/reload phases/inspect/melee/plant) и звуков.
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const AudioManager = preload("res://client/audio_manager.gd")
const GameSettings = preload("res://client/settings.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# тайминги перезарядки из CS2
	var a = WeaponAnimController.new()
	a.set_weapon(WeaponData.WeaponId.AK47)
	_check(absf(a.reload_duration() - 2.43) < 0.01, "AK перезарядка 2.43с")
	a.set_weapon(WeaponData.WeaponId.AWP)
	_check(absf(a.reload_duration() - 3.67) < 0.01, "AWP перезарядка 3.67с")
	a.set_weapon(WeaponData.WeaponId.M4A4)
	_check(absf(a.reload_duration() - 3.07) < 0.01, "M4A4 перезарядка 3.07с")
	a.set_weapon(WeaponData.WeaponId.AK47)

	# deploy
	a.reset()
	_check(a.state == WeaponAnimController.State.DEPLOY, "deploy состояние")
	_check(a.events.has("deploy"), "deploy событие")
	a.tick(1.0)
	_check(a.is_idle(), "deploy закончен")

	# стрельба + отдача (детерминированный паттерн)
	a.set_weapon(WeaponData.WeaponId.AK47)
	a.request_fire()
	_check(a.events.has("fire"), "fire событие")
	_check(a.recoil.length() > 0.0, "отдача применена")
	var r1 = a.recoil.y
	var b = WeaponAnimController.new()
	b.set_weapon(WeaponData.WeaponId.AK47)
	b.request_fire()
	_check(b.recoil.y == r1, "паттерн отдачи детерминирован")
	a.tick(0.1)
	_check(a.is_idle(), "fire закончен")

	# перезарядка: 3 фазы и 3 события
	a.request_reload()
	_check(a.state == WeaponAnimController.State.RELOAD, "reload состояние")
	var seen: Array = []
	for i in range(60):
		a.tick(0.05)
		for e in a.events:
			if not seen.has(e):
				seen.append(e)
	_check(seen.has("reload_mag_out"), "событие mag out")
	_check(seen.has("reload_mag_in"), "событие mag in")
	_check(seen.has("reload_bolt"), "событие bolt")
	_check(a.is_idle(), "reload закончен")

	# осмотр
	a.request_inspect()
	_check(a.state == WeaponAnimController.State.INSPECT, "inspect состояние")
	_check(a.events.has("inspect_start"), "inspect_start событие")
	var inspect_events: Array = []
	for i in range(80):
		a.tick(0.05)
		for e in a.events:
			if not inspect_events.has(e):
				inspect_events.append(e)
	_check(inspect_events.has("inspect_spin"), "inspect spin событие")
	_check(inspect_events.has("inspect_end"), "inspect end событие")
	_check(a.is_idle(), "inspect закончен")

	# ближний бой, переключение, посадка/дефьюз
	a.request_melee()
	_check(a.events.has("melee_swing"), "melee swing")
	for i in range(20): a.tick(0.05)
	_check(a.is_idle(), "melee закончен")
	a.request_switch()
	_check(a.events.has("switch"), "switch событие")
	for i in range(15): a.tick(0.05)
	a.request_plant()
	var pe := false
	for i in range(80):
		a.tick(0.05)
		if a.events.has("plant_done"): pe = true
	_check(pe, "plant_done")
	a.request_defuse()
	var de := false
	for i in range(120):
		a.tick(0.05)
		if a.events.has("defuse_done"): de = true
	_check(de, "defuse_done")

	# звуки
	var am = AudioManager.new()
	root.add_child(am)
	await process_frame
	_check(am.streams.size() >= 25, "загружено %d звуков" % am.streams.size())
	for key in ["fire_rifle", "fire_awp", "reload_mag_out", "reload_mag_in", "reload_bolt",
			"inspect", "explosion", "flash", "smoke", "step_concrete", "beep", "headshot"]:
		if key == "fire_awp":
			_check(am.streams.has("fire_sniper"), "sniper fire sound")
		else:
			_check(am.streams.has(key), "звук %s" % key)
	var s = GameSettings.new()
	am.update_settings(s)
	am.weapon_fire(WeaponData.WeaponId.AK47)
	am.handle_anim_events(["reload_mag_out", "reload_mag_in", "reload_bolt", "inspect_start"], WeaponData.WeaponId.AK47)
	am.grenade_event("he_explode")
	am.world_event("footstep", Vector3(0, 0, 0), "concrete")
	_check(am.players.size() == 20, "пул 2D проигрывателей")
	_check(am.players_3d.size() == 20, "пул 3D проигрывателей")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
