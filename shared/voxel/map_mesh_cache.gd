class_name MapMeshCache
extends RefCounted
## Кэш уже сгенерированных чанков карты в рамках процесса.
## Oasis строит ~40 чанков; при повторном входе в игру переиспользуем меши,
## чтобы не тратить время на surface-nets и не увеличивать web-пакет.

const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")

static var cache: Dictionary = {}


static func get_or_build(world, cc: Vector3i, key: String, mode: int = VoxelMeshGen.SURFACE_NETS) -> ArrayMesh:
	var full_key: String = key + "|%d_%d_%d" % [cc.x, cc.y, cc.z]
	if cache.has(full_key):
		return cache[full_key]
	var mesh: ArrayMesh = VoxelMeshGen.build(world, cc, mode)
	if mesh != null:
		cache[full_key] = mesh
	return mesh


static func clear() -> void:
	cache.clear()
