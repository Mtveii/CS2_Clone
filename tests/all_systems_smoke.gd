extends SceneTree
## Кросс-системный smoke: WeaponData → Loadout → Combat → Round → Hitreg →
## Destruction → Grenades → MapModule → Audio → Settings.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const PlayerState = preload("res://shared/gameplay/player_state.gd")
const RoundState = preload("res://shared/gameplay/round_state.gd")
const HitRegistration = preload("res://shared/gameplay/hitreg.gd")
const DestructionSystem = preload("res://shared/gameplay/destruction.gd")
const GrenadeSystem = preload("res://shared/gameplay/grenades.gd")
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMat = preload("res://shared/voxel/voxel_material.gd")
const MapModuleLoader = preload("res://shared/map/map_module_loader.gd")
const AudioManager = preload("res://client/audio_manager.gd")
const GameSettings = preload("res://client/settings.gd")

var failures: int = 0


func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _init() -> void:
	# каталог и экономика
	_check(WeaponData.WEAPONS.size() == 43, "WeaponData: 43 оружия")
	var load := Loadout.new(WeaponData.Team.T, 16000)
	_check(load.slots.has(Loadout.Slot.KNIFE) and load.slots.has(Loadout.Slot.SECONDARY),
		"Loadout: нож+пистолет по умолчанию")
	_check(load.buy(WeaponData.WeaponId.M4A4) == false, "T не может купить M4A4")
	_check(load.buy(WeaponData.WeaponId.GALIL), "T покупает Galil")
	load.select(Loadout.Slot.PRIMARY)
	var shot = load.fire(1000)
	_check(shot.fired and load.active().mag == 34, "выстрел расходует патрон")
	load.active().mag = 5
	_check(load.reload(2000) and load.active().mag == 35, "reload наполняет магазин")

	# урон/раунд
	var p := PlayerState.new()
	var dmg = p.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.CHEST)
	_check(dmg.damage == 36 and p.hp == 64, "урон AK в грудь")
	var p2 := PlayerState.new()
	p2.buy_armor(true)
	var arm = p2.apply_damage(WeaponData.WeaponId.AK47, 100.0, PlayerState.Hitbox.CHEST)
	_check(arm.damage == 28 and p2.armor < 100, "броня поглощает урон")
	var round := RoundState.new()
	round.start_round()
	round.tick(15000)
	round.on_kill("T", WeaponData.WeaponId.AK47, 1)
	_check(round.money_t > round.money_ct, "награда за kill")
	round.plant_bomb("A", round.round_elapsed_ms)
	_check(round.phase == RoundState.Phase.BOMB_PLANTED, "бомба заложена")
	_check(round.defuse_bomb(round.round_elapsed_ms + 6000) and round.winner == "CT", "дефьюз → победа CT")

	# hit registration
	var hr := HitRegistration.new()
	var snap := HitRegistration.PlayerSnap.new()
	snap.player_id = 7
	snap.pos = Vector3(1, 2, 3)
	snap.yaw = 0
	snap.pitch = 0
	snap.alive = true
	snap.timestamp_ms = 1000
	hr.record_snapshot(snap)
	_check(hr.rewind_position(7, 1000).distance_to(Vector3(1, 2, 3)) < 0.01,
		"rewind позиции игрока")

	# разрушение
	var world := VoxelWorldStore.new()
	world.bounds_min = Vector3i(-8, -8, -8)
	world.bounds_max = Vector3i(8, 16, 8)
	world.fill_box_material(Vector3i(-2, 0, 2), Vector3i(2, 4, 2), VoxelMat.MaterialId.WOOD)
	var destr := DestructionSystem.new()
	var impact = destr.bullet_impact(world, Vector3i(0, 2, 2), Vector3(0, 0, -1),
			WeaponData.WeaponId.AWP, 100.0)
	_check(impact.destroyed.size() > 0, "AWP разрушает дерево")

	# гранаты
	var g := GrenadeSystem.new()
	g.throw_grenade(GrenadeSystem.Type.HE, Vector3(0, 80, 0), Vector3(0, 0, -1),
			GrenadeSystem.ThrowType.LONG, 1, WeaponData.Team.T)
	_check(g.active.size() == 1, "граната создана")
	for i in range(50):
		g.step(0.05, func(_p): return 0.0)
	_check(g.active.is_empty(), "граната детонировала по таймеру")

	# карты/аудио/настройки
	var catalog := MapModuleLoader.load_catalog()
	_check(catalog.maps.size() == 3, "каталог изолированных карт")
	_check(FileAccess.file_exists("res://assets/maps/oasis.vmap"), "Oasis на месте")
	var am := AudioManager.new()
	root.add_child(am)
	var st := GameSettings.new()
	am.update_settings(st)
	am.handle_anim_events(["fire", "reload_mag_in", "inspect_start"], WeaponData.WeaponId.AK47)
	_check(st.all_categories().size() > 0, "настройки имеют категории")
	_check(st.effective_sensitivity() > 0.0, "чувствительность положительна")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
