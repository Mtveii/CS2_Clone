class_name VoxelChunkStore
extends RefCounted

const _VC = preload("res://shared/voxel/voxel_constants.gd")
const _NP = preload("res://shared/protocol/net_protocol.gd")
## A single chunk of quantized SDF (int16, SDF_SCALE units per mm).
## Storage is a flat PackedInt32Array of size^3 (x + y*size + z*size*size).

var coords: Vector3i = Vector3i.ZERO
var size: int = _VC.CHUNK_SIZE
var sdf: PackedInt32Array = PackedInt32Array()
var dirty: bool = true
var version: int = 0

# Материал и текущая прочность каждого вокселя (индекс как у sdf).
var material: PackedByteArray = PackedByteArray()
var hp: PackedInt32Array = PackedInt32Array()

# Optional bedrock mask (same indexing). True = immutable.
var bedrock: PackedByteArray = PackedByteArray()


func _init(c: Vector3i = Vector3i.ZERO, s: int = _VC.CHUNK_SIZE) -> void:
	coords = c
	size = s
	allocate()


func allocate() -> void:
	var n := size * size * size
	sdf.resize(n)
	bedrock.resize(n)
	material.resize(n)
	hp.resize(n)
	for i in n:
		sdf[i] = _VC.SDF_MAX
		bedrock[i] = 0
		material[i] = 0
		hp[i] = 0


func index(lx: int, ly: int, lz: int) -> int:
	return lx + ly * size + lz * size * size


func in_bounds(lx: int, ly: int, lz: int) -> bool:
	return lx >= 0 and ly >= 0 and lz >= 0 and lx < size and ly < size and lz < size


func get_sdf(lx: int, ly: int, lz: int) -> int:
	if not in_bounds(lx, ly, lz):
		return _VC.SDF_MAX
	return sdf[index(lx, ly, lz)]


func set_sdf(lx: int, ly: int, lz: int, value: int, allow_bedrock: bool = false) -> bool:
	if not in_bounds(lx, ly, lz):
		return false
	var i := index(lx, ly, lz)
	if bedrock[i] == 1 and not allow_bedrock:
		return false
	sdf[i] = _VC.clamp_sdf(value)
	dirty = true
	return true


func get_material(lx: int, ly: int, lz: int) -> int:
	if not in_bounds(lx, ly, lz):
		return 0
	return material[index(lx, ly, lz)]


func set_material(lx: int, ly: int, lz: int, id: int, initial_hp: int = -1) -> void:
	if not in_bounds(lx, ly, lz):
		return
	var i := index(lx, ly, lz)
	material[i] = id
	var VM = preload("res://shared/voxel/voxel_material.gd")
	hp[i] = initial_hp if initial_hp >= 0 else VM.hp(id)
	dirty = true


func get_hp(lx: int, ly: int, lz: int) -> int:
	if not in_bounds(lx, ly, lz):
		return 0
	return hp[index(lx, ly, lz)]


func apply_damage(lx: int, ly: int, lz: int, damage: int) -> bool:
	## Возвращает true, если воксель разрушен.
	if not in_bounds(lx, ly, lz):
		return false
	var i := index(lx, ly, lz)
	if bedrock[i] == 1 or material[i] == 0:
		return false
	hp[i] -= damage
	dirty = true
	if hp[i] <= 0:
		sdf[i] = _VC.SDF_MAX  # become air
		material[i] = 0
		hp[i] = 0
		return true
	return false


func mark_bedrock(lx: int, ly: int, lz: int) -> void:
	if in_bounds(lx, ly, lz):
		bedrock[index(lx, ly, lz)] = 1


func is_bedrock(lx: int, ly: int, lz: int) -> bool:
	if not in_bounds(lx, ly, lz):
		return false
	return bedrock[index(lx, ly, lz)] == 1


func to_bytes() -> PackedByteArray:
	# Каноническая сериализация: sdf(4) + material(1) + hp(4) на воксель.
	var out := PackedByteArray()
	out.resize(sdf.size() * 9)
	for i in sdf.size():
		var v := sdf[i]
		var o := i * 9
		out[o] = v & 0xFF
		out[o + 1] = (v >> 8) & 0xFF
		out[o + 2] = (v >> 16) & 0xFF
		out[o + 3] = (v >> 24) & 0xFF
		out[o + 4] = material[i]
		var h := hp[i]
		out[o + 5] = h & 0xFF
		out[o + 6] = (h >> 8) & 0xFF
		out[o + 7] = (h >> 16) & 0xFF
		out[o + 8] = (h >> 24) & 0xFF
	return out


static func from_bytes(coords_in: Vector3i, data: PackedByteArray, s: int = _VC.CHUNK_SIZE):
	var c = new(coords_in, s)
	var n := s * s * s
	for i in n:
		var o := i * 9
		if o + 8 < data.size():
			var v := data[o] | (data[o + 1] << 8) | (data[o + 2] << 16) | (data[o + 3] << 24)
			c.sdf[i] = v
			c.material[i] = data[o + 4]
			var h := data[o + 5] | (data[o + 6] << 8) | (data[o + 7] << 16) | (data[o + 8] << 24)
			c.hp[i] = h
	return c


func checksum() -> int:
	# CRC32C over canonical serialized field data (little-endian int16).
	return _NP.crc32c(to_bytes())


func fill_sphere(center: Vector3, radius_vox: int, value: int) -> int:
	# Fills voxels within radius with value. Returns count changed.
	var changed := 0
	var r2 := radius_vox * radius_vox
	for z in range(size):
		for y in range(size):
			for x in range(size):
				var dx := x - int(center.x)
				var dy := y - int(center.y)
				var dz := z - int(center.z)
				if dx * dx + dy * dy + dz * dz <= r2:
					if set_sdf(x, y, z, value):
						changed += 1
	return changed


func clear() -> void:
	allocate()
	dirty = true
	version += 1
