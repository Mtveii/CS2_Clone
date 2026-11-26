extends RefCounted
## Упрощённый аниматор world-model (игроки, видимые другим).
## Отдельный от view-model: только idle/walk/run/shoot, без reload/осмотра.
## Экономит ресурсы: один маленький state machine на персонажа, без AnimationMixer.

enum State { IDLE, WALK, RUN, SHOOT }

const SHOOT_TIME := 0.12

var state: int = State.IDLE
var timer: float = 0.0
var pos_offset: Vector3 = Vector3.ZERO
var rot_offset: Vector3 = Vector3.ZERO
var phase: float = 0.0


func update_motion(speed_u: float) -> void:
	if state == State.SHOOT:
		return
	if speed_u < 30.0:
		state = State.IDLE
	elif speed_u < 180.0:
		state = State.WALK
	else:
		state = State.RUN


func shoot() -> void:
	## Короткий one-shot; movement не блокируется.
	state = State.SHOOT
	timer = SHOOT_TIME


func tick(dt: float) -> void:
	phase += dt * (6.0 if state == State.WALK else 10.0 if state == State.RUN else 1.5)
	if state == State.SHOOT:
		timer = maxf(timer - dt, 0.0)
		var t: float = 1.0 - (timer / SHOOT_TIME)
		rot_offset = Vector3(-0.08 * (1.0 - t), 0, 0)
		pos_offset = Vector3(0, 0, -0.02 * (1.0 - t))
		if timer <= 0.0:
			state = State.IDLE
			rot_offset = Vector3.ZERO
			pos_offset = Vector3.ZERO
		return
	var amp: float = 0.0 if state == State.IDLE else (0.012 if state == State.WALK else 0.022)
	pos_offset = Vector3(0, absf(sin(phase)) * amp, 0)
	rot_offset = Vector3(0, sin(phase) * amp * 0.5, sin(phase * 0.5) * amp)
