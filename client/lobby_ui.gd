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
const UiTheme = preload("res://client/ui_theme.gd")
const FriendsStore = preload("res://client/friends.gd")
const UiIcon = preload("res://client/ui_icon.gd")

const REF_W: float = 1280.0
const REF_H: float = 720.0

const C_BG := UiTheme.BG
const C_BG2 := UiTheme.BG_2
const C_PANEL := UiTheme.SURFACE
const C_PANEL2 := UiTheme.SURFACE_2
const C_CYAN := UiTheme.ACCENT
const C_CYAN_DARK := UiTheme.ACCENT_DARK
const C_GREEN := UiTheme.OK
const C_TEXT := UiTheme.TEXT
const C_DIM := UiTheme.TEXT_MUTED
const C_LINE := UiTheme.LINE
const C_FAINT := UiTheme.TEXT_FAINT
const C_LINE_STRONG := UiTheme.LINE_STRONG
const C_WARN := UiTheme.WARN
const C_DANGER := UiTheme.DANGER
const ICON_NAMES: Dictionary = {
	"⌂": "home", "▣": "inventory", "⚙": "settings", "⏻": "power",
	"♟": "friends", "◉": "mic", "↺": "history", "+": "add", "✕": "close",
	"◀": "prev", "▶": "next", "←": "back", "↻": "refresh", "⤴": "share",
	"🗑": "delete", "🌐": "server", "⌕": "search",
}
const RARITY := [Color(0.62, 0.65, 0.70), Color(0.30, 0.58, 0.88),
	Color(0.68, 0.40, 0.88), Color(0.90, 0.35, 0.62), Color(0.92, 0.72, 0.25)]

var settings: GameSettings
var loadout: Loadout
var friends: FriendsStore
var world = null
var agent_data: AgentData

var root: Control
var content_root: Control
var top_bar: PanelContainer
var nav_buttons: Dictionary = {}
var nav_highlight: ColorRect
var right_strip: PanelContainer
var friends_strip: VBoxContainer
var friends_count_label: Label
var friends_overlay: Control
var friends_list: VBoxContainer
var friends_input: LineEdit
var friends_empty: bool = true
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
var inventory_sort: int = 0
var inventory_tabs: Dictionary = {}
var inventory_close: Button
var inventory_loadout: Button
var inventory_sort_btn: OptionButton
var equipment_scroll: ScrollContainer
var equipment_grid: GridContainer
var equipment_team: int = -1
var equipment_sort: int = 0
var equipment_filter: int = 0
var equipment_ct_button: Button
var equipment_t_button: Button
var equipment_filter_btn: OptionButton
var equipment_sort_btn: OptionButton
var watch_list: VBoxContainer = null
var watch_refresh: Button
var watch_empty: bool = true
var watch_detail_title: Label
var watch_detail_sub: Label
var watch_actions: HBoxContainer
var watch_tab: String = "ВАШИ МАТЧИ"
var watch_tabs: Dictionary = {}
var play_map_grid: GridContainer = null
var selected_map_id: String = "oasis"
var play_mode_tabs: Array = []
var play_start_button: Button
var play_modes_back: Button
var play_source_tabs: Array = []
var play_source: String = "ПОДБОР МАТЧА"
var play_modes_row: HBoxContainer
var play_mission_label: Label
var store_tabs: Array = []
var store_tab: String = "ГЛАВНАЯ"
var store_title: Label
var store_subtitle: Label
var store_desc: Label
var store_cards: HBoxContainer
var store_banner_cards: Array = []
var bg_switch: HBoxContainer
var settings_return_screen: String = "ИГРАТЬ"
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
# Только реально существующие карты (см. assets/maps/*.vmap).
# Декоративные названия вроде Dust II/Mirage убраны, чтобы не обещать
# контент, которого в сборке нет.
const MAP_GROUPS: Array = [
	{"name": "Oasis", "file": "oasis.vmap", "group": "Hard Cover • CC0", "wait": "00:30", "color": Color(0.58, 0.48, 0.30)},
	{"name": "Training Arena", "file": "training_arena.vmap", "group": "Процедурный тест • изолированный", "wait": "00:30", "color": Color(0.30, 0.52, 0.42)},
	{"name": "Voxel Buildings", "file": "buildings_12.vmap", "group": "Mehrasaur • free", "wait": "00:30", "color": Color(0.42, 0.46, 0.56)},
	{"name": "Medieval Voxels", "file": "medieval_prop_0.vmap", "group": "FuzzyManStudios • CC0-style", "wait": "00:45", "color": Color(0.52, 0.40, 0.30)},
	{"name": "Desert Town", "source_file": "res://assets/voxel_sources/desert_town_tall_building.vox", "source_only": true, "group": "Max Parata • CC BY-ND", "wait": "—", "color": Color(0.32, 0.32, 0.34)},
	{"name": "Tiny Voxel Dungeon", "source_file": "res://assets/voxel_sources/tiny_dungeon_dragon_room.vox", "source_only": true, "group": "Max Parata • CC BY-ND", "wait": "—", "color": Color(0.28, 0.30, 0.32)},
]


func _ready() -> void:
	settings = GameSettings.new()
	settings.load_settings()
	loadout = Loadout.new(WeaponData.Team.T, 16000)
	var map_cfg := ConfigFile.new()
	if map_cfg.load("user://selected_map.cfg") == OK:
		selected_map_id = String(map_cfg.get_value("map", "id", "oasis"))
	world = get_parent().get_node_or_null("LobbyWorld")
	if world != null:
		agent_data = world.agent_data
	if agent_data == null:
		agent_data = AgentData.new()
	friends = FriendsStore.new()
	_build_shell()
	_build_friends_overlay()
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
	_refresh_friends_count()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	call_deferred("_fit_to_viewport")
	if get_viewport() != null:
		get_viewport().size_changed.connect(_fit_to_viewport)


# ---------- shell ----------

func _build_shell() -> void:
	root = Control.new()
	root.name = "LobbyUI"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build_theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.35)
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
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 20
	status_label.offset_top = -34
	status_label.offset_right = 480
	status_label.offset_bottom = -10
	status_label.add_theme_color_override("font_color", C_CYAN)
	root.add_child(status_label)


func _fit_to_viewport() -> void:
	if get_viewport() != null:
		_fit_with(get_viewport().get_visible_rect().size)


func _fit_with(vp: Vector2) -> void:
	## Полноэкранный режим: root уже FULL_RECT и следует за viewport через
	## stretch/aspect=expand. Никакого ручного scale — он ломал адаптив
	## и давал разные поля в разных браузерах.
	if root == null or vp.x <= 0.0 or vp.y <= 0.0:
		return
	root.scale = Vector2.ONE
	root.position = Vector2.ZERO


