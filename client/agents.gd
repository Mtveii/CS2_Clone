class_name AgentData
extends RefCounted
## оригинальные агенты (не Valve) + процедурные воксельные модельки по умолчанию.

const Team = preload("res://shared/gameplay/weapons.gd").Team

class Agent:
	var id: String
	var name: String
	var team: int
	var role: String
	var color: Color
	var accent: Color


var agents: Array = []


func _init() -> void:
	# Tеррористы
	agents.append(_make("vanguard", "Vanguard", Team.T, "Entry", Color(0.75, 0.45, 0.15), Color(0.2, 0.15, 0.1)))
	agents.append(_make("rebel", "Rebel", Team.T, "Support", Color(0.6, 0.2, 0.15), Color(0.15, 0.1, 0.1)))
	agents.append(_make("nomad", "Nomad", Team.T, "Sniper", Color(0.55, 0.5, 0.3), Color(0.2, 0.2, 0.12)))
	agents.append(_make("ghost", "Ghost", Team.T, "Lurker", Color(0.3, 0.3, 0.35), Color(0.1, 0.1, 0.12)))
	# CT спецназ
	agents.append(_make("sentinel", "Sentinel", Team.CT, "Anchor", Color(0.2, 0.4, 0.7), Color(0.1, 0.15, 0.25)))
	agents.append(_make("ranger", "Ranger", Team.CT, "Entry", Color(0.25, 0.55, 0.5), Color(0.1, 0.2, 0.2)))
	agents.append(_make("aegis", "Aegis", Team.CT, "Support", Color(0.5, 0.5, 0.65), Color(0.15, 0.15, 0.25)))
	agents.append(_make("warden", "Warden", Team.CT, "Sniper", Color(0.3, 0.35, 0.45), Color(0.1, 0.12, 0.18)))


func _make(id: String, name: String, team: int, role: String, color: Color, accent: Color) -> Agent:
	var a := Agent.new()
	a.id = id
	a.name = name
	a.team = team
	a.role = role
	a.color = color
	a.accent = accent
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


## Строит простую воксельную модельку агента (дефолтную, без скинов).
func build_voxel_model(agent: Agent) -> Node3D:
	var root := Node3D.new()
	root.name = "AgentModel_" + agent.id

	# Материалы
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = agent.color
	mat_body.roughness = 0.85
	var mat_gear := StandardMaterial3D.new()
	mat_gear.albedo_color = agent.accent
	mat_gear.roughness = 0.7
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
	#长长的武器剪影（默认模型）
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
