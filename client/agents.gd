class_name AgentData
extends RefCounted
## оригинальные агенты + фракции/редкости; CT и T экипируются раздельно.

const WeaponData = preload("res://shared/gameplay/weapons.gd")
const UiTheme = preload("res://client/ui_theme.gd")
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
	mat_body.roughness = 0.82
	var mat_gear := StandardMaterial3D.new()
	mat_gear.albedo_color = agent.accent
	mat_gear.roughness = 0.7
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.68, 0.52, 0.40)
	var mat_visor := StandardMaterial3D.new()
	mat_visor.albedo_color = Color(0.06, 0.10, 0.14)
	mat_visor.metallic = 0.75
	mat_visor.roughness = 0.18
	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.10, 0.11, 0.13)
	var mat_team := StandardMaterial3D.new()
	mat_team.albedo_color = UiTheme.TEAM_T if agent.team == Team.T else UiTheme.TEAM_CT
	mat_team.emission = mat_team.albedo_color
	mat_team.emission_energy = 0.25

	_add_sphere(root, "Head", Vector3(0, 1.60, 0), 0.17, mat_skin)
	_add_sphere(root, "Helmet", Vector3(0, 1.72, -0.01), 0.19, mat_gear)
	_add_box(root, "Visor", Vector3(0, 1.61, 0.16), Vector3(0.29, 0.09, 0.05), mat_visor)
	_add_box(root, "Chin", Vector3(0, 1.49, 0.10), Vector3(0.20, 0.07, 0.10), mat_dark)

	if agent.role == "Sniper":
		_add_box(root, "Hood", Vector3(0, 1.70, -0.14), Vector3(0.34, 0.26, 0.16), mat_gear)
	elif agent.role == "Support":
		_add_cyl(root, "HelmetCrest", Vector3(0, 1.88, 0), 0.05, 0.16, mat_dark)
	elif agent.role == "Entry":
		_add_box(root, "HelmetRail", Vector3(0, 1.86, 0.02), Vector3(0.30, 0.04, 0.28), mat_dark)
	else:
		_add_box(root, "CapBrim", Vector3(0, 1.72, 0.18), Vector3(0.32, 0.04, 0.14), mat_dark)

	_add_box(root, "Torso", Vector3(0, 1.13, 0), Vector3(0.56, 0.60, 0.32), mat_body)
	_add_box(root, "ChestPlate", Vector3(0, 1.20, 0.18), Vector3(0.48, 0.40, 0.08), mat_gear)
	_add_box(root, "TeamPatch", Vector3(-0.17, 1.28, 0.23), Vector3(0.10, 0.07, 0.02), mat_team)
	for i in range(3):
		_add_box(root, "Pouch_%d" % i, Vector3(-0.15 + i * 0.15, 0.96, 0.24), Vector3(0.12, 0.13, 0.06), mat_dark)
	_add_box(root, "StrapL", Vector3(-0.21, 1.18, 0.21), Vector3(0.06, 0.50, 0.05), mat_dark, Vector3(0, 0, -12))
	_add_box(root, "StrapR", Vector3(0.21, 1.18, 0.21), Vector3(0.06, 0.50, 0.05), mat_dark, Vector3(0, 0, 12))
	if agent.role == "Support":
		_add_box(root, "Backpack", Vector3(0, 1.14, -0.25), Vector3(0.40, 0.44, 0.20), mat_dark)

	_add_sphere(root, "ShoulderL", Vector3(-0.34, 1.34, 0), 0.12, mat_gear)
	_add_sphere(root, "ShoulderR", Vector3(0.34, 1.34, 0), 0.12, mat_gear)
	_add_cyl(root, "UpperArmL", Vector3(-0.39, 1.12, 0.02), 0.075, 0.40, mat_body, Vector3(-10, 0, 8))
	_add_cyl(root, "UpperArmR", Vector3(0.39, 1.12, 0.02), 0.075, 0.40, mat_body, Vector3(-10, 0, -8))
	_add_cyl(root, "ForearmL", Vector3(-0.38, 0.83, 0.12), 0.065, 0.34, mat_gear, Vector3(-38, 0, 4))
	_add_cyl(root, "ForearmR", Vector3(0.38, 0.83, 0.12), 0.065, 0.34, mat_gear, Vector3(-38, 0, -4))
	_add_box(root, "GloveL", Vector3(-0.34, 0.68, 0.30), Vector3(0.14, 0.12, 0.16), mat_dark)
	_add_box(root, "GloveR", Vector3(0.34, 0.68, 0.30), Vector3(0.14, 0.12, 0.16), mat_dark)

	_add_cyl(root, "ThighL", Vector3(-0.15, 0.62, 0), 0.10, 0.42, mat_body)
	_add_cyl(root, "ThighR", Vector3(0.15, 0.62, 0), 0.10, 0.42, mat_body)
	_add_cyl(root, "ShinL", Vector3(-0.15, 0.25, 0.02), 0.085, 0.36, mat_gear)
	_add_cyl(root, "ShinR", Vector3(0.15, 0.25, 0.02), 0.085, 0.36, mat_gear)
	_add_box(root, "KneePadL", Vector3(-0.15, 0.45, 0.11), Vector3(0.16, 0.13, 0.06), mat_dark)
	_add_box(root, "KneePadR", Vector3(0.15, 0.45, 0.11), Vector3(0.16, 0.13, 0.06), mat_dark)
	_add_box(root, "BootL", Vector3(-0.15, 0.07, 0.07), Vector3(0.20, 0.14, 0.34), mat_dark)
	_add_box(root, "BootR", Vector3(0.15, 0.07, 0.07), Vector3(0.20, 0.14, 0.34), mat_dark)

	var gun_len: float = 0.62
	if agent.role == "Sniper":
		gun_len = 0.86
	elif agent.role == "Entry":
		gun_len = 0.46
	_add_box(root, "WeaponBody", Vector3(0.20, 1.02, 0.34), Vector3(0.10, 0.12, gun_len * 0.55), mat_dark)
	_add_cyl(root, "WeaponBarrel", Vector3(0.20, 1.05, 0.34 - gun_len * 0.55), 0.025, gun_len * 0.45, mat_dark, Vector3(90, 0, 0))
	_add_box(root, "WeaponMag", Vector3(0.20, 0.90, 0.34), Vector3(0.08, 0.20, 0.10), mat_gear, Vector3(-12, 0, 0))
	if agent.role == "Sniper":
		_add_cyl(root, "Scope", Vector3(0.20, 1.16, 0.32), 0.035, 0.24, mat_dark, Vector3(90, 0, 0))
	return root


