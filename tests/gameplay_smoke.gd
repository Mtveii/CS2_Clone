extends SceneTree
## Gameplay smoke: CS2 movement, economy, round state.
const MovementModel = preload("res://shared/gameplay/movement.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const RoundState = preload("res://shared/gameplay/round_state.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# --- movement ---
	var m = MovementModel.new()
	m.reset(Vector3(0, 0, 0))
	var ground = func(_p): return 0.0
	var no_ladder = func(_p): return false

	m.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.on_ground, "starts on ground")
	_check(m.speed_u() > 0.0, "accelerates forward")
	var first_speed = m.speed_u()
	# accelerate over 1 s toward max ~250
	for i in range(64):
		m.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.speed_u() > first_speed, "accelerates over time")
	_check(m.speed_u() <= 251.0, "speed cap ~250 u/s (got %.1f)" % m.speed_u())

	# friction / counter-strafe: no input -> speed decays to 0
	for i in range(64):
		m.step(0, 0.0, 0.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.speed_u() < 1.0, "friction stops player (got %.2f)" % m.speed_u())

	# gravity / jump
	m.reset(Vector3(0, 0, 0))
	m.step(MovementModel.Buttons.JUMP, 0.0, 0.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(not m.on_ground, "jump leaves ground")
	_check(m.vel_u.y > 250.0, "jump velocity ~301 (got %.1f)" % m.vel_u.y)

	# air-strafe: sideways input in air must add horizontal speed
	var air = MovementModel.new()
	air.reset(Vector3(0, 100, 0))
	air.on_ground = false
	air.vel_u = Vector3(0, 0, -200.0)
	var air_ground = func(_p): return -1000.0
	for i in range(8):
		air.step(0, 1.0, 0.0, 0, 0, MovementModel.TICK_DT, air_ground, no_ladder)
	_check(absf(air.vel_u.x) > 0.5, "air-strafe adds lateral speed (got %.2f)" % air.vel_u.x)

	# walk / crouch slower
	var m2 = MovementModel.new()
	m2.reset(Vector3(0, 0, 0))
	for i in range(64):
		m2.step(MovementModel.Buttons.WALK, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m2.speed_u() <= 132.0, "walk speed ~130 (got %.1f)" % m2.speed_u())
	var m3 = MovementModel.new()
	m3.reset(Vector3(0, 0, 0))
	for i in range(64):
		m3.step(MovementModel.Buttons.CROUCH, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m3.speed_u() <= 87.0, "crouch speed ~85 (got %.1f)" % m3.speed_u())

	# weapon speed influences max
	m3.set_weapon_speed(WeaponData.move_speed(WeaponData.WeaponId.AWP))
	for i in range(64):
		m3.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m3.speed_u() <= 201.0, "AWP slows to 200 u/s (got %.1f)" % m3.speed_u())

	# --- economy / round ---
	var r = RoundState.new()
	r.start_warmup()
	r.start_round()
	_check(r.phase == RoundState.Phase.FREEZE, "freeze")
	r.tick(15000)
	_check(r.phase == RoundState.Phase.LIVE, "live")
	r.tick(1000)
	_check(r.time_remaining_ms() < 115000, "time decreases")
	_check(r.plant_bomb("A", r.round_elapsed_ms), "plant")
	_check(r.phase == RoundState.Phase.BOMB_PLANTED, "bomb planted")
	r.tick(40000)
	_check(r.phase == RoundState.Phase.ROUND_END, "detonation ends round")
	_check(r.winner == "T", "T wins on detonation")
	_check(r.money_t >= RoundState.WIN_OBJECTIVE, "T gets 3500 objective reward")

	var r2 = RoundState.new()
	r2.start_round()
	r2.tick(15000)
	r2.plant_bomb("B", r2.round_elapsed_ms)
	_check(r2.defuse_bomb(r2.round_elapsed_ms + 6000), "defuse succeeds")
	_check(r2.winner == "CT" and r2.end_reason == "defuse", "CT wins on defuse")

	# loss ladder
	var r3 = RoundState.new()
	r3.start_round()
	r3.apply_loss("T", false)
	_check(r3.money_t == RoundState.START_MONEY + 1900, "pistol loss pays 1900 (got %d)" % r3.money_t)
	r3.apply_loss("T", true)
	_check(r3.money_t >= RoundState.START_MONEY + 1900 + 2400 + 600, "loss + plant bonus")

	# kill rewards by class
	var before = r3.money_ct
	r3.on_kill("CT", WeaponData.WeaponId.MP9)
	_check(r3.money_ct - before == 600 + RoundState.CT_KILL_TEAM_BONUS, "SMG kill 600 + CT bonus")

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
