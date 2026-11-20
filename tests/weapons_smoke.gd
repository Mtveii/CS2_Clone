extends SceneTree
## Weapons smoke: stats, damage formula, economy rewards, animation states.
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# catalog
	_check(WeaponData.WEAPONS.size() >= 40, "weapon count >= 40 (got %d)" % WeaponData.WEAPONS.size())
	var expected = [WeaponData.WeaponId.GLOCK, WeaponData.WeaponId.AWP,
		WeaponData.WeaponId.KNIFE, WeaponData.WeaponId.C4, WeaponData.WeaponId.HE]
	for w in expected:
		_check(WeaponData.WEAPONS.has(w), "weapon %d exists" % w)
	var t_pistols = WeaponData.weapons_for_team(WeaponData.Team.T, "pistol")
	_check(t_pistols.has(WeaponData.WeaponId.GLOCK), "T has Glock")
	_check(not t_pistols.has(WeaponData.WeaponId.USP), "T has no USP")
	var ct_pistols = WeaponData.weapons_for_team(WeaponData.Team.CT, "pistol")
	_check(ct_pistols.has(WeaponData.WeaponId.USP) and ct_pistols.has(WeaponData.WeaponId.P2000), "CT has USP+P2000")

	# damage & hitbox
	_check(WeaponData.compute_damage(WeaponData.WeaponId.AWP, 10.0, "chest", false) > 100, "AWP one-shot body")
	var ak_hs = WeaponData.compute_damage(WeaponData.WeaponId.AK47, 10.0, "head", true)
	_check(ak_hs >= 100, "AK one-tap helmet head (got %d)" % ak_hs)
	var m4s_hs = WeaponData.compute_damage(WeaponData.WeaponId.M4A1S, 10.0, "head", true)
	_check(m4s_hs < 100, "M4A1-S cannot one-tap helmet (got %d)" % m4s_hs)
	var deagle_hs = WeaponData.compute_damage(WeaponData.WeaponId.DEAGLE, 10.0, "head", true)
	_check(deagle_hs >= 100, "Deagle one-tap")
	_check(WeaponData.compute_damage(WeaponData.WeaponId.AK47, 10.0, "left_leg", false) <
		WeaponData.compute_damage(WeaponData.WeaponId.AK47, 10.0, "chest", false), "legs 0.75x")

	# armor: SG553 has 100% pen -> armor irrelevant
	var sg_no = WeaponData.compute_damage(WeaponData.WeaponId.SG553, 10.0, "chest", false)
	var sg_yes = WeaponData.compute_damage(WeaponData.WeaponId.SG553, 10.0, "chest", true)
	_check(sg_no == sg_yes, "SG553 ignores armor")

	# falloff: shotgun loses a lot at range, AWP almost none
	var nova_close = WeaponData.compute_damage(WeaponData.WeaponId.NOVA, 100.0, "chest", false)
	var nova_far = WeaponData.compute_damage(WeaponData.WeaponId.NOVA, 1200.0, "chest", false)
	_check(nova_far < nova_close, "shotgun falloff")
	var awp_close = WeaponData.compute_damage(WeaponData.WeaponId.AWP, 500.0, "chest", false)
	var awp_far = WeaponData.compute_damage(WeaponData.WeaponId.AWP, 5000.0, "chest", false)
	_check(awp_far >= awp_close * 0.8, "AWP low falloff")

	# fire rate / economy
	_check(absf(WeaponData.fire_interval(WeaponData.WeaponId.AK47) - 0.1) < 0.001, "AK 600 RPM -> 0.1s")
	_check(WeaponData.kill_reward(WeaponData.WeaponId.AWP) == 100, "AWP kill $100")
	_check(WeaponData.kill_reward(WeaponData.WeaponId.KNIFE) == 1500, "Knife kill $1500")
	_check(WeaponData.kill_reward(WeaponData.WeaponId.MP9) == 600, "SMG kill $600")
	_check(WeaponData.pellets(WeaponData.WeaponId.NOVA) == 9, "Nova 9 pellets")
	_check(WeaponData.compute_shotgun_damage(WeaponData.WeaponId.NOVA, 10.0, "chest", false, 9) > 0, "shotgun damage")
	_check(WeaponData.move_speed(WeaponData.WeaponId.KNIFE) == 250.0, "knife speed 250")
	_check(WeaponData.move_speed(WeaponData.WeaponId.AWP) == 200.0, "AWP speed 200")
	_check(WeaponData.KNIFE_SKINS.size() >= 5, "knife skins")

	# animation state machine
	var anim = WeaponAnimController.new()
	anim.reset()
	_check(anim.state == WeaponAnimController.State.DEPLOY, "deploy state")
	anim.tick(1.0)
	_check(anim.is_idle(), "deploy -> idle")
	_check(anim.request_fire(), "fire request")
	_check(not anim.request_reload(), "reload blocked during fire")
	anim.tick(0.2)
	_check(anim.is_idle(), "idle after fire")
	_check(anim.request_reload(), "reload request")
	anim.tick(3.0)
	_check(anim.is_idle(), "idle after reload")
	_check(anim.request_inspect(), "inspect request")
	anim.tick(3.5)
	_check(anim.is_idle(), "idle after inspect")
	_check(anim.request_melee(), "melee request")

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
