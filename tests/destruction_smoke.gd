extends SceneTree
## Разрушение: материалы, урон оружия -> разрушение, HE, огонь, физика обломков.
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelConstDefs = preload("res://shared/voxel/voxel_constants.gd")
const VoxelMat = preload("res://shared/voxel/voxel_material.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const DestructionSystem = preload("res://shared/gameplay/destruction.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# материалы
	_check(VoxelMat.hp(VoxelMat.MaterialId.GLASS) == 8, "glass hp 8")
	_check(VoxelMat.hp(VoxelMat.MaterialId.CONCRETE) == 120, "concrete hp 120")
	_check(VoxelMat.flammability(VoxelMat.MaterialId.WOOD) > 0.0, "wood flammable")
	_check(VoxelMat.flammability(VoxelMat.MaterialId.CONCRETE) == 0.0, "concrete not flammable")

	# мир со стеной из разных материалов
	var w = VoxelWorldStore.new()
	w.bounds_min = Vector3i(-16, -8, -16)
	w.bounds_max = Vector3i(16, 24, 16)
	var wood_filled = w.fill_box_material(Vector3i(-4, 0, 2), Vector3i(4, 4, 2), VoxelMat.MaterialId.WOOD)
	_check(wood_filled > 0, "wood wall created (%d voxels)" % wood_filled)
	var concrete_filled = w.fill_box_material(Vector3i(-4, 0, 6), Vector3i(4, 4, 6), VoxelMat.MaterialId.CONCRETE)
	_check(concrete_filled > 0, "concrete wall created (%d voxels)" % concrete_filled)

	# урон оружия -> разрушение
	var d = DestructionSystem.new()
	d.reset()
	var wood_voxel = Vector3i(0, 2, 2)
	var hp_before = w.get_voxel_hp(wood_voxel)
	# AWP: урон 115, пробитие 0.975 -> энергия ~170 -> дерево (30 hp) разрушается
	var res_awp = d.bullet_impact(w, wood_voxel, Vector3(0, 0, -1), WeaponData.WeaponId.AWP, 100.0)
	_check(res_awp.damage == 115, "AWP damage 115 used for destruction")
	_check(res_awp.destroyed.size() > 0, "AWP destroys wood voxel")
	_check(w.get_voxel_material(wood_voxel) == VoxelMat.MaterialId.AIR, "destroyed voxel -> air")
	_check(d.total_destroyed_voxels > 0, "destroyed counter increments")

	# Glock не должен пробить бетон с первого выстрела
	var concrete_voxel = Vector3i(0, 2, 6)
	var hp_concrete_before = w.get_voxel_hp(concrete_voxel)
	var res_glock = d.bullet_impact(w, concrete_voxel, Vector3(0, 0, -1), WeaponData.WeaponId.GLOCK, 0.0)
	_check(res_glock.damage == 30, "Glock damage 30 used")
	_check(w.get_voxel_hp(concrete_voxel) < hp_concrete_before, "concrete damaged but not destroyed")
	_check(w.get_voxel_material(concrete_voxel) == VoxelMat.MaterialId.CONCRETE, "concrete survives glock")

	# HE разрушает переменное число вокселей в зависимости от материала
	var d2 = DestructionSystem.new()
	var res_he_wood = d2.he_blast(w, w.voxel_to_world_mm(Vector3i(0, 2, 2)) + Vector3(100, 100, 100))
	_check(res_he_wood.destroyed > 0, "HE destroys wood voxels (%d)" % res_he_wood.destroyed)
	_check(d2.debris.size() > 0, "HE spawns debris (%d)" % d2.debris.size())

	# огонь разрушает дерево, но не бетон (свежая стена, HE всё сжёг выше)
	var wf = VoxelWorldStore.new()
	wf.bounds_min = Vector3i(-16, -8, -16); wf.bounds_max = Vector3i(16, 24, 16)
	wf.fill_box_material(Vector3i(-4, 0, 2), Vector3i(4, 4, 2), VoxelMat.MaterialId.WOOD)
	var d3 = DestructionSystem.new()
	var wood_v2 = Vector3i(0, 2, 2)
	var fire = d3.fire_damage_step(wf, wf.voxel_to_world_mm(wood_v2) + Vector3(100, 100, 100), 5.0, 1.0)
	_check(fire.dps == 40, "fire dps capped 40")
	_check(fire.destroyed > 0, "fire destroys wood (%d)" % fire.destroyed)
	var concrete_fire = DestructionSystem.new()
	var fire_c = concrete_fire.fire_damage_step(w, w.voxel_to_world_mm(Vector3i(0, 2, 6)) + Vector3(100, 100, 100), 5.0, 1.0)
	_check(fire_c.destroyed == 0, "fire does not destroy concrete")

	# физика обломков: гравитация и отскок
	var ground = func(_p): return 0.0
	var d4 = DestructionSystem.new()
	d4._spawn_debris(Vector3(0, 1000, 0), VoxelMat.MaterialId.WOOD, 3, Vector3(100, 0, 0))
	_check(d4.debris.size() == 3, "debris spawned")
	var y0 = d4.debris[0].pos_mm.y
	d4.step_debris(0.1, ground)
	_check(d4.debris.size() > 0 and d4.debris[0].pos_mm.y < y0, "debris falls under gravity")
	for i in range(50):
		d4.step_debris(0.05, ground)
	_check(d4.debris.size() > 0 and d4.debris[0].pos_mm.y >= 0.0, "debris lands on ground")
	var any_ground := false
	for piece in d4.debris:
		if piece.on_ground:
			any_ground = true
			break
	_check(any_ground, "debris marked on ground")
	for i in range(100):
		d4.step_debris(0.05, ground)
	_check(d4.debris.is_empty(), "debris expires after lifetime")

	# детерминизм: одинаковые выстрелы -> одинаковый результат
	var w1 = VoxelWorldStore.new()
	w1.bounds_min = Vector3i(-16, -8, -16); w1.bounds_max = Vector3i(16, 24, 16)
	w1.fill_box_material(Vector3i(-2, 0, 2), Vector3i(2, 2, 2), VoxelMat.MaterialId.WOOD)
	var w2 = VoxelWorldStore.new()
	w2.bounds_min = Vector3i(-16, -8, -16); w2.bounds_max = Vector3i(16, 24, 16)
	w2.fill_box_material(Vector3i(-2, 0, 2), Vector3i(2, 2, 2), VoxelMat.MaterialId.WOOD)
	var r1 = DestructionSystem.new().bullet_impact(w1, Vector3i(0, 1, 2), Vector3(0, 0, -1), WeaponData.WeaponId.AK47, 100.0)
	var r2 = DestructionSystem.new().bullet_impact(w2, Vector3i(0, 1, 2), Vector3(0, 0, -1), WeaponData.WeaponId.AK47, 100.0)
	_check(r1.destroyed.size() == r2.destroyed.size(), "deterministic destruction (got %d vs %d)" % [r1.destroyed.size(), r2.destroyed.size()])

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
