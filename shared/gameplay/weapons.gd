class_name WeaponData
extends RefCounted
## CS2 weapon catalog ported from datamined game stats (2026 build).
## Range/falloff in Hammer units (500 u ≈ 12.7 m).

enum Team { ANY, T, CT }

enum WeaponId {
	# Pistols
	GLOCK, USP, P2000, P250, DUAL_BERETTAS, TEC9, FIVE_SEVEN, CZ75, DEAGLE, R8,
	# SMGs
	MAC10, MP9, MP7, MP5SD, UMP45, BIZON, P90,
	# Rifles
	GALIL, FAMAS, AK47, M4A4, M4A1S, SG553, AUG,
	# Snipers
	SSG08, AWP, G3SG1, SCAR20,
	# Heavy
	NOVA, XM1014, SAWEDOFF, MAG7, NEGEV, M249,
	# Melee / utility / objective
	KNIFE, ZEUS, HE, FLASH, SMOKE, MOLOTOV, INCENDIARY, DECOY, C4,
}

const HITBOX_MULT: Dictionary = {
	"head": 4.0, "chest": 1.0, "stomach": 1.25,
	"left_arm": 1.0, "right_arm": 1.0,
	"left_leg": 0.75, "right_leg": 0.75,
}
const ARMOR_REDUCTION: float = 0.5

