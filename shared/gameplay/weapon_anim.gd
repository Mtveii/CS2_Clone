class_name WeaponAnimController
extends RefCounted
## CS2-подобный контроллер анимаций оружия: deploy / fire / reload (с фазами) /
## inspect / melee / switch / plant / defuse + отдача с восстановлением + bob/sway.
## Эмитирует событийные строки в `events` — аудио-слой подключается к ним.

const _W = preload("res://shared/gameplay/weapons.gd")

enum State { IDLE, FIRE, RELOAD, DEPLOY, INSPECT, MELEE, SWITCH, PLANT, DEFUSE }
enum MotionState { IDLE, WALK, RUN }

# Реальные тайминги перезарядки CS2 (сек), источник: steam guide + tradeit 2026.
const RELOAD_TIMES: Dictionary = {
	0: 2.27, 1: 2.17, 2: 2.27, 3: 2.27, 4: 3.77, 5: 2.57, 6: 2.27, 7: 2.83, 8: 2.20, 9: 2.27,
	10: 2.57, 11: 2.13, 12: 3.13, 13: 2.94, 14: 3.43, 15: 2.43, 16: 3.37,
	17: 3.03, 18: 3.30, 19: 2.43, 20: 3.07, 21: 3.07, 22: 2.77, 23: 3.77,
	24: 3.70, 25: 3.67, 26: 4.67, 27: 3.07,
	28: 4.74, 29: 4.22, 30: 4.22, 31: 2.47, 32: 5.70, 33: 5.70,
}

# Время восстановления точности после выстрела (AK 0.368, M4A4 0.339 — csdb.gg).
const RECOVERY: Dictionary = {19: 0.368, 20: 0.339, 21: 0.339}

# Детерминированные паттерны отдачи (первые 5 выстрелов вверх, затем горизонталь).
const AK_PATTERN: Array = [
	Vector2(0, -0.9), Vector2(0, -1.8), Vector2(0, -2.6), Vector2(0, -3.2), Vector2(0, -3.6),
	Vector2(-0.4, -3.8), Vector2(-1.0, -3.7), Vector2(-1.6, -3.3), Vector2(-2.0, -2.8),
	Vector2(-1.4, -2.5), Vector2(0.2, -2.4), Vector2(1.4, -2.3), Vector2(2.2, -2.0),
]

var state: int = State.IDLE
var sub_phase: int = 0          # 0=mag out,1=mag in,2=bolt
var timer: float = 0.0
var weapon_id: int = 20         # AK47 по умолчанию
var shots_fired: int = 0
var recoil: Vector2 = Vector2.ZERO
var recovery_left: float = 0.0
var motion_state: int = MotionState.IDLE
var motion_speed: float = 0.0

# Выходные трансформы для viewmodel.
var pos_offset: Vector3 = Vector3.ZERO
var rot_offset: Vector3 = Vector3.ZERO
var fov_offset: float = 0.0
var events: Array = []          # очищается каждый tick

var deploy_time: float = 0.30
var inspect_time: float = 3.2
var melee_time: float = 0.65
var switch_time: float = 0.25
var plant_time: float = 3.2
var defuse_time: float = 5.0


func set_weapon(id: int) -> void:
	weapon_id = id
	shots_fired = 0
	recoil = Vector2.ZERO
	recovery_left = 0.0


func reload_duration() -> float:
	return float(RELOAD_TIMES.get(weapon_id, 2.5))


func cancel_action() -> void:
	## Сброс текущего one-shot (например, отмена перезарядки при смене оружия).
	state = State.IDLE
	sub_phase = 0
	timer = 0.0


func equip(id: int) -> void:
	## Смена оружия прерывает всё текущее состояние и запускает equip 0.2–0.4с.
	set_weapon(id)
	state = State.DEPLOY
	timer = deploy_time
	pos_offset = Vector3.ZERO
	rot_offset = Vector3.ZERO
	events.append("equip")


