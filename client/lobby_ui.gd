extends CanvasLayer
## Лобби: верхняя панель, агент по центру,-party, плейлист, инвентарь, настройки.
## Управляет 3D-миром из lobby_world.gd и использует GameSettings + Loadout.

const GameSettings = preload("res://client/settings.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponIcon = preload("res://client/weapon_icon.gd")

const COLOR_BG := Color(0.06, 0.07, 0.10, 0.92)
const COLOR_PANEL := Color(0.10, 0.12, 0.16, 0.95)
const COLOR_ACCENT := Color(0.20, 0.75, 1.0)
const COLOR_GREEN := Color(0.25, 0.75, 0.35)
const COLOR_TEXT := Color(0.92, 0.94, 0.98)

var settings: GameSettings
var loadout: Loadout
var world = null

var root: Control
var top_bar: PanelContainer
var party_panel: PanelContainer
var play_panel: PanelContainer
var agent_card: PanelContainer
var inventory_strip: PanelContainer
var settings_overlay: Control
var inventory_overlay: Control
var nickname_label: Label
var wallet_label: Label
var agent_name_label: Label
var agent_role_label: Label
var team_tabs: Array = []
var settings_content: VBoxContainer
var inventory_grid: GridContainer
var status_label: Label

var selected_settings_tab: int = 0


func _ready() -> void:
	settings = GameSettings.new()
	settings.load_settings()
	loadout = Loadout.new(WeaponData.Team.CT, 16000)
	world = get_parent().get_node_or_null("LobbyWorld")
	_build_ui()
	_refresh_agent_info()
	_refresh_wallet()
	_refresh_inventory_strip()


func _build_ui() -> void:
	root = Control.new()
	root.name = "LobbyUI"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_top_bar()
	_build_party_panel()
	_build_play_panel()
	_build_agent_card()
	_build_inventory_strip()
	_build_settings_overlay()
	_build_inventory_overlay()
	_build_status()


func _style_panel(p: PanelContainer, bg: Color = COLOR_PANEL) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COLOR_ACCENT.darkened(0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)


func _style_button(b: Button, accent: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_ACCENT if accent else Color(0.16, 0.18, 0.24)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 6
	sb.content_margin_top = 6
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = (COLOR_ACCENT.lightened(0.15) if accent else Color(0.24, 0.28, 0.36))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", Color.WHITE if accent else COLOR_TEXT)


func _make_button(text: String, callback: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 36)
	_style_button(b, accent)
	b.pressed.connect(callback)
	return b


func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 56
	_style_panel(top_bar, COLOR_BG)
	root.add_child(top_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	top_bar.add_child(h)
	var logo := Label.new()
	logo.text = "VOXEL STRIKE"
	logo.add_theme_color_override("font_color", COLOR_ACCENT)
	logo.add_theme_font_size_override("font_size", 18)
	h.add_child(logo)
	nickname_label = Label.new()
	nickname_label.text = settings.nickname + "  •  Lv. 12  •  Gold Nova II"
	nickname_label.add_theme_color_override("font_color", COLOR_TEXT)
	h.add_child(nickname_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	wallet_label = Label.new()
	wallet_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5))
	h.add_child(wallet_label)
	h.add_child(_make_button("Инвентарь", _open_inventory))
	h.add_child(_make_button("Настройки", _open_settings))
	var exit_btn := _make_button("Выход", _on_exit)
	exit_btn.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	h.add_child(exit_btn)


func _build_party_panel() -> void:
	party_panel = PanelContainer.new()
	party_panel.anchor_left = 0.0
	party_panel.anchor_top = 0.0
	party_panel.anchor_right = 0.0
	party_panel.anchor_bottom = 0.0
	party_panel.offset_left = 14
	party_panel.offset_top = 70
	party_panel.offset_right = 236
	party_panel.offset_bottom = 430
	_style_panel(party_panel)
	root.add_child(party_panel)
	var v := VBoxContainer.new()
	party_panel.add_child(v)
	var title := Label.new()
	title.text = "ГРУППА  (1/5)"
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	v.add_child(title)
	var members := ["Вы  •  онлайн", "Пригласить друга..."]
	for m in members:
		var b := Button.new()
		b.text = m
		_style_button(b)
		v.add_child(b)
	var add := _make_button("+ Пригласить", func(): _set_status("Приглашение отправлено"))
	v.add_child(add)


func _build_play_panel() -> void:
	play_panel = PanelContainer.new()
	play_panel.anchor_left = 1.0
	play_panel.anchor_top = 0.0
	play_panel.anchor_right = 1.0
	play_panel.anchor_bottom = 0.0
	play_panel.offset_left = -250
	play_panel.offset_top = 70
	play_panel.offset_right = -14
	play_panel.offset_bottom = 470
	_style_panel(play_panel)
	root.add_child(play_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	play_panel.add_child(v)
	var t := Label.new()
	t.text = "НАЙТИ МАТЧ"
	t.add_theme_color_override("font_color", COLOR_ACCENT)
	v.add_child(t)
	var modes := OptionButton.new()
	modes.add_item("Соревновательный 5x5")
	modes.add_item("Смертельный матч")
	modes.add_item("Практика")
	v.add_child(modes)
	var maps := OptionButton.new()
	maps.add_item("Тестовая арена")
	maps.add_item("Воксельный полигон")
	v.add_child(maps)
	var find := _make_button("НАЙТИ МАТЧ", func(): _launch_game("Поиск матча..."), true)
	find.custom_minimum_size = Vector2(0, 52)
	v.add_child(find)
	var info := Label.new()
	info.text = "Регион: " + settings.region + "\nПинг: < " + str(settings.max_ping) + " мс"
	info.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	v.add_child(info)


func _build_agent_card() -> void:
	agent_card = PanelContainer.new()
	agent_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	agent_card.offset_left = -220
	agent_card.offset_right = 220
	agent_card.offset_top = -190
	agent_card.offset_bottom = -78
	_style_panel(agent_card, Color(0.07, 0.09, 0.13, 0.88))
	root.add_child(agent_card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	agent_card.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	team_tabs.clear()
	for team_name in ["ТЕРРОРИСТЫ", "СПЕЦНАЗ"]:
		var b := _make_button(team_name, func(): _on_team_tab(team_tabs.size()))
		tabs.add_child(b)
		team_tabs.append(b)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(_make_button("<", func(): _on_prev_agent()))
	agent_name_label = Label.new()
	agent_name_label.text = "Agent"
	agent_name_label.add_theme_font_size_override("font_size", 22)
	agent_name_label.add_theme_color_override("font_color", COLOR_TEXT)
	agent_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	agent_name_label.custom_minimum_size = Vector2(220, 0)
	h.add_child(agent_name_label)
	h.add_child(_make_button(">", func(): _on_next_agent()))
	agent_role_label = Label.new()
	agent_role_label.text = ""
	agent_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	agent_role_label.add_theme_color_override("font_color", COLOR_ACCENT)
	v.add_child(agent_role_label)


func _build_inventory_strip() -> void:
	inventory_strip = PanelContainer.new()
	inventory_strip.name = "InventoryStrip"
	inventory_strip.anchor_left = 0.0
	inventory_strip.anchor_right = 1.0
	inventory_strip.anchor_top = 1.0
	inventory_strip.anchor_bottom = 1.0
	inventory_strip.offset_top = -70
	inventory_strip.offset_bottom = -6
	inventory_strip.offset_left = 14
	inventory_strip.offset_right = -14
	_style_panel(inventory_strip, COLOR_BG)
	root.add_child(inventory_strip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	inventory_strip.add_child(h)
	var label := Label.new()
	label.text = "СНАРЯЖЕНИЕ:"
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	h.add_child(label)
	for slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY, Loadout.Slot.KNIFE,
			Loadout.Slot.GRENADE_HE_DECOY, Loadout.Slot.GRENADE_SMOKE, Loadout.Slot.C4]:
		h.add_child(_make_slot_icon(slot))
	h.add_child(_make_button("ВСЁ →", _open_inventory))


func _make_slot_icon(slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(92, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.20)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var icon := WeaponIcon.new()
	icon.custom_minimum_size = Vector2(80, 28)
	var wi = loadout.slots.get(slot, null)
	icon.weapon_id = wi.id if wi != null else -1
	v.add_child(icon)
	var name_label := Label.new()
	name_label.text = WeaponData.get_weapon(icon.weapon_id).name if icon.weapon_id >= 0 else "Пусто"
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	return panel


func _build_status() -> void:
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_top = 64
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	root.add_child(status_label)


func _set_status(msg: String) -> void:
	status_label.text = msg


func _launch_game(msg: String) -> void:
	_set_status(msg)
	get_tree().change_scene_to_file("res://scenes/client.tscn")


func _on_team_tab(index: int) -> void:
	if world == null:
		return
	world.set_team(WeaponData.Team.T if index == 0 else WeaponData.Team.CT)
	loadout.team = WeaponData.Team.T if index == 0 else WeaponData.Team.CT
	_refresh_agent_info()
	_refresh_inventory_strip()
	for i in range(team_tabs.size()):
		_style_button(team_tabs[i], i == index)


func _on_prev_agent() -> void:
	if world != null:
		world.prev_agent()
	_refresh_agent_info()


func _on_next_agent() -> void:
	if world != null:
		world.next_agent()
	_refresh_agent_info()


func _refresh_agent_info() -> void:
	if world == null:
		return
	var a = world.current_agent()
	if a == null:
		return
	agent_name_label.text = a.name
	agent_role_label.text = a.role.to_upper() + "  •  " + ("Т" if a.team == WeaponData.Team.T else "CT")
	world.set_team(a.team)
	loadout.team = a.team
	for i in range(team_tabs.size()):
		_style_button(team_tabs[i], (i == 0 and a.team == WeaponData.Team.T) or (i == 1 and a.team == WeaponData.Team.CT))


func _refresh_wallet() -> void:
	wallet_label.text = "$ " + str(loadout.money)


func _refresh_inventory_strip() -> void:
	# пересоздаём иконки (просто и надёжно)
	for c in inventory_strip.get_children():
		c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	inventory_strip.add_child(h)
	var label := Label.new()
	label.text = "СНАРЯЖЕНИЕ:"
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	h.add_child(label)
	for slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY, Loadout.Slot.KNIFE,
			Loadout.Slot.GRENADE_HE_DECOY, Loadout.Slot.GRENADE_SMOKE, Loadout.Slot.C4]:
		h.add_child(_make_slot_icon(slot))
	h.add_child(_make_button("ВСЁ →", _open_inventory))


# ==================== SETTINGS OVERLAY ====================

func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.8)
	settings_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -320
	panel.offset_bottom = 320
	_style_panel(panel, Color(0.08, 0.10, 0.14, 1))
	settings_overlay.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	# левое меню категорий
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(190, 0)
	h.add_child(menu)
	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	menu.add_child(title)
	var categories := settings.all_categories()
	for i in range(categories.size()):
		var b := _make_button(categories[i], func(): _select_settings_tab(i))
		b.custom_minimum_size = Vector2(180, 40)
		menu.add_child(b)
	# права область
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 520)
	right.add_child(scroll)
	settings_content = VBoxContainer.new()
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_content)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(bottom)
	bottom.add_child(_make_button("Применить", func(): _on_apply_settings(), true))
	bottom.add_child(_make_button("Назад", func(): _close_settings()))


func _select_settings_tab(index: int) -> void:
	selected_settings_tab = index
	_rebuild_settings_content()


func _rebuild_settings_content() -> void:
	for c in settings_content.get_children():
		c.queue_free()
	match selected_settings_tab:
		0: _build_mouse_settings()
		1: _build_video_settings()
		2: _build_audio_settings()
		3: _build_crosshair_settings()
		4: _build_viewmodel_settings()
		5: _build_game_settings()


func _section_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COLOR_ACCENT)
	l.add_theme_font_size_override("font_size", 15)
	settings_content.add_child(l)


