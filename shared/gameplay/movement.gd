class_name MovementModel
extends RefCounted
## CS2-ported movement model (Source-style accelerate/friction + CS2 air accelerate).
## Units: Hammer units (1 u = 19.05 mm). Positions in Godot are in meters via U_TO_M.
## Deterministic: fixed-point-friendly, no hidden state except on_ground.

const TICK_HZ: int = 64
const TICK_DT: float = 1.0 / 64.0

const U_TO_MM: float = 19.05
const U_TO_M: float = 0.01905

# Verified / measured CS2 convars (memorin.app, 2026-07)
const SV_ACCELERATE: float = 5.5
const SV_FRICTION: float = 5.2
const SV_STOPSPEED: float = 60.0
const SV_AIRACCELERATE: float = 12.0
const SV_AIR_MAX_WISHSPEED: float = 30.0
const GRAVITY: float = 800.0
const JUMP_VELOCITY: float = 301.76
const STEP_HEIGHT_U: float = 18.0
const LADDER_SPEED_U: float = 200.0

const RUN_SPEED_KNIFE: float = 250.0
const WALK_MULT: float = 0.52
const CROUCH_MULT: float = 0.34

enum Buttons {
	JUMP = 1 << 0,
	CROUCH = 1 << 1,
	WALK = 1 << 2,
}

var pos_u: Vector3 = Vector3.ZERO      # Hammer units
var vel_u: Vector3 = Vector3.ZERO
var yaw: int = 0                       # 0..65535
var pitch: int = 0
var on_ground: bool = true
var crouching: bool = false
var walking: bool = false
var alive: bool = true
var on_ladder: bool = false

var move_speed: float = RUN_SPEED_KNIFE  # from equipped weapon (u/s)


func reset(spawn_u: Vector3) -> void:
	pos_u = spawn_u
	vel_u = Vector3.ZERO
	on_ground = true
	crouching = false
	walking = false
	on_ladder = false


func set_weapon_speed(speed_u: float) -> void:
	move_speed = speed_u


## Source engine Accelerate (ground) + CS2 AirAccelerate.
func step(
	buttons: int,
	move_x: float,
	move_z: float,
	yaw_in: int,
	pitch_in: int,
	dt: float,
	ground_check: Callable,
	ladder_check: Callable
) -> void:
	if not alive:
		return
	yaw = yaw_in
	pitch = pitch_in
	crouching = (buttons & Buttons.CROUCH) != 0
	walking = (buttons & Buttons.WALK) != 0

	# desired direction in world space (x = right, z = forward-ish)
	var yaw_rad = (float(yaw) / 65536.0) * TAU
	var fwd = Vector3(-sin(yaw_rad), 0, -cos(yaw_rad))
	var right = Vector3(cos(yaw_rad), 0, -sin(yaw_rad))
	var wish = fwd * move_z + right * move_x
	if wish.length() > 1.0:
		wish = wish.normalized()

	var speed_mult: float = 1.0
	if crouching:
		speed_mult = CROUCH_MULT
	elif walking:
		speed_mult = WALK_MULT
	var wish_speed: float = move_speed * speed_mult

	# ladder: vertical movement based on look pitch
	on_ladder = ladder_check.call(pos_u)
	if on_ladder:
		var ladder_dir = clampf(float(pitch) / 8192.0, -1.0, 1.0)
		vel_u.y = ladder_dir * LADDER_SPEED_U
		var lateral = wish * wish_speed
		vel_u.x = lateral.x
		vel_u.z = lateral.z
		pos_u += vel_u * dt
		return

	if on_ground:
		_friction(dt)
		_accelerate(wish, wish_speed, SV_ACCELERATE, dt)
	else:
		_air_accelerate(wish, wish_speed, dt)

	# jump (bunny hop: only when on ground)
	if (buttons & Buttons.JUMP) != 0 and on_ground:
		vel_u.y = JUMP_VELOCITY
		on_ground = false

	# gravity
	if not on_ground:
		vel_u.y -= GRAVITY * dt

	# integrate
	pos_u += vel_u * dt

	# ground / step
	var ground_y = ground_check.call(pos_u)
	if pos_u.y <= ground_y + STEP_HEIGHT_U and vel_u.y <= 0:
		if pos_u.y <= ground_y:
			pos_u.y = ground_y
			# bhop speed cap: gentle clamp above max speed after landing
			var h = Vector3(vel_u.x, 0, vel_u.z)
			var max_allowed = move_speed * 1.25
			if h.length() > max_allowed:
				var scale = max_allowed / h.length()
				vel_u.x *= scale
				vel_u.z *= scale
			vel_u.y = 0
			on_ground = true
	else:
		on_ground = false


func _friction(dt: float) -> void:
	var speed = sqrt(vel_u.x * vel_u.x + vel_u.z * vel_u.z)
	if speed <= 0.001:
		vel_u.x = 0.0
		vel_u.z = 0.0
		return
	var control = maxf(speed, SV_STOPSPEED)
	var drop = control * SV_FRICTION * dt
	var new_speed = maxf(speed - drop, 0.0)
	var scale = new_speed / speed
	vel_u.x *= scale
	vel_u.z *= scale


func _accelerate(wish: Vector3, wish_speed: float, accel: float, dt: float) -> void:
	var current = vel_u.x * wish.x + vel_u.z * wish.z
	var add_speed = wish_speed - current
	if add_speed <= 0.0:
		return
	var accel_speed = minf(accel * wish_speed * dt, add_speed)
	vel_u.x += wish.x * accel_speed
	vel_u.z += wish.z * accel_speed


func _air_accelerate(wish: Vector3, wish_speed_full: float, dt: float) -> void:
	# CS2: cap wish speed for the "may I add" test, but use the FULL wish speed for
	# the acceleration magnitude. This is the source of air-strafing.
	var wish_speed_capped = minf(wish_speed_full, SV_AIR_MAX_WISHSPEED)
	var current = vel_u.x * wish.x + vel_u.z * wish.z
	var add_speed = wish_speed_capped - current
	if add_speed <= 0.0:
		return
	var accel_speed = minf(SV_AIRACCELERATE * wish_speed_full * dt, add_speed)
	vel_u.x += wish.x * accel_speed
	vel_u.z += wish.z * accel_speed


func to_mm() -> Vector3:
	return pos_u * U_TO_MM


func to_meters() -> Vector3:
	return pos_u * U_TO_M


func from_mm(p_mm: Vector3) -> void:
	pos_u = p_mm / U_TO_MM


func speed_u() -> float:
	return sqrt(vel_u.x * vel_u.x + vel_u.z * vel_u.z)
