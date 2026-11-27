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
	root.size = Vector2(1280.0, 720.0)
	await process_frame
	var ui = inst.get_node("UI")
	var world = inst.get_node("LobbyWorld")
	var r = ui.get_node_or_null("LobbyUI")
	_check(r != null, "root UI")

	# верхняя панель: 4 вкладки как в CS + 4 иконки слева + полоса друзей справа
	_check(ui.nav_buttons.size() == 4, "4 вкладки")
	for t in ["ИГРАТЬ", "ПРОСМОТР", "ИНВЕНТАРЬ", "МАГАЗИН"]:
		_check(ui.nav_buttons.has(t), "вкладка " + t)
	_check(r.get_node_or_null("FriendsStrip") != null, "полоса друзей справа")
	# адаптивность: FULL_RECT + stretch/expand, без двойного scale
	_check(ui.get_viewport().get_visible_rect().size == Vector2(1280.0, 720.0), "референс 1280x720")
	_check(ui.root.size == Vector2(1280.0, 720.0), "root занимает весь viewport")
	ui._fit_with(Vector2(1920.0, 1080.0))
	_check(ui.root.scale == Vector2.ONE, "UI не масштабируется повторно")
	_check(ui.root.scale == Vector2.ONE, "UI не масштабируется повторно")
	ui._fit_with(Vector2(800.0, 600.0))
	_check(ui.root.scale == Vector2.ONE, "нет двойного масштаба 800x600")
	ui._fit_with(Vector2(1280.0, 720.0))
	_check(r.get_node_or_null("SettingsOverlay") != null, "экран настроек")
	_check(r.get_node_or_null("InventoryOverlay") != null, "экран инвентаря")
	_check(r.get_child_count() > 0, "UI построен")

	# сквозной путь игрока: ИГРАТЬ -> ПОДБОР -> назад
	ui._show_screen("ИГРАТЬ")
	_check(ui.play_start_button != null, "кнопка ИГРАТЬ на главном экране")
	ui.play_start_button.pressed.emit()
	_check(ui.current_screen == "ПОДБОР" and ui.play_modes_panel.visible, "кнопка ИГРАТЬ открывает подбор")
	ui.play_modes_back.pressed.emit()
	_check(ui.current_screen == "ИГРАТЬ" and ui.play_panel.visible, "назад возвращает на главный экран")

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
	_check(ui.watch_empty and ui.watch_list.get_child_count() == 1,
		"Просмотр показывает пустое состояние, а не фейковые матчи (%d)" % ui.watch_list.get_child_count())
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
	_check(ui.play_map_grid.get_child_count() == 6,
		"в сетке 6 карточек загруженных карт (%d)" % ui.play_map_grid.get_child_count())
	var disabled_cards: int = 0
	for card in ui.play_map_grid.get_children():
		var check: CheckButton = (card.get_child(0) as VBoxContainer).get_child(0) as CheckButton
		if check != null and check.disabled:
			disabled_cards += 1
	_check(disabled_cards == 2, "2 CC BY-ND карты отмечены как исходники (%d)" % disabled_cards)
	var real_maps: int = 0
	var source_maps: int = 0
	var playable: int = 0
	for m in ui.MAP_GROUPS:
		if bool(m.get("source_only", false)):
			if FileAccess.file_exists(String(m.get("source_file", ""))):
				source_maps += 1
		else:
			playable += 1
			if FileAccess.file_exists("res://assets/maps/" + String(m.get("file", ""))):
				real_maps += 1
	_check(real_maps == playable and playable > 0,
			"все играбельные карты имеют .vmap (%d/%d)" % [real_maps, playable])
	_check(source_maps == 2, "CC BY-ND источники показаны как исходники (%d)" % source_maps)
	_check(ui.MAP_GROUPS.size() == 6, "в меню 6 загруженных карт (%d)" % ui.MAP_GROUPS.size())

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
	_check(ui.inventory_close != null, "кнопка закрытия инвентаря")
	ui.inventory_close.pressed.emit()
	_check(not ui.inventory_overlay.visible, "инвентарь закрывается кнопкой")

	# CT/T
	world.set_team(WeaponData.Team.CT)
	_check(world.current_agent().team == WeaponData.Team.CT, "переключение CT")
	world.next_agent()
	_check(world.current_agent() != null, "следующий агент")
	_check(WeaponData.WEAPONS.size() == 43, "43武器 в каталоге")
	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