func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 44
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.SURFACE_3
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
	h.add_child(_icon_button("⚙", func(): _open_settings()))
	h.add_child(_icon_button("⏻", func(): _set_status("Выход: закройте вкладку браузера")))
	# центр: вкладки
	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(center)
	nav_highlight = ColorRect.new()
	nav_highlight.color = UiTheme.ACCENT_SOFT
	nav_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nav_highlight.size = Vector2(150, 32)
	center.add_child(nav_highlight)
	var nav := HBoxContainer.new()
	nav.set_anchors_preset(Control.PRESET_CENTER)
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BOTH
	nav.add_theme_constant_override("separation", 14)
	center.add_child(nav)
	nav_buttons.clear()
	for tab in ["ИГРАТЬ", "ПРОСМОТР", "ИНВЕНТАРЬ", "МАГАЗИН"]:
		var captured: String = tab
		var b := _text_button(tab, func(): _show_screen(captured), 20)
		nav.add_child(b)
		nav_buttons[tab] = b
	# справа: пользователь
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	wallet_label = Label.new()
	wallet_label.add_theme_color_override("font_color", UiTheme.OK)
	right.add_child(wallet_label)
	nickname_label = Label.new()
	nickname_label.text = settings.nickname
	right.add_child(nickname_label)
	var person := _icon_button("♟", func(): _toggle_friends())
	right.add_child(person)
	friends_count_label = _label("0", UiTheme.F_SM, C_DIM)
	right.add_child(friends_count_label)


func _build_right_strip() -> void:
	right_strip = PanelContainer.new()
	right_strip.name = "FriendsStrip"
	right_strip.anchor_left = 1.0
	right_strip.anchor_top = 0.0
	right_strip.anchor_right = 1.0
	right_strip.anchor_bottom = 1.0
	right_strip.offset_left = -56
	right_strip.offset_right = 0
	right_strip.offset_top = 44
	right_strip.offset_bottom = 0
	right_strip.add_theme_stylebox_override("panel",
		UiTheme.stylebox(UiTheme.SURFACE_3, Color(0, 0, 0, 0), UiTheme.R_NONE, 0, 2, 0))
	root.add_child(right_strip)

	var v := VBoxContainer.new()
	v.name = "StripContent"
	v.add_theme_constant_override("separation", UiTheme.S1)
	right_strip.add_child(v)
	friends_strip = VBoxContainer.new()
	friends_strip.name = "FriendsStripIcons"
	friends_strip.add_theme_constant_override("separation", UiTheme.S1)
	v.add_child(friends_strip)
	_rebuild_friends_strip()

	v.add_child(Control.new())
	var radio := _icon_button("◉", func(): _toggle_voice())
	radio.name = "VoiceButton"
	radio.custom_minimum_size = Vector2(44, 34)
	radio.tooltip_text = "Микрофон"
	v.add_child(radio)
	var hist := _icon_button("↺", func(): _show_screen("ПРОСМОТР"))
	hist.name = "HistoryButton"
	hist.custom_minimum_size = Vector2(44, 34)
	hist.tooltip_text = "История матчей"
	v.add_child(hist)
	var sliders := _icon_button("⚙", func(): _open_settings())
	sliders.name = "SettingsButton"
	sliders.custom_minimum_size = Vector2(44, 34)
	sliders.tooltip_text = "Настройки"
	v.add_child(sliders)


func _toggle_voice() -> void:
	voice_enabled = not voice_enabled
	var b: Button = right_strip.get_node_or_null("StripContent/VoiceButton") as Button
	if b != null:
		b.add_theme_color_override("font_color", UiTheme.OK if voice_enabled else C_FAINT)
	_set_status("Микрофон: " + ("включён" if voice_enabled else "выключен"))


var voice_enabled: bool = true


func _rebuild_friends_strip() -> void:
	if friends_strip == null:
		return
	_clear(friends_strip)
	if friends.is_empty():
		var add := _icon_button("+", func(): _toggle_friends())
		add.name = "AddFriend"
		add.custom_minimum_size = Vector2(44, 44)
		add.tooltip_text = "Добавить друга"
		add.add_theme_color_override("font_color", C_CYAN)
		friends_strip.add_child(add)
		return
	for name in friends.names:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(44, 44)
		p.tooltip_text = name + " — в сети"
		p.add_theme_stylebox_override("panel", UiTheme.flat(_avatar_color(name), UiTheme.R_SM))
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 0)
		p.add_child(inner)
		var mark := ColorRect.new()
		mark.color = UiTheme.OK_BRIGHT
		mark.custom_minimum_size = Vector2(44, 4)
		inner.add_child(mark)
		var initial := _label(String(name).substr(0, 1).to_upper(), UiTheme.F_MD, C_TEXT)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(initial)
		friends_strip.add_child(p)


func _avatar_color(name: String) -> Color:
	var palette := [Color(0.35, 0.42, 0.50), Color(0.55, 0.45, 0.30),
		Color(0.45, 0.30, 0.55), Color(0.30, 0.45, 0.45), Color(0.50, 0.35, 0.35)]
	return palette[abs(name.hash()) % palette.size()]


func _refresh_friends_count() -> void:
	if friends_count_label != null:
		friends_count_label.text = str(friends.count())


func _build_friends_overlay() -> void:
	friends_overlay = Control.new()
	friends_overlay.name = "FriendsOverlay"
	friends_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	friends_overlay.visible = false
	root.add_child(friends_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	friends_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -260
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_2, UiTheme.LINE_STRONG, UiTheme.R_LG, 2, UiTheme.S3, UiTheme.S3))
	friends_overlay.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.S2)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_label("ДРУЗЬЯ", UiTheme.F_XL, C_TEXT))
	head.add_child(Control.new())
	var close := _icon_button("✕", func(): _toggle_friends())
	close.tooltip_text = "Закрыть"
	head.add_child(close)

	var input_row := HBoxContainer.new()
	v.add_child(input_row)
	friends_input = LineEdit.new()
	friends_input.placeholder_text = "Ник друга"
	friends_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friends_input.add_theme_font_size_override("font_size", UiTheme.F_MD)
	friends_input.text_submitted.connect(func(_text: String): _add_friend())
	input_row.add_child(friends_input)
	var add := _blue_button("ДОБАВИТЬ", func(): _add_friend())
	add.custom_minimum_size = Vector2(120, 34)
	input_row.add_child(add)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	friends_list = VBoxContainer.new()
	friends_list.add_theme_constant_override("separation", UiTheme.S2)
	scroll.add_child(friends_list)
	v.add_child(_label("Список хранится локально в этом браузере", UiTheme.F_SM, C_FAINT))


func _toggle_friends() -> void:
	if friends_overlay == null:
		return
	friends_overlay.visible = not friends_overlay.visible
	if friends_overlay.visible:
		_rebuild_friends_list()
		friends_input.grab_focus()


func _rebuild_friends_list() -> void:
	if friends_list == null:
		return
	_clear(friends_list)
	friends_empty = friends.is_empty()
	if friends_empty:
		var empty := PanelContainer.new()
		empty.name = "FriendsEmpty"
		empty.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD, 1, UiTheme.S4, UiTheme.S4))
		var ev := VBoxContainer.new()
		empty.add_child(ev)
		var title := _label("Пока нет друзей", UiTheme.F_LG, C_TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ev.add_child(title)
		var hint := _label("Введите ник выше и нажмите «Добавить» — здесь появится список.", UiTheme.F_SM, C_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ev.add_child(hint)
		friends_list.add_child(empty)
		return
	for name in friends.names:
		var row := PanelContainer.new()
		row.name = "Friend_" + name
		row.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_SM))
		var h := HBoxContainer.new()
		row.add_child(h)
		var avatar := ColorRect.new()
		avatar.color = _avatar_color(name)
		avatar.custom_minimum_size = Vector2(34, 34)
		h.add_child(avatar)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(text)
		text.add_child(_label(name, UiTheme.F_MD, C_TEXT))
		text.add_child(_label("в сети", UiTheme.F_SM, UiTheme.OK))
		var remove := _icon_button("✕", func(): _remove_friend(name))
		remove.custom_minimum_size = Vector2(30, 30)
		remove.tooltip_text = "Удалить из списка"
		remove.add_theme_color_override("font_color", C_FAINT)
		h.add_child(remove)
		friends_list.add_child(row)


