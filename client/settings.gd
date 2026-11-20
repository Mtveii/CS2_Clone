class_name GameSettings
extends RefCounted
## Полная система настроек в стиле CS2 (все категории), сохраняется в user://settings.cfg.
## Значения по умолчанию соответствуют типичным CS2-настройкам.

const CONFIG_PATH := "user://settings.cfg"

# --- Mouse / Keyboard ---
var sensitivity: float = 1.0
var zoom_sensitivity: float = 1.0
var sensitivity_multiplier: float = 1.0  # 1 / 2 / 4
var raw_input: bool = true
var mouse_acceleration: bool = false
var mouse_accel_custom: float = 0.0
var pointer_precision: bool = false
var invert_mouse_y: bool = false
var bind_w: String = "W"
var bind_a: String = "A"
var bind_s: String = "S"
var bind_d: String = "D"
var bind_jump: String = "Space"
var bind_crouch: String = "Ctrl"
var bind_walk: String = "Shift"
var bind_fire: String = "Mouse1"
var bind_reload: String = "R"
var bind_use: String = "E"
var bind_inspect: String = "F"
var bind_drop: String = "G"
var bind_grenade: String = "Mouse2"
var bind_flash: String = "Q"
var bind_smoke: String = "V"
var bind_he: String = "Mouse4"
var bind_molotov: String = "J"

# --- Video ---
var resolution: String = "1280x720"
var aspect_ratio: String = "16:9"
var display_mode: int = 0  # 0=fullscreen,1=windowed,2=borderless
var brightness: float = 0.5
var shadow_quality: int = 2  # 0 low .. 3 high
var texture_quality: int = 2
var effect_detail: int = 2
var shader_detail: int = 2
var boost_player_contrast: bool = true
var multicore_rendering: bool = true
var msaa: int = 0  # 0,2,4,8
var fxaa: bool = false
var vsync: bool = false
var fps_cap: int = 0  # 0 = unlimited
var glow: bool = true
var color_correction: bool = true
var antialiasing: int = 0
var anisotropic: int = 4

# --- Audio ---
var volume_master: float = 0.8
var volume_music: float = 0.5
var volume_sfx: float = 1.0
var volume_voice: float = 1.0
var hrtf: bool = true
var surround: bool = false
var voice_volume: float = 0.7
var mic_volume: float = 1.0
var sound_device: String = "Default"

# --- Crosshair ---
var crosshair_style: int = 0  # 0=classic static,1=dynamic,2=classic dynamic
var crosshair_color: String = "green"  # green, red, yellow, blue, cyan, white, custom
var crosshair_custom_color: Color = Color(0.2, 1, 0.2)
var crosshair_size: float = 2.0
var crosshair_thickness: float = 2.0
var crosshair_gap: float = 3.0
var crosshair_outline: bool = true
var crosshair_outline_thickness: float = 1.0
var crosshair_center_dot: bool = false
var crosshair_opacity: float = 1.0
var crosshair_follow_recoil: bool = false
var crosshair_t_style: bool = false
var crosshair_alpha: float = 1.0

# --- Viewmodel / Gameplay ---
var viewmodel_fov: float = 68.0
var viewmodel_offset_x: float = 1.5
var viewmodel_offset_y: float = -1.5
var viewmodel_offset_z: float = -2.0
var viewmodel_bob: float = 0.4
var viewmodel_sway: float = 1.0
var weapon_hand: int = 2  # 0=left,1=right,2=both
var ragdoll_physics: bool = true
var helmet: bool = true
var flashlight: bool = false
var auto_reload: bool = false
var hud_scale: float = 1.0
var hud_color: String = "default"
var radar_scale: float = 1.0
var show_fps: bool = false
var show_netgraph: bool = false
var damage_numbers: bool = true

# --- Game / Network ---
var nickname: String = "Player"
var language: String = "English"
var region: String = "Auto"
var max_ping: int = 100
var steam_group: bool = true

