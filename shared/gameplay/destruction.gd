class_name DestructionSystem
extends RefCounted
## Разрушение на основе фактов урона CS2-оружия.
## Weapon damage -> impact energy -> damage voxel HP -> destroyed voxels -> debris physics.
## Детерминировано: целочисленные расчёты, без random в сетевом пути.

const _Weapon = preload("res://shared/gameplay/weapons.gd")
const _Mat = preload("res://shared/voxel/voxel_material.gd")
const _VC = preload("res://shared/voxel/voxel_constants.gd")

# Физика обломков (Hammer units -> mm)
const GRAVITY_MM_S2: float = 800.0 * 19.05
const BOUNCE: float = 0.45
const DEBRIS_LIFETIME_S: float = 4.0
const HE_DESTRUCTION_RADIUS_U: float = 160.0   # ~3 м
const MOLOTOV_RADIUS_U: float = 100.0          # ~1.9 м

class Debris:
	var pos_mm: Vector3
	var vel_mm_s: Vector3
	var material: int
	var size_mm: float
	var lifetime: float = DEBRIS_LIFETIME_S
	var mass_kg: float = 1.0

	var on_ground: bool = false


var debris: Array = []
var total_destroyed_voxels: int = 0


func reset() -> void:
	debris.clear()
	total_destroyed_voxels = 0


## Пуля: урон оружия (с учётом дистанции) -> энергия -> пробитие voxel'ей.
func bullet_impact(
	world,
	hit_voxel: Vector3i,
	dir: Vector3,
	weapon_id: int,
	distance_u: float
) -> Dictionary:
	var w: Dictionary = _Weapon.get_weapon(weapon_id)
	var base_damage: int = _Weapon.damage_falloff(int(w.damage), distance_u, w)
	var pen: float = float(w.armor_pen)
	# Энергия удара: урон × множитель пробития. Мощные пули (AWP/Deagle) разрушают сильнее.
	var energy: float = float(base_damage) * (0.5 + pen)
	var destroyed: Array = []
	var damaged: Array = []
	var dir_n := dir.normalized()

	var v := hit_voxel
	var max_depth: int = 6
	for step in range(max_depth):
		if not world.in_bounds_voxel(v):
			break
		if world.is_bedrock_voxel(v):
			break
		var ck: Vector3i = world.chunk_key(v)
		var chunk = world.get_chunk(ck, false)
		if chunk == null:
			break
		var lx := posmod(v.x, world.chunk_size)
		var ly := posmod(v.y, world.chunk_size)
		var lz := posmod(v.z, world.chunk_size)
		var mat: int = chunk.get_material(lx, ly, lz)
		if mat == _Mat.MaterialId.AIR:
			break
		var resist: float = _Mat.penetration_mult(mat)
		var applied: int = int(energy * resist)
		var was_destroyed: bool = chunk.apply_damage(lx, ly, lz, applied)
		if was_destroyed:
			destroyed.append(v)
			_spawn_debris(world.voxel_to_world_mm(v) + Vector3(100, 100, 100), mat, 1, dir_n * energy)
			total_destroyed_voxels += 1
		else:
			damaged.append(v)
		# потеря энергии при прохождении через материал
		energy *= (1.0 - resist) * 0.7
		if energy < 1.0:
			break
		# переход к следующему вокселю по лучу (упрощённый DDA)
		v = _step_voxel(v, dir_n)

	return {
		"damage": base_damage,
		"energy": int(energy),
		"destroyed": destroyed,
		"damaged": damaged,
		"debris_spawned": destroyed.size(),
	}


## HE-граната: 98 урона в центре, сферический спад -> повреждение вокселей + обломки.
func he_blast(world, center_mm: Vector3) -> Dictionary:
	var radius_mm: float = HE_DESTRUCTION_RADIUS_U * 19.05
	var center_v: Vector3i = world.world_mm_to_voxel(center_mm)
	var r_vox: int = int(ceil(radius_mm / float(world.voxel_size_mm))) + 1
	var destroyed: Array = []
	var affected: Array = []
	for z in range(center_v.z - r_vox, center_v.z + r_vox + 1):
		for y in range(center_v.y - r_vox, center_v.y + r_vox + 1):
			for x in range(center_v.x - r_vox, center_v.x + r_vox + 1):
				var v := Vector3i(x, y, z)
				if not world.in_bounds_voxel(v) or world.is_bedrock_voxel(v):
					continue
				var d: float = Vector3(x - center_v.x, y - center_v.y, z - center_v.z).length()
				if d > r_vox:
					continue
				var falloff: float = 1.0 - (d / float(r_vox))
				var dmg: int = int(98.0 * falloff)
				if dmg <= 0:
					continue
				var ck: Vector3i = world.chunk_key(v)
				var chunk = world.get_chunk(ck, false)
				if chunk == null:
					continue
				var lx := posmod(v.x, world.chunk_size)
				var ly := posmod(v.y, world.chunk_size)
				var lz := posmod(v.z, world.chunk_size)
				var mat: int = chunk.get_material(lx, ly, lz)
				if mat == _Mat.MaterialId.AIR:
					continue
				var was_destroyed: bool = chunk.apply_damage(lx, ly, lz, dmg)
				affected.append(v)
				if was_destroyed:
					destroyed.append(v)
					var impulse := (Vector3(float(v.x), float(v.y), float(v.z)) - Vector3(float(center_v.x), float(center_v.y), float(center_v.z))).normalized() * dmg * 3.0
					_spawn_debris(world.voxel_to_world_mm(v) + Vector3(100, 100, 100), mat, _Mat.debris_count(mat), impulse)
					total_destroyed_voxels += 1
	return {"destroyed": destroyed.size(), "affected": affected.size(), "debris": debris.size()}


