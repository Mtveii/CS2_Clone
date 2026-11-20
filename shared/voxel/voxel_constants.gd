class_name VoxelConstDefs
extends RefCounted
## Shared constants for the voxel core (see docs/ARCHITECTURE.md).

const CHUNK_SIZE: int = 32
const VOXEL_SIZE_MM: int = 200

# SDF storage is quantized to int16 (0.1 mm resolution).
const SDF_SCALE: int = 10
const SDF_MAX: int = 32767
const SDF_MIN: int = -32768

# A voxel is solid when its SDF <= 0.
const SOLID_THRESHOLD: int = 0

# Bedrock: boundary shell thickness in voxels.
const BEDROCK_SHELL: int = 2

# Edit op defaults (mm).
const DEFAULT_EDIT_RADIUS_MM: int = 2000
const DEFAULT_EDIT_POWER: int = 5000

# Rate limits (per player).
const MAX_EDITS_PER_SEC: int = 10
const MAX_AFFECTED_CHUNKS_PER_OP: int = 8

# Meshing.
const MESH_ISO: int = 0

static func voxel_to_world_mm(v: Vector3i) -> Vector3:
	return Vector3(v.x, v.y, v.z) * float(VOXEL_SIZE_MM)

static func world_mm_to_voxel(p: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(p.x / float(VOXEL_SIZE_MM))),
		int(floor(p.y / float(VOXEL_SIZE_MM))),
		int(floor(p.z / float(VOXEL_SIZE_MM)))
	)

static func chunk_of_voxel(v: Vector3i, chunk_size: int = CHUNK_SIZE) -> Vector3i:
	return Vector3i(
		floori(float(v.x) / float(chunk_size)),
		floori(float(v.y) / float(chunk_size)),
		floori(float(v.z) / float(chunk_size))
	)

static func local_index(v: Vector3i, chunk_size: int = CHUNK_SIZE) -> int:
	var lx := ((v.x % chunk_size) + chunk_size) % chunk_size
	var ly := ((v.y % chunk_size) + chunk_size) % chunk_size
	var lz := ((v.z % chunk_size) + chunk_size) % chunk_size
	return lx + ly * chunk_size + lz * chunk_size * chunk_size

static func clamp_sdf(value: int) -> int:
	return clampi(value, SDF_MIN, SDF_MAX)