var settings_changed: bool = false


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mouse", "sensitivity", sensitivity)
	cfg.set_value("mouse", "zoom_sensitivity", zoom_sensitivity)
	cfg.set_value("mouse", "sensitivity_multiplier", sensitivity_multiplier)
	cfg.set_value("mouse", "raw_input", raw_input)
	cfg.set_value("mouse", "mouse_acceleration", mouse_acceleration)
	cfg.set_value("mouse", "invert_mouse_y", invert_mouse_y)
	cfg.set_value("keys", "bind_w", bind_w)
	cfg.set_value("keys", "bind_jump", bind_jump)
	cfg.set_value("keys", "bind_fire", bind_fire)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "fps_cap", fps_cap)
	cfg.set_value("audio", "volume_master", volume_master)
	cfg.set_value("audio", "volume_sfx", volume_sfx)
	cfg.set_value("crosshair", "style", crosshair_style)
	cfg.set_value("crosshair", "color", crosshair_color)
	cfg.set_value("crosshair", "size", crosshair_size)
	cfg.set_value("crosshair", "thickness", crosshair_thickness)
	cfg.set_value("crosshair", "gap", crosshair_gap)
	cfg.set_value("viewmodel", "fov", viewmodel_fov)
	cfg.set_value("viewmodel", "offset_x", viewmodel_offset_x)
	cfg.set_value("game", "nickname", nickname)
	cfg.save(CONFIG_PATH)
	settings_changed = false


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	sensitivity = float(cfg.get_value("mouse", "sensitivity", sensitivity))
	zoom_sensitivity = float(cfg.get_value("mouse", "zoom_sensitivity", zoom_sensitivity))
	sensitivity_multiplier = float(cfg.get_value("mouse", "sensitivity_multiplier", sensitivity_multiplier))
	raw_input = bool(cfg.get_value("mouse", "raw_input", raw_input))
	mouse_acceleration = bool(cfg.get_value("mouse", "mouse_acceleration", mouse_acceleration))
	invert_mouse_y = bool(cfg.get_value("mouse", "invert_mouse_y", invert_mouse_y))
	bind_w = str(cfg.get_value("keys", "bind_w", bind_w))
	bind_jump = str(cfg.get_value("keys", "bind_jump", bind_jump))
	bind_fire = str(cfg.get_value("keys", "bind_fire", bind_fire))
	resolution = str(cfg.get_value("video", "resolution", resolution))
	brightness = float(cfg.get_value("video", "brightness", brightness))
	shadow_quality = int(cfg.get_value("video", "shadow_quality", shadow_quality))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	fps_cap = int(cfg.get_value("video", "fps_cap", fps_cap))
	volume_master = float(cfg.get_value("audio", "volume_master", volume_master))
	volume_sfx = float(cfg.get_value("audio", "volume_sfx", volume_sfx))
	crosshair_style = int(cfg.get_value("crosshair", "style", crosshair_style))
	crosshair_color = str(cfg.get_value("crosshair", "color", crosshair_color))
	crosshair_size = float(cfg.get_value("crosshair", "size", crosshair_size))
	crosshair_thickness = float(cfg.get_value("crosshair", "thickness", crosshair_thickness))
	crosshair_gap = float(cfg.get_value("crosshair", "gap", crosshair_gap))
	viewmodel_fov = float(cfg.get_value("viewmodel", "fov", viewmodel_fov))
	viewmodel_offset_x = float(cfg.get_value("viewmodel", "offset_x", viewmodel_offset_x))
	nickname = str(cfg.get_value("game", "nickname", nickname))


func effective_sensitivity() -> float:
	return sensitivity * sensitivity_multiplier


func all_categories() -> Array:
	return ["Mouse / Keyboard", "Video", "Audio", "Crosshair", "Viewmodel / Gameplay", "Game / Network"]