func _add_slider(label: String, min_v: float, max_v: float, step: float, value: float, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 0)
	s.value_changed.connect(callback)
	h.add_child(s)
	var val := Label.new()
	val.text = "%.2f" % value
	s.value_changed.connect(func(v): val.text = "%.2f" % v)
	h.add_child(val)
	settings_content.add_child(h)


func _add_check(label: String, value: bool, callback: Callable) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.toggled.connect(callback)
	settings_content.add_child(c)


func _add_option(label: String, items: Array, selected: int, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var o := OptionButton.new()
	for item in items:
		o.add_item(str(item))
	o.selected = selected
	o.item_selected.connect(callback)
	h.add_child(o)
	settings_content.add_child(h)


func _add_text(label: String, value: String, callback: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.text_changed.connect(callback)
	h.add_child(e)
	settings_content.add_child(h)


func _build_mouse_settings() -> void:
	_section_title("МЫШЬ")
	_add_slider("Чувствительность", 0.1, 10.0, 0.01, settings.sensitivity, func(v): settings.sensitivity = v)
	_add_slider("Чувствительность при прицеле", 0.1, 10.0, 0.01, settings.zoom_sensitivity, func(v): settings.zoom_sensitivity = v)
	_add_option("Множитель чувствительности", [1, 2, 4], int(settings.sensitivity_multiplier) - 1, func(i): settings.sensitivity_multiplier = [1.0, 2.0, 4.0][i])
	_add_check("Сырой ввод (Raw Input)", settings.raw_input, func(v): settings.raw_input = v)
	_add_check("Ускорение мыши", settings.mouse_acceleration, func(v): settings.mouse_acceleration = v)
	_add_slider("Пользовательское ускорение", 0.0, 10.0, 0.1, settings.mouse_accel_custom, func(v): settings.mouse_accel_custom = v)
	_add_check("Точность указателя", settings.pointer_precision, func(v): settings.pointer_precision = v)
	_add_check("Инвертировать ось Y", settings.invert_mouse_y, func(v): settings.invert_mouse_y = v)
	_section_title("КЛАВИШИ")
	_add_text("Вперёд (W)", settings.bind_w, func(v): settings.bind_w = v)
	_add_text("Прыжок", settings.bind_jump, func(v): settings.bind_jump = v)
	_add_text("Огонь", settings.bind_fire, func(v): settings.bind_fire = v)
	_add_text("Перезарядка", settings.bind_reload, func(v): settings.bind_reload = v)
	_add_text("Осмотр оружия", settings.bind_inspect, func(v): settings.bind_inspect = v)
	_add_text("Дымовая граната", settings.bind_smoke, func(v): settings.bind_smoke = v)
	_add_text("Световая граната", settings.bind_flash, func(v): settings.bind_flash = v)


func _build_video_settings() -> void:
	_section_title("ВИДЕО")
	_add_option("Разрешение", ["1280x720", "1920x1080", "1600x900", "2560x1440"], 0, func(i): settings.resolution = ["1280x720", "1920x1080", "1600x900", "2560x1440"][i])
	_add_option("Соотношение сторон", ["16:9", "16:10", "4:3", "21:9"], 0, func(i): settings.aspect_ratio = ["16:9", "16:10", "4:3", "21:9"][i])
	_add_option("Режим отображения", ["Полноэкранный", "Оконный", "Без рамки"], settings.display_mode, func(i): settings.display_mode = i)
	_add_slider("Яркость", 0.0, 1.0, 0.01, settings.brightness, func(v): settings.brightness = v)
	_add_option("Качество теней", ["Низкое", "Среднее", "Высокое", "Очень высокое"], settings.shadow_quality, func(i): settings.shadow_quality = i)
	_add_option("Качество текстур", ["Низкое", "Среднее", "Высокое", "Очень высокое"], settings.texture_quality, func(i): settings.texture_quality = i)
	_add_option("Детализация эффектов", ["Низкое", "Среднее", "Высокое"], settings.effect_detail, func(i): settings.effect_detail = i)
	_add_option("Детализация шейдеров", ["Низкое", "Среднее", "Высокое"], settings.shader_detail, func(i): settings.shader_detail = i)
	_add_check("Увеличение контраста игроков", settings.boost_player_contrast, func(v): settings.boost_player_contrast = v)
	_add_check("Многоядерный рендеринг", settings.multicore_rendering, func(v): settings.multicore_rendering = v)
	_add_option("MSAA", [0, 2, 4, 8], 0, func(i): settings.msaa = [0, 2, 4, 8][i])
	_add_check("FXAA", settings.fxaa, func(v): settings.fxaa = v)
	_add_check("Вертикальная синхронизация", settings.vsync, func(v): settings.vsync = v)
	_add_slider("Ограничение FPS (0 = без)", 0.0, 360.0, 30.0, float(settings.fps_cap), func(v): settings.fps_cap = int(v))
	_add_check("Свечение", settings.glow, func(v): settings.glow = v)
	_add_check("Коррекция цвета", settings.color_correction, func(v): settings.color_correction = v)


func _build_audio_settings() -> void:
	_section_title("ЗВУК")
	_add_slider("Общая громкость", 0.0, 1.0, 0.01, settings.volume_master, func(v): settings.volume_master = v)
	_add_slider("Музыка", 0.0, 1.0, 0.01, settings.volume_music, func(v): settings.volume_music = v)
	_add_slider("Звуковые эффекты", 0.0, 1.0, 0.01, settings.volume_sfx, func(v): settings.volume_sfx = v)
	_add_slider("Голос", 0.0, 1.0, 0.01, settings.volume_voice, func(v): settings.volume_voice = v)
	_add_check("HRTF (объёмный звук для наушников)", settings.hrtf, func(v): settings.hrtf = v)
	_add_check("Объёмный звук", settings.surround, func(v): settings.surround = v)
	_add_slider("Громкость микрофона", 0.0, 1.0, 0.01, settings.mic_volume, func(v): settings.mic_volume = v)
	_add_text("Устройство вывода", settings.sound_device, func(v): settings.sound_device = v)


func _build_crosshair_settings() -> void:
	_section_title("ПРИЦЕЛ")
	_add_option("Стиль", ["Классический", "Динамический", "Классический динамический"], settings.crosshair_style, func(i): settings.crosshair_style = i)
	_add_option("Цвет", ["Зелёный", "Красный", "Жёлтый", "Синий", "Голубой", "Белый"], 0, func(i): settings.crosshair_color = ["green", "red", "yellow", "blue", "cyan", "white"][i])
	_add_slider("Размер", 0.0, 20.0, 0.5, settings.crosshair_size, func(v): settings.crosshair_size = v)
	_add_slider("Толщина", 0.0, 10.0, 0.5, settings.crosshair_thickness, func(v): settings.crosshair_thickness = v)
	_add_slider("Зазор", 0.0, 20.0, 0.5, settings.crosshair_gap, func(v): settings.crosshair_gap = v)
	_add_check("Контур", settings.crosshair_outline, func(v): settings.crosshair_outline = v)
	_add_slider("Толщина контура", 0.0, 5.0, 0.1, settings.crosshair_outline_thickness, func(v): settings.crosshair_outline_thickness = v)
	_add_check("Точка в центре", settings.crosshair_center_dot, func(v): settings.crosshair_center_dot = v)
	_add_slider("Прозрачность", 0.0, 1.0, 0.05, settings.crosshair_opacity, func(v): settings.crosshair_opacity = v)
	_add_check("Следование за отдачей", settings.crosshair_follow_recoil, func(v): settings.crosshair_follow_recoil = v)
	_add_check("T-образный прицел", settings.crosshair_t_style, func(v): settings.crosshair_t_style = v)


func _build_viewmodel_settings() -> void:
	_section_title("МОДЕЛЬ ОРУЖИЯ")
	_add_slider("Поле зрения модели", 50.0, 90.0, 1.0, settings.viewmodel_fov, func(v): settings.viewmodel_fov = v)
	_add_slider("Смещение X", -5.0, 5.0, 0.1, settings.viewmodel_offset_x, func(v): settings.viewmodel_offset_x = v)
	_add_slider("Смещение Y", -5.0, 5.0, 0.1, settings.viewmodel_offset_y, func(v): settings.viewmodel_offset_y = v)
	_add_slider("Смещение Z", -5.0, 5.0, 0.1, settings.viewmodel_offset_z, func(v): settings.viewmodel_offset_z = v)
	_add_slider("Покачивание", 0.0, 2.0, 0.05, settings.viewmodel_bob, func(v): settings.viewmodel_bob = v)
	_add_slider("Колебание", 0.0, 2.0, 0.05, settings.viewmodel_sway, func(v): settings.viewmodel_sway = v)
	_add_option("Рука", ["Левая", "Правая", "Обе"], settings.weapon_hand, func(i): settings.weapon_hand = i)
	_add_check("Рэгдолл физика", settings.ragdoll_physics, func(v): settings.ragdoll_physics = v)
	_add_check("Автоперезарядка", settings.auto_reload, func(v): settings.auto_reload = v)
	_section_title("HUD")
	_add_slider("Масштаб HUD", 0.5, 2.0, 0.05, settings.hud_scale, func(v): settings.hud_scale = v)
	_add_slider("Масштаб радара", 0.5, 2.0, 0.05, settings.radar_scale, func(v): settings.radar_scale = v)
	_add_check("Показывать FPS", settings.show_fps, func(v): settings.show_fps = v)
	_add_check("Показатель урона", settings.damage_numbers, func(v): settings.damage_numbers = v)


func _build_game_settings() -> void:
	_section_title("ИГРА")
	_add_text("Никнейм", settings.nickname, func(v): settings.nickname = v)
	_add_option("Язык", ["English", "Русский"], 0, func(i): settings.language = ["English", "Русский"][i])
	_add_option("Регион", ["Auto", "Europe", "Asia", "USA"], 0, func(i): settings.region = ["Auto", "Europe", "Asia", "USA"][i])
	_add_slider("Максимальный пинг", 20.0, 300.0, 10.0, float(settings.max_ping), func(v): settings.max_ping = int(v))
	_add_check("Группа Steam", settings.steam_group, func(v): settings.steam_group = v)


func _on_apply_settings() -> void:
	settings.save()
	nickname_label.text = settings.nickname + "  •  Lv. 12  •  Gold Nova II"
	_set_status("Настройки сохранены")


func _open_settings() -> void:
	settings_overlay.visible = true
	_rebuild_settings_content()


func _close_settings() -> void:
	settings_overlay.visible = false


# ==================== INVENTORY OVERLAY ====================

func _build_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	root.add_child(inventory_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	inventory_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_right = 540
	panel.offset_top = -330
	panel.offset_bottom = 330
	_style_panel(panel, Color(0.08, 0.10, 0.14, 1))
	inventory_overlay.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "ИНВЕНТАРЬ И СНАРЯЖЕНИЕ  (дефолтные модели)"
	t.add_theme_color_override("font_color", COLOR_ACCENT)
	t.add_theme_font_size_override("font_size", 16)
	head.add_child(t)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_make_button("Закрыть", func(): _close_inventory()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 7
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_grid)
	_build_inventory_grid()


func _build_inventory_grid() -> void:
	for c in inventory_grid.get_children():
		c.queue_free()
	var ids: Array = WeaponData.WEAPONS.keys()
	ids.sort()
	for id in ids:
		inventory_grid.add_child(_make_inventory_item(int(id)))


func _make_inventory_item(id: int) -> Control:
	var w: Dictionary = WeaponData.get_weapon(id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(128, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.20)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var icon := WeaponIcon.new()
	icon.weapon_id = id
	icon.custom_minimum_size = Vector2(110, 42)
	v.add_child(icon)
	var name_l := Label.new()
	name_l.text = String(w.get("name", ""))
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	v.add_child(name_l)
	var team_l := Label.new()
	var wt: int = int(w.get("team", 0))
	team_l.text = "T" if wt == WeaponData.Team.T else ("CT" if wt == WeaponData.Team.CT else "ALL")
	team_l.add_theme_font_size_override("font_size", 9)
	team_l.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4) if wt == WeaponData.Team.T else (Color(0.5, 0.7, 1) if wt == WeaponData.Team.CT else Color(0.7, 0.75, 0.8)))
	team_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(team_l)
	return p


func _open_inventory() -> void:
	inventory_overlay.visible = true


func _close_inventory() -> void:
	inventory_overlay.visible = false


func _on_exit() -> void:
	_set_status("Выход из лобби")
