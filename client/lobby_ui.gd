extends CanvasLayer
## Главное меню: точная компоновка по референсам CS2.
## Верх: иконки слева, вкладки ИНВЕНТАРЬ/СНАРЯЖЕНИЕ/ИГРАТЬ/МАГАЗИН/НОВОСТИ, друг справа.
## Экраны: Играть (3D агент), Настройки, Просмотр, Снаряжение, Инвентарь, Магазин, Новости, Подбор.

const GameSettings = preload("res://client/settings.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponIcon = preload("res://client/weapon_icon.gd")
const AgentData = preload("res://client/agents.gd")
const UiPattern = preload("res://client/ui_pattern.gd")

const REF_W: float = 1280.0
const REF_H: float = 720.0

const C_BG := Color(0.045, 0.06, 0.09, 1.0)
const C_BG2 := Color(0.07, 0.10, 0.16, 1.0)
const C_PANEL := Color(0.075, 0.095, 0.13, 0.96)
const C_PANEL2 := Color(0.11, 0.14, 0.19, 0.98)
const C_CYAN := Color(0.28, 0.72, 0.94)
const C_CYAN_DARK := Color(0.16, 0.42, 0.60)
const C_GREEN := Color(0.42, 0.68, 0.20)
const C_TEXT := Color(0.90, 0.92, 0.95)
const C_DIM := Color(0.55, 0.60, 0.68)
const C_LINE := Color(0.20, 0.25, 0.32)
const RARITY := [Color(0.62, 0.65, 0.70), Color(0.30, 0.58, 0.88),
	Color(0.68, 0.40, 0.88), Color(0.90, 0.35, 0.62), Color(0.92, 0.72, 0.25)]

var settings: GameSettings
var loadout: Loadout
var world = null
var agent_data: AgentData

var root: Control
var content_root: Control
var top_bar: PanelContainer
var nav_buttons: Dictionary = {}
var nav_highlight: ColorRect
var right_strip: PanelContainer
var status_label: Label

var play_panel: Control
var watch_panel: Control
var news_panel: Control
var store_panel: Control
var equipment_panel: Control
var play_modes_panel: Control
var settings_overlay: Control
var inventory_overlay: Control
var inventory_strip: Control

var settings_content: VBoxContainer
var settings_sub_tabs: Array = []
var inventory_grid: GridContainer
var inventory_category: String = "ВСЕ"
var watch_list: VBoxContainer = null
var watch_tab: String = "ВАШИ МАТЧИ"
var play_map_grid: GridContainer = null
var play_mode_tabs: Array = []
var agent_name_label: Label
var agent_role_label: Label
var team_tabs: Array = []
var bg_label: Label
var nickname_label: Label
var wallet_label: Label
var current_screen: String = "ИГРАТЬ"
var play_mode: String = "ОБЫЧНЫЙ"

const INVENTORY_CATEGORIES: Array = [
	"ВСЕ", "ЭКИПИРОВКА", "ГРАФИКА", "КОНТЕЙНЕРЫ", "ПРОФИЛЬ",
	"КОНТРАКТ ОБМЕНА", "ТОРГОВАЯ ПЛОЩАДКА",
]
const EQUIPMENT_CATEGORIES: Array = [
	"Weapons", "Knives / Gloves", "Agents", "Music Kits", "Graffiti",
	"Stickers", "Patches", "Pins / Pendants", "Cases", "Collectibles",
]
const MAP_GROUPS: Array = [
	{"name": "Cobblestone", "group": "Cobblestone", "wait": "01:30", "color": Color(0.35, 0.30, 0.45)},
	{"name": "Inferno", "group": "Альфа", "wait": "01:14", "color": Color(0.50, 0.18, 0.16)},
	{"name": "Nuke", "group": "Дельта", "wait": "01:36", "color": Color(0.25, 0.40, 0.55)},
	{"name": "Overpass", "group": "Сигма", "wait": "02:34", "color": Color(0.25, 0.45, 0.35)},
	{"name": "Vertigo", "group": "Заложники", "wait": "02:16", "color": Color(0.25, 0.35, 0.55)},
	{"name": "Mirage", "group": "Альфа", "wait": "04:34", "color": Color(0.55, 0.45, 0.30)},
	{"name": "Dust II", "group": "Альфа", "wait": "03:12", "color": Color(0.55, 0.48, 0.32)},
	{"name": "Ancient", "group": "Сигма", "wait": "05:17", "color": Color(0.20, 0.40, 0.30)},
]


func _ready() -> void:
	settings = GameSettings.new()
	settings.load_settings()
	loadout = Loadout.new(WeaponData.Team.T, 16000)
	world = get_parent().get_node_or_null("LobbyWorld")
	if world != null:
		agent_data = world.agent_data
	if agent_data == null:
		agent_data = AgentData.new()
	_build_shell()
	_build_play_screen()
	_build_watch_screen()
	_build_news_screen()
	_build_store_screen()
	_build_equipment_screen()
	_build_play_modes_screen()
	_build_settings_overlay()
	_build_inventory_overlay()
	_show_screen("ИГРАТЬ")
	_refresh_agent_info()
	_refresh_wallet()
	call_deferred("_fit_to_viewport")
	if get_viewport() != null:
		get_viewport().size_changed.connect(_fit_to_viewport)


# ---------- shell ----------

func _build_shell() -> void:
	root = Control.new()
	root.name = "LobbyUI"
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(REF_W, REF_H)
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.05, 0.35)
	root.add_child(bg)
	var pattern := UiPattern.new()
	pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	pattern.color = Color(0.55, 0.62, 0.70, 0.06)
	root.add_child(pattern)
	content_root = Control.new()
	content_root.name = "Content"
	content_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_root.offset_top = 44
	content_root.offset_bottom = 0
	root.add_child(content_root)
	_build_top_bar()
	_build_right_strip()
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_top = 50
	status_label.add_theme_color_override("font_color", C_CYAN)
	root.add_child(status_label)


