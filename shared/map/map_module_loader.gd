class_name MapModuleLoader
extends RefCounted
## Изолированный загрузчик карты. Не знает про оружие, HUD, reload и state machine.
## Читает только voxel/VMap API и создаёт отдельные узлы сцены.

const VoxelWorldStore = preload("res://shared/voxel/voxel_world.gd")
const VoxelMeshGen = preload("res://shared/voxel/voxel_mesher.gd")
const VoxelMapLoader = preload("res://shared/voxel/voxel_map_loader.gd")

const CATALOG_PATH := "res://assets/maps/catalog.json"


static func load_catalog() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {"maps": []}
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		return {"maps": []}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or not (json.data is Dictionary):
		return {"maps": []}
	return json.data


static func build_geometry(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "MapGeometry_" + String(def.get("id", "map"))
	var offset := _vec(def.get("offset_m", [0, 0, 0]))
	root.position = offset
	var path := "res://assets/maps/" + String(def.get("file", ""))
	var world := VoxelWorldStore.new()
	world.bounds_min = Vector3i(-128, -8, -128)
	world.bounds_max = Vector3i(128, 64, 128)
	var res := VoxelMapLoader.load_map(path, world)
	if not bool(res.get("ok", false)) or int(res.get("loaded", 0)) == 0:
		return root
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.roughness = 0.9
	for cc in world.all_chunk_coords():
		var mesh := VoxelMeshGen.build(world, cc, VoxelMeshGen.SURFACE_NETS)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Chunk_%d_%d_%d" % [cc.x, cc.y, cc.z]
		mi.mesh = mesh
		mi.material_override = mat
		root.add_child(mi)
	return root


static func build_collisions(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "MapCollision_" + String(def.get("id", "map"))
	root.position = _vec(def.get("offset_m", [0, 0, 0]))
	var path := "res://assets/maps/" + String(def.get("collisions", ""))
	if not FileAccess.file_exists(path):
		return root
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return root
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		f.close()
		return root
	f.close()
	for item in json.data.get("boxes", []):
		var body := StaticBody3D.new()
		body.name = "InvisibleWall"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _vec(item.get("size", [1, 1, 1]))
		shape.shape = box
		body.add_child(shape)
		body.position = _vec(item.get("center", [0, 0, 0])) - root.position
		root.add_child(body)
	return root


static func build_spawns(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "MapSpawns_" + String(def.get("id", "map"))
	root.position = _vec(def.get("offset_m", [0, 0, 0]))
	var path := "res://assets/maps/" + String(def.get("spawns", ""))
	if not FileAccess.file_exists(path):
		return root
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return root
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		f.close()
		return root
	f.close()
	for team in json.data.keys():
		var marker := Marker3D.new()
		marker.name = "Spawn_" + String(team)
		marker.position = _vec(json.data[team]) - root.position
		root.add_child(marker)
	return root


static func build_objectives(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "MapSites_" + String(def.get("id", "map"))
	root.position = _vec(def.get("offset_m", [0, 0, 0]))
	var path := "res://assets/maps/" + String(def.get("objectives", ""))
	if not FileAccess.file_exists(path):
		return root
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return root
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		f.close()
		return root
	f.close()
	for site in json.data.get("sites", []):
		var marker := Marker3D.new()
		marker.name = "Bombsite_" + String(site.get("name", "?"))
		marker.position = _vec(site.get("center", [0, 0, 0])) - root.position
		root.add_child(marker)
	return root


static func _vec(value) -> Vector3:
	if not (value is Array) or (value as Array).size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
