class_name HitRegistration
extends RefCounted
## Server-side hit registration with lag compensation hooks.
## Pure logic; networking layer feeds positions.

const MAX_REWIND_MS: int = 200

# A player snapshot for rewind.
class PlayerSnap:
	var player_id: int
	var pos: Vector3          # units
	var yaw: int
	var pitch: int
	var alive: bool
	var timestamp_ms: int

# History: player_id -> Array[PlayerSnap]
var history: Dictionary = {}


func record_snapshot(snap: PlayerSnap) -> void:
	if not history.has(snap.player_id):
		hitreg_history_init(snap.player_id)
	history[snap.player_id].append(snap)
	# trim older than MAX_REWIND_MS * 2
	var cutoff = snap.timestamp_ms - MAX_REWIND_MS * 2
	var arr = history[snap.player_id]
	while arr.size() > 0 and arr[0].timestamp_ms < cutoff:
		arr.pop_front()


func hitreg_history_init(pid: int) -> void:
	history[pid] = []


func rewind_position(player_id: int, target_time_ms: int) -> Vector3:
	# Returns interpolated position at target_time, clamped to available history.
	if not history.has(player_id) or history[player_id].is_empty():
		return Vector3.ZERO
	var arr = history[player_id]
	# clamp
	if target_time_ms <= arr[0].timestamp_ms:
		return arr[0].pos
	if target_time_ms >= arr[arr.size() - 1].timestamp_ms:
		return arr[arr.size() - 1].pos
	# find segment
	for i in range(arr.size() - 1):
		if arr[i].timestamp_ms <= target_time_ms <= arr[i + 1].timestamp_ms:
			var t0 = arr[i].timestamp_ms
			var t1 = arr[i + 1].timestamp_ms
			var frac = 0.0
			if t1 > t0:
				frac = float(target_time_ms - t0) / float(t1 - t0)
			return arr[i].pos.lerp(arr[i + 1].pos, frac)
	return arr[arr.size() - 1].pos


# Hitbox offsets relative to player position (units). Simplified spheres.
const HITBOX_RADIUS: Dictionary = {
	"head": 0.15,
	"chest": 0.3,
	"stomach": 0.25,
	"left_arm": 0.12,
	"right_arm": 0.12,
	"left_leg": 0.15,
	"right_leg": 0.15,
}
const HITBOX_OFFSET: Dictionary = {
	"head": Vector3(0, 1.7, 0),
	"chest": Vector3(0, 1.3, 0),
	"stomach": Vector3(0, 1.0, 0),
	"left_arm": Vector3(-0.3, 1.3, 0),
	"right_arm": Vector3(0.3, 1.3, 0),
	"left_leg": Vector3(-0.15, 0.5, 0),
	"right_leg": Vector3(0.15, 0.5, 0),
}


func ray_vs_player(origin: Vector3, dir: Vector3, player_pos: Vector3, max_dist: float) -> Dictionary:
	# Returns { hit: bool, hitbox: String, t: float, point: Vector3 }
	var best_t = max_dist
	var best_box = ""
	var best_point = Vector3.ZERO
	for box in HITBOX_RADIUS.keys():
		var center = player_pos + HITBOX_OFFSET[box]
		var r = HITBOX_RADIUS[box]
		# ray-sphere intersection
		var oc = origin - center
		var a = dir.dot(dir)
		var b = 2.0 * oc.dot(dir)
		var c = oc.dot(oc) - r * r
		var disc = b * b - 4 * a * c
		if disc < 0:
			continue
		var sq = sqrt(disc)
		var t = (-b - sq) / (2 * a)
		if t < 0:
			t = (-b + sq) / (2 * a)
		if t < 0 or t > best_t:
			continue
		best_t = t
		best_box = box
		best_point = origin + dir * t
	return {"hit": best_box != "", "hitbox": best_box, "t": best_t, "point": best_point}


func apply_penetration(voxel_world_raycast: Callable, origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	# Returns { blocked: bool, t_wall: float } — whether a wall blocks before max_dist.
	var res = voxel_world_raycast.call(origin, dir, max_dist)
	if res.hit:
		return {"blocked": true, "t_wall": res.t, "point": res.pos_mm}
	return {"blocked": false, "t_wall": max_dist, "point": origin + dir * max_dist}
