class_name GrenadeSystem
extends RefCounted
## CS2 grenade physics and effects ported from measured/verified values.
## Distances in Hammer units (u), time in seconds.

enum Type { HE, FLASH, SMOKE, MOLOTOV, INCENDIARY, DECOY }
enum ThrowType { LONG, SHORT, MEDIUM }

const THROW_SPEED_U: float = 675.0
const GRAVITY_U_S2: float = 320.0
const BOUNCE: float = 0.45
const JUMP_THROW_LATCH_S: float = 0.1

const SMOKE_GRID: int = 32
const SMOKE_DURATION_S: float = 18.0
const SMOKE_BLOOM_S: float = 2.0
const SMOKE_HE_GAP_S: float = 2.0
const FLASH_MAX_S: float = 4.87
const HE_MAX_DAMAGE: int = 98
const FIRE_DURATION_S: float = 7.03125
const FIRE_MAX_DPS: int = 40
const DECOY_DURATION_S: float = 15.0

const THROW_SPEED_MULT: Dictionary = {
	ThrowType.LONG: 1.0,
	ThrowType.SHORT: 0.45,
	ThrowType.MEDIUM: 0.72,
}

class ActiveGrenade:
	var type: int
	var pos: Vector3
	var vel: Vector3
	var fuse: float = 0.0
	var bounced: int = 0
	var owner_id: int = 0
	var team: int = 0
	var jump_throw: bool = false
	var latched_vel: Vector3 = Vector3.ZERO


class SmokeCloud:
	var center: Vector3
	var time_left: float = SMOKE_DURATION_S
	var voxels: PackedByteArray = PackedByteArray()  # SMOKE_GRID^3 occupancy
	var he_gap_until: float = 0.0


class FireZone:
	var center: Vector3
	var time_left: float = FIRE_DURATION_S
	var owner_team: int = 0

	static func new_with(pos: Vector3, team: int) -> FireZone:
		var f := FireZone.new()
		f.center = pos
		f.owner_team = team
		return f


var active: Array = []        # ActiveGrenade
var smokes: Array = []         # SmokeCloud
var fires: Array = []          # FireZone
var flashes: Array = []        # Dictionary {pos, time_left}


func reset() -> void:
	active.clear()
	smokes.clear()
	fires.clear()
	flashes.clear()


func throw_grenade(
	type: int,
	origin: Vector3,
	dir: Vector3,
	throw_type: int,
	owner_id: int,
	team: int,
	velocity_at_throw: Vector3 = Vector3.ZERO,
	jump_throw: bool = false
) -> ActiveGrenade:
	var g := ActiveGrenade.new()
	g.type = type
	g.pos = origin
	var speed: float = THROW_SPEED_U * float(THROW_SPEED_MULT.get(throw_type, 1.0))
	var dir_n: Vector3 = dir.normalized()
	g.vel = dir_n * speed
	if jump_throw:
		# Jump-throw latch: velocity snapshot at +0.1 s after jump.
		g.jump_throw = true
		g.latched_vel = velocity_at_throw + Vector3(0, -GRAVITY_U_S2 * JUMP_THROW_LATCH_S, 0)
		g.vel = dir_n * speed + Vector3(0, g.latched_vel.y, 0)
	g.fuse = 2.0
	g.owner_id = owner_id
	g.team = team
	active.append(g)
	return g


