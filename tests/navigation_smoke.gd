extends SceneTree
## Smoke-тест навигации: проверяет все основные переходы, кнопки назад, Esc, вкладки.

const REF := Vector2(1280.0, 720.0)

var failures: int = 0

func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _press(btn: BaseButton) -> void:
	if btn == null:
		_check(false, "Кнопка null")
		return
	btn.pressed.emit()


func _init() -> void:
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	await process_frame
	await process_frame
	var ui = lobby.get_node("UI")
	ui.root.scale = Vector2.ONE
	ui.root.position = Vector2.ZERO
	await process_frame

	# ---------- 1. Топ-нав как в CS: 4 вкладки ----------
	for tab in ["ИГРАТЬ", "ПРОСМОТР", "ИНВЕНТАРЬ", "МАГАЗИН"]:
		_press(ui.nav_buttons[tab])
		await process_frame
		_check(ui.current_screen == tab, "Нав: " + tab + " -> current_screen=" + ui.current_screen)
		_check(ui.nav_buttons[tab].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Нав подсветка: " + tab)
	_check(ui.nav_buttons.size() == 4, "Ровно 4 вкладки в топ-наве")
	_press(ui.nav_buttons["ИГРАТЬ"])
	await process_frame

	# ---------- 2. Иконки слева: дом, инвентарь, настройки ----------
	var h = ui.top_bar.get_child(0)
	_press(h.get_child(0))
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "Home -> ИГРАТЬ")
	_press(h.get_child(1))
	await process_frame
	_check(ui.inventory_overlay.visible, "Иконка инвентаря -> overlay")
	_check(ui.current_screen == "ИНВЕНТАРЬ", "Инвентарь current_screen")
	_press(ui.inventory_close)
	await process_frame
	_check(not ui.inventory_overlay.visible, "Инвентарь закрыт крестиком")
	_check(ui.current_screen == "ИГРАТЬ", "Инвентарь закрыт -> ИГРАТЬ")
	_press(h.get_child(2))
	await process_frame
	_check(ui.settings_overlay.visible, "Иконка настройки -> overlay")
	_check(ui.current_screen == "НАСТРОЙКИ", "Настройки current_screen")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ui._unhandled_input(ev)
	await process_frame
	_check(not ui.settings_overlay.visible, "Esc закрыл настройки")
	_check(ui.current_screen == "ИГРАТЬ", "Esc из настроек -> ИГРАТЬ")

	# ---------- 3. ПРОСМОТР как вкладка CS ----------
	_press(ui.nav_buttons["ПРОСМОТР"])
	await process_frame
	_check(ui.current_screen == "ПРОСМОТР", "Вкладка ПРОСМОТР")
	_check(ui.nav_buttons["ПРОСМОТР"].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Подсветка ПРОСМОТР")

	# ---------- 4. ПРОСМОТР: вкладки фильтров ----------
	var watch_top = ui.watch_panel.get_child(0)
	var watch_tabs_arr := ["ВАШИ МАТЧИ", "СКАЧАННЫЕ МАТЧИ", "МЕЙДЖОРЫ"]
	var watch_counts := []
	for i in range(watch_tabs_arr.size()):
		var tab: String = watch_tabs_arr[i]
		_press(watch_top.get_child(i + 1))
		await process_frame
		_check(ui.watch_tab == tab, "Watch вкладка: " + tab)
		_check(ui.watch_tabs[tab].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Watch подсветка: " + tab)
		var wcnt: int = ui.watch_list.get_child_count()
		watch_counts.append(wcnt)
		_check(ui.watch_empty, "Watch не показывает фейковые матчи: " + tab)
		_check(ui.watch_list.get_node_or_null("WatchEmpty") != null, "Watch пустое состояние: " + tab)
	_check(watch_counts.all(func(v): return v == 1), "Watch вкладки показывают только empty-state")
	_press(watch_top.get_child(0))
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "ПРОСМОТР назад -> ИГРАТЬ")

	# ---------- 5. ИГРАТЬ -> МАГАЗИН + вкладки + назад ----------
	_press(ui.nav_buttons["МАГАЗИН"])
	await process_frame
	_check(ui.current_screen == "МАГАЗИН", "МАГАЗИН")
	var store_top = ui.store_panel.get_child(0)
	var store_tabs_arr := ["ГЛАВНАЯ", "ОБЩЕЕ", "СИНГАПУР-2026", "ТОРГОВАЯ ПЛОЩАДКА", "ИНСТРУМЕНТЫ", "АРСЕНАЛ"]
	for i in range(store_tabs_arr.size()):
		var tab: String = store_tabs_arr[i]
		_press(store_top.get_child(i + 1))
		await process_frame
		_check(ui.store_tab == tab, "Магазин вкладка: " + tab)
		_check(ui.store_tabs[i].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Магазин подсветка: " + tab)
		_check(ui.store_title.text == ui.STORE_SECTIONS[tab].title, "Магазин заголовок: " + ui.store_title.text)
	_press(store_top.get_child(0))
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "Магазин назад -> ИГРАТЬ")

	# ---------- 6. ИГРАТЬ -> ПОДБОР + source tabs + назад ----------
	_press(ui.play_start_button)
	await process_frame
	_check(ui.current_screen == "ПОДБОР", "ИГРАТЬ кнопка -> ПОДБОР")
	var source_tabs = ui.play_modes_panel.get_child(0)
	var src_arr := ["ПОДБОР МАТЧА", "ТРЕНИРОВКА", "КАРТЫ ИЗ МАСТЕРСКОЙ"]
	for i in range(src_arr.size()):
		var src: String = src_arr[i]
		_press(source_tabs.get_child(i + 1))
		await process_frame
		_check(ui.play_source == src, "Источник: " + src)
		_check(ui.play_source_tabs[i].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Источник подсветка: " + src)
		if src == "ТРЕНИРОВКА":
			_check("ТРЕНИРОВКА" in ui.play_mission_label.text, "Миссия тренировка")
			_check(not ui.play_modes_row.visible, "Режимы скрыты в тренировке")
		elif src == "КАРТЫ ИЗ МАСТЕРСКОЙ":
			_check("МАСТЕРСКОЙ" in ui.play_mission_label.text, "Миссия мастерская")
			_check(not ui.play_modes_row.visible, "Режимы скрыты в мастерской")
		else:
			_check("СОРЕВНОВАТЕЛЬНЫЙ" in ui.play_mission_label.text, "Миссия матчмейкинг")
			_check(ui.play_modes_row.visible, "Режимы видны в подборе")
	_press(source_tabs.get_child(0))
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "ПОДБОР назад -> ИГРАТЬ")

	# ---------- 7. ИГРАТЬ -> НАСТРОЙКИ + вкладки + подвкладки ----------
	_press(h.get_child(2))
	await process_frame
	_check(ui.settings_overlay.visible, "Настройки overlay")
	var settings_tabs_arr := ["ИЗОБРАЖЕНИЕ", "ЗВУК", "ИГРА", "КЛАВИАТУРА И МЫШЬ", "ПРИЦЕЛ"]
	for i in range(settings_tabs_arr.size()):
		var tab: String = settings_tabs_arr[i]
		_press(ui.settings_sub_tabs[i])
		await process_frame
		_check(ui.settings_tab_index == i, "Настройки вкладка " + str(i) + ": " + tab)
		_check(ui.settings_sub_tabs[i].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Настройки подсветка: " + tab)
		_check(ui.settings_content.get_child_count() > 0, "Настройки контент не пуст")
	_press(ui.settings_sub_tabs[0])
	await process_frame
	_check(ui.settings_sub_row.visible, "Подвкладки видны для ИЗОБРАЖЕНИЕ")
	var sub_arr := ["ГРАФИКА", "РАСШИРЕННЫЕ НАСТРОЙКИ", "ПОЗИЦИЯ КРАЁВ"]
	for j in range(sub_arr.size()):
		var sub: String = sub_arr[j]
		_press(ui.settings_sub_buttons[j])
		await process_frame
		_check(ui.settings_sub_index == j, "Подвкладка " + str(j) + ": " + sub)
		_check(ui.settings_content.get_child_count() > 0, "Подвкладка контент не пуст")
	_press(ui.settings_sub_tabs[1])
	await process_frame
	_check(not ui.settings_sub_row.visible, "Подвкладки скрыты для ЗВУК")
	ui._unhandled_input(ev)
	await process_frame
	_check(not ui.settings_overlay.visible, "Esc закрыл настройки")
	_check(ui.current_screen == "ИГРАТЬ", "Esc из настроек -> ИГРАТЬ")

	# ---------- 8. Настройки из МАГАЗИНА -> возврат в МАГАЗИН ----------
	_press(ui.nav_buttons["МАГАЗИН"])
	await process_frame
	_press(h.get_child(2))
	await process_frame
	_check(ui.settings_return_screen == "МАГАЗИН", "Return screen = МАГАЗИН")
	ui._unhandled_input(ev)
	await process_frame
	_check(not ui.settings_overlay.visible, "Esc закрыл настройки из магазина")
	_check(ui.current_screen == "МАГАЗИН", "Возврат в МАГАЗИН")

	# ---------- 9. СНАРЯЖЕНИЕ: вход из инвентаря, команда CT/T, фильтры ----------
	_press(ui.nav_buttons["ИНВЕНТАРЬ"])
	await process_frame
	_check(ui.inventory_overlay.visible, "Инвентарь перед снаряжением")
	_press(ui.inventory_loadout)
	await process_frame
	_check(ui.current_screen == "СНАРЯЖЕНИЕ", "СНАРЯЖЕНИЕ из инвентаря")
	_check(not ui.inventory_overlay.visible, "Инвентарь скрыт в снаряжении")
	_check(ui.nav_buttons["ИНВЕНТАРЬ"].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "В снаряжении активна ИНВЕНТАРЬ")
	_press(ui.equipment_ct_button)
	await process_frame
	_check(ui.equipment_team == 2, "CT команда выбрана")
	_press(ui.equipment_t_button)
	await process_frame
	_check(ui.equipment_team == 1, "T команда выбрана")
	_press(ui.equipment_t_button)
	await process_frame
	_check(ui.equipment_team == -1, "Команда сброшена повторным нажатием")
	ui.equipment_filter_btn.select(2)
	ui.equipment_filter_btn.item_selected.emit(2)
	await process_frame
	_check(ui.equipment_filter == 2, "Фильтр винтовки")
	var cnt: int = ui.equipment_grid.get_child_count()
	_check(cnt > 0 and cnt < 43, "Фильтр уменьшил список: " + str(cnt))
	ui.equipment_filter_btn.select(0)
	ui.equipment_filter_btn.item_selected.emit(0)
	await process_frame
	ui.equipment_sort_btn.select(1)
	ui.equipment_sort_btn.item_selected.emit(1)
	await process_frame
	_check(ui.equipment_sort == 1, "Сортировка по имени")

	_press(ui.nav_buttons["ИНВЕНТАРЬ"])
	await process_frame
	_check(ui.current_screen == "ИНВЕНТАРЬ" and ui.inventory_overlay.visible, "Возврат в инвентарь")

	# ---------- 10. ИНВЕНТАРЬ: категории, сортировка, закрытие ----------
	for cat in ["ВСЕ", "ЭКИПИРОВКА", "ГРАФИКА", "КОНТЕЙНЕРЫ"]:
		_press(ui.inventory_tabs[cat])
		await process_frame
		_check(ui.inventory_category == cat, "Инв категория: " + cat)
		_check(ui.inventory_tabs[cat].get_theme_color("font_color") == Color(0.28, 0.72, 0.94), "Инв подсветка: " + cat)
	ui.inventory_sort_btn.select(1)
	ui.inventory_sort_btn.item_selected.emit(1)
	await process_frame
	_check(ui.inventory_sort == 1, "Инв сортировка по имени")
	ui.inventory_sort_btn.select(2)
	ui.inventory_sort_btn.item_selected.emit(2)
	await process_frame
	_check(ui.inventory_sort == 2, "Инв сортировка по редкости")
	_press(ui.inventory_close)
	await process_frame
	_check(not ui.inventory_overlay.visible, "Инвентарь закрыт")
	_check(ui.current_screen == "ИГРАТЬ", "Инв закрыт -> ИГРАТЬ")

	# ---------- 11. Esc из разных экранов ----------
	for scr in ["ПРОСМОТР", "МАГАЗИН"]:
		_press(ui.nav_buttons[scr])
		await process_frame
		ui._unhandled_input(ev)
		await process_frame
		_check(ui.current_screen == "ИГРАТЬ", "Esc из " + scr + " -> ИГРАТЬ")
	_press(ui.bg_switch.get_child(2))
	await process_frame
	_check(ui.current_screen == "НОВОСТИ", "Кнопка НОВОСТИ на экране ИГРАТЬ")
	ui._unhandled_input(ev)
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "Esc из НОВОСТИ -> ИГРАТЬ")
	_press(ui.play_start_button)
	await process_frame
	ui._unhandled_input(ev)
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "Esc из ПОДБОР -> ИГРАТЬ")
	_press(ui.nav_buttons["ИНВЕНТАРЬ"])
	await process_frame
	_press(ui.inventory_loadout)
	await process_frame
	ui._unhandled_input(ev)
	await process_frame
	_check(ui.current_screen == "ИНВЕНТАРЬ", "Esc из СНАРЯЖЕНИЕ -> ИНВЕНТАРЬ")
	_press(ui.inventory_close)
	await process_frame
	_check(ui.current_screen == "ИГРАТЬ", "Инвентарь закрыт после Esc-навигации")

	# ---------- 12. Игровой клиент: B, Esc, close, pause, resume, exit ----------
	var client = load("res://scenes/client.tscn").instantiate()
	root.add_child(client)
	await process_frame
	await process_frame
	var hud = client.hud
	hud.root.scale = Vector2.ONE
	hud.root.position = Vector2.ZERO
	await process_frame
	var ev_b := InputEventKey.new()
	ev_b.keycode = KEY_B
	ev_b.pressed = true
	client._input(ev_b)
	await process_frame
	_check(hud.buy_open and hud.buy_panel.visible, "B открыл закупку")
	# кнопка крестик в закупке
	var buy_head = hud.buy_panel.get_child(0).get_child(0)
	_press(buy_head.get_child(3))
	await process_frame
	_check(not hud.buy_open, "Крестик закрыл закупку")
	# B снова + Esc
	client._input(ev_b)
	await process_frame
	client._input(ev)
	await process_frame
	_check(not hud.buy_open, "Esc закрыл закупку")
	# Esc -> пауза
	client._input(ev)
	await process_frame
	_check(hud.pause_open and hud.pause_panel.visible, "Esc открыл паузу")
	var pause_vbox = hud.pause_panel.get_child(0)
	_press(pause_vbox.get_child(1))
	await process_frame
	_check(not hud.pause_open, "Resume закрыл паузу")
	client._input(ev)
	await process_frame
	_check(hud.pause_open, "Esc снова пауза")
	current_scene = client
	_press(pause_vbox.get_child(2))
	for i in range(8):
		await process_frame
	_check(root.get_node_or_null("Client") == null, "Exit выгрузил игровой клиент")
	_check(current_scene != null and current_scene.get_node_or_null("UI") != null, "Exit вернул в лобби")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (" + str(failures) + ")")
	quit(1 if failures > 0 else 0)