# name, team, slot, damage, armor_pen, rpm, mag, price, kill_reward,
# move_speed(u/s), headshot_mult, falloff_pct_per_500u, range_u, pellets, reserve, recoil
const WEAPONS: Dictionary = {
	# --- Pistols ---
	WeaponId.GLOCK: {"name":"Glock-18","team":Team.T,"slot":"pistol","damage":30,"armor_pen":0.472,"rpm":400,"mag":20,"price":200,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.15,"range_u":1500,"pellets":1,"reserve":120,"recoil":2.0},
	WeaponId.USP: {"name":"USP-S","team":Team.CT,"slot":"pistol","damage":35,"armor_pen":0.505,"rpm":352,"mag":12,"price":200,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":1500,"pellets":1,"reserve":48,"recoil":2.2},
	WeaponId.P2000: {"name":"P2000","team":Team.CT,"slot":"pistol","damage":35,"armor_pen":0.505,"rpm":352,"mag":13,"price":200,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":1500,"pellets":1,"reserve":52,"recoil":2.2},
	WeaponId.P250: {"name":"P250","team":Team.ANY,"slot":"pistol","damage":38,"armor_pen":0.644,"rpm":400,"mag":13,"price":300,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":1500,"pellets":1,"reserve":52,"recoil":2.5},
	WeaponId.DUAL_BERETTAS: {"name":"Dual Berettas","team":Team.ANY,"slot":"pistol","damage":38,"armor_pen":0.52,"rpm":400,"mag":30,"price":300,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.15,"range_u":1500,"pellets":1,"reserve":120,"recoil":1.8},
	WeaponId.TEC9: {"name":"Tec-9","team":Team.T,"slot":"pistol","damage":33,"armor_pen":0.52,"rpm":500,"mag":18,"price":500,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.15,"range_u":1500,"pellets":1,"reserve":90,"recoil":2.0},
	WeaponId.FIVE_SEVEN: {"name":"Five-SeveN","team":Team.CT,"slot":"pistol","damage":32,"armor_pen":0.9115,"rpm":400,"mag":20,"price":500,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":1500,"pellets":1,"reserve":100,"recoil":2.0},
	WeaponId.CZ75: {"name":"CZ75-Auto","team":Team.ANY,"slot":"pistol","damage":31,"armor_pen":0.644,"rpm":750,"mag":12,"price":500,"kill_reward":100,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":1500,"pellets":1,"reserve":24,"recoil":2.2},
	WeaponId.DEAGLE: {"name":"Desert Eagle","team":Team.ANY,"slot":"pistol","damage":63,"armor_pen":0.934,"rpm":267,"mag":7,"price":700,"kill_reward":300,"move_speed":240,"headshot_mult":3.9,"falloff_500":0.08,"range_u":2000,"pellets":1,"reserve":35,"recoil":5.0},
	WeaponId.R8: {"name":"R8 Revolver","team":Team.ANY,"slot":"pistol","damage":86,"armor_pen":0.934,"rpm":225,"mag":8,"price":600,"kill_reward":300,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.10,"range_u":2000,"pellets":1,"reserve":32,"recoil":5.5},
	# --- SMGs ---
	WeaponId.MAC10: {"name":"MAC-10","team":Team.T,"slot":"smg","damage":29,"armor_pen":0.575,"rpm":800,"mag":30,"price":1050,"kill_reward":600,"move_speed":235,"headshot_mult":4.0,"falloff_500":0.25,"range_u":2000,"pellets":1,"reserve":120,"recoil":1.8},
	WeaponId.MP9: {"name":"MP9","team":Team.CT,"slot":"smg","damage":26,"armor_pen":0.60,"rpm":857,"mag":30,"price":1250,"kill_reward":600,"move_speed":240,"headshot_mult":4.0,"falloff_500":0.25,"range_u":2000,"pellets":1,"reserve":120,"recoil":1.7},
	WeaponId.MP7: {"name":"MP7","team":Team.ANY,"slot":"smg","damage":29,"armor_pen":0.60,"rpm":750,"mag":30,"price":1500,"kill_reward":600,"move_speed":235,"headshot_mult":4.0,"falloff_500":0.20,"range_u":2000,"pellets":1,"reserve":120,"recoil":1.9},
	WeaponId.MP5SD: {"name":"MP5-SD","team":Team.ANY,"slot":"smg","damage":27,"armor_pen":0.625,"rpm":750,"mag":30,"price":1500,"kill_reward":600,"move_speed":235,"headshot_mult":4.0,"falloff_500":0.20,"range_u":2000,"pellets":1,"reserve":120,"recoil":1.8},
	WeaponId.UMP45: {"name":"UMP-45","team":Team.ANY,"slot":"smg","damage":35,"armor_pen":0.65,"rpm":667,"mag":25,"price":1200,"kill_reward":600,"move_speed":230,"headshot_mult":4.0,"falloff_500":0.20,"range_u":2000,"pellets":1,"reserve":100,"recoil":2.0},
	WeaponId.BIZON: {"name":"PP-Bizon","team":Team.ANY,"slot":"smg","damage":27,"armor_pen":0.60,"rpm":750,"mag":64,"price":1400,"kill_reward":600,"move_speed":235,"headshot_mult":4.0,"falloff_500":0.25,"range_u":2000,"pellets":1,"reserve":256,"recoil":1.9},
	WeaponId.P90: {"name":"P90","team":Team.ANY,"slot":"smg","damage":26,"armor_pen":0.69,"rpm":750,"mag":50,"price":2350,"kill_reward":300,"move_speed":230,"headshot_mult":4.0,"falloff_500":0.20,"range_u":2000,"pellets":1,"reserve":150,"recoil":1.8},
	# --- Rifles ---
	WeaponId.GALIL: {"name":"Galil AR","team":Team.T,"slot":"rifle","damage":30,"armor_pen":0.775,"rpm":667,"mag":35,"price":1800,"kill_reward":300,"move_speed":215,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":105,"recoil":2.5},
	WeaponId.FAMAS: {"name":"FAMAS","team":Team.CT,"slot":"rifle","damage":30,"armor_pen":0.70,"rpm":667,"mag":25,"price":1950,"kill_reward":300,"move_speed":220,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":75,"recoil":2.3},
	WeaponId.AK47: {"name":"AK-47","team":Team.T,"slot":"rifle","damage":36,"armor_pen":0.775,"rpm":600,"mag":30,"price":2700,"kill_reward":300,"move_speed":215,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":90,"recoil":3.0},
	WeaponId.M4A4: {"name":"M4A4","team":Team.CT,"slot":"rifle","damage":33,"armor_pen":0.70,"rpm":667,"mag":30,"price":2900,"kill_reward":300,"move_speed":225,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":90,"recoil":2.5},
	WeaponId.M4A1S: {"name":"M4A1-S","team":Team.CT,"slot":"rifle","damage":38,"armor_pen":0.70,"rpm":600,"mag":20,"price":2900,"kill_reward":300,"move_speed":225,"headshot_mult":3.475,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":60,"recoil":2.4},
	WeaponId.SG553: {"name":"SG 553","team":Team.T,"slot":"rifle","damage":30,"armor_pen":1.0,"rpm":545,"mag":30,"price":3000,"kill_reward":300,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":90,"recoil":2.6},
	WeaponId.AUG: {"name":"AUG","team":Team.CT,"slot":"rifle","damage":28,"armor_pen":0.90,"rpm":600,"mag":30,"price":3300,"kill_reward":300,"move_speed":220,"headshot_mult":4.0,"falloff_500":0.02,"range_u":4000,"pellets":1,"reserve":90,"recoil":2.4},
	# --- Snipers ---
	WeaponId.SSG08: {"name":"SSG 08","team":Team.ANY,"slot":"sniper","damage":88,"armor_pen":0.85,"rpm":48,"mag":10,"price":1700,"kill_reward":300,"move_speed":230,"headshot_mult":4.0,"falloff_500":0.01,"range_u":8000,"pellets":1,"reserve":40,"recoil":4.0},
	WeaponId.AWP: {"name":"AWP","team":Team.ANY,"slot":"sniper","damage":115,"armor_pen":0.975,"rpm":41,"mag":5,"price":4750,"kill_reward":100,"move_speed":200,"headshot_mult":4.0,"falloff_500":0.01,"range_u":8000,"pellets":1,"reserve":30,"recoil":5.0},
	WeaponId.G3SG1: {"name":"G3SG1","team":Team.T,"slot":"sniper","damage":80,"armor_pen":0.825,"rpm":240,"mag":20,"price":5000,"kill_reward":300,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.03,"range_u":6000,"pellets":1,"reserve":90,"recoil":3.5},
	WeaponId.SCAR20: {"name":"SCAR-20","team":Team.CT,"slot":"sniper","damage":80,"armor_pen":0.825,"rpm":240,"mag":20,"price":5000,"kill_reward":300,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.03,"range_u":6000,"pellets":1,"reserve":90,"recoil":3.5},
	# --- Heavy ---
	WeaponId.NOVA: {"name":"Nova","team":Team.ANY,"slot":"heavy","damage":26,"armor_pen":0.50,"rpm":68,"mag":8,"price":1050,"kill_reward":900,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.55,"range_u":1200,"pellets":9,"reserve":32,"recoil":3.0},
	WeaponId.XM1014: {"name":"XM1014","team":Team.ANY,"slot":"heavy","damage":20,"armor_pen":0.80,"rpm":171,"mag":7,"price":2000,"kill_reward":600,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.45,"range_u":1200,"pellets":6,"reserve":32,"recoil":2.5},
	WeaponId.SAWEDOFF: {"name":"Sawed-Off","team":Team.T,"slot":"heavy","damage":32,"armor_pen":0.75,"rpm":71,"mag":7,"price":1100,"kill_reward":900,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.60,"range_u":1000,"pellets":8,"reserve":28,"recoil":3.5},
	WeaponId.MAG7: {"name":"MAG-7","team":Team.CT,"slot":"heavy","damage":30,"armor_pen":0.75,"rpm":71,"mag":5,"price":1300,"kill_reward":900,"move_speed":210,"headshot_mult":4.0,"falloff_500":0.55,"range_u":1000,"pellets":8,"reserve":25,"recoil":3.2},
	WeaponId.NEGEV: {"name":"Negev","team":Team.ANY,"slot":"heavy","damage":35,"armor_pen":0.75,"rpm":750,"mag":150,"price":1700,"kill_reward":300,"move_speed":195,"headshot_mult":4.0,"falloff_500":0.05,"range_u":4000,"pellets":1,"reserve":300,"recoil":2.0},
	WeaponId.M249: {"name":"M249","team":Team.ANY,"slot":"heavy","damage":32,"armor_pen":0.80,"rpm":750,"mag":100,"price":5200,"kill_reward":300,"move_speed":195,"headshot_mult":4.0,"falloff_500":0.05,"range_u":4000,"pellets":1,"reserve":200,"recoil":2.2},
	# --- Melee / utility / objective ---
	WeaponId.KNIFE: {"name":"Knife","team":Team.ANY,"slot":"melee","damage":50,"armor_pen":0.85,"rpm":150,"mag":0,"price":0,"kill_reward":1500,"move_speed":250,"headshot_mult":4.0,"falloff_500":0.0,"range_u":40,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.ZEUS: {"name":"Zeus x27","team":Team.ANY,"slot":"utility","damage":500,"armor_pen":1.0,"rpm":60,"mag":1,"price":200,"kill_reward":100,"move_speed":240,"headshot_mult":1.0,"falloff_500":0.0,"range_u":60,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.HE: {"name":"HE Grenade","team":Team.ANY,"slot":"grenade","damage":98,"armor_pen":1.0,"rpm":0,"mag":1,"price":300,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":350,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.FLASH: {"name":"Flashbang","team":Team.ANY,"slot":"grenade","damage":0,"armor_pen":0.0,"rpm":0,"mag":1,"price":200,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":1200,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.SMOKE: {"name":"Smoke Grenade","team":Team.ANY,"slot":"grenade","damage":0,"armor_pen":0.0,"rpm":0,"mag":1,"price":300,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":1200,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.MOLOTOV: {"name":"Molotov","team":Team.T,"slot":"grenade","damage":40,"armor_pen":1.0,"rpm":0,"mag":1,"price":400,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":300,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.INCENDIARY: {"name":"Incendiary","team":Team.CT,"slot":"grenade","damage":40,"armor_pen":1.0,"rpm":0,"mag":1,"price":600,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":260,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.DECOY: {"name":"Decoy","team":Team.ANY,"slot":"grenade","damage":0,"armor_pen":0.0,"rpm":0,"mag":1,"price":50,"kill_reward":300,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":1200,"pellets":1,"reserve":0,"recoil":0.0},
	WeaponId.C4: {"name":"C4","team":Team.T,"slot":"objective","damage":0,"armor_pen":0.0,"rpm":0,"mag":1,"price":0,"kill_reward":0,"move_speed":250,"headshot_mult":1.0,"falloff_500":0.0,"range_u":0,"pellets":1,"reserve":0,"recoil":0.0},
}

const KNIFE_SKINS: Array = [
	"Default", "Karambit", "M9 Bayonet", "Butterfly", "Flip", "Gut",
	"Bayonet | Tiger Tooth", "Karambit | Doppler",
]


static func get_weapon(id: int) -> Dictionary:
	return WEAPONS.get(id, WEAPONS[WeaponId.KNIFE])


static func weapons_for_team(team: int, slot: String = "") -> Array:
	var out: Array = []
	for id in WEAPONS.keys():
		var w: Dictionary = WEAPONS[id]
		if w.team != Team.ANY and w.team != team:
			continue
		if slot != "" and w.slot != slot:
			continue
		out.append(id)
	return out


static func damage_falloff(base_damage: int, distance_u: float, w: Dictionary) -> int:
	if distance_u <= 0:
		return base_damage
	var steps: float = distance_u / 500.0
	var loss: float = float(base_damage) * float(w.get("falloff_500", 0.0)) * steps
	return max(int(round(float(base_damage) - loss)), 0)


static func apply_hitbox(damage: int, hitbox: String, headshot_mult: float = 4.0) -> int:
	var mult: float = float(HITBOX_MULT.get(hitbox, 1.0))
	if hitbox == "head":
		mult = headshot_mult
	return int(round(float(damage) * mult))


static func apply_armor(damage: int, armored: bool, armor_pen: float, hitbox: String = "chest") -> int:
	# Legs are never protected; where armor applies, damage is multiplied by
	# armor_pen (CS2: AK 36 → 27.9 on chest; AK HS 144 → 111 through helmet).
	if not armored or hitbox == "left_leg" or hitbox == "right_leg":
		return damage
	return int(round(float(damage) * armor_pen))


static func compute_damage(weapon_id: int, distance_u: float, hitbox: String, armored: bool) -> int:
	var w: Dictionary = get_weapon(weapon_id)
	var d: int = damage_falloff(int(w.damage), distance_u, w)
	d = apply_hitbox(d, hitbox, float(w.get("headshot_mult", 4.0)))
	d = apply_armor(d, armored, float(w.armor_pen), hitbox)
	return max(d, 0)


static func compute_shotgun_damage(weapon_id: int, distance_u: float, hitbox: String, armored: bool, pellets_hit: int) -> int:
	return compute_damage(weapon_id, distance_u, hitbox, armored) * pellets_hit


static func fire_interval(weapon_id: int) -> float:
	var rpm: int = int(get_weapon(weapon_id).get("rpm", 0))
	if rpm <= 0:
		return 1.0
	return 60.0 / float(rpm)


static func is_headshot(hitbox: String) -> bool:
	return hitbox == "head"


static func pellets(weapon_id: int) -> int:
	return int(get_weapon(weapon_id).get("pellets", 1))


static func move_speed(weapon_id: int) -> float:
	return float(get_weapon(weapon_id).get("move_speed", 250.0))


static func kill_reward(weapon_id: int) -> int:
	return int(get_weapon(weapon_id).get("kill_reward", 300))


static func armor_durability_loss(weapon_id: int, damage: int) -> int:
	# Approximate: armor absorbs a share of incoming damage as durability.
	return int(round(float(damage) * 0.5 * (1.0 - float(get_weapon(weapon_id).get("armor_pen", 1.0)))))
