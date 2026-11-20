extends SceneTree
## Проверка что ВСЁ вооружение из списка доступно и ограничения работают.
const WeaponData = preload("res://shared/gameplay/weapons.gd")
const Loadout = preload("res://shared/gameplay/loadout.gd")

var failures: int = 0
func _check(c: bool, m: String) -> void:
	if c: print("[ok]   ", m)
	else: failures += 1; push_error("[fail] " + m)

func _init() -> void:
	# Точный список из запроса пользователя
	var expected_names := [
		"Glock-18","USP-S","P2000","P250","Dual Berettas","Tec-9","Five-SeveN","CZ75-Auto","Desert Eagle","R8 Revolver",
		"MAC-10","MP9","MP7","MP5-SD","UMP-45","PP-Bizon","P90",
		"Galil AR","FAMAS","AK-47","M4A4","M4A1-S","SG 553","AUG",
		"SSG 08","AWP","G3SG1","SCAR-20",
		"Nova","XM1014","Sawed-Off","MAG-7","Negev","M249",
		"Knife","Zeus x27",
		"HE Grenade","Flashbang","Smoke Grenade","Molotov","Incendiary","Decoy","C4",
	]
	_check(expected_names.size() == 43, "список содержит 43 позиции")
	var present: Array = []
	for id in WeaponData.WEAPONS.keys():
		present.append(WeaponData.WEAPONS[id].name)
	for name in expected_names:
		_check(present.has(name), "присутствует: %s" % name)

	# ножи-скины
	for skin in ["Karambit","M9 Bayonet","Butterfly","Flip","Gut","Bayonet | Tiger Tooth","Karambit | Doppler"]:
		_check(WeaponData.KNIFE_SKINS.has(skin), "скин ножа: %s" % skin)

	# команды
	var t = Loadout.new(WeaponData.Team.T, 16000)
	var ct = Loadout.new(WeaponData.Team.CT, 16000)
	_check(t.can_buy(WeaponData.WeaponId.GLOCK), "T покупает Glock")
	_check(t.can_buy(WeaponData.WeaponId.AK47), "T покупает AK-47")
	_check(t.can_buy(WeaponData.WeaponId.MOLOTOV), "T покупает Molotov")
	_check(t.can_buy(WeaponData.WeaponId.C4), "T получает C4")
	_check(not t.can_buy(WeaponData.WeaponId.USP), "T НЕ покупает USP-S")
	_check(not t.can_buy(WeaponData.WeaponId.M4A4), "T НЕ покупает M4A4")
	_check(not t.can_buy(WeaponData.WeaponId.INCENDIARY), "T НЕ покупает Incendiary")
	_check(ct.can_buy(WeaponData.WeaponId.USP), "CT покупает USP-S")
	_check(ct.can_buy(WeaponData.WeaponId.P2000), "CT покупает P2000")
	_check(ct.can_buy(WeaponData.WeaponId.M4A1S), "CT покупает M4A1-S")
	_check(ct.can_buy(WeaponData.WeaponId.INCENDIARY), "CT покупает Incendiary")
	_check(not ct.can_buy(WeaponData.WeaponId.GALIL), "CT НЕ покупает Galil")
	_check(not ct.can_buy(WeaponData.WeaponId.C4), "CT НЕ получает C4")

	# покупка и деньги
	var t2 = Loadout.new(WeaponData.Team.T, 3000)
	_check(t2.buy(WeaponData.WeaponId.AK47), "покупка AK")
	_check(t2.money == 300, "деньги списаны (2700)")
	_check(not t2.buy(WeaponData.WeaponId.AWP), "не хватает денег на AWP")
	_check(t2.select(Loadout.Slot.PRIMARY), "выбор PRIMARY")
	var shot = t2.fire(1000)
	_check(shot.fired and shot.mag_left == 29, "выстрел: 29 патронов")
	_check(not t2.fire(1000 + 50).fired, "cooldown между выстрелами")
	_check(t2.fire(1000 + 100).fired, "выстрел после cooldown")
	_check(t2.reload(2000), "перезарядка")
	_check(t2.active().mag == 30, "магазин полон")

	# гранаты: лимиты
	var t3 = Loadout.new(WeaponData.Team.T, 16000)
	_check(t3.buy(WeaponData.WeaponId.FLASH), "1-я флешка")
	_check(t3.buy(WeaponData.WeaponId.FLASH), "2-я флешка")
	_check(not t3.buy(WeaponData.WeaponId.FLASH), "3-я флешка запрещена")
	_check(t3.buy(WeaponData.WeaponId.SMOKE), "дымовая")
	_check(t3.buy(WeaponData.WeaponId.HE), "HE")
	_check(not t3.buy(WeaponData.WeaponId.DECOY), "Decoy делит слот с HE")
	_check(t3.buy(WeaponData.WeaponId.MOLOTOV), "Molotov")
	_check(not t3.buy(WeaponData.WeaponId.INCENDIARY), "T не покупает Incendiary")

	# скин ножа
	t3.set_knife_skin("Karambit | Doppler")
	_check(t3.slots[Loadout.Slot.KNIFE].skin == "Karambit | Doppler", "скин ножа применён")

	# перепродажа
	var refund = t2.sell(WeaponData.WeaponId.AK47)
	_check(refund == 1350, "возврат 50% за AK ($1350)")
	_check(t2.money == 300 + 1350, "деньги после продажи")

	if failures > 0:
		print("RESULT: FAIL (%d)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
