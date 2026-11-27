extends CanvasLayer
## Игровой HUD + меню закупки (B). Показывает здоровье, патроны, деньги, прицел.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponIcon = preload("res://client/weapon_icon.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")
const UiTheme = preload("res://client/ui_theme.gd")
const UiIcon = preload("res://client/ui_icon.gd")

signal ui_state_changed

var root: Control
var health_label: Label
var armor_label: Label
var ammo_label: Label
var money_label: Label
var weapon_label: Label
var status_label: Label
var hint_label: Label
var mouse_hint: Label
var crosshair: Control
var crosshair_settings = null
var bottom_panel: PanelContainer
var buy_panel: PanelContainer
var buy_grid: GridContainer
var buy_money: Label
var buy_status: Label
var buy_open: bool = false
var pause_panel: PanelContainer
var pause_open: bool = false

var loadout: Loadout
var player_state = null
var on_buy = Callable()


func _ready() -> void:
	root = Control.new()
	root.name = "GameHUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build_theme()
	add_child(root)
	_build_crosshair()
	_build_hud()
	_build_buy_panel()
	_build_pause_panel()


func setup(player_loadout: Loadout, buy_callback: Callable) -> void:
	loadout = player_loadout
	on_buy = buy_callback
	refresh()


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -20
	crosshair.offset_top = -20
	crosshair.offset_right = 20
	crosshair.offset_bottom = 20
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	apply_crosshair(null)


func apply_crosshair(game_settings) -> void:
	crosshair_settings = game_settings
	for c in crosshair.get_children():
		crosshair.remove_child(c)
		c.queue_free()
	var style: int = int(game_settings.crosshair_style) if game_settings != null else 0
	var size_px: float = (float(game_settings.crosshair_size) * 5.0) if game_settings != null else 10.0
	var thick: float = (float(game_settings.crosshair_thickness) * 1.4) if game_settings != null else 2.8
	var gap_px: float = (float(game_settings.crosshair_gap) * 1.8) if game_settings != null else 5.4
	var alpha: float = (float(game_settings.crosshair_alpha) * float(game_settings.crosshair_opacity)) if game_settings != null else 1.0
	var col := _crosshair_color(game_settings)
	col.a = clampf(alpha, 0.05, 1.0)
	var outline: bool = bool(game_settings.crosshair_outline) if game_settings != null else false
	var t_style: bool = bool(game_settings.crosshair_t_style) if game_settings != null else false
	var dot: bool = bool(game_settings.crosshair_center_dot) if game_settings != null else false
	var center := Vector2(20, 20)
	if style == 1:
		gap_px += 3.0
	elif style == 2:
		gap_px += 1.5
	_add_crosshair_bar(center + Vector2(0, -gap_px - size_px * 0.5), Vector2(thick, size_px), col, outline)
	if not t_style:
		_add_crosshair_bar(center + Vector2(0, gap_px + size_px * 0.5), Vector2(thick, size_px), col, outline)
	_add_crosshair_bar(center + Vector2(-gap_px - size_px * 0.5, 0), Vector2(size_px, thick), col, outline)
	_add_crosshair_bar(center + Vector2(gap_px + size_px * 0.5, 0), Vector2(size_px, thick), col, outline)
	if dot:
		var d := ColorRect.new()
		d.color = col
		d.position = center - Vector2(thick * 0.5, thick * 0.5)
		d.size = Vector2(thick, thick)
		crosshair.add_child(d)


func _add_crosshair_bar(pos: Vector2, box_size: Vector2, color: Color, outline: bool) -> void:
	if outline:
		var outer := ColorRect.new()
		outer.color = Color(0, 0, 0, color.a * 0.85)
		outer.position = pos - Vector2(1, 1)
		outer.size = box_size + Vector2(2, 2)
		crosshair.add_child(outer)
	var r := ColorRect.new()
	r.color = color
	r.position = pos - box_size * 0.5
	r.size = box_size
	crosshair.add_child(r)