## Low-poly LOD для геймплея: ~150 треугольников, без сфер и мелких деталей.
## High-poly GLB из lobbies используется только в меню.
func build_lod_model(agent: Agent) -> Node3D:
	var root := Node3D.new()
	root.name = "AgentLOD_" + agent.id
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = agent.color
	var mat_gear := StandardMaterial3D.new()
	mat_gear.albedo_color = agent.accent
	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.12, 0.13, 0.15)
	_add_box(root, "Head", Vector3(0, 1.58, 0), Vector3(0.24, 0.26, 0.24), mat_dark)
	_add_box(root, "Helmet", Vector3(0, 1.74, 0), Vector3(0.28, 0.12, 0.28), mat_gear)
	_add_box(root, "Torso", Vector3(0, 1.15, 0), Vector3(0.52, 0.58, 0.30), mat_body)
	_add_box(root, "Vest", Vector3(0, 1.18, 0.17), Vector3(0.46, 0.40, 0.07), mat_gear)
	_add_box(root, "ArmL", Vector3(-0.34, 1.10, 0), Vector3(0.14, 0.52, 0.14), mat_body)
	_add_box(root, "ArmR", Vector3(0.34, 1.10, 0), Vector3(0.14, 0.52, 0.14), mat_body)
	_add_box(root, "LegL", Vector3(-0.14, 0.48, 0), Vector3(0.18, 0.66, 0.18), mat_gear)
	_add_box(root, "LegR", Vector3(0.14, 0.48, 0), Vector3(0.18, 0.66, 0.18), mat_gear)
	_add_box(root, "BootL", Vector3(-0.14, 0.08, 0.05), Vector3(0.20, 0.14, 0.30), mat_dark)
	_add_box(root, "BootR", Vector3(0.14, 0.08, 0.05), Vector3(0.20, 0.14, 0.30), mat_dark)
	_add_box(root, "Weapon", Vector3(0.20, 1.02, 0.34), Vector3(0.08, 0.10, 0.62), mat_dark)
	return root


func _add_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)


func _add_cyl(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	cyl.rings = 2
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)


func _add_sphere(parent: Node3D, name: String, pos: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 8
	mi.mesh = sphere
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