func _fit_to_viewport() -> void:
	if get_viewport() != null:
		_fit_with(get_viewport().size)


func _fit_with(vp: Vector2) -> void:
	if root == null:
		return
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	root.size = Vector2(REF_W, REF_H)
	root.scale = Vector2(vp.x / REF_W, vp.y / REF_H)


func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 44
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.98)
	sb.border_color = C_LINE
	sb.set_border_width_all(0)
	sb.set_border_width(SIDE_BOTTOM, 1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	top_bar.add_theme_stylebox_override("panel", sb)
	root.add_child(top_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	top_bar.add_child(h)
	# слева: иконки без текста
	h.add_child(_icon_button("⌂", func(): _show_screen("ИГРАТЬ")))
	h.add_child(_icon_button("▣", func(): _show_screen("ИНВЕНТАРЬ")))
	h.add_child(_icon_button("⚙", func(): _show_screen("НАСТРОЙКИ")))
	h.add_child(_icon_button("⏻", func(): _set_status("Выход")))
	# центр: вкладки
	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(center)
	nav_highlight = ColorRect.new()
	nav_highlight.color = Color(0.20, 0.45, 0.62, 0.55)
	nav_highlight.set_anchors_preset(Control.PRESET_CENTER)
	nav_highlight.size = Vector2(150, 32)
	center.add_child(nav_highlight)
	var nav := HBoxContainer.new()
	nav.set_anchors_preset(Control.PRESET_CENTER)
	nav.add_theme_constant_override("separation", 14)
	center.add_child(nav)
	nav_buttons.clear()
	for tab in ["ИНВЕНТАРЬ", "СНАРЯЖЕНИЕ", "ИГРАТЬ", "МАГАЗИН", "НОВОСТИ"]:
		var captured: String = tab
		var b := _text_button(tab, func(): _show_screen(captured), 20)
		nav.add_child(b)
		nav_buttons[tab] = b
	# справа: пользователь
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	wallet_label = Label.new()
	wallet_label.add_theme_color_override("font_color", Color(0.55, 0.80, 0.45))
	right.add_child(wallet_label)
	nickname_label = Label.new()
	nickname_label.text = settings.nickname
	right.add_child(nickname_label)
	var person := _icon_button("♟", func(): _toggle_friends())
	right.add_child(person)
	var cnt := Label.new()
	cnt.text = "4"
	right.add_child(cnt)


func _build_right_strip() -> void:
	right_strip = PanelContainer.new()
	right_strip.name = "FriendsStrip"
	right_strip.anchor_left = 1.0
	right_strip.anchor_top = 0.0
	right_strip.anchor_right = 1.0
	right_strip.anchor_bottom = 0.0
	right_strip.offset_left = -56
	right_strip.offset_right = 0
	right_strip.offset_top = 44
	right_strip.offset_bottom = 720
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.96)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	right_strip.add_theme_stylebox_override("panel", sb)
	root.add_child(right_strip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	right_strip.add_child(v)
	var colors := [Color(0.35, 0.42, 0.50), Color(0.55, 0.45, 0.30),
		Color(0.45, 0.25, 0.55), Color(0.30, 0.40, 0.45)]
	var green := [true, false, false, false]
	for i in range(4):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(44, 44)
		var psb := StyleBoxFlat.new()
		psb.bg_color = colors[i]
		p.add_theme_stylebox_override("panel", psb)
		var inner := VBoxContainer.new()
		p.add_child(inner)
		var mark := ColorRect.new()
		mark.color = Color(0.3, 0.85, 0.3) if green[i] else Color(0.2, 0.22, 0.25)
		mark.custom_minimum_size = Vector2(44, 4)
		inner.add_child(mark)
		v.add_child(p)
	v.add_child(Control.new())
	var radio := _icon_button("◉", func(): _set_status("Голос: 20"))
	radio.custom_minimum_size = Vector2(44, 34)
	v.add_child(radio)
	var hist := _icon_button("↺", func(): _set_status("История: 47"))
	hist.custom_minimum_size = Vector2(44, 34)
	v.add_child(hist)
	var sliders := _icon_button("⚙", func(): _show_screen("НАСТРОЙКИ"))
	sliders.custom_minimum_size = Vector2(44, 34)
	v.add_child(sliders)


func _toggle_friends() -> void:
	_set_status("Друзья: 4 в сети")


# ---------- helpers ----------

func _mk_sb(bg: Color, border: Color = C_LINE, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _icon_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(34, 30)
	b.add_theme_stylebox_override("normal", _mk_sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _mk_sb(Color(0.2, 0.3, 0.4, 0.4), Color(0, 0, 0, 0)))
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", C_TEXT)
	b.pressed.connect(cb)
	return b


func _text_button(text: String, cb: Callable, font_size: int = 14, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _mk_sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _mk_sb(Color(0.15, 0.30, 0.42, 0.6), Color(0, 0, 0, 0)))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", C_CYAN if accent else C_TEXT)
	b.pressed.connect(cb)
	return b


func _green_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_stylebox_override("normal", _mk_sb(C_GREEN, Color(0.55, 0.75, 0.35), 2))
	b.add_theme_stylebox_override("hover", _mk_sb(C_GREEN.lightened(0.12), Color(0.6, 0.8, 0.4), 2))
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b


func _blue_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _mk_sb(Color(0.13, 0.33, 0.46), C_CYAN_DARK, 2))
	b.add_theme_stylebox_override("hover", _mk_sb(Color(0.18, 0.42, 0.58), C_CYAN, 2))
	b.add_theme_color_override("font_color", C_TEXT)
	b.pressed.connect(cb)
	return b


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _label(text: String, size: int = 14, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel(bg: Color = C_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _mk_sb(bg))
	return p


func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	content_root.add_child(c)
	return c


func _show_screen(name: String) -> void:
	current_screen = name
	for c in content_root.get_children():
		c.visible = false
	settings_overlay.visible = name == "НАСТРОЙКИ"
	inventory_overlay.visible = name == "ИНВЕНТАРЬ"
	if name == "НАСТРОЙКИ":
		_rebuild_settings_content()
	if name == "ИНВЕНТАРЬ":
		_rebuild_inventory(inventory_category)
	if name == "ИГРАТЬ":
		play_panel.visible = true
		play_modes_panel.visible = false
	elif name == "ПРОСМОТР":
		watch_panel.visible = true
	elif name == "СНАРЯЖЕНИЕ":
		equipment_panel.visible = true
	elif name == "МАГАЗИН":
		store_panel.visible = true
	elif name == "НОВОСТИ":
		news_panel.visible = true
	elif name == "ПОДБОР":
		play_panel.visible = false
		play_modes_panel.visible = true
		_build_map_grid()
	# подсветка вкладки (İграть остаётся активной для подэкранов)
	var tab_name: String = name if nav_buttons.has(name) else "ИГРАТЬ"
	for key in nav_buttons.keys():
		var b: Button = nav_buttons[key]
		b.add_theme_color_override("font_color", C_CYAN if key == tab_name else C_TEXT)
	var b2: Button = nav_buttons.get(tab_name, null)
	if b2 != null:
		var parent: Control = nav_highlight.get_parent() as Control
		var delta: Vector2 = b2.global_position - parent.global_position
		var target := Vector2(delta.x / root.scale.x, delta.y / root.scale.y)
		var tw := create_tween()
		tw.tween_property(nav_highlight, "position", target, 0.2)
		tw.parallel().tween_property(nav_highlight, "size", b2.size, 0.2)
	if settings_overlay.visible and name == "НАСТРОЙКИ":
		var gear: Button = top_bar.get_child(0).get_child(2)
		gear.add_theme_color_override("font_color", C_CYAN)


func _select_tab(tab: String) -> void:
	_show_screen(tab)


func _set_status(msg: String) -> void:
	status_label.text = msg


func _launch_game(msg: String) -> void:
	_set_status(msg)
	get_tree().change_scene_to_file("res://scenes/client.tscn")


func _refresh_wallet() -> void:
	if wallet_label != null:
		wallet_label.text = "$" + str(loadout.money)


func _refresh_agent_info() -> void:
	if world == null:
		return
	var a = world.current_agent()
	if a == null:
		return
	if agent_name_label != null:
		agent_name_label.text = a.name
	if agent_role_label != null:
		agent_role_label.text = a.role.to_upper() + "  •  " + ("Т" if a.team == WeaponData.Team.T else "CT")
	if bg_label != null:
		bg_label.text = world.background_name()


# ---------- экран ИГРАТЬ ----------

func _build_play_screen() -> void:
	play_panel = _screen()
	play_panel.name = "PlayScreen"
	# левая колонка промо-карточек
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 14
	left.offset_top = 14
	left.offset_right = 250
	left.offset_bottom = -110
	left.add_theme_constant_override("separation", 6)
	play_panel.add_child(left)
	left.add_child(_promo_card("МИССИЯ  •  осталось 4  через 3 дня",
		"«СОРЕВНОВАТЕЛЬНЫЙ», VERTIGO\nПОБЕД В РАНГАХ: 18",
		Color(0.10, 0.18, 0.36), Color(0.35, 0.55, 0.85), 120))
	left.add_child(_promo_card("Арсенальный пропуск",
		"Получите доступ к новым коллекциям\n«Арбалет», «Шлифовщик» и технологиям,\nкак у «Лиходейки» и не только.",
		Color(0.10, 0.30, 0.18), Color(0.25, 0.70, 0.35), 130))
	left.add_child(_promo_card("SINGAPORE 2026",
		"Открыть раздел мейджора\n800  ◉",
		Color(0.35, 0.14, 0.06), Color(0.85, 0.35, 0.12), 165))
	var arrows := HBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(arrows)
	arrows.add_child(_icon_button("◀", func(): _prev_background()))
	var dot := ColorRect.new()
	dot.color = C_TEXT
	dot.custom_minimum_size = Vector2(24, 4)
	arrows.add_child(dot)
	arrows.add_child(_icon_button("▶", func(): _next_background()))
	left.add_child(Control.new())
	var music := _promo_card("НОВОЕ И ПОПУЛЯРНОЕ   Показать все",
		"StatTrak™  НОВОЕ!\nНабор музыка | Voyage of Cozi Zuehlsdorff\n– Nevada\n218.84  ↘ 344.88",
		Color(0.16, 0.15, 0.16), Color(0.55, 0.45, 0.30), 108)
	left.add_child(music)
	# бейдж игрока по центру
	var badge := PanelContainer.new()
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.offset_top = 40
	badge.offset_left = -110
	badge.offset_right = 110
	badge.add_theme_stylebox_override("panel", _mk_sb(Color(0.05, 0.07, 0.10, 0.8)))
	play_panel.add_child(badge)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(bv)
	agent_name_label = _label("Agent", 16, C_TEXT)
	agent_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(agent_name_label)
	agent_role_label = _label("", 11, C_CYAN)
	agent_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(agent_role_label)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(icons)
	for col in [Color(0.30, 0.45, 0.65), Color(0.25, 0.40, 0.60), Color(0.65, 0.50, 0.20)]:
		var box := ColorRect.new()
		box.color = col
		box.custom_minimum_size = Vector2(28, 28)
		icons.add_child(box)
	# переключатель фона под сценой
	bg_label = _label("Dust II", 12, C_DIM)
	bg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg_label.offset_top = 96
	bg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_panel.add_child(bg_label)
	var bg_switch := HBoxContainer.new()
	bg_switch.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg_switch.offset_top = 118
	bg_switch.alignment = BoxContainer.ALIGNMENT_CENTER
	play_panel.add_child(bg_switch)
	bg_switch.add_child(_text_button("◀ фон", func(): _prev_background()))
	bg_switch.add_child(_text_button("фон ▶", func(): _next_background()))
	bg_switch.add_child(_blue_button("ПРОСМОТР МАТЧЕЙ", func(): _show_screen("ПРОСМОТР")))


func _promo_card(title: String, body: String, bg: Color, accent: Color, height: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(236, height)
	var sb := _mk_sb(bg, accent)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := _label(title, 12, Color(0.85, 0.90, 0.95))
	v.add_child(t)
	var strip := ColorRect.new()
	strip.color = accent
	strip.custom_minimum_size = Vector2(0, 2)
	v.add_child(strip)
	var b := _label(body, 11, Color(0.75, 0.80, 0.86))
	v.add_child(b)
	v.add_child(Control.new())
	var scrub := ColorRect.new()
	scrub.color = Color(0.85, 0.85, 0.85, 0.5)
	scrub.custom_minimum_size = Vector2(0, 3)
	v.add_child(scrub)
	return p


func _prev_background() -> void:
	if world != null:
		world.prev_background()
	if bg_label != null:
		bg_label.text = world.background_name()


func _next_background() -> void:
	if world != null:
		world.next_background()
	if bg_label != null:
		bg_label.text = world.background_name()


# ---------- ПРОСМОТР ----------

func _build_watch_screen() -> void:
	watch_panel = _screen()
	watch_panel.name = "WatchScreen"
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	watch_panel.add_child(top)
	for t in ["ВАШИ МАТЧИ", "СКАЧАННЫЕ МАТЧИ", "МЕЙДЖОРЫ"]:
		var captured: String = t
		top.add_child(_blue_button(t, func(): _select_watch_tab(captured)))
	watch_panel.add_child(_icon_button("↻", func(): _rebuild_watch_list()))
	# левый список матчей
	var list_panel := PanelContainer.new()
	list_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	list_panel.offset_left = 0
	list_panel.offset_top = 50
	list_panel.offset_right = 330
	list_panel.offset_bottom = -10
	list_panel.add_theme_stylebox_override("panel", _mk_sb(Color(0.05, 0.07, 0.10, 0.85)))
	watch_panel.add_child(list_panel)
	watch_list = VBoxContainer.new()
	watch_list.add_theme_constant_override("separation", 2)
	list_panel.add_child(watch_list)
	_rebuild_watch_list()
	# детали матча
	var detail := PanelContainer.new()
	detail.set_anchors_preset(Control.PRESET_CENTER)
	detail.offset_left = 350
	detail.offset_right = -80
	detail.offset_top = 70
	detail.offset_bottom = -90
	detail.add_theme_stylebox_override("panel", _mk_sb(Color(0.05, 0.06, 0.09, 0.90)))
	watch_panel.add_child(detail)
	var dv := VBoxContainer.new()
	detail.add_child(dv)
	dv.add_child(_label("ИНФЕРНО  •  9 - 4  •  ПОБЕДА", 20, C_TEXT))
	dv.add_child(_label("Карта: Inferno     Длительность: 9 минут     Дата: Четверг, 11:46", 12, C_DIM))
	dv.add_child(_label("КЛУБЫ", 12, C_CYAN))
	var tbl := HBoxContainer.new()
	dv.add_child(tbl)
	tbl.add_child(_label("⭐ 4  s1mple / S6H608k [9]          9   0   9   21", 13))
	dv.add_child(_label("ТЕРРОРИСТЫ", 12, Color(0.85, 0.65, 0.25)))
	dv.add_child(_label("⭐ 9  POSSESSED / LeGasY          12   0   5   24", 13))
	# нижние кнопки
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.offset_bottom = -10
	bottom.offset_right = -80
	watch_panel.add_child(bottom)
	bottom.add_child(_green_button("СКАЧАТЬ", func(): _download_match("Матч", null)))
	bottom.add_child(_icon_button("⤴", func(): _set_status("Поделиться")))
	bottom.add_child(_icon_button("🗑", func(): _set_status("Удалить")))


func _select_watch_tab(tab: String) -> void:
	watch_tab = tab
	_rebuild_watch_list()


func _rebuild_watch_list() -> void:
	if watch_list == null:
		return
	_clear(watch_list)
	var matches := [
		["Inferno", "9 - 4", "Четверг, 11:46", true],
		["Inferno", "6 - 9", "Четверг, 11:32", false],
		["Dust II", "16 - 13", "Среда, 16:19", true],
		["Mirage", "13 - 7", "Среда, 15:35", true],
		["Inferno", "3 - 9", "Среда, 15:23", false],
		["Inferno", "9 - 5", "Среда, 15:10", true],
		["Dust II", "13 - 2", "Вторник, 13:01", true],
	]
	for m in matches:
		var row := PanelContainer.new()
		var col := Color(0.10, 0.28, 0.12) if m[3] else Color(0.32, 0.10, 0.10)
		row.add_theme_stylebox_override("panel", _mk_sb(col, Color(0.25, 0.3, 0.35)))
		var h := HBoxContainer.new()
		row.add_child(h)
		var icon := ColorRect.new()
		icon.color = Color(0.55, 0.30, 0.20) if m[0] == "Inferno" else Color(0.45, 0.45, 0.35)
		icon.custom_minimum_size = Vector2(48, 48)
		h.add_child(icon)
		var v := VBoxContainer.new()
		h.add_child(v)
		v.add_child(_label(String(m[0]), 12, C_TEXT))
		v.add_child(_label(String(m[1]) + "   " + String(m[2]), 11, C_DIM))
		watch_list.add_child(row)


func _download_match(name: String, btn) -> void:
	_set_status("Матч загружен: " + name)


# ---------- НОВОСТИ ----------

func _build_news_screen() -> void:
	news_panel = _screen()
	news_panel.name = "NewsScreen"
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	news_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	var articles := [
		["2026-11-18", "Мощёная дорога в Сингапур", "Сегодняшнее обновление знаменует возвращение легендарной карты — Cobblestone! Ветераны Cobblestone будут чувствовать себя как дома в знакомых местах вроде спуска, курятник..."],
		["2026-09-23", "Штурмовое предупреждение", "Пришла пора бросать в штурм прорыв — представляем вам «штурм», новый скоростной режим игры 3 на 3. Шаг за шагом пробивайтесь через череду арен, выбранных случайным образом..."],
		["2026-07-29", "Кёльн-2026: итоговые наклейки", "Сегодня мы выпускаем серию наклеек с логотипами кёльнского мейджора, в дизайне которых угадывается финальное место команды в турнире..."],
	]
	for i in range(articles.size()):
		var a: Array = articles[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _mk_sb(Color(0.05, 0.08, 0.12, 0.9)))
		var h := HBoxContainer.new()
		row.add_child(h)
		var img := ColorRect.new()
		img.color = [Color(0.45, 0.32, 0.22), Color(0.30, 0.35, 0.42), Color(0.55, 0.45, 0.20)][i]
		img.custom_minimum_size = Vector2(420, 240 if i == 0 else 160)
		h.add_child(img)
		var txt := VBoxContainer.new()
		h.add_child(txt)
		txt.add_child(_label(String(a[0]), 11, C_DIM))
		txt.add_child(_label(String(a[1]), 20 if i == 0 else 16, C_TEXT))
		txt.add_child(_label(String(a[2]), 11, C_DIM))
		v.add_child(row)


# ---------- МАГАЗИН ----------

func _build_store_screen() -> void:
	store_panel = _screen()
	store_panel.name = "StoreScreen"
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	store_panel.add_child(top)
	for t in ["ГЛАВНАЯ", "ОБЩЕЕ", "СИНГАПУР-2026", "ТОРГОВАЯ ПЛОЩАДКА", "ИНСТРУМЕНТЫ", "АРСЕНАЛ"]:
		top.add_child(_blue_button(t, func(): _set_status(t)))
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 60
	banner.offset_left = 60
	banner.offset_right = -60
	banner.offset_bottom = 260
	var sb := _mk_sb(Color(0.32, 0.18, 0.06), Color(0.55, 0.35, 0.10))
	banner.add_theme_stylebox_override("panel", sb)
	store_panel.add_child(banner)
	var bh := HBoxContainer.new()
	banner.add_child(bh)
	for i in range(4):
		var card := ColorRect.new()
		card.color = Color(0.18, 0.18, 0.20) if i < 2 else Color(0.12, 0.10, 0.07)
		card.custom_minimum_size = Vector2(180, 150)
		bh.add_child(card)
	var info := VBoxContainer.new()
	bh.add_child(info)
	info.add_child(_label("ЕЖЕНЕДЕЛЬНЫЙ НАБОР", 22, C_TEXT))
	info.add_child(_label("ЕЖЕНЕДЕЛЬНЫЕ НАГРАДЫ ПОЛУЧЕНЫ", 12, Color(0.95, 0.70, 0.25)))
	info.add_child(_label("Прогресс до следующего набора начнёт\nзасчитываться через 3 дня", 11, C_DIM))
	var music := PanelContainer.new()
	music.set_anchors_preset(Control.PRESET_CENTER)
	music.offset_top = 280
	music.offset_left = 60
	music.offset_right = -60
	music.offset_bottom = 460
	music.add_theme_stylebox_override("panel", _mk_sb(C_PANEL))
	store_panel.add_child(music)
	var mv := VBoxContainer.new()
	music.add_child(mv)
	mv.add_child(_label("Наборы музыки Monstercat", 18, C_TEXT))
	var cards := HBoxContainer.new()
	mv.add_child(cards)
	for i in range(6):
		var c := ColorRect.new()
		c.color = Color(0.20 + float(i) * 0.02, 0.18, 0.22)
		c.custom_minimum_size = Vector2(170, 110)
		cards.add_child(c)


# ---------- СНАРЯЖЕНИЕ ----------

func _build_equipment_screen() -> void:
	equipment_panel = _screen()
	equipment_panel.name = "EquipmentScreen"
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 430
	top.add_theme_stylebox_override("panel", _mk_sb(Color(0.06, 0.14, 0.24, 0.96)))
	equipment_panel.add_child(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	top.add_child(h)
	# левыйrail категорий
	var left_rail := VBoxContainer.new()
	left_rail.custom_minimum_size = Vector2(66, 0)
	h.add_child(left_rail)
	for i in range(8):
		var c := ColorRect.new()
		c.color = Color(0.20 + i * 0.02, 0.26, 0.34)
		c.custom_minimum_size = Vector2(54, 40)
		left_rail.add_child(c)
	# CT агент
	var ct := PanelContainer.new()
	ct.custom_minimum_size = Vector2(220, 0)
	ct.add_theme_stylebox_override("panel", _mk_sb(Color(0.10, 0.20, 0.32), Color(0, 0, 0, 0)))
	h.add_child(ct)
	var ctv := VBoxContainer.new()
	ct.add_child(ctv)
	var ct_tag := _blue_button("СПЕЦНАЗ", func(): _set_status("СПЕЦНАЗ"))
	ctv.add_child(ct_tag)
	var ct_model := ColorRect.new()
	ct_model.color = Color(0.28, 0.34, 0.26)
	ct_model.custom_minimum_size = Vector2(180, 250)
	ctv.add_child(ct_model)
	# сетка оружия 3 колонки
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	h.add_child(grid)
	var groups := ["СТАРТОВЫЙ ПИСТОЛЕТ", "ПРОМЕЖУТОЧНОЕ", "ВИНТОВКИ",
		"ДРУГИЕ ПИСТОЛЕТЫ", "ПП", "СНАЙПЕРКИ", "ДРОБОВИКИ", "ПУЛЕМЁТЫ", "ГРАНАТЫ"]
	for gi in range(groups.size()):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(150, 108)
		cell.add_theme_stylebox_override("panel", _mk_sb(Color(0.09, 0.20, 0.32)))
		var cv := VBoxContainer.new()
		cell.add_child(cv)
		cv.add_child(_label(groups[gi], 10, C_CYAN))
		var icon := WeaponIcon.new()
		icon.weapon_id = [2, 10, 19, 8, 12, 25, 28, 33, 36][gi]
		icon.custom_minimum_size = Vector2(130, 60)
		cv.add_child(icon)
		var line := ColorRect.new()
		line.color = RARITY[gi % RARITY.size()]
		line.custom_minimum_size = Vector2(0, 2)
		cv.add_child(line)
		grid.add_child(cell)
	# T агент + правыйrail
	var t := PanelContainer.new()
	t.custom_minimum_size = Vector2(200, 0)
	t.add_theme_stylebox_override("panel", _mk_sb(Color(0.12, 0.10, 0.08), Color(0, 0, 0, 0)))
	h.add_child(t)
	var tv := VBoxContainer.new()
	t.add_child(tv)
	var t_tag := _text_button("ТЕРРОРИСТЫ", func(): _set_status("ТЕРРОРИСТЫ"), 13)
	t_tag.add_theme_color_override("font_color", Color(0.85, 0.65, 0.25))
	tv.add_child(t_tag)
	var t_model := ColorRect.new()
	t_model.color = Color(0.42, 0.36, 0.30)
	t_model.custom_minimum_size = Vector2(160, 250)
	tv.add_child(t_model)
	var right_rail := VBoxContainer.new()
	right_rail.custom_minimum_size = Vector2(66, 0)
	h.add_child(right_rail)
	for i in range(8):
		var c := ColorRect.new()
		c.color = Color(0.24, 0.20, 0.16)
		c.custom_minimum_size = Vector2(54, 40)
		right_rail.add_child(c)
	# фильтры + нижняя сетка
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 438
	bar.offset_bottom = 492
	bar.add_theme_stylebox_override("panel", _mk_sb(C_PANEL2))
	equipment_panel.add_child(bar)
	var bh := HBoxContainer.new()
	bar.add_child(bh)
	var all := OptionButton.new()
	all.add_item("Все предметы")
	bh.add_child(all)
	bh.add_child(Control.new())
	var sort := OptionButton.new()
	sort.add_item("По новизне")
	bh.add_child(sort)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_grid.offset_top = 500
	inventory_grid.offset_left = 12
	inventory_grid.offset_right = -12
	inventory_grid.offset_bottom = -6
	equipment_panel.add_child(inventory_grid)
	_rebuild_equipment_grid()


func _rebuild_equipment_grid() -> void:
	_clear(inventory_grid)
	var ids: Array = WeaponData.WEAPONS.keys()
	ids.sort()
	for id in ids:
		inventory_grid.add_child(_make_inventory_item(int(id)))


func _make_inventory_item(id: int) -> Control:
	var w: Dictionary = WeaponData.get_weapon(id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(150, 96)
	p.add_theme_stylebox_override("panel", _mk_sb(Color(0.13, 0.14, 0.17)))
	var v := VBoxContainer.new()
	p.add_child(v)
	var icon := WeaponIcon.new()
	icon.weapon_id = id
	icon.custom_minimum_size = Vector2(130, 50)
	v.add_child(icon)
	v.add_child(_label(String(w.get("name", "")), 10, C_TEXT))
	var team: int = int(w.get("team", 0))
	v.add_child(_label("T" if team == WeaponData.Team.T else ("CT" if team == WeaponData.Team.CT else "ALL"), 9, C_DIM))
	var line := ColorRect.new()
	line.color = RARITY[abs(id) % RARITY.size()]
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	return p


# ---------- ПОДБОР МАТЧА ----------

func _build_play_modes_screen() -> void:
	play_modes_panel = _screen()
	play_modes_panel.name = "PlayModesScreen"
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_top = 10
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	play_modes_panel.add_child(tabs)
	for t in ["ПОДБОР МАТЧА", "ТРЕНИРОВКА", "КАРТЫ ИЗ МАСТЕРСКОЙ"]:
		var captured: String = t
		tabs.add_child(_blue_button(t, func(): _set_status(captured)))
	tabs.add_child(_icon_button("🌐", func(): _set_status("Серверы")))
	var modes := HBoxContainer.new()
	modes.set_anchors_preset(Control.PRESET_TOP_WIDE)
	modes.offset_top = 48
	modes.offset_bottom = 86
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	play_modes_panel.add_child(modes)
	play_mode_tabs.clear()
	for m in ["ПРЕМЬЕР-РЕЖИМ", "СОРЕВНОВАТЕЛЬНЫЙ", "НАПАРНИКИ", "ШТУРМ", "ОБЫЧНЫЙ",
			"БОЙ НАСМЕРТЬ", "ГОНКА ВООРУЖЕНИЙ", "ЗАЧИСТКА", "ЗАКРЫТЫЙ ПОДБОР МАТЧА"]:
		var captured: String = m
		var b := _blue_button(m, func(): _set_play_mode(captured))
		modes.add_child(b)
		play_mode_tabs.append(b)
	# левая панель статуса
	var left := PanelContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 0
	left.offset_top = 96
	left.offset_right = 240
	left.offset_bottom = -80
	left.add_theme_stylebox_override("panel", _mk_sb(Color(0.06, 0.09, 0.13, 0.9)))
	play_modes_panel.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(_label("★  ПРАЙМ-СТАТУС\n     ВКЛЮЧЕН", 13, Color(0.85, 0.75, 0.35)))
	lv.add_child(_label("Опции", 11, C_DIM))
	var tog := CheckButton.new()
	tog.text = "Открытая группа"
	tog.button_pressed = true
	lv.add_child(tog)
	# сетка карт
	play_map_grid = GridContainer.new()
	play_map_grid.columns = 4
	play_map_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_map_grid.offset_left = 250
	play_map_grid.offset_right = -20
	play_map_grid.offset_top = 96
	play_map_grid.offset_bottom = 84
	play_map_grid.add_theme_constant_override("h_separation", 8)
	play_map_grid.add_theme_constant_override("v_separation", 8)
	play_modes_panel.add_child(play_map_grid)
	_build_map_grid()
	# нижняя панель
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -72
	bottom.add_theme_stylebox_override("panel", _mk_sb(Color(0.05, 0.07, 0.10, 0.95)))
	play_modes_panel.add_child(bottom)
	var bh := HBoxContainer.new()
	bottom.add_child(bh)
	var mission := ColorRect.new()
	mission.color = Color(0.14, 0.22, 0.38)
	mission.custom_minimum_size = Vector2(260, 52)
	bh.add_child(mission)
	var ml := _label("«СОРЕВНОВАТЕЛЬНЫЙ», VERTIGO\nВыгрывайте раунды", 11, C_TEXT)
	mission.add_child(ml)
	bh.add_child(Control.new())
	bh.add_child(_green_button("НАЧАТЬ", func(): _launch_game("Матч запущен...")))


func map_grid_ready() -> bool:
	return play_map_grid != null and play_map_grid.get_child_count() > 0


func _set_play_mode(mode: String) -> void:
	play_mode = mode
	_build_map_grid()


func _build_map_grid() -> void:
	if play_map_grid == null:
		return
	_clear(play_map_grid)
	for b in play_mode_tabs:
		b.add_theme_color_override("font_color", C_CYAN if b.text == play_mode else C_TEXT)
	if play_mode == "ПРЕМЬЕР-РЕЖИМ":
		_build_premier_view()
		return
	var maps: Array = MAP_GROUPS if play_mode != "БОЙ НАСМЕРТЬ" else MAP_GROUPS
	for i in range(maps.size()):
		var m: Dictionary = maps[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 230)
		var sb := _mk_sb(m.color, Color(0.35, 0.4, 0.45))
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		card.add_child(v)
		var check := CheckButton.new()
		check.button_pressed = i < 2
		v.add_child(check)
		var badge := ColorRect.new()
		badge.color = m.color.lightened(0.15)
		badge.custom_minimum_size = Vector2(0, 70)
		v.add_child(badge)
		v.add_child(_label(String(m.group), 16, C_TEXT))
		v.add_child(_label("◷ Время ожидания " + String(m.wait), 10, C_DIM))
		play_map_grid.add_child(card)


func _build_premier_view() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 460)
	panel.add_theme_stylebox_override("panel", _mk_sb(C_PANEL2))
	play_map_grid.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(_label("// ВАША ГРУППА", 16, C_CYAN))
	v.add_child(_label("Место   Рейтинг CS   Игрок   Победы   Точность   Вклад", 11, C_DIM))
	v.add_child(_label("1 875 069     10,231   LeGasY      34      59.55%      57%", 12, C_TEXT))
	v.add_child(_label("// ПРОГРЕСС СЕЗОНА", 16, C_CYAN))
	v.add_child(_label("10,231  •  Самый высокий рейтинг CS за этот сезон   34/50", 11, C_TEXT))
	var bar := ColorRect.new()
	bar.color = C_CYAN
	bar.custom_minimum_size = Vector2(0, 6)
	v.add_child(bar)
	v.add_child(_label("// ЛИДЕРЫ", 16, C_CYAN))
	v.add_child(_label("424 270   19,522   Kona       19   55.88%   13%", 11, C_TEXT))
	v.add_child(_label("1 875 069  10,231   LeGasY     34   59.55%   57%", 11, C_CYAN))
	v.add_child(_label("// ПОСЛЕДНИЕ ПОБЕДЫ  •  радар карт", 16, C_CYAN))


# ---------- НАСТРОЙКИ (два уровня вкладок, строки с value справа) ----------

const SETTINGS_TABS: Array = ["ИЗОБРАЖЕНИЕ", "ЗВУК", "ИГРА", "КЛАВИАТУРА И МЫШЬ", "ПРИЦЕЛ"]
var settings_tab_index: int = 0


func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.08, 0.13, 0.98)
	settings_overlay.add_child(bg)
	var pattern := UiPattern.new()
	pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	pattern.color = Color(0.5, 0.6, 0.7, 0.04)
	settings_overlay.add_child(pattern)
	# первый уровень вкладок
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_top = 18
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_overlay.add_child(tabs)
	tabs.add_child(_icon_button("⌕", func(): _set_status("Поиск настроек")))
	settings_sub_tabs.clear()
	for i in range(SETTINGS_TABS.size()):
		var idx: int = i
		var b := _blue_button(SETTINGS_TABS[i], func(): _select_settings_tab(idx))
		tabs.add_child(b)
		settings_sub_tabs.append(b)
	# второй уровень
	var sub := HBoxContainer.new()
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 58
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_overlay.add_child(sub)
	for s in ["ГРАФИКА", "РАСШИРЕННЫЕ НАСТРОЙКИ", "ПОЗИЦИЯ КРАЁВ"]:
		sub.add_child(_blue_button(s, func(): _set_status(s)))
	# контент
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = 60
	scroll.offset_left = 230
	scroll.offset_right = -230
	settings_overlay.add_child(scroll)
	settings_content = VBoxContainer.new()
	settings_content.add_theme_constant_override("separation", 10)
	scroll.add_child(settings_content)
	# нижняя панель
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -58
	bottom.add_theme_stylebox_override("panel", _mk_sb(Color(0.03, 0.05, 0.08, 0.98)))
	settings_overlay.add_child(bottom)
	var bh := HBoxContainer.new()
	bottom.add_child(bh)
	bh.add_child(_text_button("↺  СБРОСИТЬ", func(): _on_apply_settings()))
	bh.add_child(Control.new())
	bh.add_child(_text_button("ОТМЕНИТЬ ИЗМЕНЕНИЯ", func(): _close_settings(), 12))
	var apply_btn := _text_button("ПРИМЕНИТЬ ИЗМЕНЕНИЯ", func(): _on_apply_settings(), 12)
	apply_btn.add_theme_color_override("font_color", C_CYAN)
	bh.add_child(apply_btn)


func _select_settings_tab(index: int) -> void:
	settings_tab_index = index
	for i in range(settings_sub_tabs.size()):
		var b: Button = settings_sub_tabs[i]
		b.add_theme_color_override("font_color", C_CYAN if i == index else C_TEXT)
	_rebuild_settings_content()


func _setting_row(label: String, value: String, is_slider: bool = false, percent: float = 0.5) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _mk_sb(Color(0, 0, 0, 0)))
	settings_content.add_child(row)
	var h := HBoxContainer.new()
	row.add_child(h)
	h.add_child(_label(label, 14, C_TEXT))
	h.add_child(Control.new())
	if is_slider:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.value = percent
		s.custom_minimum_size = Vector2(220, 20)
		h.add_child(s)
		h.add_child(_label(str(int(percent * 100.0)) + "%", 13, C_TEXT))
	else:
		var o := OptionButton.new()
		o.add_item(value)
		o.custom_minimum_size = Vector2(280, 28)
		h.add_child(o)
	var line := ColorRect.new()
	line.color = C_LINE
	line.custom_minimum_size = Vector2(0, 1)
	settings_content.add_child(line)


func _rebuild_settings_content() -> void:
	_clear(settings_content)
	match settings_tab_index:
		0: _build_image_settings()
		1: _build_sound_settings()
		2: _build_gameplay_settings()
		3: _build_input_settings()
		4: _build_crosshair_settings()


func _build_image_settings() -> void:
	settings_content.add_child(_label("Графика", 22, Color(0.75, 0.80, 0.85)))
	settings_content.add_child(_label("Экран", 12, C_CYAN))
	_setting_row("Экран", "МОНИТОР 1 – G270Q20")
	_setting_row("Режим отображения", "ПОЛНОЗКРАННЫЙ В ОКНЕ")
	_setting_row("Формат экрана", "ОБЫЧНЫЙ, 4:3")
	_setting_row("Разрешение", "1280X960")
	_setting_row("Частота обновления", "200 Hz")
	_setting_row("Яркость", "", true, 0.93)
	settings_content.add_child(_label("Отрегулировать общую яркость с помощью\nизменения гаммы коррекции внутреннего рендеринга.", 10, C_DIM))


func _build_sound_settings() -> void:
	settings_content.add_child(_label("Звук", 22, C_TEXT))
	_setting_row("Общая громкость", "93%")
	_setting_row("Устройство вывода", "Dynamic Range")
	_setting_row("EQ-профиль", "По умолчанию")
	_setting_row("Музыка", "50%")
	_setting_row("Звуковые эффекты", "100%")
	_setting_row("HRTF", "Включено")
	_setting_row("Голосовой чат", "Включено")


func _build_gameplay_settings() -> void:
	settings_content.add_child(_label("Игра", 22, C_TEXT))
	_setting_row("HUD", "Масштаб 1.0")
	_setting_row("Команда", "Показывать")
	_setting_row("Коммуникация", "Пинги включены")
	_setting_row("Spectator / Scoreboard", "По умолчанию")
	_setting_row("Radar / Tablet", "Вращение выкл.")
	_setting_row("Item (viewmodel)", "FOV 68")
	_setting_row("Трейсеры", "Включены")
	_setting_row("Авто-зум снайперки", "Выключен")


func _build_input_settings() -> void:
	settings_content.add_child(_label("Клавиатура и мышь", 22, C_TEXT))
	_setting_row("Чувствительность мыши", "1.00")
	_setting_row("Raw Input", "Включено")
	_setting_row("Reverse Mouse", "Выключено")
	_setting_row("Duck Mode", "Hold")
	_setting_row("Walk Mode", "Hold")
	_setting_row("Zoom Button", "Hold")
	_setting_row("Вперёд", "W")
	_setting_row("Присесть", "Ctrl")
	_setting_row("Прыжок", "Space")
	_setting_row("Огонь", "Mouse1")
	_setting_row("Перезарядка", "R")
	_setting_row("Осмотр оружия", "F")


func _build_crosshair_settings() -> void:
	settings_content.add_child(_label("Прицел", 22, C_TEXT))
	_setting_row("Стиль", "Классический")
	_setting_row("Размер", "2.0")
	_setting_row("Толщина", "2.0")
	_setting_row("Зазор", "3.0")
	_setting_row("Цвет", "Зелёный")
	_setting_row("Контур", "Включён")
	_setting_row("Точка в центре", "Выключена")
	_setting_row("Show Player Crosshairs To Everyone", "Выключено")


func _on_apply_settings() -> void:
	settings.save()
	if nickname_label != null:
		nickname_label.text = settings.nickname
	_set_status("Настройки сохранены")


func _open_settings() -> void:
	_show_screen("НАСТРОЙКИ")


func _close_settings() -> void:
	_show_screen("ИГРАТЬ")


# ---------- ИНВЕНТАРЬ ----------

func _build_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	root.add_child(inventory_overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.07, 0.11, 0.98)
	inventory_overlay.add_child(bg)
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.offset_top = 18
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory_overlay.add_child(tabs)
	tabs.add_child(_icon_button("⌕", func(): _set_status("Поиск")))
	for cat in INVENTORY_CATEGORIES:
		var captured: String = cat
		tabs.add_child(_blue_button(cat, func(): _set_inventory_category(captured)))
	var sort := OptionButton.new()
	sort.add_item("По новизне")
	sort.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sort.offset_top = 62
	sort.offset_right = -30
	inventory_overlay.add_child(sort)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 105
	inventory_overlay.add_child(scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 7
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(inventory_grid)
	_rebuild_inventory("ВСЕ")


func _set_inventory_category(cat: String) -> void:
	inventory_category = cat
	_rebuild_inventory(cat)


func _rebuild_inventory(cat: String) -> void:
	if inventory_grid == null:
		return
	_clear(inventory_grid)
	var ids: Array = WeaponData.WEAPONS.keys()
	ids.sort()
	for id in ids:
		inventory_grid.add_child(_make_inventory_item(int(id)))


func _open_inventory() -> void:
	_show_screen("ИНВЕНТАРЬ")


func _close_inventory() -> void:
	_show_screen("ИГРАТЬ")