func _crosshair_color(game_settings) -> Color:
	if game_settings == null:
		return UiTheme.OK_BRIGHT
	var chosen: String = String(game_settings.crosshair_color)
	match chosen:
		"red": return UiTheme.DANGER
		"yellow": return UiTheme.WARN
		"blue": return UiTheme.TEAM_CT
		"cyan": return UiTheme.ACCENT
		"white": return UiTheme.TEXT
		"custom": return game_settings.crosshair_custom_color
	return UiTheme.OK_BRIGHT


func _build_hud() -> void:
	bottom_panel = PanelContainer.new()
	bottom_panel.name = "StatusPanel"
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_panel.offset_left = -340
	bottom_panel.offset_top = -124
	bottom_panel.offset_right = -14
	bottom_panel.offset_bottom = -14
	bottom_panel.add_theme_stylebox_override("panel", UiTheme.stylebox(
		Color(0.03, 0.05, 0.08, 0.82), Color(0, 0, 0, 0), UiTheme.R_MD, 0, 10, 6))
	root.add_child(bottom_panel)
	var v := VBoxContainer.new()
	bottom_panel.add_child(v)
	weapon_label = _mk_label("Weapon", UiTheme.F_MD, UiTheme.TEXT)
	v.add_child(weapon_label)
	var h := HBoxContainer.new()
	v.add_child(h)
	ammo_label = _mk_label("30 / 90", UiTheme.F_LG + 2, UiTheme.TEXT)
	h.add_child(ammo_label)
	h.add_child(Control.new())
	health_label = _mk_label("HP 100", UiTheme.F_MD, UiTheme.OK_BRIGHT)
	h.add_child(health_label)
	armor_label = _mk_label("ARMOR 0", UiTheme.F_SM, UiTheme.TEAM_CT)
	h.add_child(armor_label)
	money_label = _mk_label("$16000", UiTheme.F_MD, UiTheme.OK)
	v.add_child(money_label)
	status_label = _mk_label("", UiTheme.F_SM, UiTheme.WARN)
	v.add_child(status_label)
	hint_label = _mk_label("Кликните по экрану, чтобы захватить мышь", UiTheme.F_XS, UiTheme.TEXT_MUTED)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 14
	hint_label.offset_top = -34
	hint_label.offset_right = 620
	hint_label.offset_bottom = -12
	root.add_child(hint_label)
	mouse_hint = _mk_label("КЛИКНИТЕ, ЧТОБЫ НАЧАТЬ ИГРУ", UiTheme.F_LG + 2, UiTheme.TEXT)
	mouse_hint.name = "MouseHint"
	mouse_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mouse_hint.offset_left = -260
	mouse_hint.offset_top = 78
	mouse_hint.offset_right = 260
	mouse_hint.offset_bottom = 110
	mouse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(mouse_hint)