func _add_friend() -> void:
	if friends_input == null:
		return
	var name := friends_input.text.strip_edges()
	if name.is_empty():
		_set_status("Введите ник друга")
		return
	if not friends.add(name):
		_set_status("Этот друг уже в списке")
		return
	friends_input.clear()
	_rebuild_friends_list()
	_rebuild_friends_strip()
	_refresh_friends_count()
	_set_status("Добавлен друг: " + name)


func _remove_friend(name: String) -> void:
	friends.remove(name)
	_rebuild_friends_list()
	_rebuild_friends_strip()
	_refresh_friends_count()
	_set_status("Удалён друг: " + name)


# ---------- helpers ----------

func _mk_sb(bg: Color, border: Color = C_LINE, radius: int = UiTheme.R_MD) -> StyleBoxFlat:
	return UiTheme.stylebox(bg, border, radius)


func _icon_button(text: String, cb: Callable) -> Button:
	var icon_name: String = String(ICON_NAMES.get(text, "dot"))
	var b := Button.new()
	b.name = "IconButton_" + icon_name
	b.custom_minimum_size = Vector2(34, 30)
	b.add_theme_stylebox_override("normal", _mk_sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", UiTheme.button_style("hover_overlay"))
	var glyph := UiIcon.new()
	glyph.name = "Glyph"
	glyph.icon_name = icon_name
	glyph.icon_color = C_TEXT
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.offset_left = -12
	glyph.offset_top = -12
	glyph.offset_right = 12
	glyph.offset_bottom = 12
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	b.pressed.connect(cb)
	return b


func _text_button(text: String, cb: Callable, font_size: int = 14, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _mk_sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", UiTheme.button_style("hover_overlay"))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", C_CYAN if accent else C_TEXT)
	b.pressed.connect(cb)
	return b


func _green_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_stylebox_override("normal", UiTheme.button_style("primary"))
	b.add_theme_stylebox_override("hover", UiTheme.button_style("primary"))
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b


func _blue_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", UiTheme.button_style("accent"))
	b.add_theme_stylebox_override("hover", UiTheme.button_style("accent_hover"))
	b.add_theme_color_override("font_color", C_TEXT)
	b.pressed.connect(cb)
	return b


func _small_tab_button(text: String, cb: Callable) -> Button:
	## Компактная вкладка: длинные русские подписи не вылезают за экран.
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 28)
	var sb := UiTheme.button_style("accent")
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	var hsb := UiTheme.button_style("accent_hover")
	hsb.content_margin_left = 5
	hsb.content_margin_right = 5
	hsb.content_margin_top = 3
	hsb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hsb)
	b.add_theme_font_size_override("font_size", 11)
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
		_select_settings_tab(settings_tab_index)
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
	# подсветка вкладки (подэкраны наследуют вкладку родителя)
	var tab_name: String = "ИГРАТЬ"
	if nav_buttons.has(name):
		tab_name = name
	elif name == "СНАРЯЖЕНИЕ":
		tab_name = "ИНВЕНТАРЬ"
	elif name == "НАСТРОЙКИ":
		if nav_buttons.has(settings_return_screen):
			tab_name = settings_return_screen
		elif settings_return_screen == "СНАРЯЖЕНИЕ":
			tab_name = "ИНВЕНТАРЬ"
	for key in nav_buttons.keys():
		var b: Button = nav_buttons[key]
		b.add_theme_color_override("font_color", C_CYAN if key == tab_name else C_TEXT)
	var gear: Button = top_bar.get_child(0).get_child(2) as Button
	if gear != null:
		gear.add_theme_color_override("font_color", C_CYAN if name == "НАСТРОЙКИ" else C_TEXT)
	call_deferred("_update_nav_highlight", tab_name)


func _update_nav_highlight(tab_name: String) -> void:
	if nav_highlight == null or not is_instance_valid(nav_highlight):
		return
	var b2: Button = nav_buttons.get(tab_name, null)
	if b2 == null:
		nav_highlight.visible = false
		return
	var parent: Control = nav_highlight.get_parent() as Control
	if parent == null:
		return
	nav_highlight.visible = true
	var target := b2.global_position - parent.global_position
	var tw := create_tween()
	tw.tween_property(nav_highlight, "position", target, 0.15)
	tw.parallel().tween_property(nav_highlight, "size", b2.size, 0.15)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if friends_overlay != null and friends_overlay.visible:
		_toggle_friends()
	elif inventory_overlay != null and inventory_overlay.visible:
		_close_inventory()
	elif settings_overlay != null and settings_overlay.visible:
		_close_settings()
	elif current_screen != "ИГРАТЬ":
		_show_screen(_parent_screen(current_screen))


func _parent_screen(name: String) -> String:
	if name == "СНАРЯЖЕНИЕ":
		return "ИНВЕНТАРЬ"
	return "ИГРАТЬ"


func _select_tab(tab: String) -> void:
	_show_screen(tab)


func _set_status(msg: String) -> void:
	status_label.text = msg


func _select_map(map_name: String) -> void:
	selected_map_id = map_name
	var cfg := ConfigFile.new()
	cfg.set_value("map", "id", map_name)
	cfg.save("user://selected_map.cfg")
	_build_map_grid()
	_set_status("Карта выбрана: " + map_name)


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
	left.anchor_bottom = 1.0
	left.offset_left = 14
	left.offset_top = 14
	left.offset_right = 250
	left.offset_bottom = -44
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
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var music := _promo_card("НОВОЕ И ПОПУЛЯРНОЕ   Показать все",
		"StatTrak™  НОВОЕ!\nНабор музыка | Voyage of Cozi Zuehlsdorff\n– Nevada\n218.84  ↘ 344.88",
		Color(0.16, 0.15, 0.16), Color(0.55, 0.45, 0.30), 108)
	left.add_child(music)
	# бейдж игрока по центру, над кнопкой «ИГРАТЬ»
	var badge := PanelContainer.new()
	badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	badge.offset_left = -120
	badge.offset_right = 120
	badge.offset_top = -176
	badge.offset_bottom = -96
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
	bg_label = _label("Янтарный двор", 12, C_DIM)
	bg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_label.offset_top = 96
	bg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_panel.add_child(bg_label)
	bg_switch = HBoxContainer.new()
	bg_switch.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg_switch.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_switch.offset_top = 118
	bg_switch.alignment = BoxContainer.ALIGNMENT_CENTER
	play_panel.add_child(bg_switch)
	bg_switch.add_child(_text_button("◀ фон", func(): _prev_background()))
	bg_switch.add_child(_text_button("фон ▶", func(): _next_background()))
	bg_switch.add_child(_blue_button("НОВОСТИ", func(): _show_screen("НОВОСТИ")))
	# главная кнопка входа в игру (как PLAY в CS2)
	play_start_button = _green_button("ИГРАТЬ", func(): _show_screen("ПОДБОР"))
	play_start_button.name = "PlayButton"
	play_start_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	play_start_button.offset_left = -120
	play_start_button.offset_right = 120
	play_start_button.offset_top = -74
	play_start_button.offset_bottom = -24
	play_panel.add_child(play_start_button)


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
	var t := _label(title, UiTheme.F_SM, UiTheme.TEXT)
	v.add_child(t)
	var strip := ColorRect.new()
	strip.color = accent
	strip.custom_minimum_size = Vector2(0, 2)
	v.add_child(strip)
	var b := _label(body, UiTheme.F_SM, UiTheme.TEXT_MUTED)
	v.add_child(b)
	v.add_child(Control.new())
	var scrub := ColorRect.new()
	scrub.color = Color(0.85, 0.85, 0.85, 0.5)
	scrub.custom_minimum_size = Vector2(0, 3)
	v.add_child(scrub)
	return p


