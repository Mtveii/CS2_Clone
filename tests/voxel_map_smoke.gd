extends SceneTree
## Тест загрузки найденной CC0-карты Oasis в воксельный мир.
const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMapLoader = preload("res://shared/voxel/voxel_map_loader.gd")
const VoxelMat = preload("res://shared/voxel/voxel_material.gd")
const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	var path := "res://assets/maps/oasis.vmap"
	_check(FileAccess.file_exists(path), "карта oasis.vmap найдена")
	var bounds = VoxelMapLoader.map_bounds(path)
	_check(not bounds.is_empty(), "заголовок VMAP читается")
	_check(int(bounds.get("count", 0)) == 144180, "144180 вокселей (%s)" % str(bounds.get("count", 0)))
	print("bbox: ", bounds.get("min"), " -> ", bounds.get("max"))

	var w = VoxelWorldStore.new()
	w.bounds_min = Vector3i(-128, -8, -128)
	w.bounds_max = Vector3i(128, 64, 128)
	var res = VoxelMapLoader.load_map(path, w)
	_check(res.ok, "загрузка ok")
	_check(res.loaded > 100000, "загружено %d вокселей" % res.loaded)
	#-materialные проверки
	var found_solid := false
	var found_wood := false
	for c in w.chunks.values():
		for i in range(c.material.size()):
			if c.material[i] != 0:
				found_solid = true
			if c.material[i] == VoxelMat.MaterialId.WOOD:
				found_wood = true
			if found_solid and found_wood:
				break
	_check(found_solid, "есть твёрдые воксели")
	_check(found_wood, "есть деревянные воксели")
	var ch_coords = w.all_chunk_coords()
	_check(ch_coords.size() > 0, "чанки созданы (%d)" % ch_coords.size())
	var cs = w.chunk_checksum(ch_coords[0])
	_check(cs != 0, "чексумма чанка %d" % cs)
	# луч попадает в стену
	var rc = w.raycast_sdf(Vector3(0, 1600, 0), Vector3(0, 0, -1), 25000.0)
	_check(rc.hit, "луч попал в карту")
	# меш строится
	var mesh = VoxelMeshGen.build(w, ch_coords[0], VoxelMeshGen.SURFACE_NETS)
	_check(mesh != null, "меш построен")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
