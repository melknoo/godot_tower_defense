# tower_data.gd
# Mit Elemental Engraving für Basis-Türme
extends Node

signal element_unlocked(element: String)
signal element_upgraded(element: String, new_level: int)

var element_levels: Dictionary = {}

const UNLOCKABLE_ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]
const ENGRAVABLE_TOWERS: Array[String] = ["archer", "sword"]  # NEU: Türme die graviert werden können
const DEBUG_EXTRA_TOWERS := false

var towers := {
	"archer": {
		"name": "Bogen",
		"description": "Standard Fernkampf-Turm\nKann elementar graviert werden!",
		"cost": 35,
		"damage": [25, 45, 60],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.6, 0.5, 0.4],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.687, 0.947, 0.913),
		"upgrade_costs": [50, 110],
		"special": "",
		"is_base": true,
		"engravable": true,  # NEU
		"combinations": [],
		"animated": false,
		"attack_type": "projectile"
	},
	"sword": {
		"name": "Schwert",
		"description": "Nahkampf, trifft alle in Reichweite\nKann elementar graviert werden!",
		"cost": 25,
		"damage": [18, 32, 50],
		"range": [80.0, 90.0, 110.0],
		"fire_rate": [0.7, 0.8, 0.7],
		"splash": [70.0, 80.0, 90.0],
		"color": Color(0.8, 0.7, 0.6),
		"upgrade_costs": [55, 115],
		"special": "cleave",
		"cleave_angle": [360.0, 360.0, 360.0],
		"is_base": true,
		"engravable": true,  # NEU
		"combinations": [],
		"animated": true,
		"attack_type": "melee"
	},
	"water": {
		"name": "Wasser",
		"description": "Verlangsamt Gegner\nEffektiv gegen: 🔥",
		"cost": 50,
		"damage": [20, 35, 50],
		"range": [120.0, 140.0, 160.0],
		"fire_rate": [1.0, 0.9, 0.8],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.3, 0.6, 1.0),
		"upgrade_costs": [65, 110],
		"special": "slow",
		"slow_amount": [0.3, 0.4, 0.5],
		"is_base": false,
		"combinations": ["steam", "ice"],
		"animated": true,
		"attack_type": "projectile"
	},
	"fire": {
		"name": "Feuer",
		"description": "Brennender Flächenschaden\nEffektiv gegen: 🪨",
		"cost": 50,
		"damage": [25, 45, 70],
		"range": [100.0, 110.0, 120.0],
		"fire_rate": [1.2, 1.1, 1.0],
		"splash": [40.0, 50.0, 60.0],
		"color": Color(1.0, 0.4, 0.2),
		"upgrade_costs": [65, 110],
		"special": "burn",
		"burn_damage": [5, 10, 15],
		"is_base": false,
		"combinations": ["steam", "lava"],
		"animated": true,
		"attack_type": "projectile"
	},
	"earth": {
		"name": "Erde",
		"description": "Hoher Schaden, langsam\nEffektiv gegen: 💨",
		"cost": 50,
		"damage": [40, 70, 110],
		"range": [90.0, 100.0, 110.0],
		"fire_rate": [2.0, 1.8, 1.6],
		"splash": [0.0, 30.0, 50.0],
		"color": Color(0.6, 0.4, 0.2),
		"upgrade_costs": [75, 110],
		"special": "stun",
		"stun_chance": [0.1, 0.15, 0.2],
		"is_base": false,
		"combinations": ["lava", "nature"],
		"animated": true,
		"attack_type": "projectile"
	},
	"air": {
		"name": "Luft",
		"description": "Schnell, Kettenblitz\nEffektiv gegen: 💧",
		"cost": 50,
		"damage": [15, 25, 40],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.5, 0.4, 0.3],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.8, 0.9, 1.0),
		"upgrade_costs": [65, 110],
		"special": "chain",
		"chain_targets": [0, 2, 3],
		"is_base": false,
		"combinations": ["ice", "nature"],
		"animated": true,
		"attack_type": "projectile"
	}
}

