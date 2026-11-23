class_name AgentData
extends RefCounted
## оригинальные агенты + фракции/редкости; CT и T экипируются раздельно.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const Team = WeaponData.Team

enum Rarity { DISTINGUISHED, EXCEPTIONAL, SUPERIOR, MASTER }

const RARITY_NAMES: Array = ["Distinguished", "Exceptional", "Superior", "Master"]
const RARITY_COLORS: Array = [
	Color(0.65, 0.68, 0.75), Color(0.35, 0.65, 0.95),
	Color(0.75, 0.45, 0.95), Color(0.95, 0.75, 0.25),
]

class Agent:
	var id: String
	var name: String
	var team: int
	var role: String
	var faction: String
	var rarity: int
	var color: Color
	var accent: Color
	var owned: bool = true


var agents: Array = []
var equipped_ct: String = ""
var equipped_t: String = ""


func _init() -> void:
	# --- T: фракции Professionals / Guerrilla / Elite Crew / Elite Team / Phoenix ---
	agents.append(_make("t_pro", "Vanguard", Team.T, "Entry", "The Professionals", Rarity.DISTINGUISHED, Color(0.72, 0.52, 0.28)))
	agents.append(_make("t_guer", "Guerrilla", Team.T, "Lurker", "Guerrilla Warfare", Rarity.EXCEPTIONAL, Color(0.45, 0.55, 0.30)))
	agents.append(_make("t_elite", "Cavalier", Team.T, "Support", "Elite Crew", Rarity.SUPERIOR, Color(0.60, 0.35, 0.20)))
	agents.append(_make("t_team", "Specter", Team.T, "Sniper", "Elite Team", Rarity.MASTER, Color(0.30, 0.30, 0.36)))
	agents.append(_make("t_phoenix", "Ember", Team.T, "Entry", "Phoenix", Rarity.SUPERIOR, Color(0.80, 0.30, 0.15)))
	# --- CT: Navy SEALs / SAS / SWAT / TACP / Gendarmerie / FBI / Sabre / KSK ---
	agents.append(_make("ct_seal", "Trident", Team.CT, "Anchor", "Navy SEALs", Rarity.DISTINGUISHED, Color(0.20, 0.38, 0.62)))
	agents.append(_make("ct_sas", "Falcon", Team.CT, "Entry", "SAS", Rarity.EXCEPTIONAL, Color(0.30, 0.42, 0.35)))
	agents.append(_make("ct_swat", "Riot", Team.CT, "Support", "SWAT", Rarity.SUPERIOR, Color(0.18, 0.20, 0.28)))
	agents.append(_make("ct_tacp", "Bolter", Team.CT, "Sniper", "TACP", Rarity.MASTER, Color(0.35, 0.38, 0.45)))
	agents.append(_make("ct_gend", "Gendarme", Team.CT, "Anchor", "National Gendarmerie", Rarity.EXCEPTIONAL, Color(0.25, 0.35, 0.60)))
	agents.append(_make("ct_fbi", "Agent S", Team.CT, "Support", "FBI", Rarity.SUPERIOR, Color(0.25, 0.28, 0.40)))
	agents.append(_make("ct_sabre", "Sabre", Team.CT, "Entry", "1st Brazilian Battalion", Rarity.MASTER, Color(0.30, 0.55, 0.40)))
	agents.append(_make("ct_ksk", "Kestrel", Team.CT, "Sniper", "KSK", Rarity.MASTER, Color(0.35, 0.45, 0.30)))
	equipped_t = agents[0].id
	equipped_ct = agents[5].id


func _make(id: String, name: String, team: int, role: String, faction: String, rarity: int, color: Color) -> Agent:
	var a := Agent.new()
	a.id = id
	a.name = name
	a.team = team
	a.role = role
	a.faction = faction
	a.rarity = rarity
	a.color = color
	a.accent = color.darkened(0.5)
	return a


func by_team(team: int) -> Array:
	var out: Array = []
	for a in agents:
		if a.team == team:
			out.append(a)
	return out


func find(id: String) -> Agent:
	for a in agents:
		if a.id == id:
			return a
	return null


func can_equip(agent: Agent) -> bool:
	## Нужно физически владеть предметом; CT и T — разные предметы.
	return agent != null and agent.owned


func equip(agent: Agent) -> bool:
	if not can_equip(agent):
		return false
	if agent.team == Team.CT:
		equipped_ct = agent.id
	else:
		equipped_t = agent.id
	return true


func equipped(team: int) -> Agent:
	return find(equipped_ct if team == Team.CT else equipped_t)


static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]


func factions_for(team: int) -> Array:
	var out: Array = []
	for a in by_team(team):
		if not out.has(a.faction):
			out.append(a.faction)
	return out


## Все агенты имеют одинаковые хитбоксы — косметика.
func hitbox_profile() -> String:
	return "standard_humanoid_100hp"


func build_voxel_model(agent: Agent) -> Node3D:
	var root := Node3D.new()
	root.name = "AgentModel_" + agent.id
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = agent.color
	mat_body.roughness = 0.85
	var mat_gear := StandardMaterial3D.new()
	mat_gear.albedo_color = agent.accent
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.78, 0.60, 0.45)
	var mat_visor := StandardMaterial3D.new()
	mat_visor.albedo_color = Color(0.1, 0.15, 0.2)
	mat_visor.metallic = 0.6
	_add_box(root, "Head", Vector3(0, 1.62, 0), Vector3(0.32, 0.34, 0.30), mat_skin)
	_add_box(root, "Helmet", Vector3(0, 1.78, 0), Vector3(0.36, 0.16, 0.34), mat_gear)
	_add_box(root, "Visor", Vector3(0, 1.66, 0.16), Vector3(0.30, 0.10, 0.04), mat_visor)
	_add_box(root, "Torso", Vector3(0, 1.15, 0), Vector3(0.60, 0.62, 0.34), mat_body)
	_add_box(root, "Vest", Vector3(0, 1.18, 0.19), Vector3(0.54, 0.46, 0.10), mat_gear)
	_add_box(root, "ArmL", Vector3(-0.40, 1.15, 0), Vector3(0.18, 0.55, 0.18), mat_body)
	_add_box(root, "ArmR", Vector3(0.40, 1.15, 0), Vector3(0.18, 0.55, 0.18), mat_body)
	_add_box(root, "LegL", Vector3(-0.16, 0.45, 0), Vector3(0.22, 0.70, 0.22), mat_gear)
	_add_box(root, "LegR", Vector3(0.16, 0.45, 0), Vector3(0.22, 0.70, 0.22), mat_gear)
	_add_box(root, "BootL", Vector3(-0.16, 0.08, 0.05), Vector3(0.24, 0.16, 0.32), mat_gear)
	_add_box(root, "BootR", Vector3(0.16, 0.08, 0.05), Vector3(0.24, 0.16, 0.32), mat_gear)
	var mat_gun := StandardMaterial3D.new()
	mat_gun.albedo_color = Color(0.18, 0.18, 0.2)
	mat_gun.metallic = 0.5
	_add_box(root, "Weapon", Vector3(0.28, 1.10, 0.35), Vector3(0.10, 0.12, 0.70), mat_gun)
	return root


func _add_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
