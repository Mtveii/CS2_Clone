extends SceneTree
## Тест главного меню по референсам: вкладки, агенты, фоны, экраны, карты, инвентарь.
const GameSettings = preload("res://client/settings.gd")
const AgentData = preload("res://client/agents.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# агенты
	var ad = AgentData.new()
	_check(ad.agents.size() == 13, "13 агентов")
	_check(ad.by_team(WeaponData.Team.T).size() == 5, "5 T агентов")
	_check(ad.by_team(WeaponData.Team.CT).size() == 8, "8 CT агентов")
	_check(ad.factions_for(WeaponData.Team.T).size() == 5, "5 фракций T")
	_check(ad.factions_for(WeaponData.Team.CT).size() == 8, "8 фракций CT")
	_check(ad.hitbox_profile() == "standard_humanoid_100hp", "одинаковые хитбоксы")
	ad.find("t_pro").owned = false
	_check(not ad.can_equip(ad.find("t_pro")), "нельзя экипировать чужого агента")

	# сцена
	var packed = load("res://scenes/lobby.tscn")
	_check(packed != null, "сцена lobby.tscn")
	var inst = packed.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	var ui = inst.get_node("UI")
	var world = inst.get_node("LobbyWorld")
	var r = ui.get_node_or_null("LobbyUI")
	_check(r != null, "root UI")

	# верхняя панель: 5 вкладок + 4 иконки слева + полоса друзей справа
	_check(ui.nav_buttons.size() == 5, "5 вкладок")
	for t in ["ИНВЕНТАРЬ", "СНАРЯЖЕНИЕ", "ИГРАТЬ", "МАГАЗИН", "НОВОСТИ"]:
		_check(ui.nav_buttons.has(t), "вкладка " + t)
	_check(r.get_node_or_null("FriendsStrip") != null, "полоса друзей справа")
	# адаптивность: референс 1280x720 масштабируется на любое окно
	ui._fit_with(Vector2(1920.0, 1080.0))
	_check(ui.root.size == Vector2(1280.0, 720.0), "референсный размер UI")
	_check(absf(ui.root.scale.x - 1.5) < 0.01, "масштаб 1920x1080 = 1.5")
	ui._fit_with(Vector2(800.0, 600.0))
	_check(absf(ui.root.scale.x - 0.625) < 0.01, "масштаб 800x600 по ширине")
	_check(absf(ui.root.scale.y - 0.833) < 0.01, "масштаб 800x600 по высоте")
	ui._fit_with(Vector2(1280.0, 720.0))
	_check(r.get_node_or_null("SettingsOverlay") != null, "экран настроек")
	_check(r.get_node_or_null("InventoryOverlay") != null, "экран инвентаря")
	_check(r.get_child_count() > 0, "UI построен")

	# фоны
	_check(world.BACKGROUNDS.size() == 13, "13 ванильных фонов")
	var b0 = world.background_name()
	world.next_background()
	_check(world.background_name() != b0, "смена фона")
	world.prev_background()
	_check(world.background_name() == b0, "возврат фона")
	_check(world.get_node_or_null("Dust") != null, "частицы")
	_check(world.get_node_or_null("LobbyCamera") != null, "камера")

	# экраны
	ui._show_screen("ИГРАТЬ")
	_check(ui.play_panel.visible, "экран Играть")
	ui._show_screen("ПРОСМОТР")
	_check(ui.watch_panel.visible, "экран Просмотр")
	_check(ui.watch_list.get_child_count() == 7, "7 матчей в списке (%d)" % ui.watch_list.get_child_count())
	ui._download_match("матч", null)
	ui._show_screen("НОВОСТИ")
	_check(ui.news_panel.visible, "экран Новости")
	ui._show_screen("МАГАЗИН")
	_check(ui.store_panel.visible, "экран Магазин")
	ui._show_screen("СНАРЯЖЕНИЕ")
	_check(ui.equipment_panel.visible, "экран Снаряжение")

	# подбор матча
	ui._show_screen("ПОДБОР")
	_check(ui.play_modes_panel.visible, "экран Подбор")
	_check(ui.play_mode_tabs.size() == 9, "9 режимов")
	_check(ui.map_grid_ready(), "карточки карт построены")

	# настройки: 5 вкладок, без выбора фона в Изображении
	ui._open_settings()
	_check(ui.settings_overlay.visible, "настройки открыты")
	ui._select_settings_tab(3)
	_check(ui.settings_content.get_child_count() > 5, "Клавиатура и мышь заполнена (%d)" % ui.settings_content.get_child_count())
	ui._select_settings_tab(0)
	var txt := ""
	for c in ui.settings_content.get_children():
		if c is Label:
			txt += c.text
	_check(not txt.contains("Main Menu Background Scenery"), "фона нет в Изображении")
	_check(ui.SETTINGS_TABS.size() == 5, "5 вкладок настроек")
	ui._close_settings()

	# инвентарь: 7 категорий, 43武器
	ui._open_inventory()
	_check(ui.inventory_overlay.visible, "инвентарь открыт")
	_check(ui.INVENTORY_CATEGORIES.size() == 7, "7 категорий инвентаря")
	_check(ui.inventory_grid.get_child_count() == 43, "43武器 (%d)" % ui.inventory_grid.get_child_count())
	ui._close_inventory()

	# CT/T
	world.set_team(WeaponData.Team.CT)
	_check(world.current_agent().team == WeaponData.Team.CT, "переключение CT")
	world.next_agent()
	_check(world.current_agent() != null, "следующий агент")
	_check(WeaponData.WEAPONS.size() == 43, "43武器 в каталоге")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
