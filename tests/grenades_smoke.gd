extends SceneTree
## Grenade smoke: physics, smoke voxels, flash, fire, HE.
const GrenadeSystem = preload("res://shared/gameplay/grenades.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	var g = GrenadeSystem.new()
	g.reset()
	# constants
	_check(GrenadeSystem.THROW_SPEED_U == 675.0, "throw speed 675 u/s")
	_check(absf(GrenadeSystem.GRAVITY_U_S2 - 320.0) < 0.01, "grenade gravity 320")
	_check(absf(GrenadeSystem.BOUNCE - 0.45) < 0.01, "bounce 0.45")
	_check(GrenadeSystem.SMOKE_GRID == 32, "smoke 32^3 voxels")
	_check(absf(GrenadeSystem.SMOKE_DURATION_S - 18.0) < 0.01, "smoke 18 s")
	_check(absf(GrenadeSystem.FIRE_DURATION_S - 7.03125) < 0.01, "fire 7.03125 s")

	# long vs short throw
	var long = g.throw_grenade(GrenadeSystem.Type.SMOKE, Vector3(0, 64, 0), Vector3(0, 0, -1),
		GrenadeSystem.ThrowType.LONG, 1, 0)
	var short = g.throw_grenade(GrenadeSystem.Type.SMOKE, Vector3(0, 64, 0), Vector3(0, 0, -1),
		GrenadeSystem.ThrowType.SHORT, 1, 0)
	_check(long.vel.length() > short.vel.length(), "long throw faster than short")
	_check(g.active.size() == 2, "two active grenades")

	# physics step + detonation -> smoke
	var ground = func(_p): return 0.0
	for i in range(200):
		g.step(0.02, ground)
	_check(g.active.is_empty(), "grenades detonated")
	_check(g.smokes.size() == 2, "two smokes spawned")

	# smoke voxels + HE gap
	var s = g.smokes[0]
	var filled = 0
	for v in s.voxels:
		if v == 1: filled += 1
	_check(filled > 1000, "smoke voxels populated (got %d)" % filled)
	g._he_blast(s.center)
	_check(s.he_gap_until > 0.0, "HE creates smoke gap")

	# flash duration depends on angle/distance
	var full = g.flash_duration(Vector3(0, 0, 0), Vector3(0, 0, 500), Vector3(0, 0, 1))
	var away = g.flash_duration(Vector3(0, 0, 0), Vector3(0, 0, 500), Vector3(0, 0, -1))
	_check(full > 0.0 and away == 0.0, "flash only when looking at it")
	_check(full <= GrenadeSystem.FLASH_MAX_S, "flash capped")

	# fire damage ramps
	_check(g.fire_dps(0.0) < g.fire_dps(5.0), "fire damage increases")
	_check(g.fire_dps(100.0) == 40, "fire capped 40 dps")

	# HE damage falloff
	var near = g.he_damage(0.0, false)
	var far = g.he_damage(300.0, false)
	_check(near == 98 and far < near, "HE 98 max, falloff")
	var armored = g.he_damage(0.0, true)
	_check(armored < near, "HE less vs armor")

	# smoke blocks ray
	g.smokes[0].he_gap_until = 0.0
	_check(g.smoke_blocks_ray(Vector3(0, 0, -1000), Vector3(0, 0, 1), 3000.0), "smoke blocks vision")

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