func _prev_background() -> void:
	if world == null:
		return
	world.prev_background()
	if bg_label != null:
		bg_label.text = world.background_name()


func _next_background() -> void:
	if world == null:
		return
	world.next_background()
	if bg_label != null:
		bg_label.text = world.background_name()


# ---------- ПРОСМОТР ----------

func _build_watch_screen() -> void:
	watch_panel = _screen()
	watch_panel.name = "WatchScreen"
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	watch_panel.add_child(top)
	top.add_child(_icon_button("←", func(): _show_screen("ИГРАТЬ")))
	watch_tabs.clear()
	for t in ["ВАШИ МАТЧИ", "СКАЧАННЫЕ МАТЧИ", "МЕЙДЖОРЫ"]:
		var captured: String = t
		var b := _blue_button(t, func(): _select_watch_tab(captured))
		top.add_child(b)
		watch_tabs[t] = b
	watch_refresh = _icon_button("↻", func(): _rebuild_watch_list())
	top.add_child(watch_refresh)
	# левый список матчей
	var list_panel := PanelContainer.new()
	list_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	list_panel.anchor_bottom = 1.0
	list_panel.offset_left = 0
	list_panel.offset_top = 50
	list_panel.offset_right = 330
	list_panel.offset_bottom = -84
	list_panel.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
	watch_panel.add_child(list_panel)
	watch_list = VBoxContainer.new()
	watch_list.add_theme_constant_override("separation", 2)
	list_panel.add_child(watch_list)
	_select_watch_tab("ВАШИ МАТЧИ")
	# детали матча
	var detail := PanelContainer.new()
	detail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	detail.anchor_right = 1.0
	detail.anchor_bottom = 1.0
	detail.offset_left = 350
	detail.offset_right = -80
	detail.offset_top = 70
	detail.offset_bottom = -100
	detail.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
	watch_panel.add_child(detail)
	var dv := VBoxContainer.new()
	dv.name = "WatchDetail"
	detail.add_child(dv)
	watch_detail_title = _label("СПИСОК ПУСТ", UiTheme.F_LG, C_TEXT)
	dv.add_child(watch_detail_title)
	watch_detail_sub = _label("Матчи появятся здесь после записи.", UiTheme.F_MD, C_DIM)
	watch_detail_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(watch_detail_sub)
	# нижние кнопки: доступны только когда есть выбранный матч
	watch_actions = HBoxContainer.new()
	watch_actions.name = "WatchActions"
	watch_actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	watch_actions.offset_left = -420
	watch_actions.offset_top = -64
	watch_actions.offset_right = -80
	watch_actions.offset_bottom = -18
	watch_actions.visible = false
	watch_panel.add_child(watch_actions)
	watch_actions.add_child(_green_button("СКАЧАТЬ", func(): _download_match("Матч", null)))
	watch_actions.add_child(_icon_button("⤴", func(): _set_status("Поделиться")))
	watch_actions.add_child(_icon_button("🗑", func(): _set_status("Удалить")))


func _select_watch_tab(tab: String) -> void:
	watch_tab = tab
	for key in watch_tabs.keys():
		var b: Button = watch_tabs[key]
		b.add_theme_color_override("font_color", C_CYAN if key == tab else C_TEXT)
	_rebuild_watch_list()