func step(dt: float, ground_check: Callable) -> void:
	for i in range(active.size() - 1, -1, -1):
		var g: ActiveGrenade = active[i]
		g.vel.y -= GRAVITY_U_S2 * dt
		g.pos += g.vel * dt
		var ground_y: float = ground_check.call(g.pos)
		if g.pos.y <= ground_y:
			g.pos.y = ground_y
			g.vel.y = absf(g.vel.y) * BOUNCE
			g.vel.x *= 0.7
			g.vel.z *= 0.7
			g.bounced += 1
			if absf(g.vel.y) < 20.0:
				g.vel.y = 0.0
		g.fuse -= dt
		if g.fuse <= 0.0:
			_detonate(g)
			active.remove_at(i)

	# smoke timers
	for i in range(smokes.size() - 1, -1, -1):
		var s: SmokeCloud = smokes[i]
		s.time_left -= dt
		if s.he_gap_until > 0.0:
			s.he_gap_until -= dt
		if s.time_left <= 0.0:
			smokes.remove_at(i)
	# fire timers
	for i in range(fires.size() - 1, -1, -1):
		var f: FireZone = fires[i]
		f.time_left -= dt
		if f.time_left <= 0.0:
			fires.remove_at(i)
	# flash timers
	for i in range(flashes.size() - 1, -1, -1):
		var fl: Dictionary = flashes[i]
		fl.time_left -= dt
		if fl.time_left <= 0.0:
			flashes.remove_at(i)


func _detonate(g: ActiveGrenade) -> void:
	match g.type:
		Type.SMOKE:
			_spawn_smoke(g.pos)
		Type.FLASH:
			flashes.append({"pos": g.pos, "time_left": FLASH_MAX_S, "team": g.team})
		Type.HE:
			_he_blast(g.pos)
		Type.MOLOTOV, Type.INCENDIARY:
			fires.append(FireZone.new_with(g.pos, g.team))
		Type.DECOY:
			pass  # audio/radar event emitted by gameplay layer


func _spawn_smoke(pos: Vector3) -> void:
	var s := SmokeCloud.new()
	s.center = pos
	s.voxels.resize(SMOKE_GRID * SMOKE_GRID * SMOKE_GRID)
	var r: int = SMOKE_GRID / 2
	for z in range(SMOKE_GRID):
		for y in range(SMOKE_GRID):
			for x in range(SMOKE_GRID):
				var dx := x - r
				var dy := y - r
				var dz := z - r
				if dx * dx + dy * dy + dz * dz <= r * r:
					s.voxels[x + y * SMOKE_GRID + z * SMOKE_GRID * SMOKE_GRID] = 1
	smokes.append(s)
	# smoke extinguishes overlapping fire (1/3 coverage simplified: center overlap)
	for i in range(fires.size() - 1, -1, -1):
		if fires[i].center.distance_to(pos) < 150.0:
			fires.remove_at(i)


func _he_blast(pos: Vector3) -> void:
	# HE creates a temporary gap in nearby smokes.
	for s in smokes:
		if s.center.distance_to(pos) < 250.0:
			s.he_gap_until = SMOKE_HE_GAP_S


func he_damage(distance_u: float, armored: bool) -> int:
	if distance_u > 350.0:
		return 0
	var t: float = 1.0 - (distance_u / 350.0)
	var d: int = int(round(float(HE_MAX_DAMAGE) * t))
	if armored:
		d = int(round(float(d) * 0.58))  # ~57 at point blank
	return d


func flash_duration(player_pos: Vector3, flash_pos: Vector3, look_dir: Vector3) -> float:
	var to_flash: Vector3 = flash_pos - player_pos
	var dist: float = to_flash.length()
	if dist < 1.0:
		return FLASH_MAX_S
	var dot: float = to_flash.normalized().dot(look_dir.normalized())
	if dot <= 0.0:
		return 0.0
	var distance_factor: float = clampf(1.0 - dist / 1200.0, 0.0, 1.0)
	return FLASH_MAX_S * dot * distance_factor


func fire_dps(time_in_fire: float) -> int:
	# Damage ramps 1 -> 8 (capped) then 40 dps; simplified as increasing DPS.
	var dps: int = clampi(1 + int(time_in_fire * 40.0), 1, FIRE_MAX_DPS)
	return dps


func smoke_blocks_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float) -> bool:
	for s in smokes:
		if s.he_gap_until > 0.0:
			continue
		var to: Vector3 = s.center - ray_origin
		var t: float = to.dot(ray_dir.normalized())
		if t < 0.0 or t > max_dist:
			continue
		var closest: Vector3 = ray_origin + ray_dir.normalized() * t
		if closest.distance_to(s.center) < 180.0:
			return true
	return false
