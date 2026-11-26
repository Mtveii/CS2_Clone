extends RefCounted
## Локальный список друзей. По умолчанию пуст: записи появляются только
## после того, как пользователь сам добавит друга в меню.

const PATH := "user://friends.cfg"

var names: Array[String] = []
var path: String = PATH


func _init(custom_path: String = PATH) -> void:
	path = custom_path
	load_entries()


func load_entries() -> void:
	names.clear()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	var raw: Array = cf.get_value("friends", "names", [])
	for value in raw:
		var n := String(value).strip_edges()
		if n.is_empty():
			continue
		if not names.has(n):
			names.append(n)


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("friends", "names", names)
	cf.save(path)


func add(name: String) -> bool:
	var n := name.strip_edges()
	if n.is_empty() or names.has(n):
		return false
	names.append(n)
	save()
	return true


func remove(name: String) -> void:
	names.erase(name)
	save()


func has(name: String) -> bool:
	return names.has(name)


func count() -> int:
	return names.size()


func is_empty() -> bool:
	return names.is_empty()
