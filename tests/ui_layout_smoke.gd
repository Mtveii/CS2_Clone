extends SceneTree
## Проверка web-адаптива: элементы не выходят за 1280x720 и ключевые блоки не перекрываются.
## Работает в референсных координатах (движок масштабирует CanvasLayer через stretch).

const REF := Vector2(1280.0, 720.0)

var failures: int = 0

func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _inside(name: String, c: Control, pad: float = 0.5) -> bool:
	var r := c.get_global_rect()
	var ok := r.position.x >= -pad and r.position.y >= -pad \
		and r.end.x <= REF.x + pad and r.end.y <= REF.y + pad
	_check(ok, "%s в экране (%.0f,%.0f)-(%.0f,%.0f)" % [
		name, r.position.x, r.position.y, r.end.x, r.end.y])
	return ok


func _all_children_inside(panel: Control) -> void:
	for c in panel.get_children():
		if c is Control:
			_inside(String(c.name) if String(c.name) != "" else c.get_class(), c)


func _init() -> void:
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	root.size = REF
	await process_frame
	await process_frame
	var ui = lobby.get_node("UI")
	ui.root.scale = Vector2.ONE
	ui.root.position = Vector2.ZERO
	await process_frame

	# --- главный экран ---
	ui._show_screen("ИГРАТЬ")
	await process_frame
	await process_frame
	_inside("верхняя панель", ui.top_bar)
	_inside("полоса друзей", ui.right_strip)
	_inside("кнопка ИГРАТЬ", ui.play_start_button)
	_inside("левая колонка", ui.play_panel.get_child(0))
	_check(ui.play_start_button != null, "главная кнопка ИГРАТЬ существует")
	var status_rect: Rect2 = ui.status_label.get_global_rect()
	var left_rect: Rect2 = ui.play_panel.get_child(0).get_global_rect()
	var play_rect: Rect2 = ui.play_start_button.get_global_rect()
	_check(status_rect.position.y >= left_rect.end.y, "статус ниже левой колонки")
	_check(status_rect.end.x <= play_rect.position.x, "статус не перекрывает кнопку ИГРАТЬ")

	# --- просмотр матчей ---
	ui._show_screen("ПРОСМОТР")
	await process_frame
	_all_children_inside(ui.watch_panel)
	var watch_list: Control = ui.watch_panel.get_child(1)
	var watch_detail: Control = ui.watch_panel.get_child(2)
	_check(watch_list.get_global_rect().end.x <= watch_detail.get_global_rect().position.x,
		"список матчей не залезает на детали")

	# --- магазин ---
	ui._show_screen("МАГАЗИН")
	await process_frame
	_all_children_inside(ui.store_panel)
	var banner: Control = ui.store_panel.get_child(1)
	var music: Control = ui.store_panel.get_child(2)
	_check(banner.get_global_rect().end.y <= music.get_global_rect().position.y,
		"баннер магазина не перекрывает музыку")

	# --- подбор матча ---
	ui._show_screen("ПОДБОР")
	await process_frame
	_all_children_inside(ui.play_modes_panel)
	var modes: Control = ui.play_modes_panel.get_child(1)
	var maps: Control = ui.play_modes_panel.get_child(3)
	var bottom: Control = ui.play_modes_panel.get_child(4)
	_check(modes.get_global_rect().end.x <= REF.x, "режимы помещаются по ширине")
	_check(maps.get_global_rect().end.y <= bottom.get_global_rect().position.y,
		"карты не залезают на нижнюю панель")
	_check(ui.play_modes_back != null, "кнопка назад в подборе")

	# --- снаряжение ---
	ui._show_screen("СНАРЯЖЕНИЕ")
	await process_frame
	_all_children_inside(ui.equipment_panel)
	_check(ui.equipment_grid.get_child_count() == 43, "сетка снаряжения: 43 предмета")

	# --- настройки ---
	ui._open_settings()
	await process_frame
	_all_children_inside(ui.settings_overlay)
	var settings_scroll: Control = ui.settings_overlay.get_child(4)
	var settings_bottom: Control = ui.settings_overlay.get_child(5)
	_check(settings_scroll.get_global_rect().end.y <= settings_bottom.get_global_rect().position.y,
		"контент настроек не залезает на нижнюю панель")
	ui._close_settings()

	# --- инвентарь ---
	ui._open_inventory()
	await process_frame
	_all_children_inside(ui.inventory_overlay)
	_inside("закрыть инвентарь", ui.inventory_close)
	var inv_tabs: Control = ui.inventory_overlay.get_child(1)
	var inv_sort: Control = ui.inventory_overlay.get_child(2)
	var inv_scroll: Control = ui.inventory_overlay.get_child(3)
	_check(inv_tabs.get_global_rect().end.y <= inv_sort.get_global_rect().position.y,
		"вкладки инвентаря не перекрывают сортировку")
	_check(inv_sort.get_global_rect().end.y <= inv_scroll.get_global_rect().position.y,
		"сортировка не перекрывает сетку предметов")
	ui._close_inventory()

	# --- игровой HUD ---
	var client = load("res://scenes/client.tscn").instantiate()
	root.add_child(client)
	await process_frame
	await process_frame
	var hud = client.hud
	hud.root.scale = Vector2.ONE
	hud.root.position = Vector2.ZERO
	await process_frame
	_inside("HUD статус", hud.bottom_panel)
	_inside("HUD подсказка", hud.hint_label)
	_inside("HUD захват мыши", hud.mouse_hint)
	var ch: Rect2 = hud.crosshair.get_global_rect()
	_check(ch.get_center().distance_to(REF * 0.5) < 1.0, "прицел по центру экрана")
	_check(hud.hint_label.get_global_rect().end.x <= hud.bottom_panel.get_global_rect().position.x,
		"подсказка HUD не перекрывает статус")
	hud.toggle_buy()
	await process_frame
	_inside("меню закупки", hud.buy_panel)
	hud.toggle_buy()
	hud.toggle_pause()
	await process_frame
	_inside("меню паузы", hud.pause_panel)
	hud.close_pause()

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
