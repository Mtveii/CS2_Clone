class_name VoxelMeshGen
extends RefCounted

const _VC = preload("res://shared/voxel/voxel_constants.gd")
const _VW = preload("res://shared/voxel/voxel_world.gd")
const _VM = preload("res://shared/voxel/voxel_material.gd")
## Surface-nets mesher for a chunk of a _VW.
## Produces an ArrayMesh from the SDF field. No large lookup tables required.

const SURFACE_NETS: int = 0
const BLOCKY: int = 1

# Куда смотреть от ячейки поверхности, чтобы найти материал (без аллокаций на вершину).
const _MAT_PROBES: Array = [
	Vector3i.ZERO,
	Vector3i(0, -1, 0), Vector3i(0, 1, 0),
	Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
	Vector3i(0, 0, -1), Vector3i(0, 0, 1),
]


static func build(world: _VW, chunk_coords: Vector3i, mode: int = SURFACE_NETS) -> ArrayMesh:
	if mode == BLOCKY:
		return _build_blocky(world, chunk_coords)
	return _build_surface_nets(world, chunk_coords)


static func _build_surface_nets(world: _VW, cc: Vector3i) -> ArrayMesh:
	var cs: int = world.chunk_size
	var origin: Vector3i = cc * cs
	var nx: int = cs + 1
	var ny: int = cs + 1
	var nz: int = cs + 1
	# Sample (cs+1)^3 corners, including a 1-voxel border.
	var sdf_arr: PackedInt32Array = PackedInt32Array()
	sdf_arr.resize(nx * ny * nz)
	for kz in range(nz):
		for ky in range(ny):
			for kx in range(nx):
				var v: Vector3i = origin + Vector3i(kx - 1, ky - 1, kz - 1)
				var idx: int = kx + ky * nx + kz * nx * ny
				sdf_arr[idx] = world.get_sdf_voxel(v)

	# cell_index maps cell (flat) -> vertex index or -1
	var cell_index: Array = []
	cell_index.resize(cs * cs * cs)
	for i in range(cs * cs * cs):
		cell_index[i] = -1

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()

	var scale: float = float(world.voxel_size_mm) / 1000.0

	var edges: Array = [
		[0, 1], [2, 3], [4, 5], [6, 7],
		[0, 2], [1, 3], [4, 6], [5, 7],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	var corner_pos: Array = [
		Vector3(0, 0, 0), Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3(1, 1, 0),
		Vector3(0, 0, 1), Vector3(1, 0, 1),
		Vector3(0, 1, 1), Vector3(1, 1, 1),
	]

	for kz in range(cs):
		for ky in range(cs):
			for kx in range(cs):
				var c000: int = sdf_arr[kx + ky * nx + kz * nx * ny]
				var c100: int = sdf_arr[(kx + 1) + ky * nx + kz * nx * ny]
				var c010: int = sdf_arr[kx + (ky + 1) * nx + kz * nx * ny]
				var c110: int = sdf_arr[(kx + 1) + (ky + 1) * nx + kz * nx * ny]
				var c001: int = sdf_arr[kx + ky * nx + (kz + 1) * nx * ny]
				var c101: int = sdf_arr[(kx + 1) + ky * nx + (kz + 1) * nx * ny]
				var c011: int = sdf_arr[kx + (ky + 1) * nx + (kz + 1) * nx * ny]
				var c111: int = sdf_arr[(kx + 1) + (ky + 1) * nx + (kz + 1) * nx * ny]
				var corners: Array = [c000, c100, c010, c110, c001, c101, c011, c111]
				var mask: int = 0
				for ci in range(8):
					if (corners[ci] as int) <= _VC.SOLID_THRESHOLD:
						mask |= (1 << ci)
				if mask == 0 or mask == 255:
					continue
				# Average edge intersections.
				var sum: Vector3 = Vector3.ZERO
				var cnt: int = 0
				for e in edges:
					var a: int = e[0]
					var b: int = e[1]
					var sa: bool = (corners[a] as int) <= _VC.SOLID_THRESHOLD
					var sb: bool = (corners[b] as int) <= _VC.SOLID_THRESHOLD
					if sa == sb:
						continue
					var va: float = float(corners[a])
					var vb: float = float(corners[b])
					var t: float = va / (va - vb)
					var pa: Vector3 = corner_pos[a]
					var pb: Vector3 = corner_pos[b]
					var pt: Vector3 = pa.lerp(pb, t)
					sum += pt
					cnt += 1
				if cnt == 0:
					continue
				var local_vertex: Vector3 = (sum / float(cnt)) + Vector3(kx, ky, kz)
				var world_vertex: Vector3 = Vector3(origin.x, origin.y, origin.z) + local_vertex
				var vi: int = vertices.size()
				vertices.append(world_vertex * scale)
				var nrm: Vector3 = _gradient(world, origin + Vector3i(kx, ky, kz))
				normals.append(nrm)
				colors.append(_surface_color(world, origin + Vector3i(kx, ky, kz), world_vertex))
				cell_index[kx + ky * cs + kz * cs * cs] = vi

	# Connect adjacent surface cells with triangles.
	var indices: PackedInt32Array = PackedInt32Array()
	for kz in range(cs):
		for ky in range(cs):
			for kx in range(cs - 1):
				var i0: int = kx + ky * cs + kz * cs * cs
				var i1: int = (kx + 1) + ky * cs + kz * cs * cs
				var v0: int = cell_index[i0]
				var v1: int = cell_index[i1]
				if v0 < 0 or v1 < 0:
					continue
				if ky + 1 < cs:
					var i2: int = kx + (ky + 1) * cs + kz * cs * cs
					var v2: int = cell_index[i2]
					if v2 >= 0:
						indices.append(v0)
						indices.append(v1)
						indices.append(v2)
				if kz + 1 < cs:
					var i3: int = kx + ky * cs + (kz + 1) * cs * cs
					var v3: int = cell_index[i3]
					if v3 >= 0:
						indices.append(v0)
						indices.append(v3)
						indices.append(v1)

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if vertices.size() > 0 and indices.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Цвет поверхности берём у ближайшего твёрдого вокселя, чтобы стены/пол
# были разными (бетон/дерево), а не одним «коричневым ничем».
static func _surface_color(world: _VW, cell: Vector3i, world_pos: Vector3) -> Color:
	var mat_id: int = 0
	for off in _MAT_PROBES:
		var p: Vector3i = cell + (off as Vector3i)
		if world.get_sdf_voxel(p) <= _VC.SOLID_THRESHOLD:
			var m: int = world.get_voxel_material(p)
			if m != 0:
				mat_id = m
				break
	if mat_id == 0:
		mat_id = _VM.MaterialId.CONCRETE
	var base: Color = _VM.get_material(mat_id).get("color", Color(0.6, 0.6, 0.62))
	# Детерминированная лёгкая вариация оттенка на воксель, чтобы не было «пластика».
	var h: float = sin(world_pos.x * 12.9898 + world_pos.y * 78.233 + world_pos.z * 37.719) * 43758.5453
	var frac: float = h - floor(h)
	var shade: float = 0.86 + 0.18 * frac
	return Color(base.r * shade, base.g * shade, base.b * shade, 1.0)


static func _gradient(world: _VW, v: Vector3i) -> Vector3:
	var gx: float = float(world.get_sdf_voxel(v + Vector3i(1, 0, 0)) - world.get_sdf_voxel(v + Vector3i(-1, 0, 0))) * 0.5
	var gy: float = float(world.get_sdf_voxel(v + Vector3i(0, 1, 0)) - world.get_sdf_voxel(v + Vector3i(0, -1, 0))) * 0.5
	var gz: float = float(world.get_sdf_voxel(v + Vector3i(0, 0, 1)) - world.get_sdf_voxel(v + Vector3i(0, 0, -1))) * 0.5
	var g: Vector3 = Vector3(gx, gy, gz)
	if g.length() < 0.0001:
		return Vector3(0, 1, 0)
	return g.normalized()


static func _build_blocky(world: _VW, cc: Vector3i) -> ArrayMesh:
	var cs: int = world.chunk_size
	var origin: Vector3i = cc * cs
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var scale: float = float(world.voxel_size_mm) / 1000.0
	for z in range(cs):
		for y in range(cs):
			for x in range(cs):
				var v: Vector3i = origin + Vector3i(x, y, z)
				if world.get_sdf_voxel(v) > _VC.SOLID_THRESHOLD:
					continue
				var p: Vector3 = Vector3(x + origin.x, y + origin.y, z + origin.z)
				var c000: Vector3 = p
				var c100: Vector3 = p + Vector3(1, 0, 0)
				var c010: Vector3 = p + Vector3(0, 1, 0)
				var c110: Vector3 = p + Vector3(1, 1, 0)
				var c001: Vector3 = p + Vector3(0, 0, 1)
				var c101: Vector3 = p + Vector3(1, 0, 1)
				var c011: Vector3 = p + Vector3(0, 1, 1)
				var c111: Vector3 = p + Vector3(1, 1, 1)
				var tris: Array = [
					[c000, c100, c110], [c000, c110, c010],
					[c001, c011, c111], [c001, c111, c101],
					[c000, c001, c101], [c000, c101, c100],
					[c010, c110, c111], [c010, c111, c011],
					[c000, c010, c011], [c000, c011, c001],
					[c100, c101, c111], [c100, c111, c110],
				]
				var face_normals: Array = [
					Vector3(0, 0, -1), Vector3(0, 0, -1),
					Vector3(0, 0, 1), Vector3(0, 0, 1),
					Vector3(0, -1, 0), Vector3(0, -1, 0),
					Vector3(0, 1, 0), Vector3(0, 1, 0),
					Vector3(-1, 0, 0), Vector3(-1, 0, 0),
					Vector3(1, 0, 0), Vector3(1, 0, 0),
				]
				for ti in range(tris.size()):
					var tri: Array = tris[ti]
					var nrm: Vector3 = face_normals[ti]
					var i0: int = vertices.size()
					for pnt in tri:
						vertices.append((pnt as Vector3) * scale)
						normals.append(nrm)
					indices.append(i0)
					indices.append(i0 + 1)
					indices.append(i0 + 2)
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if vertices.size() > 0 and indices.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
