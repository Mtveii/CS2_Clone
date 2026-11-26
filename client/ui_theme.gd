extends RefCounted
## Единая дизайн-система интерфейса (см. docs/UI_STYLEGUIDE.md).
## Все экраны лобби и HUD берут цвета/радиусы/отступы отсюда, чтобы
## кнопки, панели и карточки выглядели как один продукт.
## Палитра — тёмный тактический интерфейс: графит + один циановый акцент,
## янтарный T и синий CT. Никаких случайных цветов и радиусов на местах.

# --- Палитра ---
const BG := Color(0.045, 0.06, 0.09, 1.0)
const BG_2 := Color(0.07, 0.10, 0.16, 1.0)
const SURFACE := Color(0.075, 0.095, 0.13, 0.96)
const SURFACE_2 := Color(0.11, 0.14, 0.19, 0.98)
const SURFACE_3 := Color(0.055, 0.07, 0.10, 0.94)
const ACCENT := Color(0.28, 0.72, 0.94)
const ACCENT_DARK := Color(0.16, 0.42, 0.60)
const ACCENT_SOFT := Color(0.18, 0.42, 0.58, 0.65)
const TEXT := Color(0.90, 0.92, 0.95)
const TEXT_MUTED := Color(0.55, 0.60, 0.68)
const TEXT_FAINT := Color(0.40, 0.45, 0.52)
const LINE := Color(0.20, 0.25, 0.32)
const LINE_STRONG := Color(0.30, 0.40, 0.50)
const OK := Color(0.42, 0.68, 0.20)
const OK_BRIGHT := Color(0.30, 0.85, 0.30)
const WARN := Color(0.88, 0.62, 0.22)
const DANGER := Color(0.82, 0.30, 0.28)
const TEAM_T := Color(0.85, 0.65, 0.25)
const TEAM_CT := Color(0.30, 0.60, 0.90)

# --- Радиусы (только эти значения) ---
const R_NONE := 0
const R_SM := 4
const R_MD := 8
const R_LG := 12
const R_PILL := 999

# --- Отступы ---
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32

# --- Типографика ---
const F_XS := 10
const F_SM := 11
const F_MD := 13
const F_LG := 16
const F_XL := 20
const F_TITLE := 24
const F_HERO := 32


static func radius(value: int) -> int:
	## Приводит произвольный радиус к шкале системы.
	if value <= 0:
		return R_NONE
	if value <= R_SM:
		return R_SM
	if value <= R_MD:
		return R_MD
	return R_LG


static func stylebox(bg: Color, border: Color = LINE, r: int = R_MD,
		border_width: int = 1, pad_x: int = S2, pad_y: int = S1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius(r))
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func flat(bg: Color, r: int = R_MD) -> StyleBoxFlat:
	return stylebox(bg, Color(0, 0, 0, 0), r, 0)


static func button_style(kind: String = "ghost") -> StyleBoxFlat:
	match kind:
		"primary":
			return stylebox(Color(0.20, 0.52, 0.30), OK, R_SM)
		"accent":
			return stylebox(Color(0.13, 0.33, 0.46), ACCENT_DARK, R_SM)
		"accent_hover":
			return stylebox(ACCENT_SOFT, ACCENT, R_SM)
		"hover_overlay":
			return stylebox(ACCENT_SOFT, Color(0, 0, 0, 0), R_SM, 0)
		"ghost":
			return stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), R_SM, 0)
		"danger":
			return stylebox(Color(0.30, 0.12, 0.12), DANGER, R_SM)
	return stylebox(SURFACE_2, LINE, R_SM)


static func build_theme() -> Theme:
	## Базовые стили для всех Control: явные override на местах всё ещё
	## побеждают, но новые элементы сразу выглядят в системе.
	var t := Theme.new()
	t.default_font_size = F_MD
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", F_MD)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_font_size("font_size", "Button", F_MD)
	t.set_stylebox("normal", "Button", button_style("ghost"))
	t.set_stylebox("hover", "Button", stylebox(ACCENT_SOFT, Color(0, 0, 0, 0), R_SM, 0))
	t.set_stylebox("pressed", "Button", stylebox(Color(0.10, 0.26, 0.38, 0.8), ACCENT_DARK, R_SM))
	t.set_stylebox("disabled", "Button", flat(Color(0, 0, 0, 0), R_SM))
	t.set_stylebox("panel", "PanelContainer", stylebox(SURFACE, LINE, R_MD))
	t.set_stylebox("panel", "Panel", stylebox(SURFACE, LINE, R_MD))
	t.set_stylebox("normal", "LineEdit", stylebox(BG_2, LINE_STRONG, R_SM))
	t.set_stylebox("focus", "LineEdit", stylebox(BG_2, ACCENT, R_SM))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	t.set_font_size("font_size", "LineEdit", F_MD)
	t.set_stylebox("normal", "CheckButton", flat(Color(0, 0, 0, 0), R_SM))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", F_SM)
	t.set_stylebox("normal", "OptionButton", stylebox(SURFACE_2, LINE_STRONG, R_SM))
	t.set_stylebox("hover", "OptionButton", stylebox(SURFACE_2.lightened(0.08), ACCENT, R_SM))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "OptionButton", F_SM)
	return t
