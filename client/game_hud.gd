extends CanvasLayer
## Игровой HUD + меню закупки (B). Показывает здоровье, патроны, деньги, прицел.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const WeaponIcon = preload("res://client/weapon_icon.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")

var root: Control
var health_label: Label
var armor_label: Label
var ammo_label: Label
var money_label: Label
var weapon_label: Label
var status_label: Label
var crosshair: Control
var buy_panel: PanelContainer
var buy_grid: GridContainer
var buy_money: Label
var buy_status: Label
var buy_open: bool = false

var loadout: Loadout
var player_state = null
var on_buy = Callable()


func _ready() -> void:
	root = Control.new()
	root.name = "GameHUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_crosshair()
	_build_hud()
	_build_buy_panel()


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
	crosshair.custom_minimum_size = Vector2(40, 40)
	root.add_child(crosshair)
	for offset in [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10), Vector2(0, 10)]:
		var r := ColorRect.new()
		r.color = Color(0.2, 1.0, 0.2, 0.9)
		r.position = offset
		r.size = Vector2(3, 3) if offset.x != 0 else Vector2(3, 3)
		crosshair.add_child(r)


func _build_hud() -> void:
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.offset_left = -320
	bottom.offset_bottom = -10
	bottom.offset_right = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.75)
	sb.set_corner_radius_all(4)
	bottom.add_theme_stylebox_override("panel", sb)
	root.add_child(bottom)
	var v := VBoxContainer.new()
	bottom.add_child(v)
	weapon_label = _mk_label("Weapon", 13, Color.WHITE)
	v.add_child(weapon_label)
	var h := HBoxContainer.new()
	v.add_child(h)
	ammo_label = _mk_label("30 / 90", 18, Color.WHITE)
	h.add_child(ammo_label)
	h.add_child(Control.new())
	health_label = _mk_label("HP 100", 14, Color(0.5, 1.0, 0.5))
	h.add_child(health_label)
	armor_label = _mk_label("ARMOR 0", 12, Color(0.5, 0.75, 1.0))
	h.add_child(armor_label)
	money_label = _mk_label("$16000", 14, Color(0.6, 0.9, 0.5))
	v.add_child(money_label)
	status_label = _mk_label("", 12, Color(1, 0.6, 0.3))
	v.add_child(status_label)
	var hint := _mk_label("WASD — движение  •  B — закупка  •  R — перезарядка  •  F — осмотр", 10, Color(0.6, 0.7, 0.8))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 14
	hint.offset_bottom = -16
	root.add_child(hint)


func _build_buy_panel() -> void:
	buy_panel = PanelContainer.new()
	buy_panel.name = "BuyMenu"
	buy_panel.set_anchors_preset(Control.PRESET_CENTER)
	buy_panel.offset_left = -430
	buy_panel.offset_right = 430
	buy_panel.offset_top = -300
	buy_panel.offset_bottom = 300
	buy_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.97)
	sb.border_color = Color(0.25, 0.6, 0.85)
	sb.set_border_width_all(2)
	buy_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(buy_panel)
	var v := VBoxContainer.new()
	buy_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_mk_label("МЕНЮ ЗАКУПКИ", 20, Color(0.3, 0.8, 1.0)))
	head.add_child(Control.new())
	buy_money = _mk_label("$16000", 16, Color(0.6, 0.9, 0.5))
	head.add_child(buy_money)
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
	buy_status = _mk_label("", 12, Color(1, 0.7, 0.3))
	v.add_child(buy_status)
	v.add_child(_mk_label("B — закрыть", 11, Color(0.6, 0.7, 0.8)))


func toggle_buy() -> void:
	buy_open = not buy_open
	buy_panel.visible = buy_open
	if buy_open:
		_fill_cat("rifle")


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