func _rebuild_watch_list() -> void:
	if watch_list == null:
		return
	_clear(watch_list)
	watch_empty = true
	var hint: String = "Сыграйте матч — он появится здесь."
	if watch_tab == "СКАЧАННЫЕ МАТЧИ":
		hint = "Скачанные повторы появятся здесь."
	elif watch_tab == "МЕЙДЖОРЫ":
		hint = "Расписание и повторы мейджоров появятся после подключения к серверу。"
	var empty := PanelContainer.new()
	empty.name = "WatchEmpty"
	empty.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD, 1, UiTheme.S4, UiTheme.S4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.S2)
	empty.add_child(v)
	var title := _label("Здесь пока пусто", UiTheme.F_LG, C_TEXT)
	v.add_child(title)
	var sub := _label(hint, UiTheme.F_SM, C_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	watch_list.add_child(empty)
	if watch_detail_title != null:
		watch_detail_title.text = "МАТЧИ НЕ ЗАПИСАНЫ"
	if watch_detail_sub != null:
		watch_detail_sub.text = hint
	if watch_actions != null:
		watch_actions.visible = false


func _download_match(name: String, btn) -> void:
	_set_status("Матч загружен: " + name)


# ---------- НОВОСТИ ----------

func _build_news_screen() -> void:
	news_panel = _screen()
	news_panel.name = "NewsScreen"
	news_panel.add_child(_icon_button("←", func(): _show_screen("ИГРАТЬ")))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 48
	news_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	var articles := [
		["2026-11-26", "Карта Oasis: цвет и свет", "Воксельная карта теперь использует цвета материалов вершин и мягкий процедурный шум вместо однотонной заливки."],
		["2026-11-26", "Модель оружия от первого лица", "Каждое оружие получило собственную процедурную модель, руки и анимацию отдачи без остаточного смещения."],
		["2026-11-25", "Навигация как в CS2", "Четыре вкладки вверху, полноэкранный адаптив и единая дизайн-система для всех меню."],
	]
	for i in range(articles.size()):
		var a: Array = articles[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiTheme.stylebox(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
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

const STORE_SECTIONS: Dictionary = {
	"ГЛАВНАЯ": {"title": "ЕЖЕНЕДЕЛЬНЫЙ НАБОР", "subtitle": "ЕЖЕНЕДЕЛЬНЫЕ НАГРАДЫ ПОЛУЧЕНЫ", "desc": "Прогресс до следующего набора начнёт\nзасчитываться через 3 дня"},
	"ОБЩЕЕ": {"title": "ОБЩИЕ ПРЕДМЕТЫ", "subtitle": "Популярные скины и кейсы", "desc": "Самые востребованные предметы сообщества"},
	"СИНГАПУР-2026": {"title": "МЕЙДЖОР СИНГАПУР 2026", "subtitle": "Коллекция турнира", "desc": "Эксклюзивные скины и наклейки мейджора"},
	"ТОРГОВАЯ ПЛОЩАДКА": {"title": "ТОРГОВАЯ ПЛОЩАДКА", "subtitle": "Купить и продать предметы", "desc": "Рынок Steam Community — история цен и заказы"},
	"ИНСТРУМЕНТЫ": {"title": "ИНСТРУМЕНТЫ И СТИКЕРЫ", "subtitle": "Наклейки, патчи, контейнеры", "desc": "Инструменты для кастомизации оружия"},
	"АРСЕНАЛ": {"title": "АРСЕНАЛ", "subtitle": "Наборы музыки и звуки", "desc": "Музыкальные наборы Monstercat и другие"},
}

func _build_store_screen() -> void:
	store_panel = _screen()
	store_panel.name = "StoreScreen"
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 12
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	store_panel.add_child(top)
	top.add_child(_icon_button("←", func(): _show_screen("ИГРАТЬ")))
	store_tabs.clear()
	for t in STORE_SECTIONS.keys():
		var captured: String = t
		var b := _blue_button(t, func(): _select_store_tab(captured))
		top.add_child(b)
		store_tabs.append(b)
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 60
	banner.offset_left = 60
	banner.offset_right = -60
	banner.offset_bottom = 260
	var sb := _mk_sb(Color(0.32, 0.18, 0.06), Color(0.55, 0.35, 0.10))
	banner.add_theme_stylebox_override("panel", sb)
	store_panel.add_child(banner)
	var bh := HBoxContainer.new()
	banner.add_child(bh)
	store_banner_cards.clear()
	for i in range(4):
		var card := ColorRect.new()
		card.color = Color(0.18, 0.18, 0.20) if i < 2 else Color(0.12, 0.10, 0.07)
		card.custom_minimum_size = Vector2(180, 150)
		bh.add_child(card)
		store_banner_cards.append(card)
	var info := VBoxContainer.new()
	bh.add_child(info)
	store_title = _label(STORE_SECTIONS["ГЛАВНАЯ"].title, 22, C_TEXT)
	info.add_child(store_title)
	store_subtitle = _label(STORE_SECTIONS["ГЛАВНАЯ"].subtitle, UiTheme.F_SM, UiTheme.WARN)
	info.add_child(store_subtitle)
	store_desc = _label(STORE_SECTIONS["ГЛАВНАЯ"].desc, 11, C_DIM)
	info.add_child(store_desc)
	var music := PanelContainer.new()
	music.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	store_cards = cards
	for i in range(6):
		var c := ColorRect.new()
		c.color = Color(0.20 + float(i) * 0.02, 0.18, 0.22)
		c.custom_minimum_size = Vector2(170, 110)
		cards.add_child(c)
	_select_store_tab("ГЛАВНАЯ")


func _select_store_tab(tab: String) -> void:
	store_tab = tab
	for b in store_tabs:
		b.add_theme_color_override("font_color", C_CYAN if b.text == tab else C_TEXT)
	if STORE_SECTIONS.has(tab):
		var data: Dictionary = STORE_SECTIONS[tab]
		store_title.text = String(data.title)
		store_subtitle.text = String(data.subtitle)
		store_desc.text = String(data.desc)
		var shift: float = float(abs(tab.hash()) % 8) * 0.02
		for i in range(store_banner_cards.size()):
			var card: ColorRect = store_banner_cards[i] as ColorRect
			if card != null:
				card.color = Color(0.18 + shift, 0.18 + float(i) * 0.02, 0.22) if i < 2 else Color(0.12 + shift, 0.10, 0.07)
		for i in range(store_cards.get_child_count()):
			var c: ColorRect = store_cards.get_child(i) as ColorRect
			if c != null:
				c.color = Color(0.20 + float(i) * 0.02 + shift * 0.5, 0.18, 0.22)


# ---------- СНАРЯЖЕНИЕ ----------

func _build_equipment_screen() -> void:
	equipment_panel = _screen()
	equipment_panel.name = "EquipmentScreen"
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 430
	top.add_theme_stylebox_override("panel", _mk_sb(Color(0.06, 0.14, 0.24, 0.96)))
	equipment_panel.add_child(top)
	var back := _icon_button("←", func(): _show_screen("ИНВЕНТАРЬ"))
	back.name = "BackButton"
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 8
	back.offset_top = 6
	back.offset_right = 40
	back.offset_bottom = 38
	equipment_panel.add_child(back)
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
	equipment_ct_button = _blue_button("СПЕЦНАЗ", func(): _select_equipment_team(WeaponData.Team.CT))
	ctv.add_child(equipment_ct_button)
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
	equipment_t_button = _text_button("ТЕРРОРИСТЫ", func(): _select_equipment_team(WeaponData.Team.T), 13)
	equipment_t_button.add_theme_color_override("font_color", UiTheme.TEAM_T)
	tv.add_child(equipment_t_button)
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
	equipment_filter_btn = OptionButton.new()
	equipment_filter_btn.add_item("Все категории")
	equipment_filter_btn.add_item("Пистолеты")
	equipment_filter_btn.add_item("Винтовки")
	equipment_filter_btn.add_item("ПП")
	equipment_filter_btn.add_item("Снайперки")
	equipment_filter_btn.add_item("Дробовики")
	equipment_filter_btn.add_item("Пулемёты")
	equipment_filter_btn.add_item("Гранаты")
	equipment_filter_btn.item_selected.connect(func(idx): _select_equipment_filter(idx))
	bh.add_child(equipment_filter_btn)
	bh.add_child(Control.new())
	equipment_sort_btn = OptionButton.new()
	equipment_sort_btn.add_item("По новизне")
	equipment_sort_btn.add_item("По имени")
	equipment_sort_btn.add_item("По цене")
	equipment_sort_btn.item_selected.connect(func(idx): _select_equipment_sort(idx))
	bh.add_child(equipment_sort_btn)
	equipment_scroll = ScrollContainer.new()
	equipment_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	equipment_scroll.offset_top = 500
	equipment_scroll.offset_left = 12
	equipment_scroll.offset_right = -12
	equipment_scroll.offset_bottom = -8
	equipment_panel.add_child(equipment_scroll)
	equipment_grid = GridContainer.new()
	equipment_grid.columns = 6
	equipment_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_grid.add_theme_constant_override("h_separation", 8)
	equipment_grid.add_theme_constant_override("v_separation", 8)
	equipment_scroll.add_child(equipment_grid)
	_rebuild_equipment_grid()


func _rebuild_equipment_grid() -> void:
	if equipment_grid == null:
		return
	_clear(equipment_grid)
	var ids: Array = WeaponData.WEAPONS.keys()
	ids.sort()
	# фильтр по команде
	if equipment_team != -1:
		ids = ids.filter(func(id): return _weapon_matches_team(int(id), equipment_team))
	# фильтр по категории
	if equipment_filter != 0:
		ids = ids.filter(func(id): return _weapon_matches_category(int(id), equipment_filter))
	# сортировка
	if equipment_sort == 1:
		ids.sort_custom(func(a, b): return String(WeaponData.get_weapon(a).get("name", "")).nocasecmp_to(String(WeaponData.get_weapon(b).get("name", ""))) < 0)
	elif equipment_sort == 2:
		ids.sort_custom(func(a, b): return int(WeaponData.get_weapon(a).get("price", 0)) > int(WeaponData.get_weapon(b).get("price", 0)))
	for id in ids:
		equipment_grid.add_child(_make_inventory_item(int(id)))


func _select_equipment_team(team: int) -> void:
	if equipment_team == team:
		equipment_team = -1
	else:
		equipment_team = team
	# обновляем подсветку кнопок
	if equipment_ct_button != null:
		equipment_ct_button.add_theme_color_override("font_color", C_CYAN if equipment_team == WeaponData.Team.CT else C_TEXT)
	if equipment_t_button != null:
		equipment_t_button.add_theme_color_override("font_color", C_CYAN if equipment_team == WeaponData.Team.T else C_TEXT)
	_rebuild_equipment_grid()


func _select_equipment_filter(idx: int) -> void:
	equipment_filter = idx
	_rebuild_equipment_grid()


func _select_equipment_sort(idx: int) -> void:
	equipment_sort = idx
	_rebuild_equipment_grid()


func _weapon_matches_team(weapon_id: int, team: int) -> bool:
	var w: Dictionary = WeaponData.get_weapon(weapon_id)
	var wteam: int = int(w.get("team", 0))
	return wteam == 0 or wteam == team


func _weapon_matches_category(weapon_id: int, cat: int) -> bool:
	var w: Dictionary = WeaponData.get_weapon(weapon_id)
	var slot: String = String(w.get("slot", ""))
	match cat:
		1: return slot == "pistol"
		2: return slot == "rifle"
		3: return slot == "smg"
		4: return slot == "sniper"
		5: return slot == "heavy" and int(w.get("pellets", 1)) > 1
		6: return slot == "heavy" and int(w.get("pellets", 1)) == 1
		7: return slot in ["grenade", "utility"]
	return true


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
	# верхние вкладки: источник
	var source_tabs := HBoxContainer.new()
	source_tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	source_tabs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	source_tabs.offset_top = 10
	source_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	play_modes_panel.add_child(source_tabs)
	play_modes_back = _icon_button("←", func(): _show_screen("ИГРАТЬ"))
	source_tabs.add_child(play_modes_back)
	play_source_tabs.clear()
	for t in ["ПОДБОР МАТЧА", "ТРЕНИРОВКА", "КАРТЫ ИЗ МАСТЕРСКОЙ"]:
		var captured: String = t
		var b := _blue_button(t, func(): _select_play_source(captured))
		source_tabs.add_child(b)
		play_source_tabs.append(b)
	source_tabs.add_child(_icon_button("🌐", func(): _set_status("Серверы")))
	# вкладки режимов (только для подбора матча)
	var modes := HBoxContainer.new()
	modes.set_anchors_preset(Control.PRESET_TOP_WIDE)
	modes.offset_top = 48
	modes.offset_bottom = 86
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 4)
	play_modes_panel.add_child(modes)
	play_modes_row = modes
	play_mode_tabs.clear()
	for m in ["ПРЕМЬЕР-РЕЖИМ", "СОРЕВНОВАТЕЛЬНЫЙ", "НАПАРНИКИ", "ШТУРМ", "ОБЫЧНЫЙ",
			"БОЙ НАСМЕРТЬ", "ГОНКА ВООРУЖЕНИЙ", "ЗАЧИСТКА", "ЗАКРЫТЫЙ ПОДБОР МАТЧА"]:
		var captured: String = m
		var b := _small_tab_button(m, func(): _set_play_mode(captured))
		modes.add_child(b)
		play_mode_tabs.append(b)
	# левая панель статуса
	var left := PanelContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.anchor_bottom = 1.0
	left.offset_left = 0
	left.offset_top = 96
	left.offset_right = 240
	left.offset_bottom = -80
	left.add_theme_stylebox_override("panel", _mk_sb(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
	play_modes_panel.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(_label("ПРАЙМ-СТАТУС\nВКЛЮЧЕН", 13, Color(0.85, 0.75, 0.35)))
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
	play_map_grid.offset_bottom = -84
	play_map_grid.add_theme_constant_override("h_separation", 8)
	play_map_grid.add_theme_constant_override("v_separation", 8)
	play_modes_panel.add_child(play_map_grid)
	# нижняя панель
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -72
	bottom.add_theme_stylebox_override("panel", _mk_sb(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
	play_modes_panel.add_child(bottom)
	var bh := HBoxContainer.new()
	bottom.add_child(bh)
	var mission := PanelContainer.new()
	mission.custom_minimum_size = Vector2(300, 52)
	mission.add_theme_stylebox_override("panel", _mk_sb(Color(0.14, 0.22, 0.38)))
	bh.add_child(mission)
	play_mission_label = _label("«СОРЕВНОВАТЕЛЬНЫЙ», VERTIGO\nВыигрывайте раунды", 11, C_TEXT)
	mission.add_child(play_mission_label)
	bh.add_child(Control.new())
	bh.add_child(_green_button("НАЧАТЬ", func(): _launch_game("Матч запущен...")))
	_select_play_source("ПОДБОР МАТЧА")


func _select_play_source(source: String) -> void:
	play_source = source
	for b in play_source_tabs:
		b.add_theme_color_override("font_color", C_CYAN if b.text == source else C_TEXT)
	play_modes_row.visible = source == "ПОДБОР МАТЧА"
	if source == "ТРЕНИРОВКА":
		play_mission_label.text = "ТРЕНИРОВКА\nСтрельба по мишеням, рекоил, движение"
	elif source == "КАРТЫ ИЗ МАСТЕРСКОЙ":
		play_mission_label.text = "КАРТЫ ИЗ МАСТЕРСКОЙ\nПодписанные карты сообщества"
	else:
		play_mission_label.text = "«СОРЕВНОВАТЕЛЬНЫЙ», VERTIGO\nВыигрывайте раунды"
	_build_map_grid()


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
	if play_source == "ТРЕНИРОВКА":
		_build_training_view()
		return
	if play_source == "КАРТЫ ИЗ МАСТЕРСКОЙ":
		_build_workshop_view()
		return
	if play_mode == "ПРЕМЬЕР-РЕЖИМ":
		_build_premier_view()
		return
	var maps: Array = MAP_GROUPS if play_mode != "БОЙ НАСМЕРТЬ" else MAP_GROUPS
	for i in range(maps.size()):
		var m: Dictionary = maps[i]
		var source_only: bool = bool(m.get("source_only", false))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 230)
		card.tooltip_text = String(m.group)
		var sb := _mk_sb(m.color if not source_only else m.color.darkened(0.25), Color(0.35, 0.4, 0.45))
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		card.add_child(v)
		var check := CheckButton.new()
		check.button_pressed = i < 2 and not source_only
		check.disabled = source_only
		v.add_child(check)
		var badge := ColorRect.new()
		badge.color = m.color.lightened(0.15)
		badge.custom_minimum_size = Vector2(0, 70)
		v.add_child(badge)
		v.add_child(_label(String(m.name), 16, C_TEXT if not source_only else C_DIM))
		if source_only:
			v.add_child(_label("ТОЛЬКО ИСТОЧНИК .vox", 10, C_FAINT))
			v.add_child(_label("CC BY-ND — без конвертации", 10, C_WARN))
		else:
			v.add_child(_label(String(m.group) + "   ◷ " + String(m.wait), 10, C_DIM))
			var click := Button.new()
			click.name = "Select_" + String(m.get("name", "map"))
			click.set_anchors_preset(Control.PRESET_FULL_RECT)
			click.flat = true
			click.modulate = Color(1, 1, 1, 0.001)
			var map_name: String = String(m.get("name", "Oasis"))
			click.pressed.connect(func(): _select_map(map_name))
			card.add_child(click)
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


func _build_training_view() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 460)
	panel.add_theme_stylebox_override("panel", _mk_sb(C_PANEL2))
	play_map_grid.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(_label("// ТРЕНИРОВКА", 16, C_CYAN))
	v.add_child(_label("Выберите тип тренировки:", 12, C_TEXT))
	var train_types := ["Стрельба по мишеням (Aim Botz)", "Управление рекойлом", "Движение (Bhop/Surf)", "Удержание ракурсов", "Работа с гранатами"]
	for tt in train_types:
		var btn := _green_button(tt, func(t=tt): _set_status("Запуск: " + t))
		btn.custom_minimum_size = Vector2(400, 44)
		v.add_child(btn)
	v.add_child(Control.new())
	v.add_child(_label("Нажмите НАЧАТЬ для запуска тренировки", 11, C_DIM))


func _build_workshop_view() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 460)
	panel.add_theme_stylebox_override("panel", _mk_sb(C_PANEL2))
	play_map_grid.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(_label("// КАРТЫ ИЗ МАСТЕРСКОЙ", 16, C_CYAN))
	v.add_child(_label("Подписанные карты не найдены", 12, C_DIM))
	v.add_child(_label("Посетите мастерскую Steam для подписки на карты", 11, C_DIM))
	v.add_child(Control.new())
	var btn := _blue_button("ОТКРЫТЬ МАСТЕРСКУЮ", func(): _set_status("Открыть мастерскую Steam"))
	btn.custom_minimum_size = Vector2(240, 44)
	v.add_child(btn)


# ---------- НАСТРОЙКИ (два уровня вкладок, строки с value справа) ----------

const SETTINGS_TABS: Array = ["ИЗОБРАЖЕНИЕ", "ЗВУК", "ИГРА", "КЛАВИАТУРА И МЫШЬ", "ПРИЦЕЛ"]
var settings_tab_index: int = 0
var settings_sub_index: int = 0
var settings_sub_row: HBoxContainer
var settings_sub_buttons: Array = []


func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UiTheme.BG_2
	settings_overlay.add_child(bg)
	var pattern := UiPattern.new()
	pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	pattern.color = Color(0.5, 0.6, 0.7, 0.04)
	settings_overlay.add_child(pattern)
	# первый уровень вкладок
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.grow_horizontal = Control.GROW_DIRECTION_BOTH
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
	# второй уровень (показывается только для ИЗОБРАЖЕНИЕ)
	settings_sub_row = HBoxContainer.new()
	settings_sub_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	settings_sub_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_sub_row.offset_top = 58
	settings_sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_sub_row.visible = false
	settings_overlay.add_child(settings_sub_row)
	settings_sub_buttons.clear()
	for s in ["ГРАФИКА", "РАСШИРЕННЫЕ НАСТРОЙКИ", "ПОЗИЦИЯ КРАЁВ"]:
		var idx: int = settings_sub_buttons.size()
		var b := _blue_button(s, func(): _select_settings_sub(idx))
		settings_sub_row.add_child(b)
		settings_sub_buttons.append(b)
	# контент
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = -60
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
	bottom.add_theme_stylebox_override("panel", _mk_sb(UiTheme.SURFACE_3, UiTheme.LINE, UiTheme.R_MD))
	settings_overlay.add_child(bottom)
	var bh := HBoxContainer.new()
	bottom.add_child(bh)
	bh.add_child(_text_button("↺  СБРОСИТЬ", func(): _on_reset_settings()))
	bh.add_child(Control.new())
	bh.add_child(_text_button("ОТМЕНИТЬ ИЗМЕНЕНИЯ", func(): _close_settings(), 12))
	var apply_btn := _text_button("ПРИМЕНИТЬ ИЗМЕНЕНИЯ", func(): _on_apply_settings(), 12)
	apply_btn.add_theme_color_override("font_color", C_CYAN)
	bh.add_child(apply_btn)


func _select_settings_tab(index: int) -> void:
	settings_tab_index = index
	settings_sub_index = 0
	for i in range(settings_sub_tabs.size()):
		var b: Button = settings_sub_tabs[i]
		b.add_theme_color_override("font_color", C_CYAN if i == index else C_TEXT)
	# показываем подвкладки только для ИЗОБРАЖЕНИЕ (индекс 0)
	settings_sub_row.visible = (index == 0)
	for i in range(settings_sub_buttons.size()):
		var b: Button = settings_sub_buttons[i]
		b.add_theme_color_override("font_color", C_CYAN if i == settings_sub_index else C_TEXT)
	_rebuild_settings_content()


func _select_settings_sub(index: int) -> void:
	settings_sub_index = index
	for i in range(settings_sub_buttons.size()):
		var b: Button = settings_sub_buttons[i]
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
	if settings_tab_index == 0:
		# ИЗОБРАЖЕНИЕ - подвкладки
		match settings_sub_index:
			0: _build_image_settings()
			1: _build_image_advanced_settings()
			2: _build_image_edges_settings()
	else:
		match settings_tab_index:
			1: _build_sound_settings()
			2: _build_gameplay_settings()
			3: _build_input_settings()
			4: _build_crosshair_settings()


func _build_image_settings() -> void:
	settings_content.add_child(_label("Графика", UiTheme.F_XL, UiTheme.TEXT_MUTED))
	settings_content.add_child(_label("Экран", 12, C_CYAN))
	_setting_row("Экран", "МОНИТОР 1 – G270Q20")
	_setting_row("Режим отображения", "ПОЛНОЗКРАННЫЙ В ОКНЕ")
	_setting_row("Формат экрана", "ОБЫЧНЫЙ, 4:3")
	_setting_row("Разрешение", "1280X960")
	_setting_row("Частота обновления", "200 Hz")
	_setting_row("Яркость", "", true, 0.93)
	settings_content.add_child(_label("Отрегулировать общую яркость с помощью\nизменения гаммы коррекции внутреннего рендеринга.", 10, C_DIM))


func _build_image_advanced_settings() -> void:
	settings_content.add_child(_label("Расширенные настройки графики", UiTheme.F_XL, UiTheme.TEXT_MUTED))
	settings_content.add_child(_label("Качество", 12, C_CYAN))
	_setting_row("Качество теней", "Высокое")
	_setting_row("Качество текстур", "Высокое")
	_setting_row("Детализация эффектов", "Высокая")
	_setting_row("Детализация шейдеров", "Высокая")
	_setting_row("Контраст игроков", "Включено")
	_setting_row("Многоядерный рендеринг", "Включено")
	_setting_row("MSAA", "4x")
	_setting_row("FXAA", "Выключено")
	_setting_row("VSync", "Выключено")
	_setting_row("Ограничение FPS", "0 (неограничено)")
	_setting_row("Свечение", "Включено")
	_setting_row("Цветокоррекция", "Включено")
	_setting_row("Антиалиасинг", "FXAA")
	_setting_row("Анизотропная фильтрация", "16x")


func _build_image_edges_settings() -> void:
	settings_content.add_child(_label("Позиция краёв / HUD", UiTheme.F_XL, UiTheme.TEXT_MUTED))
	_setting_row("Масштаб HUD", "", true, 1.0)
	_setting_row("Цвет HUD", "Зелёный")
	_setting_row("Масштаб радара", "", true, 1.0)
	_setting_row("Показывать FPS", "Выключено")
	_setting_row("Показывать сетевой график", "Выключено")
	_setting_row("Номера урона", "Включено")
	_setting_row("Позиция обзора оружия", "", true, 0.5)
	settings_content.add_child(_label("Настройка позиции краёв экрана для нестандартных разрешений", 10, C_DIM))


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
	settings_content.add_child(_label("Прицел", UiTheme.F_XL, C_TEXT))
	_crosshair_option("Стиль", ["Классический", "Динамический", "Классический динамический"],
		settings.crosshair_style, func(i: int): settings.crosshair_style = i)
	_crosshair_slider("Размер", 0.5, 6.0, settings.crosshair_size, 0.1,
		func(v: float): settings.crosshair_size = v)
	_crosshair_slider("Толщина", 1.0, 5.0, settings.crosshair_thickness, 0.1,
		func(v: float): settings.crosshair_thickness = v)
	_crosshair_slider("Зазор", 0.0, 10.0, settings.crosshair_gap, 0.5,
		func(v: float): settings.crosshair_gap = v)
	var colors := ["green", "red", "yellow", "blue", "cyan", "white"]
	var color_names := ["Зелёный", "Красный", "Жёлтый", "Синий", "Циан", "Белый"]
	_crosshair_option("Цвет", color_names, maxi(colors.find(settings.crosshair_color), 0),
		func(i: int): settings.crosshair_color = colors[i])
	_crosshair_toggle("Контур", settings.crosshair_outline,
		func(v: bool): settings.crosshair_outline = v)
	_crosshair_toggle("Точка в центре", settings.crosshair_center_dot,
		func(v: bool): settings.crosshair_center_dot = v)
	_crosshair_toggle("T-образный", settings.crosshair_t_style,
		func(v: bool): settings.crosshair_t_style = v)
	_crosshair_slider("Прозрачность", 0.0, 1.0, settings.crosshair_alpha, 0.05,
		func(v: float): settings.crosshair_alpha = v)
	_crosshair_toggle("Следует за отдачей", settings.crosshair_follow_recoil,
		func(v: bool): settings.crosshair_follow_recoil = v)
	settings_content.add_child(_label("Нажмите «Применить», чтобы сохранить изменения.", UiTheme.F_SM, C_DIM))


func _crosshair_option(label: String, items: Array, selected: int, cb: Callable) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _mk_sb(Color(0, 0, 0, 0)))
	settings_content.add_child(row)
	var h := HBoxContainer.new()
	row.add_child(h)
	h.add_child(_label(label, UiTheme.F_MD, C_TEXT))
	h.add_child(Control.new())
	var o := OptionButton.new()
	for item in items:
		o.add_item(String(item))
	o.select(clampi(selected, 0, items.size() - 1))
	o.custom_minimum_size = Vector2(280, 28)
	o.item_selected.connect(cb)
	h.add_child(o)
	_settings_line()


func _crosshair_slider(label: String, min_value: float, max_value: float,
		value: float, step: float, cb: Callable) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _mk_sb(Color(0, 0, 0, 0)))
	settings_content.add_child(row)
	var h := HBoxContainer.new()
	row.add_child(h)
	h.add_child(_label(label, UiTheme.F_MD, C_TEXT))
	h.add_child(Control.new())
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 20)
	var readout := _label("%.1f" % value, UiTheme.F_SM, C_TEXT)
	s.value_changed.connect(func(v: float):
		readout.text = "%.1f" % v
		cb.call(v))
	h.add_child(s)
	h.add_child(readout)
	_settings_line()