func update_motion(speed_u: float) -> void:
	## Отдельный от one-shot состояний слой движения: IDLE ↔ WALK ↔ RUN.
	motion_speed = speed_u
	if speed_u < 30.0:
		motion_state = MotionState.IDLE
	elif speed_u < 180.0:
		motion_state = MotionState.WALK
	else:
		motion_state = MotionState.RUN


func reset() -> void:
	state = State.DEPLOY
	timer = deploy_time
	events.append("deploy")


func request_fire() -> bool:
	if state != State.IDLE:
		return false
	state = State.FIRE
	timer = _W.fire_interval(weapon_id)
	shots_fired += 1
	# отдача по_pattern (детерминированная), для полуавтоматов — случайная малая
	var pattern: Array = AK_PATTERN
	var idx: int = (shots_fired - 1) % pattern.size()
	var kick: Vector2 = pattern[idx]
	if String(_W.WEAPONS[weapon_id].get("slot", "")) == "sniper" or weapon_id == 9 or weapon_id == 10:
		kick = Vector2(0, -4.5)
	recoil += kick
	recovery_left = float(RECOVERY.get(weapon_id, 0.30))
	events.append("fire")
	return true


func request_reload() -> bool:
	if state != State.IDLE:
		return false
	state = State.RELOAD
	sub_phase = 0
	timer = reload_duration() * 0.45
	events.append("reload_start")
	return true


func request_inspect() -> bool:
	if state == State.RELOAD or state == State.INSPECT:
		return false
	state = State.INSPECT
	timer = inspect_time
	events.append("inspect_start")
	return true


func request_melee() -> bool:
	if state == State.MELEE:
		return false
	state = State.MELEE
	timer = melee_time
	events.append("melee_swing")
	return true


func request_switch() -> bool:
	if state == State.SWITCH:
		return false
	state = State.SWITCH
	timer = switch_time
	events.append("switch")
	return true


func request_plant() -> bool:
	if state != State.IDLE:
		return false
	state = State.PLANT
	timer = plant_time
	events.append("plant_start")
	return true


func request_defuse() -> bool:
	if state != State.IDLE:
		return false
	state = State.DEFUSE
	timer = defuse_time
	events.append("defuse_start")
	return true


