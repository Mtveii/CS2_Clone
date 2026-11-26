extends SceneTree
## Проверка единой темы, полноэкранного root и динамических (не фейковых) списков.

const UiTheme = preload("res://client/ui_theme.gd")
const FriendsStore = preload("res://client/friends.gd")

var failures: int = 0
var news_text: String = ""

func _check(c: bool, m: String) -> void:
	if c:
		print("[ok]   ", m)
	else:
		failures += 1
		push_error("[fail] " + m)


func _init() -> void:
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	root.size = Vector2(1280.0, 720.0)
	await process_frame
	await process_frame
	var ui = lobby.get_node("UI")

	# --- тема и полноэкранный root ---
	_check(ui.root.theme != null, "root использует общую Theme")
	_check(ui.root.anchor_right == 1.0 and ui.root.anchor_bottom == 1.0, "root FULL_RECT")
	_check(ui.root.size.is_equal_approx(root.get_visible_rect().size), "root размер = viewport")
	_check(UiTheme.radius(2) == UiTheme.R_SM, "радиус 2 приведён к шкале R_SM")
	_check(UiTheme.radius(9) == UiTheme.R_LG, "радиус 9 приведён к шкале R_LG")
	var sb := UiTheme.stylebox(UiTheme.SURFACE, UiTheme.LINE, UiTheme.R_MD)
	_check(sb.get_corner_radius(CORNER_TOP_LEFT) == UiTheme.R_MD, "стиль панели: радиус 8")
	_check(sb.content_margin_left == UiTheme.S2, "стиль панели: отступ 8")
	_check(ui.C_CYAN == UiTheme.ACCENT, "акцент лобби совпадает с темой")

	# --- друзья: изначально пусто ---
	var test_path := "user://friends_test.cfg"
	ConfigFile.new().save(test_path)
	ui.friends = FriendsStore.new(test_path)
	ui._rebuild_friends_strip()
	ui._refresh_friends_count()
	_check(ui.friends.is_empty(), "список друзей изначально пуст")
	_check(ui.friends_strip.get_node_or_null("AddFriend") != null, "пустой слот показывает '+'")
	_check(ui.friends_count_label.text == "0", "счётчик друзей = 0")
	ui._toggle_friends()
	await process_frame
	_check(ui.friends_overlay.visible, "оверлей друзей открывается")
	_check(ui.friends_empty, "оверлей показывает пустое состояние")
	_check(ui.friends_list.get_node_or_null("FriendsEmpty") != null, "FriendsEmpty присутствует")

	# --- добавление и сохранение ---
	ui.friends_input.text = "  TEST_BOT  "
	ui._add_friend()
	await process_frame
	_check(ui.friends.count() == 1, "друг добавлен")
	_check(ui.friends.has("TEST_BOT"), "имя нормализовано")
	_check(ui.friends_count_label.text == "1", "счётчик обновлён")
	_check(not ui.friends_empty, "пустое состояние скрыто")
	_check(ui.friends_list.get_node_or_null("Friend_TEST_BOT") != null, "строка друга создана")
	_check(FriendsStore.new(test_path).count() == 1, "список сохранён на диск")
	ui.friends_input.text = "TEST_BOT"
	ui._add_friend()
	_check(ui.friends.count() == 1, "дубликат не добавляется")

	# --- удаление ---
	ui._remove_friend("TEST_BOT")
	await process_frame
	_check(ui.friends.is_empty(), "друг удалён")
	_check(ui.friends_list.get_node_or_null("FriendsEmpty") != null, "пустое состояние вернулось")
	_check(FriendsStore.new(test_path).is_empty(), "удаление сохранено")
	ui._toggle_friends()

	# --- просмотр: никаких фейковых матчей ---
	for tab in ["ВАШИ МАТЧИ", "СКАЧАННЫЕ МАТЧИ", "МЕЙДЖОРЫ"]:
		ui._show_screen("ПРОСМОТР")
		ui._select_watch_tab(tab)
		await process_frame
		_check(ui.watch_empty, "Просмотр пуст: " + tab)
		_check(ui.watch_list.get_node_or_null("WatchEmpty") != null, "WatchEmpty: " + tab)
		_check(not ui.watch_actions.visible, "нет кнопок для несуществующего матча: " + tab)

	# --- новости: только реальные записи проекта ---
	ui._show_screen("НОВОСТИ")
	await process_frame
	news_text = ""
	_collect_labels(ui.news_panel)
	var has_real_news := news_text.contains("Oasis") and news_text.contains("Навигация")
	_check(has_real_news, "новости описывают реальные изменения проекта")

	print("RESULT: PASS" if failures == 0 else "RESULT: FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)


func _collect_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			news_text += (child as Label).text
		_collect_labels(child)
