extends Node
## Аудио-слой:EventListener анимаций, пул проигрывателей, 3D-звук, громкости из настроек.
## Звуки оригинальные (процедурные WAV в assets/audio), не ассеты Valve.

const GameSettings = preload("res://client/settings.gd")
const WeaponData = preload("res://shared/gameplay/weapons.gd")

const POOL_SIZE: int = 20
const AUDIO_DIR := "res://assets/audio/"

var streams: Dictionary = {}
var players: Array = []
var players_3d: Array = []
var settings: GameSettings

var volume_sfx: float = 1.0
var volume_master: float = 0.8
var next_player: int = 0

# Категория оружия -> имя звука выстрела
const FIRE_SOUNDS: Dictionary = {
	"pistol": "fire_pistol",
	"smg": "fire_smg",
	"rifle": "fire_rifle",
	"sniper": "fire_sniper",
	"heavy": "fire_shotgun",
	"melee": "melee_swing",
	"utility": "switch",
}


func _ready() -> void:
	_load_streams()
	_setup_pool()


func _load_streams() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		push_warning("Audio directory not found: " + AUDIO_DIR)
		return
	for f in dir.get_files():
		if not f.ends_with(".wav"):
			continue
		var key := f.substr(0, f.length() - 4)
		var s := load(AUDIO_DIR + f)
		if s != null:
			streams[key] = s


func _setup_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_%d" % i
		p.bus = "Master"
		add_child(p)
		players.append(p)
	for i in range(POOL_SIZE):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "Sfx3D_%d" % i
		p3.bus = "Master"
		p3.max_db = 6.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = 1000.0  # 1 Hammer unit = 19.05mm -> ~0.05 units per meter
		add_child(p3)
		players_3d.append(p3)


func update_settings(s: GameSettings) -> void:
	settings = s
	volume_master = s.volume_master
	volume_sfx = s.volume_sfx
	_apply_volumes()


func _apply_volumes() -> void:
	var v: float = clampf(volume_master * volume_sfx, 0.0, 1.0)
	var db: float = linear_to_db(maxf(v, 0.0001))
	for p in players:
		p.volume_db = db
	for p in players_3d:
		p.volume_db = db


func play(name: String, volume_scale: float = 1.0, pitch: float = 1.0) -> void:
	if not streams.has(name) or players.is_empty():
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(clampf(volume_master * volume_sfx * volume_scale, 0.0, 1.0), 0.0001))
	p.play()


func play_3d(name: String, pos: Vector3, max_dist_u: float = 1200.0, volume_scale: float = 1.0) -> void:
	if not streams.has(name) or players_3d.is_empty():
		return
	var p: AudioStreamPlayer3D = players_3d[next_player % players_3d.size()]
	next_player = (next_player + 1) % players_3d.size()
	p.stream = streams[name]
	p.global_position = pos * 0.01905  # Hammer units -> meters
	p.max_distance = max_dist_u * 0.01905
	p.pitch_scale = 1.0
	p.volume_db = linear_to_db(maxf(clampf(volume_master * volume_sfx * volume_scale, 0.0, 1.0), 0.0001))
	p.play()


func weapon_fire(weapon_id: int) -> void:
	var w: Dictionary = WeaponData.get_weapon(weapon_id)
	var slot: String = String(w.get("slot", ""))
	var snd: String = String(FIRE_SOUNDS.get(slot, "fire_rifle"))
	# Глушители: USP-S / M4A1-S
	if weapon_id == WeaponData.WeaponId.USP or weapon_id == WeaponData.WeaponId.M4A1S:
		snd = "fire_silenced"
	play(snd)


## Обработка событий из WeaponAnimController.events.
func handle_anim_events(events: Array, weapon_id: int) -> void:
	for e in events:
		match String(e):
			"fire": weapon_fire(weapon_id)
			"reload_start", "reload_mag_out": play("reload_mag_out")
			"reload_mag_in": play("reload_mag_in")
			"reload_bolt": play("reload_bolt")
			"inspect_start", "inspect_spin": play("inspect")
			"deploy": play("deploy")
			"melee_swing": play("melee_swing")
			"melee_hit": play("hit")
			"switch": play("switch")
			"plant_done": play("plant")
			"defuse_done": play("defuse")


func grenade_event(kind: String) -> void:
	match kind:
		"pull": play("switch")
		"throw": play("melee_swing")
		"bounce": play("step_metal", 0.5)
		"he_explode": play("explosion")
		"flash_explode": play("flash")
		"smoke_deploy": play("smoke")
		"fire_start": play("fire_burn")
		"decoy": play("ui_click")


func world_event(kind: String, pos: Vector3, surface: String = "concrete") -> void:
	match kind:
		"footstep": play_3d("step_" + surface, pos, 900.0)
		"land": play_3d("step_" + surface, pos, 1400.0, 1.3)
		"gunshot": play_3d("fire_rifle", pos, 5000.0)
		"explosion": play_3d("explosion", pos, 3000.0)
		"beep": play_3d("beep", pos, 2500.0)
