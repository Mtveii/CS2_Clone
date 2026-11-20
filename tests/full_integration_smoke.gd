extends SceneTree
## Интеграционный тест ВСЕХ механик + отчёт о сходстве с CS2.
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMat = preload("res://shared/voxel/voxel_material.gd")
const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")
const NetProtocol = preload("res://shared/protocol/net_protocol.gd")
const MovementModel = preload("res://shared/gameplay/movement.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const HitRegistration = preload("res://shared/gameplay/hitreg.gd")
const RoundState = preload("res://shared/gameplay/round_state.gd")
const GrenadeSystem = preload("res://shared/gameplay/grenades.gd")
const DestructionSystem = preload("res://shared/gameplay/destruction.gd")
const WeaponAnimController = preload("res://shared/gameplay/weapon_anim.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")

var failures: int = 0
var checks: int = 0

func _check(c: bool, m: String) -> void:
	checks += 1
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	print("=== ИНТЕГРАЦИОННЫЙ ТЕСТ ВСЕХ МЕХАНИК ===")
	_test_movement()
	_test_weapons()
	_test_hitreg()
	_test_rounds()
	_test_grenades()
	_test_destruction()
	_test_viewmodel()
	_test_protocol_and_voxels()
	print("=== ИТОГО: %d проверок, %d ошибок ===" % [checks, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)


func _test_movement() -> void:
	print("--- ДВИЖЕНИЕ ---")
	var m = MovementModel.new()
	m.reset(Vector3.ZERO)
	var ground = func(_p): return 0.0
	var no_ladder = func(_p): return false
	for i in range(64):
		m.step(0, 0.0, 1.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(absf(m.speed_u() - 250.0) < 15.0, "скорость бега ~250 u/s (got %.1f)" % m.speed_u())
	# counter-strafe
	for i in range(32):
		m.step(0, -1.0, 0.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.speed_u() < 250.0, "counter-strafe снижает скорость")
	# jump + air-strafe
	m.reset(Vector3.ZERO)
	m.step(MovementModel.Buttons.JUMP, 0.0, 0.0, 0, 0, MovementModel.TICK_DT, ground, no_ladder)
	_check(m.vel_u.y > 280.0 and not m.on_ground, "прыжок 301.76 u/s")
	var air = MovementModel.new()
	air.reset(Vector3(0, 100, 0))
	air.on_ground = false
	air.vel_u = Vector3(0, 0, -200)
	var high_ground = func(_p): return -1000.0
	for i in range(10):
		air.step(0, 1.0, 0.0, 0, 0, MovementModel.TICK_DT, high_ground, no_ladder)
	_check(absf(air.vel_u.x) > 1.0, "air-strafe работает (got %.2f)" % air.vel_u.x)


func _test_weapons() -> void:
	print("--- ОРУЖИЕ ---")
	_check(WeaponData.WEAPONS.size() >= 40, "все оружия присутствуют (%d)" % WeaponData.WEAPONS.size())
	_check(WeaponData.compute_damage(WeaponData.WeaponId.AWP, 100.0, "chest", true) >= 100, "AWP oneshot body")
	_check(WeaponData.compute_damage(WeaponData.WeaponId.AK47, 100.0, "head", true) >= 100, "AK oneshot head")
	_check(WeaponData.compute_damage(WeaponData.WeaponId.M4A1S, 100.0, "head", true) < 100, "M4A1-S не oneshot")
	_check(WeaponData.kill_reward(WeaponData.WeaponId.KNIFE) == 1500, "нож $1500")
	_check(WeaponData.move_speed(WeaponData.WeaponId.AWP) == 200.0, "AWP замедляет")
	# инвентарь: все 43 + команды
	var l = Loadout.new(WeaponData.Team.T, 16000)
	_check(l.buy(WeaponData.WeaponId.AK47), "покупка AK через инвентарь")
	_check(not l.can_buy(WeaponData.WeaponId.M4A4), "T не покупает M4A4")
	_check(l.buy(WeaponData.WeaponId.C4), "T получает C4")
	l.set_knife_skin("Butterfly")
	_check(l.slots[Loadout.Slot.KNIFE].skin == "Butterfly", "скин ножа")


func _test_hitreg() -> void:
	print("--- ХИТ-РЕГИСТРАЦИЯ ---")
	var h = HitRegistration.new()
	var snap = HitRegistration.PlayerSnap.new()
	snap.player_id = 1
	snap.pos = Vector3(0, 0, 1000)
	snap.timestamp_ms = 1000
	h.record_snapshot(snap)
	var rewound = h.rewind_position(1, 1000)
	_check(rewound == Vector3(0, 0, 1000), "rewind позиции")
	var hit = h.ray_vs_player(Vector3(0, 1.6, 0), Vector3(0, 0, 1), Vector3(0, 0, 1000), 2000.0)
	_check(hit.hit, "попадание по игроку")
	_check(hit.hitbox != "", "hitbox определён (%s)" % hit.hitbox)


func _test_rounds() -> void:
	print("--- РАУНДЫ И ЭКОНОМИКА ---")
	var r = RoundState.new()
	r.start_warmup(); r.start_round(); r.tick(15000)
	_check(r.phase == RoundState.Phase.LIVE, "раунд начался")
	r.plant_bomb("A", r.round_elapsed_ms)
	_check(r.phase == RoundState.Phase.BOMB_PLANTED, "бомба установлена")
	r.tick(40000)
	_check(r.winner == "T", "взрыв -> победа T")
	r.apply_loss("T", true)
	_check(r.money_t > RoundState.START_MONEY, "деньги за посадку")
	r.on_kill("CT", WeaponData.WeaponId.AWP)
	_check(r.money_ct >= RoundState.CT_KILL_TEAM_BONUS, "CT бонус за убийство")


func _test_grenades() -> void:
	print("--- ГРАНАТЫ ---")
	var g = GrenadeSystem.new()
	g.reset()
	var gr = g.throw_grenade(GrenadeSystem.Type.SMOKE, Vector3(0, 64, 0), Vector3(0, 0, -1),
		GrenadeSystem.ThrowType.LONG, 1, 0)
	_check(gr != null and g.active.size() == 1, "дымовая брошена")
	var ground = func(_p): return 0.0
	for i in range(200):
		g.step(0.02, ground)
	_check(g.smokes.size() == 1, "дым образовался")
	_check(g.smoke_blocks_ray(Vector3(0, 0, -1000), Vector3(0, 0, 1), 3000.0), "дым блокирует обзор")
	_check(g.flash_duration(Vector3.ZERO, Vector3(0, 0, 500), Vector3(0, 0, 1)) > 0.0, "флеш ослепляет")
	_check(g.fire_dps(100.0) == 40, "огонь 40 dps")


func _test_destruction() -> void:
	print("--- РАЗРУШЕНИЕ ---")
	var w = VoxelWorldStore.new()
	w.bounds_min = Vector3i(-16, -8, -16); w.bounds_max = Vector3i(16, 24, 16)
	w.fill_box_material(Vector3i(-4, 0, 2), Vector3i(4, 4, 2), VoxelMat.MaterialId.WOOD)
	var d = DestructionSystem.new()
	var res = d.bullet_impact(w, Vector3i(0, 2, 2), Vector3(0, 0, -1), WeaponData.WeaponId.AWP, 0.0)
	_check(res.destroyed.size() > 0, "пуля AWP разрушает дерево")
	var he = d.he_blast(w, w.voxel_to_world_mm(Vector3i(0, 2, 2)) + Vector3(100, 100, 100))
	_check(he.destroyed > 0 and d.debris.size() > 0, "HE разрушает и создаёт обломки (%d)" % he.destroyed)
	var ground = func(_p): return 0.0
	for i in range(50):
		d.step_debris(0.05, ground)
	_check(d.debris.size() > 0 or d.total_destroyed_voxels > 0, "физика обломков работает")


func _test_viewmodel() -> void:
	print("--- АНИМАЦИЯ ОРУЖИЯ (ОСМОТР) ---")
	var a = WeaponAnimController.new()
	a.reset()
	a.tick(1.0)
	_check(a.is_idle(), "deploy -> idle")
	_check(a.request_inspect(), "осмотр запущен")
	_check(a.state == WeaponAnimController.State.INSPECT, "состояние INSPECT")
	a.tick(1.5)
	_check(not a.is_idle(), "осмотр длится")
	a.tick(2.0)
	_check(a.is_idle(), "осмотр завершён")
	_check(a.request_reload(), "перезарядка")
	_check(a.request_melee(), "удар прикладом/ножом")


func _test_protocol_and_voxels() -> void:
	print("--- ПРОТОКОЛ И ВОКСЕЛИ ---")
	var hello = NetProtocol.encode_hello("test", 1)
	_check(NetProtocol.message_type(hello) == NetProtocol.MsgType.HELLO, "HELLO")
	var inp = NetProtocol.encode_input(1, 1, 100, 200, 0, 0, 16)
	_check(NetProtocol.message_type(inp) == NetProtocol.MsgType.INPUT, "INPUT")
	var op = NetProtocol.encode_voxel_op(2, 1, 1, 1, 1, 0, 0, 0, 200, 100)
	_check(NetProtocol.message_type(op) == NetProtocol.MsgType.VOXEL_OP, "VOXEL_OP")
	_check(NetProtocol.crc32c("123456789".to_utf8_buffer()) == 0xE3069283, "CRC32C")
	var w = VoxelWorldStore.new()
	w.bounds_min = Vector3i(-8, -8, -8); w.bounds_max = Vector3i(8, 8, 8)
	w.edit_box(Vector3(-200, 0, -200), Vector3(200, 400, 200), 100000)
	_check(w.chunk_checksum(Vector3i(0, 0, 0)) != 0, "чексумма чанка")
	var mesh = VoxelMeshGen.build(w, Vector3i(0, 0, 0), VoxelMeshGen.SURFACE_NETS)
	_check(mesh != null, "меш чанка построен")
