class_name VoxelMapLoader
extends RefCounted
## Загрузчик компактного VMAP (CC0-карта Oasis) в VoxelWorldStore.

const VoxelMaterialData = preload("res://shared/voxel/voxel_material.gd")


static func load_map(path: String, world) -> Dictionary:
	## Возвращает { loaded: int, ok: bool }
	if not FileAccess.file_exists(path):
		return {"loaded": 0, "ok": false}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"loaded": 0, "ok": false}
	if f.get_32() != 0x50414D56:  # 'VMAP'
		f.close()
		return {"loaded": 0, "ok": false}
	var version: int = f.get_32()
	var voxel_size: int = f.get_32()
	var count: int = f.get_32()
	if version != 1 or count <= 0:
		f.close()
		return {"loaded": 0, "ok": false}
	world.voxel_size_mm = voxel_size
	var loaded := 0
	for i in range(count):
		var x := _s16(f.get_16())
		var y := _s16(f.get_16())
		var z := _s16(f.get_16())
		var mat := f.get_8()
		var v := Vector3i(x, y, z)
		if world.set_voxel_material(v, mat):
			loaded += 1
	f.close()
	return {"loaded": loaded, "ok": true}


static func map_bounds(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	if f.get_32() != 0x50414D56:
		f.close()
		return {}
	f.get_32()
	f.get_32()
	var count: int = f.get_32()
	var min_v: Vector3i = Vector3i(9999, 9999, 9999)
	var max_v: Vector3i = Vector3i(-9999, -9999, -9999)
	for i in range(count):
		var v: Vector3i = Vector3i(_s16(f.get_16()), _s16(f.get_16()), _s16(f.get_16()))
		f.get_8()
		min_v.x = mini(min_v.x, v.x); min_v.y = mini(min_v.y, v.y); min_v.z = mini(min_v.z, v.z)
		max_v.x = maxi(max_v.x, v.x); max_v.y = maxi(max_v.y, v.y); max_v.z = maxi(max_v.z, v.z)
	f.close()
	return {"min": min_v, "max": max_v, "count": count}


static func _s16(v: int) -> int:
	return v - 65536 if v >= 32768 else v
