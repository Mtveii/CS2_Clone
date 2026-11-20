class_name RoundState
extends RefCounted
## CS2 round + economy port (MR12-style, individual money, loss-bonus ladder).

const WeaponData = preload("res://shared/gameplay/weapons.gd")

enum Phase { WARMUP, FREEZE, LIVE, BOMB_PLANTED, ROUND_END }

const START_MONEY: int = 800
const MONEY_CAP: int = 16000
const WIN_ELIMINATION: int = 3250
const WIN_OBJECTIVE: int = 3500
const LOSS_LADDER: Array = [1400, 1900, 2400, 2900, 3400]
const PLANT_BONUS: int = 300
const DEFUSE_BONUS: int = 300
const T_PLANT_LOSS_BONUS: int = 600
const CT_KILL_TEAM_BONUS: int = 50
const KILL_REWARD: int = 300
const ROUND_LOSS_REWARD: int = 1400  # legacy alias

var phase: int = Phase.WARMUP
var round_number: int = 0
var round_time_ms: int = 115000
var freeze_time_ms: int = 15000
var bomb_timer_ms: int = 40000
var defuse_time_ms: int = 5000
var round_elapsed_ms: int = 0
var bomb_planted_at_ms: int = -1
var bomb_site: String = ""
var winner: String = ""
var score_t: int = 0
var score_ct: int = 0
var end_reason: String = ""

# Per-team economy (team-level sums; per-player stored via money_by_player).
var money_t: int = START_MONEY
var money_ct: int = START_MONEY
var loss_level_t: int = 1  # teams begin each half at level 1 ($1900 on pistol loss)
var loss_level_ct: int = 1
var money_by_player: Dictionary = {}  # player_id -> int
var plant_bonus_paid: bool = false
var ct_kills_this_round: int = 0


func start_warmup() -> void:
	phase = Phase.WARMUP
	round_number = 0
	score_t = 0
	score_ct = 0


func start_half() -> void:
	money_t = START_MONEY
	money_ct = START_MONEY
	loss_level_t = 1
	loss_level_ct = 1
	for k in money_by_player.keys():
		money_by_player[k] = START_MONEY


func start_round() -> void:
	round_number += 1
	round_elapsed_ms = 0
	bomb_planted_at_ms = -1
	bomb_site = ""
	winner = ""
	end_reason = ""
	plant_bonus_paid = false
	ct_kills_this_round = 0
	phase = Phase.FREEZE


func tick(dt_ms: int) -> void:
	round_elapsed_ms += dt_ms
	match phase:
		Phase.FREEZE:
			if round_elapsed_ms >= freeze_time_ms:
				phase = Phase.LIVE
				round_elapsed_ms = 0
		Phase.LIVE:
			if round_elapsed_ms >= round_time_ms:
				end_round("CT", "time")
		Phase.BOMB_PLANTED:
			if round_elapsed_ms - bomb_planted_at_ms >= bomb_timer_ms:
				end_round("T", "detonation")
		Phase.ROUND_END:
			pass


func plant_bomb(site: String, time_ms: int) -> bool:
	if phase != Phase.LIVE:
		return false
	phase = Phase.BOMB_PLANTED
	bomb_site = site
	bomb_planted_at_ms = time_ms
	round_elapsed_ms = time_ms
	if not plant_bonus_paid:
		plant_bonus_paid = true
	return true


func defuse_bomb(time_ms: int) -> bool:
	if phase != Phase.BOMB_PLANTED:
		return false
	if time_ms - bomb_planted_at_ms < defuse_time_ms:
		return false
	end_round("CT", "defuse")
	return true


func end_round(w: String, reason: String = "elimination") -> void:
	if phase == Phase.ROUND_END:
		return
	phase = Phase.ROUND_END
	winner = w
	end_reason = reason
	if w == "T":
		score_t += 1
		var team_reward: int = WIN_OBJECTIVE if reason == "detonation" else WIN_ELIMINATION
		money_t = mini(money_t + team_reward, MONEY_CAP)
		# T loss after plant handled separately by apply_loss()
		loss_level_ct = _step_down(loss_level_ct)
	elif w == "CT":
		score_ct += 1
		var reward: int = WIN_OBJECTIVE if reason == "defuse" else WIN_ELIMINATION
		money_ct = mini(money_ct + reward, MONEY_CAP)
		loss_level_t = _step_down(loss_level_t)


func apply_loss(losing_team: String, bomb_planted: bool, defused: bool = false) -> void:
	var level: int = loss_level_t if losing_team == "T" else loss_level_ct
	var loss: int = LOSS_LADDER[clampi(level, 0, LOSS_LADDER.size() - 1)]
	if losing_team == "T":
		money_t = mini(money_t + loss, MONEY_CAP)
		if bomb_planted:
			money_t = mini(money_t + T_PLANT_LOSS_BONUS, MONEY_CAP)
		loss_level_t = mini(loss_level_t + 1, LOSS_LADDER.size() - 1)
	else:
		money_ct = mini(money_ct + loss, MONEY_CAP)
		loss_level_ct = mini(loss_level_ct + 1, LOSS_LADDER.size() - 1)


func on_kill(killer_team: String, weapon_id: int = -1, player_id: int = -1) -> void:
	var reward: int = KILL_REWARD
	if weapon_id >= 0:
		reward = WeaponData.kill_reward(weapon_id)
	if killer_team == "T":
		money_t = mini(money_t + reward, MONEY_CAP)
	else:
		money_ct = mini(money_ct + reward, MONEY_CAP)
		ct_kills_this_round += 1
		money_ct = mini(money_ct + CT_KILL_TEAM_BONUS, MONEY_CAP)
	if player_id >= 0:
		add_player_money(player_id, reward)


func add_player_money(player_id: int, amount: int) -> void:
	var cur: int = int(money_by_player.get(player_id, START_MONEY))
	money_by_player[player_id] = clampi(cur + amount, 0, MONEY_CAP)


func spend_player_money(player_id: int, amount: int) -> bool:
	var cur: int = int(money_by_player.get(player_id, START_MONEY))
	if cur < amount:
		return false
	money_by_player[player_id] = cur - amount
	return true


func _step_down(level: int) -> int:
	return maxi(level - 1, 0)


func is_live() -> bool:
	return phase == Phase.LIVE or phase == Phase.BOMB_PLANTED


func time_remaining_ms() -> int:
	if phase == Phase.LIVE:
		return maxi(round_time_ms - round_elapsed_ms, 0)
	if phase == Phase.BOMB_PLANTED:
		return maxi(bomb_timer_ms - (round_elapsed_ms - bomb_planted_at_ms), 0)
	return 0
