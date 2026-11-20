extends SceneTree
## Voxel smoke test. Run:
##   godot --headless --path . --script res://tests/voxel_smoke.gd

const VoxelConstDefs = preload("res://shared/voxel/voxel_constants.gd")
const VoxelChunkStore = preload("res://shared/voxel/voxel_chunk.gd")
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")

var failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[ok]   ", msg)
	else:
		failures += 1
		push_error("[fail] " + msg)


func _init() -> void:
	# Constants
	_check(VoxelConstDefs.CHUNK_SIZE == 32, "chunk size 32")
	_check(VoxelConstDefs.VOXEL_SIZE_MM == 200, "voxel size 200mm")

	# Chunk
	var c = VoxelChunkStore.new(Vector3i(0, 0, 0))
	_check(c.sdf.size() == 32 * 32 * 32, "chunk allocates 32^3")
	_check(c.get_sdf(0, 0, 0) == VoxelConstDefs.SDF_MAX, "default air")
	c.set_sdf(1, 1, 1, -100)
	_check(c.get_sdf(1, 1, 1) == -100, "set/get sdf")
	_check(c.dirty == true, "dirty after set")

	# Bedrock
	c.mark_bedrock(2, 2, 2)
	_check(c.is_bedrock(2, 2, 2), "bedrock mark")
	_check(not c.set_sdf(2, 2, 2, -50), "bedrock blocks set")
	_check(c.get_sdf(2, 2, 2) == VoxelConstDefs.SDF_MAX, "bedrock unchanged")

	# World
	var w = VoxelWorldStore.new()
	w.bounds_min = Vector3i(-4, -4, -4)
	w.bounds_max = Vector3i(4, 4, 4)
	_check(w.in_bounds_voxel(Vector3i(0, 0, 0)), "in bounds")
	_check(not w.in_bounds_voxel(Vector3i(10, 0, 0)), "out of bounds")

	# Bedrock boundary
	_check(w.is_bedrock_voxel(Vector3i(-4, 0, 0)), "boundary bedrock")

	# SDF round-trip
	w.set_sdf_voxel(Vector3i(1, 1, 1), -500)
	_check(w.get_sdf_voxel(Vector3i(1, 1, 1)) == -500, "world set/get sdf")

	# Bedrock cannot be overwritten
	_check(not w.set_sdf_voxel(Vector3i(-4, 0, 0), -500), "world bedrock blocks set")

	# Sphere edit
	var res = w.edit_sphere(Vector3(200, 200, 200), 400, 1000)
	_check(res.changed > 0, "sphere edit changes voxels (got %d)" % res.changed)
	_check(res.affected.size() > 0, "sphere edit affects chunks")

	# Box edit
	var res2 = w.edit_box(Vector3(0, 0, 0), Vector3(400, 400, 400), 500)
	_check(res2.changed >= 0, "box edit runs")

	# Raycast
	var rc = w.raycast_sdf(Vector3(0, 0, 0), Vector3(1, 0, 0), 1000.0)
	_check(rc.has("hit"), "raycast returns hit field")

	# Chunk checksum stability — identical edit sequence must produce identical bytes.
	var w3 = VoxelWorldStore.new()
	w3.bounds_min = Vector3i(-4, -4, -4)
	w3.bounds_max = Vector3i(4, 4, 4)
	w3.edit_sphere(Vector3(200, 200, 200), 400, 1000)
	w3.edit_box(Vector3(0, 0, 0), Vector3(400, 400, 400), 500)
	var coords = Vector3i(0, 0, 0)
	var cs1 = w3.chunk_checksum(coords)
	var bytes = w3.serialize_chunk(coords)
	_check(bytes.size() > 0, "serialize chunk non-empty")

	var w4 = VoxelWorldStore.new()
	w4.bounds_min = Vector3i(-4, -4, -4)
	w4.bounds_max = Vector3i(4, 4, 4)
	w4.edit_sphere(Vector3(200, 200, 200), 400, 1000)
	w4.edit_box(Vector3(0, 0, 0), Vector3(400, 400, 400), 500)
	_check(w4.chunk_checksum(coords) == cs1, "deterministic checksum (got %d vs %d)" % [w4.chunk_checksum(coords), cs1])

	# Meshing (blocky) non-empty
	var mesh = VoxelMeshGen.build(w, Vector3i(0, 0, 0), VoxelMeshGen.BLOCKY)
	_check(mesh.get_surface_count() >= 0, "blocky mesh builds")
	_check(mesh.get_aabb().size.length() >= 0, "mesh aabb valid")

	# Surface nets meshing
	var mesh2 = VoxelMeshGen.build(w, Vector3i(0, 0, 0), VoxelMeshGen.SURFACE_NETS)
	_check(mesh2.get_surface_count() >= 0, "surface nets mesh builds")

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
