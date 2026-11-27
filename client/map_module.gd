extends Node
## Autoload-модуль карты. Подключается к игровой сцене ПОСЛЕ инициализации
## боевой системы и не импортирует/не меняет combat-файлы.

const MapModuleLoader = preload("res://shared/map/map_module_loader.gd")

var attached_scenes: Array = []


func _ready() -> void:
	# Игровая сцена сама грузит выбранную карту; автоподключение дубликатов
	# мешает работе и нагружает браузер.
	pass


func _on_scene_changed(scene_root: Node) -> void:
	if scene_root != null and scene_root.name == "Client":
		call_deferred("attach_to", scene_root)


func attach_to(client_root: Node) -> void:
	if client_root == null or client_root.get_node_or_null("IsolatedMap") != null:
		return
	var container := Node3D.new()
	container.name = "IsolatedMap"
	client_root.add_child(container)
	for def in MapModuleLoader.load_catalog().get("maps", []):
		container.add_child(MapModuleLoader.build_geometry(def))
		container.add_child(MapModuleLoader.build_collisions(def))
		container.add_child(MapModuleLoader.build_spawns(def))
		container.add_child(MapModuleLoader.build_objectives(def))
	if not attached_scenes.has(client_root):
		attached_scenes.append(client_root)