var combinations := {
	"steam": {
		"name": "Dampf", "requires": ["water", "fire"],
		"description": "Nebel der Gegner verwirrt",
		"cost": 100, "damage": [60, 90, 130],
		"range": [130.0, 150.0, 170.0], "fire_rate": [1.0, 0.9, 0.8],
		"splash": [50.0, 60.0, 70.0], "color": Color(0.8, 0.8, 0.9),
		"upgrade_costs": [80, 150], "special": "confuse", "attack_type": "projectile"
	},
	"ice": {
		"name": "Eis", "requires": ["water", "air"],
		"description": "Friert Gegner ein",
		"cost": 100, "damage": [30, 50, 75],
		"range": [140.0, 160.0, 180.0], "fire_rate": [1.2, 1.0, 0.8],
		"splash": [0.0, 0.0, 0.0], "color": Color(0.7, 0.9, 1.0),
		"upgrade_costs": [75, 140], "special": "freeze", "attack_type": "projectile"
	},
	"lava": {
		"name": "Lava", "requires": ["fire", "earth"],
		"description": "Hinterlässt brennende Pfützen",
		"cost": 120, "damage": [80, 120, 170],
		"range": [80.0, 90.0, 100.0], "fire_rate": [2.5, 2.2, 1.9],
		"splash": [60.0, 75.0, 90.0], "color": Color(1.0, 0.3, 0.0),
		"upgrade_costs": [100, 180], "special": "pool", "attack_type": "projectile"
	},
	"nature": {
		"name": "Natur", "requires": ["earth", "air"],
		"description": "Ranken die Gegner festhalten",
		"cost": 100, "damage": [25, 40, 60],
		"range": [120.0, 140.0, 160.0], "fire_rate": [1.5, 1.3, 1.1],
		"splash": [30.0, 40.0, 50.0], "color": Color(0.3, 0.8, 0.2),
		"upgrade_costs": [70, 130], "special": "root", "attack_type": "projectile"
	}
}

const MAX_LEVEL := 2
const MAX_ELEMENT_LEVEL := 3
const ENGRAVING_COST := 30  # Gold-Kosten für Gravur


func _ready() -> void:
	for element in UNLOCKABLE_ELEMENTS:
		element_levels[element] = 0
	print("[TowerData] %d Basis-Türme, %d Kombinationen geladen" % [towers.size(), combinations.size()])


# === ELEMENT INVESTMENT ===

func invest_core_in_element(element: String) -> bool:
	if element not in UNLOCKABLE_ELEMENTS:
		return false
	var current_level: int = element_levels.get(element, 0)
	if current_level >= MAX_ELEMENT_LEVEL:
		return false
	if not GameState.spend_element_core():
		return false
	element_levels[element] = current_level + 1
	var new_level: int = element_levels[element]
	if new_level == 1:
		element_unlocked.emit(element)
	else:
		element_upgraded.emit(element, new_level)
	return true


func get_element_level(element: String) -> int:
	return element_levels.get(element, 0)


func is_element_unlocked(element: String) -> bool:
	return get_element_level(element) >= 1


func get_max_tower_level_for_element(element: String) -> int:
	var elem_level := get_element_level(element)
	if elem_level == 0:
		return -1
	return elem_level - 1


# === ENGRAVING SYSTEM ===

func can_engrave(tower_type: String) -> bool:
	return tower_type in ENGRAVABLE_TOWERS


func get_available_engravings() -> Array[String]:
	var available: Array[String] = []
	for element in UNLOCKABLE_ELEMENTS:
		if is_element_unlocked(element):
			available.append(element)
	return available


func get_engraving_cost() -> int:
	return ENGRAVING_COST


func can_afford_engraving() -> bool:
	return GameState.can_afford(ENGRAVING_COST)


# === TOWER AVAILABILITY ===

func can_upgrade(tower_type: String, current_tower_level: int) -> bool:
	if tower_type in ENGRAVABLE_TOWERS:
		return current_tower_level < MAX_LEVEL
	if towers.has(tower_type) and tower_type in UNLOCKABLE_ELEMENTS:
		var max_allowed := get_max_tower_level_for_element(tower_type)
		return current_tower_level < max_allowed and current_tower_level < MAX_LEVEL
	if combinations.has(tower_type):
		var requires: Array = combinations[tower_type].get("requires", [])
		var min_level := MAX_ELEMENT_LEVEL
		for req in requires:
			min_level = mini(min_level, get_element_level(req))
		var max_allowed := min_level - 1
		return current_tower_level < max_allowed and current_tower_level < MAX_LEVEL
	return current_tower_level < MAX_LEVEL