func _build_buy_panel() -> void:
	buy_panel = PanelContainer.new()
	buy_panel.name = "BuyMenu"
	buy_panel.set_anchors_preset(Control.PRESET_CENTER)
	buy_panel.offset_left = -430
	buy_panel.offset_right = 430
	buy_panel.offset_top = -300
	buy_panel.offset_bottom = 300
	buy_panel.visible = false
	buy_panel.add_theme_stylebox_override("panel", UiTheme.stylebox(
		UiTheme.SURFACE_3, UiTheme.ACCENT_DARK, UiTheme.R_LG, 2, UiTheme.S3, UiTheme.S3))
	root.add_child(buy_panel)
	var v := VBoxContainer.new()
	buy_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_mk_label("МЕНЮ ЗАКУПКИ", UiTheme.F_XL, UiTheme.ACCENT))
	head.add_child(Control.new())
	buy_money = _mk_label("$16000", UiTheme.F_LG, UiTheme.OK)
	head.add_child(buy_money)
	var close := Button.new()
	close.name = "IconButton_close"
	close.tooltip_text = "Закрыть закупку (B)"
	var glyph := UiIcon.new()
	glyph.icon_name = "close"
	glyph.icon_color = UiTheme.TEXT
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.offset_left = -12
	glyph.offset_top = -12
	glyph.offset_right = 12
	glyph.offset_bottom = 12
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close.add_child(glyph)
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(toggle_buy)
	head.add_child(close)
	var cats := HBoxContainer.new()
	v.add_child(cats)
	for cat in ["pistol", "smg", "rifle", "sniper", "heavy", "grenade", "gear"]:
		var captured: String = cat
		var b := Button.new()
		b.text = cat.to_upper()
		b.pressed.connect(func(): _fill_cat(captured))
		cats.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	buy_grid = GridContainer.new()
	buy_grid.columns = 4
	scroll.add_child(buy_grid)
	buy_status = _mk_label("", UiTheme.F_SM, UiTheme.WARN)
	v.add_child(buy_status)
	v.add_child(_mk_label("B — закрыть", UiTheme.F_SM, UiTheme.TEXT_MUTED))