func _crosshair_toggle(label: String, value: bool, cb: Callable) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _mk_sb(Color(0, 0, 0, 0)))
	settings_content.add_child(row)
	var h := HBoxContainer.new()
	row.add_child(h)
	h.add_child(_label(label, UiTheme.F_MD, C_TEXT))
	h.add_child(Control.new())
	var b := CheckButton.new()
	b.button_pressed = value
	b.toggled.connect(cb)
	h.add_child(b)
	_settings_line()


func _settings_line() -> void:
	var line := ColorRect.new()
	line.color = C_LINE
	line.custom_minimum_size = Vector2(0, 1)
	settings_content.add_child(line)


func _on_apply_settings() -> void:
	settings.save()
	if nickname_label != null:
		nickname_label.text = settings.nickname
	_set_status("Настройки сохранены")


func _on_reset_settings() -> void:
	settings = GameSettings.new()
	settings.save()
	if nickname_label != null:
		nickname_label.text = settings.nickname
	_rebuild_settings_content()
	_set_status("Настройки сброшены")


func _open_settings() -> void:
	settings_return_screen = current_screen
	if settings_return_screen == "НАСТРОЙКИ":
		settings_return_screen = "ИГРАТЬ"
	_show_screen("НАСТРОЙКИ")


func _close_settings() -> void:
	var target: String = settings_return_screen
	if target == "" or target == "НАСТРОЙКИ":
		target = "ИГРАТЬ"
	_show_screen(target)


