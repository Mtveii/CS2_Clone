extends SceneTree
## Проверка процедурного viewmodel: у каждого класса оружия своя модель,
## есть руки/ствол, трансформы конечны, отдача не накапливается.

const WeaponViewModelScript = preload("res://client/weapon_viewmodel.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _init() -> void:
	var vm = WeaponViewModelScript.new()
	root.add_child(vm)
	await process_frame

	var cases: Array = [
		[WeaponData.WeaponId.GLOCK, "Glock-18", 2],
		[WeaponData.WeaponId.MP9, "MP9", 2],
		[WeaponData.WeaponId.AK47, "AK-47", 2],
		[WeaponData.WeaponId.AWP, "AWP", 2],
		[WeaponData.WeaponId.NOVA, "Nova", 2],
		[WeaponData.WeaponId.NEGEV, "Negev", 2],
		[WeaponData.WeaponId.KNIFE, "Knife", 1],
		[WeaponData.WeaponId.HE, "HE Grenade", 1],
		[WeaponData.WeaponId.C4, "C4", 1],
	]
	for case in cases:
		var id: int = int(case[0])
		var expected_name: String = String(case[1])
		var expected_hands: int = int(case[2])
		vm.set_weapon(id)
		var model: Node3D = vm.model_root
		_check(vm.model_name == expected_name, "%s: имя модели (%s)" % [expected_name, vm.model_name])
		_check(model.get_child_count() >= 6,
				"%s: собрана из деталей (%d)" % [expected_name, model.get_child_count()])
		_check(model.get_node_or_null("Muzzle") != null, "%s: есть дуло" % expected_name)
		_check(vm.hands.size() == expected_hands,
				"%s: рук %d" % [expected_name, vm.hands.size()])
		var meshes := 0
		var finite := true
		for c in model.get_children():
			if c is MeshInstance3D:
				meshes += 1
				var p: Vector3 = c.position
				if is_nan(p.x) or is_nan(p.y) or is_nan(p.z):
					finite = false
				if c.material_override == null:
					finite = false
				if c.mesh is BoxMesh and (c.mesh as BoxMesh).size.length() <= 0.0:
					finite = false
				if c.mesh is CylinderMesh and (c.mesh as CylinderMesh).height <= 0.0:
					finite = false
		_check(meshes >= 6, "%s: мешей %d" % [expected_name, meshes])
		_check(finite, "%s: трансформы и меши корректны" % expected_name)

	# разные классы не должны выглядеть одинаково
	vm.set_weapon(WeaponData.WeaponId.GLOCK)
	var pistol_parts: int = vm.model_root.get_child_count()
	vm.set_weapon(WeaponData.WeaponId.AWP)
	var sniper_parts: int = vm.model_root.get_child_count()
	_check(pistol_parts != sniper_parts, "пистолет и снайперка отличаются (%d vs %d)"
			% [pistol_parts, sniper_parts])

	# анимация: отдача возвращается в ноль, смещение не дрейфует
	var a = WeaponAnimController.new()
	a.set_weapon(WeaponData.WeaponId.AK47)
	a.reset()
	for i in range(180):
		a.tick(1.0 / 60.0)
	_check(a.is_idle(), "deploy завершается")
	var idle_pos: float = a.pos_offset.length()
	for i in range(20):
		a.tick(1.0 / 60.0)
	_check(absf(a.pos_offset.length() - idle_pos) < 0.01, "в покое нет накопления смещения")
	var fired: bool = a.request_fire()
	_check(fired, "выстрел запускает FIRE")
	for i in range(30):
		a.tick(1.0 / 60.0)
	for i in range(240):
		a.tick(1.0 / 60.0)
	_check(a.is_idle(), "после выстрела снова IDLE")
	_check(a.recoil.length() < 0.05, "отдача вернулась в ноль (%.3f)" % a.recoil.length())
	_check(a.pos_offset.length() < 0.01, "смещение вернулось (%.3f)" % a.pos_offset.length())
	_check(not (is_nan(a.pos_offset.x) or is_nan(a.rot_offset.x)), "трансформы конечны")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
