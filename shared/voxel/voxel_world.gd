class_name VoxelWorldStore
extends RefCounted

const _VC = preload("res://shared/voxel/voxel_constants.gd")
const _VChunk = preload("res://shared/voxel/voxel_chunk.gd")
## Authoritative voxel world: chunk storage + integer SDF edit ops.
## Server and client prediction share this logic (see docs/ARCHITECTURE.md).

var voxel_size_mm: int = _VC.VOXEL_SIZE_MM
var chunk_size: int = _VC.CHUNK_SIZE
var chunks: Dictionary = {}  # Vector3i -> _VChunk

# World bounds in voxels (inclusive min, exclusive max). Edits outside are rejected.
var bounds_min: Vector3i = Vector3i(-256, -8, -256)
var bounds_max: Vector3i = Vector3i(256, 64, 256)

# Edit op counter (global, server-assigned). Clients use their own sequence_id.
var op_counter: int = 0


func _init() -> void:
	pass


func chunk_key(v: Vector3i) -> Vector3i:
	return _VC.chunk_of_voxel(v, chunk_size)


func get_chunk(coords: Vector3i, create: bool = false) -> _VChunk:
	if chunks.has(coords):
		return chunks[coords]
	if create:
		var c := _VChunk.new(coords, chunk_size)
		chunks[coords] = c
		return c
	return null


func remove_chunk(coords: Vector3i) -> void:
	chunks.erase(coords)


func world_mm_to_voxel(p: Vector3) -> Vector3i:
	return _VC.world_mm_to_voxel(p)


func voxel_to_world_mm(v: Vector3i) -> Vector3:
	return _VC.voxel_to_world_mm(v)


func in_bounds_voxel(v: Vector3i) -> bool:
	return v.x >= bounds_min.x and v.y >= bounds_min.y and v.z >= bounds_min.z \
		and v.x < bounds_max.x and v.y < bounds_max.y and v.z < bounds_max.z


func is_bedrock_voxel(v: Vector3i) -> bool:
	# Boundary shell + floor below playable region.
	if v.x < bounds_min.x + _VC.BEDROCK_SHELL \
		or v.x >= bounds_max.x - _VC.BEDROCK_SHELL \
		or v.z < bounds_min.z + _VC.BEDROCK_SHELL \
		or v.z >= bounds_max.z - _VC.BEDROCK_SHELL \
		or v.y < bounds_min.y + _VC.BEDROCK_SHELL:
		return true
	return false


func get_sdf_voxel(v: Vector3i) -> int:
	if not in_bounds_voxel(v):
		return _VC.SDF_MIN  # treat outside as solid
	if is_bedrock_voxel(v):
		return _VC.SDF_MIN
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, false)
	if chunk == null:
		# Unloaded chunk treated as empty (air).
		return _VC.SDF_MAX
	var lx := ((v.x % chunk_size) + chunk_size) % chunk_size
	var ly := ((v.y % chunk_size) + chunk_size) % chunk_size
	var lz := ((v.z % chunk_size) + chunk_size) % chunk_size
	return chunk.get_sdf(lx, ly, lz)


func set_sdf_voxel(v: Vector3i, value: int, allow_bedrock: bool = false) -> bool:
	if not in_bounds_voxel(v):
		return false
	if is_bedrock_voxel(v) and not allow_bedrock:
		return false
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, true)
	var lx := ((v.x % chunk_size) + chunk_size) % chunk_size
	var ly := ((v.y % chunk_size) + chunk_size) % chunk_size
	var lz := ((v.z % chunk_size) + chunk_size) % chunk_size
	if chunk.is_bedrock(lx, ly, lz) and not allow_bedrock:
		return false
	return chunk.set_sdf(lx, ly, lz, value, allow_bedrock)


# ---- Edit ops (integer, deterministic) ----

func edit_sphere(center_mm: Vector3, radius_mm: int, power: int) -> Dictionary:
	# Returns { op_index, affected_chunks: Array[Vector3i], changed_voxels: int }
	var center_v := world_mm_to_voxel(center_mm)
	var radius_v := int(ceil(float(radius_mm) / float(voxel_size_mm))) + 1
	var affected: Array = []
	var changed := 0
	for z in range(center_v.z - radius_v, center_v.z + radius_v + 1):
		for y in range(center_v.y - radius_v, center_v.y + radius_v + 1):
			for x in range(center_v.x - radius_v, center_v.x + radius_v + 1):
				var v := Vector3i(x, y, z)
				if not in_bounds_voxel(v):
					continue
				if is_bedrock_voxel(v):
					continue
				var dx := x - center_v.x
				var dy := y - center_v.y
				var dz := z - center_v.z
				var d2 := dx * dx + dy * dy + dz * dz
				if d2 > radius_v * radius_v:
					continue
				# SDF: subtract power scaled; closer to center removes more.
				var dist := sqrt(float(d2))
				var falloff := 1.0 - (dist / float(radius_v))
				var delta := int(power * falloff)
				var cur := get_sdf_voxel(v)
				if set_sdf_voxel(v, cur - delta):
					changed += 1
					var ck := chunk_key(v)
					if not affected.has(ck):
						affected.append(ck)
	op_counter += 1
	return {"op_index": op_counter, "affected": affected, "changed": changed}