func tick(dt: float) -> void:
	events.clear()
	# Восстановление отдачи. Важно доводить её до нуля, а не только пока
	# идёт recovery_left, иначе после выстрелов остаётся постоянный сдвиг
	# viewmodel («тряска»/перекос оружия).
	if recovery_left > 0.0:
		recovery_left = maxf(recovery_left - dt, 0.0)
	if recovery_left > 0.0 or recoil.length() > 0.001:
		recoil = recoil.lerp(Vector2.ZERO, clampf(dt * 6.0, 0.0, 1.0))
		if recoil.length() < 0.001:
			recoil = Vector2.ZERO

	if state == State.IDLE:
		pos_offset = Vector3(0, sin(timer * 2.0) * 0.002, 0)
		rot_offset = Vector3(recoil.y * 0.01, recoil.x * 0.01, 0)
		fov_offset = 0.0
		timer += dt
		return

	timer -= dt
	var total: float = maxf(_state_duration(), 0.001)
	var t: float = clampf(1.0 - (timer / total), 0.0, 1.0)
	match state:
		State.FIRE:
			pos_offset = Vector3(0, 0, -0.02 * (1.0 - t))
			rot_offset = Vector3(-0.05 * (1.0 - t), 0, 0)
			if timer <= 0:
				state = State.IDLE
				timer = 0.0
		State.RELOAD:
			# 3 фазы: вытаскивание магазина -> вставка -> затвор
			var p0: float = 0.40
			var p1: float = 0.75
			if t < p0 and sub_phase == 0:
				pos_offset = Vector3(0.04, -0.10 * sin(t / p0 * PI), 0)
				rot_offset = Vector3(0, 0, 0.25 * sin(t / p0 * PI))
			elif t >= p0 and sub_phase == 0:
				sub_phase = 1
				events.append("reload_mag_out")
			if t >= p0 and t < p1 and sub_phase == 1:
				pos_offset = Vector3(0.06 * sin((t - p0) / (p1 - p0) * PI), -0.06, 0)
				rot_offset = Vector3(0.15, 0, 0.2 * sin((t - p0) / (p1 - p0) * PI))
			elif t >= p1 and sub_phase == 1:
				sub_phase = 2
				events.append("reload_mag_in")
			if t >= p1 and sub_phase == 2:
				pos_offset = Vector3(0, -0.03, 0)
				rot_offset = Vector3(-0.25 * (1.0 - t), 0, -0.15)
			if timer <= 0:
				events.append("reload_bolt")
				events.append("reload_done")
				state = State.IDLE
				sub_phase = 0
				timer = 0.0
		State.DEPLOY:
			pos_offset = Vector3(0, -0.22 * (1.0 - t), 0)
			rot_offset = Vector3(0.55 * (1.0 - t), 0, 0)
			if timer <= 0:
				state = State.IDLE
				timer = 0.0
		State.INSPECT:
			rot_offset = Vector3(0, sin(t * TAU) * 0.55, sin(t * TAU) * 0.15)
			pos_offset = Vector3(0.05 * sin(t * TAU), 0.02 * sin(t * TAU * 2), 0)
			if t >= 0.35 and not events.has("inspect_spin"):
				events.append("inspect_spin")
			if timer <= 0:
				events.append("inspect_end")
				state = State.IDLE
				timer = 0.0
		State.MELEE:
			pos_offset = Vector3(0, 0, -0.35 * (1.0 - absf(1.0 - 2.0 * t)))
			rot_offset = Vector3(-0.5 * (1.0 - absf(1.0 - 2.0 * t)), 0, 0)
			if t >= 0.5 and not events.has("melee_hit"):
				events.append("melee_hit")
			if timer <= 0:
				state = State.IDLE
				timer = 0.0
		State.SWITCH:
			pos_offset = Vector3(0, -0.3 * absf(1.0 - 2.0 * t), 0)
			rot_offset = Vector3(0.3 * absf(1.0 - 2.0 * t), 0, 0)
			if timer <= 0:
				state = State.IDLE
				timer = 0.0
		State.PLANT:
			pos_offset = Vector3(0, -0.15 * t, 0)
			rot_offset = Vector3(0.3 * t, 0, 0)
			if t >= 0.9 and not events.has("plant_done"):
				events.append("plant_done")
			if timer <= 0:
				state = State.IDLE
				timer = 0.0
		State.DEFUSE:
			pos_offset = Vector3(0, -0.12 * t, 0)
			rot_offset = Vector3(0.25 * t, 0, 0.2 * sin(t * TAU * 4))
			if timer <= 0:
				events.append("defuse_done")
				state = State.IDLE
				timer = 0.0


func _state_duration() -> float:
	match state:
		State.FIRE: return _W.fire_interval(weapon_id)
		State.RELOAD: return reload_duration()
		State.DEPLOY: return deploy_time
		State.INSPECT: return inspect_time
		State.MELEE: return melee_time
		State.SWITCH: return switch_time
		State.PLANT: return plant_time
		State.DEFUSE: return defuse_time
	return 0.1


func is_idle() -> bool:
	return state == State.IDLE


## Модификаторы bob/sway от движения (используются настройки viewmodel).
func apply_viewmodel_motion(speed_u: float, crouch: bool, dt: float, bob: float, sway: float) -> void:
	var amp: float = clampf(speed_u / 250.0, 0.0, 1.0) * bob
	pos_offset.x += sin(timer * 6.0) * 0.01 * amp
	pos_offset.y += absf(cos(timer * 6.0)) * 0.008 * amp
	if crouch:
		pos_offset.y -= 0.02
	rot_offset.z += sin(timer * 3.0) * 0.01 * sway
