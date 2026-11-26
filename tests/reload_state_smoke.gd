extends SceneTree
## Состояния анимаций: таймер-первичная перезарядка, equip-отмена, motion-sync,
## упрощённый world-model аниматор. Адаптация Krunker-style промпта под Godot.

const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const WorldModelAnim = preload("res://client/world_model_anim.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _init() -> void:
	var a := WeaponAnimController.new()
	a.set_weapon(WeaponData.WeaponId.AK47)

	# equip 0.2–0.4 s и отдельный clip
	a.equip(WeaponData.WeaponId.M4A4)
	_check(a.state == WeaponAnimController.State.DEPLOY, "equip состояние")
	_check(a.events.has("equip"), "equip событие")
	_check(a.deploy_time >= 0.2 and a.deploy_time <= 0.4,
		"equip длится %.2fс" % a.deploy_time)

	# таймер первичен, анимация вторична
	a.state = WeaponAnimController.State.IDLE
	a.timer = 0.0
	a.events.clear()
	_check(a.request_reload(), "R инициирует перезарядку")
	_check(a.state == WeaponAnimController.State.RELOAD, "состояние RELOAD")
	var done: bool = false
	var phases: Array = []
	for i in range(60):
		a.tick(0.05)
		for e in a.events:
			if not phases.has(e):
				phases.append(e)
			if e == "reload_done":
				done = true
	_check(done, "reload_done приходит по таймеру")
	_check(phases.has("reload_mag_out") and phases.has("reload_mag_in")
			and phases.has("reload_bolt"), "все фазы клипа проиграны")
	_check(a.is_idle(), "RELOAD → IDLE")

	# отмена перезарядки сменой оружия
	a.state = WeaponAnimController.State.IDLE
	a.request_reload()
	a.equip(WeaponData.WeaponId.AWP)
	_check(a.state == WeaponAnimController.State.DEPLOY, "смена оружия прерывает reload")
	var cancelled_done: bool = false
	for i in range(80):
		a.tick(0.05)
		if a.events.has("reload_done"):
			cancelled_done = true
	_check(not cancelled_done, "отменённый reload не выдает reload_done")

	# IDLE ↔ WALK ↔ RUN по скорости
	a.state = WeaponAnimController.State.IDLE
	a.update_motion(0.0)
	_check(a.motion_state == WeaponAnimController.MotionState.IDLE, "motion: idle")
	a.update_motion(120.0)
	_check(a.motion_state == WeaponAnimController.MotionState.WALK, "motion: walk")
	a.update_motion(240.0)
	_check(a.motion_state == WeaponAnimController.MotionState.RUN, "motion: run")

	# world-model: отдельный упрощённый автомат
	var w := WorldModelAnim.new()
	w.update_motion(0.0)
	_check(w.state == WorldModelAnim.State.IDLE, "world: idle")
	w.update_motion(200.0)
	_check(w.state == WorldModelAnim.State.RUN, "world: run")
	w.shoot()
	_check(w.state == WorldModelAnim.State.SHOOT and w.timer > 0.0,
		"world: shoot one-shot")
	for i in range(10):
		w.tick(0.02)
	_check(w.state == WorldModelAnim.State.IDLE, "world: shoot → idle")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