func edit_box(min_mm: Vector3, max_mm: Vector3, power: int) -> Dictionary:
	var vmin := world_mm_to_voxel(min_mm)
	var vmax := world_mm_to_voxel(max_mm)
	var affected: Array = []
	var changed := 0
	for z in range(vmin.z, vmax.z + 1):
		for y in range(vmin.y, vmax.y + 1):
			for x in range(vmin.x, vmax.x + 1):
				var v := Vector3i(x, y, z)
				if not in_bounds_voxel(v) or is_bedrock_voxel(v):
					continue
				var cur := get_sdf_voxel(v)
				if set_sdf_voxel(v, cur - power):
					changed += 1
					var ck := chunk_key(v)
					if not affected.has(ck):
						affected.append(ck)
	op_counter += 1
	return {"op_index": op_counter, "affected": affected, "changed": changed}


func edit_ray(origin_mm: Vector3, dir: Vector3, radius_mm: int, length_mm: int, power: int) -> Dictionary:
	var dir_n := dir.normalized()
	var steps := int(ceil(float(length_mm) / float(voxel_size_mm))) + 1
	var affected: Array = []
	var changed := 0
	for s in range(steps):
		var p := origin_mm + dir_n * (float(s) * float(voxel_size_mm))
		var res: Dictionary = edit_sphere(p, radius_mm, power)
		changed += res.changed
		for ck in res.affected:
			if not affected.has(ck):
				affected.append(ck)
	op_counter += 1
	return {"op_index": op_counter, "affected": affected, "changed": changed}


# ---- Material / damage helpers ----

func set_voxel_material(v: Vector3i, mat_id: int, initial_hp: int = -1) -> bool:
	if not in_bounds_voxel(v) or is_bedrock_voxel(v):
		return false
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, true)
	var lx := posmod(v.x, chunk_size)
	var ly := posmod(v.y, chunk_size)
	var lz := posmod(v.z, chunk_size)
	chunk.set_material(lx, ly, lz, mat_id, initial_hp)
	if mat_id != 0:
		chunk.set_sdf(lx, ly, lz, _VC.SDF_MIN)
	return true


func get_voxel_material(v: Vector3i) -> int:
	if not in_bounds_voxel(v):
		return 0
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, false)
	if chunk == null:
		return 0
	return chunk.get_material(posmod(v.x, chunk_size), posmod(v.y, chunk_size), posmod(v.z, chunk_size))


func fill_box_material(vmin: Vector3i, vmax: Vector3i, mat_id: int) -> int:
	var n := 0
	for z in range(vmin.z, vmax.z + 1):
		for y in range(vmin.y, vmax.y + 1):
			for x in range(vmin.x, vmax.x + 1):
				if set_voxel_material(Vector3i(x, y, z), mat_id):
					n += 1
	return n


func damage_voxel(v: Vector3i, damage: int) -> bool:
	## true = воксель разрушен
	if not in_bounds_voxel(v) or is_bedrock_voxel(v):
		return false
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, false)
	if chunk == null:
		return false
	return chunk.apply_damage(posmod(v.x, chunk_size), posmod(v.y, chunk_size), posmod(v.z, chunk_size), damage)


func get_voxel_hp(v: Vector3i) -> int:
	if not in_bounds_voxel(v):
		return 0
	var ck := chunk_key(v)
	var chunk := get_chunk(ck, false)
	if chunk == null:
		return 0
	return chunk.get_hp(posmod(v.x, chunk_size), posmod(v.y, chunk_size), posmod(v.z, chunk_size))


# ---- Queries ----

func raycast_sdf(origin_mm: Vector3, dir: Vector3, max_mm: float) -> Dictionary:
	# Returns { hit: bool, pos_mm: Vector3, voxel: Vector3i, t: float }
	var dir_n := dir.normalized()
	var t := 0.0
	var step := float(voxel_size_mm) * 0.5
	while t < max_mm:
		var p := origin_mm + dir_n * t
		var v := world_mm_to_voxel(p)
		if get_sdf_voxel(v) <= _VC.SOLID_THRESHOLD:
			return {"hit": true, "pos_mm": p, "voxel": v, "t": t}
		t += step
	return {"hit": false, "pos_mm": origin_mm + dir_n * max_mm, "voxel": Vector3i.ZERO, "t": max_mm}


func chunk_checksum(coords: Vector3i) -> int:
	var chunk := get_chunk(coords, false)
	if chunk == null:
		return 0
	return chunk.checksum()


func serialize_chunk(coords: Vector3i) -> PackedByteArray:
	var chunk := get_chunk(coords, false)
	if chunk == null:
		return PackedByteArray()
	return chunk.to_bytes()


func all_chunk_coords() -> Array:
	return chunks.keys()


func voxel_count() -> int:
	var n := 0
	for c in chunks.values():
		n += c.sdf.size()
	return n
