extends SceneTree
## Production-контракты: инварианты FSM, экономики, физики и гранат под нагрузкой.
## Тест намеренно «жёсткий»: ровно 1000+ итераций и проверка каждого шага.

const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const PlayerState = preload("res://shared/gameplay/player_state.gd")
const MovementModel = preload("res://shared/gameplay/movement.gd")
const GrenadeSystem = preload("res://shared/gameplay/grenades.gd")
const FriendsStore = preload("res://client/friends.gd")

var failures: int = 0
var checks: int = 0


func _check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error("[fail] " + m)


func _finite(v: Vector3) -> bool:
	return not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z)


func _init() -> void:
	# --- FSM анимаций: 900 смешанных input, никаких застреваний/NaN ---
	var a := WeaponAnimController.new()
	a.set_weapon(WeaponData.WeaponId.AK47)
	a.reset()
	a.tick(1.0)
	var reload_done: int = 0
	for i in range(900):
		match i % 41:
			0: a.request_fire()
			3: a.request_reload()
			6: a.request_inspect()
			9: a.equip(WeaponData.WeaponId.M4A4)
			12: a.cancel_action()
		a.tick(1.0 / 60.0)
		if a.events.has("reload_done"):
			reload_done += 1
		_check(a.state >= 0 and a.state <= 8, "FSM state в диапазоне на шаге %d" % i)
		_check(a.timer >= -0.001, "FSM timer >= 0 на шаге %d" % i)
		_check(_finite(a.pos_offset) and _finite(a.rot_offset),
			"FSM offsets конечны на шаге %d" % i)
	for i in range(200):
		a.tick(0.05)
	_check(a.is_idle(), "FSM возвращается в IDLE после нагрузки")
	a.cancel_action()
	if a.request_reload():
		for i in range(80):
			a.tick(0.05)
			if a.events.has("reload_done"):
				reload_done += 1
	_check(a.recoil.length() < 0.01, "recoil полностью затух (%.4f)" % a.recoil.length())
	_check(reload_done > 0, "reload_done эмитируется хотя бы раз (%d)" % reload_done)

	# --- экономика: 1000 случайных покупок/выборов/выстрелов ---
	var load := Loadout.new(WeaponData.Team.T, 800)
	var ids: Array = WeaponData.WEAPONS.keys()
	for i in range(1000):
		load.buy(int(ids[i % ids.size()]))
		if i % 5 == 0:
			load.select(i % 10)
		if i % 7 == 0:
			load.fire(i * 100)
		if i % 11 == 0:
			load.reload(i * 100)
		_check(load.money >= 0, "деньги не уходят в минус на шаге %d" % i)
		var wi = load.active()
		_check(wi == null or (wi.mag >= 0 and wi.reserve >= 0),
			"магазин/резерв неотрицательны на шаге %d" % i)

	# --- урон: 200 попаданий, HP всегда в [0,100] ---
	var p := PlayerState.new()
	for i in range(200):
		if not p.alive:
			p.reset()
		p.apply_damage(WeaponData.WeaponId.AK47, float(i % 500),
				int(i % 5))
		_check(p.hp >= 0 and p.hp <= 100, "HP в диапазоне на шаге %d" % i)

	# --- движение: 1000 шагов с разными вводами, без NaN/телепортов ---
	var m := MovementModel.new()
	m.reset(Vector3(0, 31.5, 0))
	var ground := func(_pos): return 31.5
	var no_ladder := func(_p): return false
	var max_step: float = 0.0
	var last := m.pos_u
	for i in range(1000):
		var mx: float = float((i % 3) - 1)
		var mz: float = float(((i / 7) % 3) - 1)
		var buttons: int = 0
		if i % 17 == 0: buttons |= MovementModel.Buttons.JUMP
		if i % 23 == 0: buttons |= MovementModel.Buttons.CROUCH
		m.step(buttons, mx, mz, (i * 97) % 65536, 0, 1.0 / 64.0, ground, no_ladder)
		_check(_finite(m.pos_u) and _finite(m.vel_u), "movement finite на шаге %d" % i)
		var step: float = m.pos_u.distance_to(last)
		max_step = maxf(max_step, step)
		_check(step < 50.0, "нет телепорта на шаге %d (%.1f u)" % [i, step])
		last = m.pos_u

	# --- гранаты: 50 бросков, 300 шагов, всё детонирует и очищается ---
	var g := GrenadeSystem.new()
	for i in range(50):
		g.throw_grenade(i % 6, Vector3(0, 80, 0),
				Vector3(float(i % 3) - 1, 0.2, -1), i % 3, i, WeaponData.Team.T)
	_check(g.active.size() == 50, "50 активных гранат создано")
	for i in range(300):
		g.step(0.05, ground)
		_check(g.active.size() <= 50, "число гранат не растёт на шаге %d" % i)
	_check(g.active.is_empty(), "все гранаты детонировали")
	_check(g.smokes.size() < 10 and g.fires.size() < 10, "weather-зоны ограничены")

	# --- битые конфиги не ломают загрузку ---
	var broken := "user://friends_broken_test.cfg"
	var f := FileAccess.open(broken, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var friends := FriendsStore.new(broken)
	_check(friends.is_empty(), "битый friends.cfg → пустой список")
	dir_remove(broken)

	print("CHECKS: %d" % checks)
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d/%d)" % [failures, checks])
	quit(1 if failures > 0 else 0)


func dir_remove(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
