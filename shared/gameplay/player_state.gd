class_name PlayerState
extends RefCounted
## Состояние игрока: HP, броня,コマンド死亡, нанесение урона по правилам CS2.

const _W = preload("res://shared/gameplay/weapons.gd")

enum Hitbox { HEAD, CHEST, STOMACH, ARM, LEG }

var hp: int = 100
var armor: int = 0
var helmet: bool = false
var alive: bool = true
var kills: int = 0
var team: int = 0

const HITBOX_NAMES: Dictionary = {
	Hitbox.HEAD: "head", Hitbox.CHEST: "chest", Hitbox.STOMACH: "stomach",
	Hitbox.ARM: "left_arm", Hitbox.LEG: "left_leg",
}


func reset() -> void:
	hp = 100
	armor = 0
	helmet = false
	alive = true
	kills = 0


func buy_armor(with_helmet: bool) -> bool:
	## Возвращает true, если броня была куплена (деньги списывает Loadout).
	armor = 100
	if with_helmet:
		helmet = true
	return true


func apply_damage(weapon_id: int, distance_u: float, hitbox: int) -> Dictionary:
	## Возвращает { damage, absorbed, hp_before, hp_after, killed }
	if not alive:
		return {"damage": 0, "absorbed": 0, "hp_before": hp, "hp_after": hp, "killed": false}
	var hb: String = HITBOX_NAMES.get(hitbox, "chest")
	# без шлема голова не защищена, но множитель headshot сохраняется
	var armored: bool = armor > 0 and hb != "left_leg" and (hb != "head" or helmet)
	var dmg: int = _W.compute_damage(weapon_id, distance_u, hb, armored)
	var absorbed: int = 0
	if armored:
		absorbed = _W.armor_durability_loss(weapon_id, dmg)
		armor = maxi(armor - absorbed, 0)
	hp = maxi(hp - dmg, 0)
	var killed: bool = hp <= 0
	if killed:
		alive = false
	return {"damage": dmg, "absorbed": absorbed, "hp_before": hp + dmg, "hp_after": hp, "killed": killed}


func apply_he(distance_u: float) -> Dictionary:
	var dmg: int = 98 if distance_u <= 0 else maxi(98 - int(distance_u / 4.0), 0)
	if armor > 0:
		dmg = int(dmg * 0.58)
		armor = maxi(armor - dmg, 0)
	hp = maxi(hp - dmg, 0)
	var killed: bool = hp <= 0
	if killed:
		alive = false
	return {"damage": dmg, "absorbed": 0, "hp_before": hp + dmg, "hp_after": hp, "killed": killed}