func is_tower_available(tower_type: String) -> bool:
	if tower_type in ENGRAVABLE_TOWERS:
		return true
	if towers.has(tower_type):
		return is_element_unlocked(tower_type)
	if combinations.has(tower_type):
		var requires: Array = combinations[tower_type].get("requires", [])
		for req in requires:
			if not is_element_unlocked(req):
				return false
		return true
	return false


func get_available_tower_types() -> Array[String]:
	var available: Array[String] = ["archer", "sword"]
	for element in UNLOCKABLE_ELEMENTS:
		if is_element_unlocked(element):
			available.append(element)
	for combo_name in combinations:
		if is_tower_available(combo_name):
			available.append(combo_name)
	return available


# === ELEMENT HELPERS ===

func get_upgradeable_elements() -> Array[String]:
	var upgradeable: Array[String] = []
	for element in UNLOCKABLE_ELEMENTS:
		if get_element_level(element) < MAX_ELEMENT_LEVEL:
			upgradeable.append(element)
	return upgradeable


func get_total_cores_invested() -> int:
	var total := 0
	for element in UNLOCKABLE_ELEMENTS:
		total += get_element_level(element)
	return total


func get_unlocked_count() -> int:
	var count := 0
	for element in UNLOCKABLE_ELEMENTS:
		if is_element_unlocked(element):
			count += 1
	return count


func get_total_unlockable() -> int:
	return UNLOCKABLE_ELEMENTS.size()


func get_locked_elements() -> Array[String]:
	var locked: Array[String] = []
	for element in UNLOCKABLE_ELEMENTS:
		if not is_element_unlocked(element):
			locked.append(element)
	return locked


func reset_unlocks() -> void:
	for element in UNLOCKABLE_ELEMENTS:
		element_levels[element] = 0


# === DATA GETTERS ===

func get_stat(tower_type: String, stat: String, level: int = 0) -> Variant:
	var data := get_tower_data(tower_type)
	if data.is_empty() or not data.has(stat):
		return null
	var value = data[stat]
	if value is Array:
		level = clampi(level, 0, value.size() - 1)
		return value[level]
	return value


func get_tower_data(tower_type: String) -> Dictionary:
	if towers.has(tower_type):
		return towers[tower_type]
	if combinations.has(tower_type):
		return combinations[tower_type]
	return {}


func has_tower(tower_type: String) -> bool:
	return towers.has(tower_type) or combinations.has(tower_type)


func is_combination(tower_type: String) -> bool:
	return combinations.has(tower_type)


func is_melee_tower(tower_type: String) -> bool:
	var data := get_tower_data(tower_type)
	return data.get("attack_type", "projectile") == "melee"


func get_base_tower_types() -> Array[String]:
	var types: Array[String] = []
	for key in towers.keys():
		types.append(key)
	return types


func get_upgrade_cost(tower_type: String, current_level: int) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty() or not can_upgrade(tower_type, current_level):
		return -1
	var costs: Array = data.get("upgrade_costs", [])
	if current_level >= costs.size():
		return -1
	return costs[current_level]


func get_sell_value(tower_type: String, level: int, placed_this_wave: bool) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return 0
	var total_invested: int = data.get("cost", 0)
	var upgrade_costs: Array = data.get("upgrade_costs", [])
	for i in range(level):
		if i < upgrade_costs.size():
			total_invested += upgrade_costs[i]
	return total_invested if placed_this_wave else total_invested / 2


func find_combination(type1: String, type2: String) -> String:
	for combo_name in combinations:
		var requires: Array = combinations[combo_name].get("requires", [])
		if type1 in requires and type2 in requires:
			return combo_name
	return ""


func get_legacy_data(tower_type: String, level: int = 0) -> Dictionary:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return {}
	return {
		"cost": data.get("cost", 0),
		"damage": get_stat(tower_type, "damage", level),
		"range": get_stat(tower_type, "range", level),
		"fire_rate": get_stat(tower_type, "fire_rate", level),
		"splash": get_stat(tower_type, "splash", level),
		"color": data.get("color", Color.WHITE),
		"attack_type": data.get("attack_type", "projectile")
	}


func get_save_data() -> Dictionary:
	return {"element_levels": element_levels.duplicate()}


func load_save_data(data: Dictionary) -> void:
	if data.has("element_levels"):
		element_levels = data["element_levels"].duplicate()