func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.name = "PauseMenu"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -220
	pause_panel.offset_right = 220
	pause_panel.offset_top = -160
	pause_panel.offset_bottom = 160
	pause_panel.visible = false
	pause_panel.add_theme_stylebox_override("panel", UiTheme.stylebox(
		Color(0.04, 0.07, 0.11, 0.98), UiTheme.ACCENT_DARK, UiTheme.R_LG, 2, UiTheme.S5, UiTheme.S5))
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pause_panel.add_child(v)
	var title := _mk_label("ПАУЗА", 26, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := Button.new()
	resume.text = "ПРОДОЛЖИТЬ"
	resume.custom_minimum_size = Vector2(0, 46)
	resume.add_theme_font_size_override("font_size", 18)
	resume.pressed.connect(close_pause)
	v.add_child(resume)
	var exit := Button.new()
	exit.text = "В ГЛАВНОЕ МЕНЮ"
	exit.custom_minimum_size = Vector2(0, 46)
	exit.add_theme_font_size_override("font_size", 18)
	exit.pressed.connect(_request_exit)
	v.add_child(exit)
	v.add_child(_mk_label("Esc — закрыть паузу", UiTheme.F_SM, UiTheme.TEXT_MUTED))


func toggle_buy() -> void:
	buy_open = not buy_open
	buy_panel.visible = buy_open
	if buy_open:
		_fill_cat("rifle")
		if pause_open:
			pause_open = false
			pause_panel.visible = false
	ui_state_changed.emit()


func toggle_pause() -> void:
	pause_open = not pause_open
	pause_panel.visible = pause_open
	if pause_open and buy_open:
		buy_open = false
		buy_panel.visible = false
	ui_state_changed.emit()


func close_pause() -> void:
	if not pause_open:
		return
	pause_open = false
	pause_panel.visible = false
	ui_state_changed.emit()


func is_ui_open() -> bool:
	return buy_open or pause_open


func set_mouse_captured(captured: bool) -> void:
	if mouse_hint != null:
		mouse_hint.visible = not captured and not is_ui_open()
	if hint_label != null:
		if captured:
			hint_label.text = "ЛКМ — огонь  •  R — перезарядка  •  B — закупка  •  1/2/3/4 — оружие  •  F/I — осмотр  •  G/ПКМ — граната  •  C — присед  •  Shift — шаг  •  Esc — меню"
		else:
			hint_label.text = "Кликните по экрану, чтобы захватить мышь"


func _request_exit() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func refresh() -> void:
	if loadout == null:
		return
	var wi = loadout.active()
	if wi != null and wi.id >= 0:
		weapon_label.text = WeaponData.get_weapon(wi.id).name
		ammo_label.text = str(wi.mag) + " / " + str(wi.reserve)
	else:
		weapon_label.text = "—"
		ammo_label.text = "0 / 0"
	health_label.text = "HP " + str(player_state.hp) if player_state != null else "HP 100"
	armor_label.text = ("ARMOR " + str(loadout.armor) + (" + HELMET" if loadout.helmet else "")) if loadout != null else "ARMOR 0"
	money_label.text = "$" + str(loadout.money)
	buy_money.text = "$" + str(loadout.money)


func message(text: String) -> void:
	status_label.text = text
	buy_status.text = text


func _fill_cat(cat: String) -> void:
	if buy_grid == null:
		return
	for c in buy_grid.get_children():
		buy_grid.remove_child(c)
		c.queue_free()
	if cat == "gear":
		_fill_gear()
		return
	for id in WeaponData.WEAPONS.keys():
		var w: Dictionary = WeaponData.get_weapon(id)
		if String(w.get("slot", "")) != cat:
			continue
		var team: int = int(w.get("team", WeaponData.Team.ANY))
		if loadout != null and team != WeaponData.Team.ANY and team != loadout.team:
			continue
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(190, 100)
		var vb := VBoxContainer.new()
		p.add_child(vb)
		var icon := WeaponIcon.new()
		icon.weapon_id = id
		icon.custom_minimum_size = Vector2(170, 45)
		vb.add_child(icon)
		vb.add_child(_mk_label(String(w.get("name", "")), 11, Color.WHITE))
		vb.add_child(_mk_label("$" + str(w.get("price", 0)), 11, Color(0.6, 0.9, 0.5)))
		var captured: int = id
		var b := Button.new()
		b.text = "КУПИТЬ"
		b.pressed.connect(func(): _buy(captured))
		vb.add_child(b)
		buy_grid.add_child(p)


func _buy(id: int) -> void:
	if loadout == null:
		return
	if loadout.buy(id):
		var wi = loadout.active()
		if wi == null or wi.id != id:
			loadout.select(_slot_for(id))
		message("Куплено: " + String(WeaponData.get_weapon(id).get("name", "")))
		if on_buy.is_valid():
			on_buy.call(id)
		refresh()
		buy_money.text = "$" + str(loadout.money)
	else:
		message("Недостаточно денег или недоступно для команды")
		refresh()


func _slot_for(id: int) -> int:
	var slot_name: String = String(WeaponData.get_weapon(id).get("slot", ""))
	if slot_name == "pistol": return Loadout.Slot.SECONDARY
	if slot_name in ["smg", "rifle", "sniper", "heavy"]: return Loadout.Slot.PRIMARY
	if slot_name == "melee": return Loadout.Slot.KNIFE
	if slot_name == "utility": return Loadout.Slot.ZEUS
	if slot_name == "objective": return Loadout.Slot.C4
	return -1


func set_player_state(state) -> void:
	player_state = state
	refresh()


func _fill_gear() -> void:
	for item in [["Kevlar", 650, false], ["Kevlar + Helmet", 1000, true]]:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(190, 100)
		var vb := VBoxContainer.new()
		p.add_child(vb)
		vb.add_child(_mk_label(String(item[0]), 13, Color.WHITE))
		vb.add_child(_mk_label("$" + str(item[1]), 11, Color(0.6, 0.9, 0.5)))
		var captured: bool = item[2]
		var b := Button.new()
		b.text = "КУПИТЬ"
		b.pressed.connect(func(): _buy_armor(captured))
		vb.add_child(b)
		buy_grid.add_child(p)


func _buy_armor(with_helmet: bool) -> void:
	if loadout == null:
		return
	if loadout.buy_armor(with_helmet):
		message("Броня куплена" + (" + шлем" if with_helmet else ""))
		refresh()
		buy_money.text = "$" + str(loadout.money)
	else:
		message("Недостаточно денег")
		refresh()
