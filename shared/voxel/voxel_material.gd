class_name VoxelMaterialData
extends RefCounted
## Материалы вокселей: твёрдость (HP на воксель), пробиваемость, цвет, обломки.
## Твёрдость в "условных HP", 1 HP = 1 урон оружия CS2.

enum MaterialId {
	AIR = 0,
	CONCRETE = 1,
	BRICK = 2,
	WOOD = 3,
	METAL = 4,
	SAND = 5,
	GLASS = 6,
	BEDROCK = 7,
}

# hp: здоровье одного вокселя. penetration_mult: во сколько раз пуля теряет меньше энергии.
# debris: сколько обломков образуется при полном разрушении. flammability: множитель урона от огня.
# color: для отладки.
const MATERIALS: Dictionary = {
	MaterialId.AIR: {"name":"Air","hp":0,"penetration_mult":1.0,"debris":0,"flammability":0.0,"color":Color(0,0,0,0)},
	MaterialId.CONCRETE: {"name":"Concrete","hp":120,"penetration_mult":0.35,"debris":3,"flammability":0.0,"color":Color(0.6,0.6,0.62)},
	MaterialId.BRICK: {"name":"Brick","hp":60,"penetration_mult":0.55,"debris":4,"flammability":0.0,"color":Color(0.65,0.32,0.25)},
	MaterialId.WOOD: {"name":"Wood","hp":30,"penetration_mult":0.85,"debris":5,"flammability":1.0,"color":Color(0.55,0.38,0.2)},
	MaterialId.METAL: {"name":"Metal","hp":200,"penetration_mult":0.25,"debris":2,"flammability":0.0,"color":Color(0.5,0.55,0.6)},
	MaterialId.SAND: {"name":"Sand","hp":15,"penetration_mult":1.2,"debris":6,"flammability":0.0,"color":Color(0.85,0.75,0.45)},
	MaterialId.GLASS: {"name":"Glass","hp":8,"penetration_mult":1.5,"debris":8,"flammability":0.0,"color":Color(0.7,0.9,1.0,0.5)},
	MaterialId.BEDROCK: {"name":"Bedrock","hp":999999,"penetration_mult":0.0,"debris":0,"flammability":0.0,"color":Color(0.2,0.2,0.2)},
}


static func get_material(id: int) -> Dictionary:
	return MATERIALS.get(id, MATERIALS[MaterialId.CONCRETE])


static func hp(id: int) -> int:
	return int(get_material(id).get("hp", 0))


static func penetration_mult(id: int) -> float:
	return float(get_material(id).get("penetration_mult", 1.0))


static func debris_count(id: int) -> int:
	return int(get_material(id).get("debris", 0))


static func flammability(id: int) -> float:
	return float(get_material(id).get("flammability", 0.0))


static func is_solid(id: int) -> bool:
	return id != MaterialId.AIR and id != MaterialId.BEDROCK


## Сколько урона требуется, чтобы разрушить N вокселей материала.
static func destruction_cost(material: int, voxel_count: int) -> int:
	return hp(material) * voxel_count
