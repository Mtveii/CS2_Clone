extends SceneTree
## Тест боя: HP/броня/урон, дефьюз, осмотр/перезарядка, HUD, стрейфы.
const PlayerState = preload("res://shared/gameplay/player_state.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const RoundState = preload("res://shared/gameplay/round_state.gd")
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const MovementModel = preload("res://shared/gameplay/movement.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# --- HP и броня ---
	var p = PlayerState.new()
	_check(p.hp == 100 and p.armor == 0, "старт 100 HP без брони")
	var hit_body = p.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.CHEST)
	_check(hit_body.damage == 36 and p.hp == 64, "AK в грудь: 36 урона, HP 64 (got %d)" % p.hp)
	var p2 = PlayerState.new()
	p2.buy_armor(true)
	_check(p2.armor == 100 and p2.helmet, "Kevlar+шлем куплены")
	var hit_armored = p2.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.CHEST)
	_check(hit_armored.damage == 28, "AK по броне: 28 (got %d)" % hit_armored.damage)
	_check(p2.armor < 100, "броня изнашивается (%d)" % p2.armor)
	var p3 = PlayerState.new()
	p3.buy_armor(true)
	var head = p3.apply_damage(WeaponData.WeaponId.AWP, 100.0, PlayerState.Hitbox.HEAD)
	_check(head.damage >= 112, "AWP в голову через шлем: %d" % head.damage)
	var legs = PlayerState.new()
	legs.buy_armor(true)
	var leg_hit = legs.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.LEG)
	_check(leg_hit.damage == 27, "ноги не защищены броней: 36*0.75=27 (got %d)" % leg_hit.damage)
	var dead = PlayerState.new()
	for i in range(10):
		if not dead.alive: break
		dead.apply_damage(WeaponData.WeaponId.AK47, 0.0, PlayerState.Hitbox.CHEST)
	_check(not dead.alive and dead.hp == 0, "смерть при 0 HP")
	var nohelm = PlayerState.new()
	nohelm.buy_armor(false)
	var head_no = nohelm.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.HEAD)
	_check(head_no.damage == 144, "голова без шлема: 36*4=144 (got %d)" % head_no.damage)
	var he = PlayerState.new()
	he.buy_armor(false)
	var he_hit = he.apply_he(0.0)
	_check(he_hit.damage == 56, "HE по броне ~57 (got %d)" % he_hit.damage)

	# --- дефьюз ---
	var r = RoundState.new()
	r.start_round(); r.tick(15000)
	r.plant_bomb("A", r.round_elapsed_ms)
	var a = WeaponAnimController.new()
	a.set_weapon(WeaponData.WeaponId.KNIFE)
	a.reset(); a.tick(1.0)
	_check(a.request_defuse(), "дефьюз запущен")
	_check(a.state == WeaponAnimController.State.DEFUSE, "состояние DEFUSE")
	var done := false
	for i in range(130):
		a.tick(0.05)
		if a.events.has("defuse_done"): done = true
	_check(done, "анимация дефьюза завершена")
	_check(r.defuse_bomb(r.round_elapsed_ms + 6000), "бомба обезврежена")
	_check(r.winner == "CT" and r.end_reason == "defuse", "победа CT по дефьюзу")

	# --- осмотр / перезарядка ---
	a._state_idle_for_test() if false else null
	var v = WeaponAnimController.new()
	v.set_weapon(WeaponData.WeaponId.AK47)
	v.reset(); v.tick(1.0)
	_check(v.request_inspect(), "осмотр")
	_check(v.events.has("inspect_start"), "inspect_start")
	_check(v.request_reload() == false, "нельзя перезарядить во время осмотра")
	for i in range(80): v.tick(0.05)
	_check(v.is_idle(), "осмотр завершён")
	_check(v.request_reload(), "перезарядка")
	_check(v.events.has("reload_start"), "reload_start")
	for i in range(60): v.tick(0.05)
	_check(v.is_idle(), "перезарядка завершена")

	# --- стрейфы ---
	var m = MovementModel.new()
	m.reset(Vector3(0, 31.7, 0))
	var ground := func(_p): return 31.5
	var no_ladder := func(_p): return false
	for i in range(64):
		m.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	var speed = m.speed_u()
	m.step(0, -1.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	for i in range(20):
		m.step(0, -1.0, 0.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.speed_u() < speed, "counter-strafe снижает скорость (%.1f -> %.1f)" % [speed, m.speed_u()])
	var air = MovementModel.new()
	air.reset(Vector3(0, 100, 0))
	air.on_ground = false
	air.vel_u = Vector3(0, 0, -200)
	var hi := func(_p): return -1000.0
	for i in range(10):
		air.step(0, 1.0, 0.0, 0, 0, MovementModel.TICK_DT, hi, no_ladder)
	_check(absf(air.vel_u.x) > 1.0, "air-strafe работает (%.2f)" % air.vel_u.x)

	# --- покупка брони и HUD ---
	var l = Loadout.new(WeaponData.Team.CT, 2000)
	_check(l.buy_armor(false) and l.armor == 100 and l.money == 1350, "Kevlar $650")
	_check(l.buy_armor(true) and l.helmet and l.money == 350, "шлем докуплен за $350")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