## Огонь (Molotov/Incendiary): нарастающий урон 1..8 хит, затем 40 dps.
func fire_damage_step(world, center_mm: Vector3, time_in_fire: float, dt: float) -> Dictionary:
	var dps: int = clampi(1 + int(time_in_fire * 40.0), 1, 40)
	var radius_mm: float = MOLOTOV_RADIUS_U * 19.05
	var center_v: Vector3i = world.world_mm_to_voxel(center_mm)
	var r_vox: int = int(ceil(radius_mm / float(world.voxel_size_mm))) + 1
	var destroyed: Array = []
	for z in range(center_v.z - r_vox, center_v.z + r_vox + 1):
		for y in range(center_v.y - r_vox, center_v.y + r_vox + 1):
			for x in range(center_v.x - r_vox, center_v.x + r_vox + 1):
				var v := Vector3i(x, y, z)
				if not world.in_bounds_voxel(v) or world.is_bedrock_voxel(v):
					continue
				var ck: Vector3i = world.chunk_key(v)
				var chunk = world.get_chunk(ck, false)
				if chunk == null:
					continue
				var lx := posmod(v.x, world.chunk_size)
				var ly := posmod(v.y, world.chunk_size)
				var lz := posmod(v.z, world.chunk_size)
				var mat: int = chunk.get_material(lx, ly, lz)
				var flam: float = _Mat.flammability(mat)
				if flam <= 0.0:
					continue
				var dmg: int = int(float(dps) * flam * dt)
				if dmg <= 0:
					continue
				if chunk.apply_damage(lx, ly, lz, dmg):
					destroyed.append(v)
					_spawn_debris(world.voxel_to_world_mm(v) + Vector3(100, 100, 100), mat, 1, Vector3.UP * dps)
					total_destroyed_voxels += 1
	return {"destroyed": destroyed.size(), "dps": dps}


func _step_voxel(v: Vector3i, dir: Vector3) -> Vector3i:
	# Выбираем ось с наибольшей компонентой направления (упрощённый DDA).
	if absf(dir.x) >= absf(dir.y) and absf(dir.x) >= absf(dir.z):
		return Vector3i(v.x + (1 if dir.x > 0 else -1), v.y, v.z)
	elif absf(dir.y) >= absf(dir.z):
		return Vector3i(v.x, v.y + (1 if dir.y > 0 else -1), v.z)
	else:
		return Vector3i(v.x, v.y, v.z + (1 if dir.z > 0 else -1))


func _spawn_debris(pos_mm: Vector3, mat: int, count: int, impulse: Vector3) -> void:
	for i in range(count):
		var d := Debris.new()
		d.pos_mm = pos_mm
		d.material = mat
		d.size_mm = 40.0 + float(posmod(i * 37, 60))
		d.mass_kg = 0.5 + float(mat) * 0.2
		d.vel_mm_s = impulse * (0.3 + float(posmod(i * 17, 10)) * 0.05)
		d.vel_mm_s.y += 200.0 + float(posmod(i * 23, 8)) * 50.0
		debris.append(d)


func step_debris(dt: float, ground_check: Callable) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var d: Debris = debris[i]
		d.lifetime -= dt
		if d.lifetime <= 0.0:
			debris.remove_at(i)
			continue
		d.vel_mm_s.y -= GRAVITY_MM_S2 * dt
		d.pos_mm += d.vel_mm_s * dt
		var ground_y: float = ground_check.call(d.pos_mm)
		if d.pos_mm.y <= ground_y:
			var impact: float = absf(d.vel_mm_s.y)
			d.pos_mm.y = ground_y
			if impact < 900.0:
				# Малый отскок -> обломок улёгся.
				d.vel_mm_s = Vector3.ZERO
				d.on_ground = true
			else:
				d.vel_mm_s.y = impact * BOUNCE
				d.vel_mm_s.x *= 0.7
				d.vel_mm_s.z *= 0.7
