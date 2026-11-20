extends SceneTree
## Тест лобби: сцена, UI-панели, настройки, инвентарь, 3D-агент.
const GameSettings = preload("res://client/settings.gd")
const AgentData = preload("res://client/agents.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# настройки: все категории
	var s = GameSettings.new()
	_check(s.all_categories().size() == 6, "6 категорий настроек")
	_check(s.sensitivity == 1.0, "чувствительность по умолчанию")
	_check(s.viewmodel_fov == 68.0, "FOV модели 68")
	_check(s.crosshair_gap == 3.0, "зазор прицела 3")
	s.sensitivity = 2.5
	s.save()
	var s2 = GameSettings.new()
	s2.load_settings()
	_check(s2.sensitivity == 2.5, "настройки сохраняются")

	# агенты
	var ad = AgentData.new()
	_check(ad.agents.size() == 8, "8 агентов")
	_check(ad.by_team(WeaponData.Team.T).size() == 4, "4 террориста")
	_check(ad.by_team(WeaponData.Team.CT).size() == 4, "4 спецназа")
	var a = ad.by_team(WeaponData.Team.T)[0]
	var model = ad.build_voxel_model(a)
	_check(model.get_child_count() >= 10, "воксельная моделька агента (%d деталей)" % model.get_child_count())

	# сцена лобби
	var packed = load("res://scenes/lobby.tscn")
	_check(packed != null, "сцена lobby.tscn загружается")
	var inst = packed.instantiate()
	_check(inst.get_node_or_null("LobbyWorld") != null, "3D-мир лобби есть")
	_check(inst.get_node_or_null("UI") != null, "UI лобби есть")
	root.add_child(inst)
	# дать время на _ready
	await process_frame
	await process_frame
	var ui = inst.get_node("UI")
	var r = ui.get_node_or_null("LobbyUI")
	_check(r != null, "root UI создан")
	if r != null:
		_check(r.get_node_or_null("SettingsOverlay") != null, "панель настроек")
		_check(r.get_node_or_null("InventoryOverlay") != null, "панель инвентаря")
		_check(r.get_node_or_null("InventoryStrip") != null, "полоса снаряжения")
		# открыть настройки и инвентарь (проверка что панели строятся)
		ui._open_settings()
		_check(ui.settings_overlay.visible, "настройки открываются")
		_check(ui.settings_content.get_child_count() > 5, "настройки заполнены (%d)" % ui.settings_content.get_child_count())
		ui._select_settings_tab(3)
		_check(ui.settings_content.get_child_count() > 5, "вкладка прицела заполнена")
		ui._close_settings()
		ui._open_inventory()
		_check(ui.inventory_overlay.visible, "инвентарь открывается")
		_check(ui.inventory_grid.get_child_count() == 43, "43武器 в сетке (%d)" % ui.inventory_grid.get_child_count())
		ui._close_inventory()
		var world = inst.get_node("LobbyWorld")
		_check(world != null and world.get_node_or_null("Pedestal/AgentDisplay") != null, "подиум с агентом")
		_check(world.get_node_or_null("Dust") != null, "частицы пыли")
		_check(world.get_node_or_null("LobbyCamera") != null, "камера лобби")
		# переключение команд и агентов
		world.set_team(WeaponData.Team.CT)
		_check(world.current_agent().team == WeaponData.Team.CT, "переключение на CT")
		world.next_agent()
		_check(world.current_agent() != null, "следующий агент")

	# все 43武器 в инвентаре
	_check(WeaponData.WEAPONS.size() == 43, "43武器 в инвентаре")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
