class_name Loadout
extends RefCounted
## Инвентарь игрока + покупка武器 с ограничениями CS2 (команда, деньги, слоты).
## Все 43武器 из WeaponData доступны через этот класс.

const _W = preload("res://shared/gameplay/weapons.gd")

enum Slot {
	PRIMARY,
	SECONDARY,
	KNIFE,
	ZEUS,
	GRENADE_HE_DECOY,
	GRENADE_FLASH_1,
	GRENADE_FLASH_2,
	GRENADE_SMOKE,
	GRENADE_FIRE,
	C4,
}

class WeaponInstance:
	var id: int = -1
	var mag: int = 0
	var reserve: int = 0
	var next_fire_ms: int = 0
	var skin: String = ""

	static func make(weapon_id: int, skin_name: String = "") -> WeaponInstance:
		var wi := WeaponInstance.new()
		wi.id = weapon_id
		var w: Dictionary = _W.get_weapon(weapon_id)
		wi.mag = int(w.get("mag", 0))
		wi.reserve = int(w.get("reserve", 0))
		wi.skin = skin_name
		return wi

var team: int = _W.Team.ANY
var money: int = 800
var slots: Dictionary = {}          # Slot -> WeaponInstance
var selected: int = Slot.SECONDARY
var knife_skin: String = "Default"


func _init(player_team: int = _W.Team.ANY, start_money: int = 800) -> void:
	team = player_team
	money = start_money
	# Нож и пистолет по умолчанию (бесплатно)
	slots[Slot.KNIFE] = WeaponInstance.make(_W.WeaponId.KNIFE, knife_skin)
	slots[Slot.SECONDARY] = WeaponInstance.make(
		_W.WeaponId.GLOCK if team == _W.Team.T else _W.WeaponId.USP
	)


func weapon_slot(weapon_id: int) -> int:
	var w: Dictionary = _W.get_weapon(weapon_id)
	match String(w.get("slot", "")):
		"pistol": return Slot.SECONDARY
		"smg", "rifle", "sniper", "heavy": return Slot.PRIMARY
		"melee": return Slot.KNIFE
		"utility": return Slot.ZEUS
		"objective": return Slot.C4
		"grenade":
			if weapon_id == _W.WeaponId.FLASH:
				return Slot.GRENADE_FLASH_1
			if weapon_id == _W.WeaponId.SMOKE:
				return Slot.GRENADE_SMOKE
			if weapon_id == _W.WeaponId.MOLOTOV or weapon_id == _W.WeaponId.INCENDIARY:
				return Slot.GRENADE_FIRE
			if weapon_id == _W.WeaponId.HE or weapon_id == _W.WeaponId.DECOY:
				return Slot.GRENADE_HE_DECOY
	return -1


func can_buy(weapon_id: int) -> bool:
	var w: Dictionary = _W.WEAPONS.get(weapon_id, {})
	if w.is_empty():
		return false
	# команда
	var wt: int = int(w.get("team", _W.Team.ANY))
	if wt != _W.Team.ANY and wt != team:
		return false
	# деньги
	var price: int = int(w.get("price", 0))
	if money < price:
		return false
	# слоты
	var slot: int = weapon_slot(weapon_id)
	if slot < 0:
		return false
	if slot == Slot.GRENADE_FLASH_1 and slots.has(Slot.GRENADE_FLASH_2):
		return false
	if slot == Slot.GRENADE_HE_DECOY and slots.has(Slot.GRENADE_HE_DECOY):
		return false  # HE и Decoy делят слот
	return true


func buy(weapon_id: int) -> bool:
	if not can_buy(weapon_id):
		return false
	var w: Dictionary = _W.WEAPONS[weapon_id]
	var slot: int = weapon_slot(weapon_id)
	if slot == Slot.GRENADE_FLASH_1 and slots.has(Slot.GRENADE_FLASH_1):
		slot = Slot.GRENADE_FLASH_2
	money -= int(w.get("price", 0))
	slots[slot] = WeaponInstance.make(weapon_id)
	return true


func give(weapon_id: int) -> bool:
	## Бесплатная выдача (спавн/админ). Игнорирует деньги, но не команду.
	var w: Dictionary = _W.WEAPONS.get(weapon_id, {})
	if w.is_empty():
		return false
	var wt: int = int(w.get("team", _W.Team.ANY))
	if wt != _W.Team.ANY and wt != team:
		return false
	var slot: int = weapon_slot(weapon_id)
	if slot < 0:
		return false
	slots[slot] = WeaponInstance.make(weapon_id)
	return true


func select(slot: int) -> bool:
	if not slots.has(slot):
		return false
	selected = slot
	return true


func active() -> WeaponInstance:
	return slots.get(selected, null)


func fire(current_ms: int) -> Dictionary:
	var wi: WeaponInstance = active()
	if wi == null or wi.id < 0:
		return {"fired": false, "reason": "empty"}
	if current_ms < wi.next_fire_ms:
		return {"fired": false, "reason": "cooldown"}
	if wi.mag <= 0:
		return {"fired": false, "reason": "empty_mag"}
	wi.mag -= 1
	wi.next_fire_ms = current_ms + int(_W.fire_interval(wi.id) * 1000.0)
	return {
		"fired": true,
		"weapon_id": wi.id,
		"damage": int(_W.WEAPONS[wi.id].get("damage", 0)),
		"mag_left": wi.mag,
	}


func reload(current_ms: int) -> bool:
	var wi: WeaponInstance = active()
	if wi == null or wi.id < 0:
		return false
	var w: Dictionary = _W.WEAPONS[wi.id]
	var mag_size: int = int(w.get("mag", 0))
	if mag_size <= 0 or wi.mag >= mag_size or wi.reserve <= 0:
		return false
	var need: int = mag_size - wi.mag
	var take: int = mini(need, wi.reserve)
	wi.mag += take
	wi.reserve -= take
	return true


func set_knife_skin(skin: String) -> void:
	knife_skin = skin
	var wi: WeaponInstance = slots.get(Slot.KNIFE, null)
	if wi != null:
		wi.skin = skin


func sell(weapon_id: int) -> int:
	## Возвращает 50% стоимости.
	var slot: int = weapon_slot(weapon_id)
	if not slots.has(slot):
		return 0
	var wi: WeaponInstance = slots[slot]
	if wi.id != weapon_id:
		return 0
	var refund: int = int(round(float(_W.WEAPONS[weapon_id].get("price", 0)) * 0.5))
	money += refund
	slots.erase(slot)
	# вернуть пистолет по умолчанию
	if slot == Slot.SECONDARY:
		slots[slot] = WeaponInstance.make(
			_W.WeaponId.GLOCK if team == _W.Team.T else _W.WeaponId.USP
		)
	return refund


func all_weapon_ids() -> Array:
	var out: Array = []
	for wi in slots.values():
		if wi.id >= 0:
			out.append(wi.id)
	return out


func reset_for_round() -> void:
	## Сохраняет купленное, если игрок выжил (упрощённо: сохраняем всё).
	pass