# ---------- ИНВЕНТАРЬ ----------

func _build_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	root.add_child(inventory_overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UiTheme.BG_2
	inventory_overlay.add_child(bg)
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tabs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tabs.offset_top = 18
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory_overlay.add_child(tabs)
	tabs.add_child(_icon_button("⌕", func(): _set_status("Поиск")))
	inventory_tabs.clear()
	for cat in INVENTORY_CATEGORIES:
		var captured: String = cat
		var tab := _small_tab_button(cat, func(): _set_inventory_category(captured))
		tabs.add_child(tab)
		inventory_tabs[cat] = tab
	inventory_loadout = _small_tab_button("СНАРЯЖЕНИЕ", func(): _show_screen("СНАРЯЖЕНИЕ"))
	inventory_loadout.name = "LoadoutButton"
	tabs.add_child(inventory_loadout)
	inventory_close = _icon_button("✕", func(): _close_inventory())
	inventory_close.name = "CloseButton"
	tabs.add_child(inventory_close)
	inventory_sort_btn = OptionButton.new()
	inventory_sort_btn.add_item("По новизне")
	inventory_sort_btn.add_item("По имени")
	inventory_sort_btn.add_item("По редкости")
	inventory_sort_btn.add_item("По цене")
	inventory_sort_btn.item_selected.connect(func(idx): _select_inventory_sort(idx))
	inventory_sort_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inventory_sort_btn.offset_left = -180
	inventory_sort_btn.offset_top = 58
	inventory_sort_btn.offset_right = -24
	inventory_sort_btn.offset_bottom = 90
	inventory_overlay.add_child(inventory_sort_btn)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = -8
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
	for key in inventory_tabs.keys():
		var b: Button = inventory_tabs[key]
		b.add_theme_color_override("font_color", C_CYAN if key == cat else C_TEXT)
	var ids: Array = []
	if cat == "ВСЕ" or cat == "ЭКИПИРОВКА":
		ids = WeaponData.WEAPONS.keys()
		ids.sort()
	# сортировка
	if inventory_sort == 1:
		ids.sort_custom(func(a, b): return String(WeaponData.get_weapon(a).get("name", "")).nocasecmp_to(String(WeaponData.get_weapon(b).get("name", ""))) < 0)
	elif inventory_sort == 2:
		ids.sort_custom(func(a, b): return RARITY[abs(int(a)) % RARITY.size()].r > RARITY[abs(int(b)) % RARITY.size()].r)
	elif inventory_sort == 3:
		ids.sort_custom(func(a, b): return int(WeaponData.get_weapon(a).get("price", 0)) > int(WeaponData.get_weapon(b).get("price", 0)))
	for id in ids:
		inventory_grid.add_child(_make_inventory_item(int(id)))
	if ids.is_empty():
		var empty := _label("В этой категории пока нет предметов", 16, C_DIM)
		empty.custom_minimum_size = Vector2(640, 120)
		inventory_grid.add_child(empty)


func _select_inventory_sort(idx: int) -> void:
	inventory_sort = idx
	_rebuild_inventory(inventory_category)


func _open_inventory() -> void:
	_show_screen("ИНВЕНТАРЬ")


func _close_inventory() -> void:
	_show_screen("ИГРАТЬ")
