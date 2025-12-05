# tower_data.gd
extends Node

signal element_unlocked(element: String)

# Freigeschaltete Elemente (archer ist immer verfügbar)
var unlocked_elements: Array[String] = []

# Basis-Elemente die freigeschaltet werden können
const UNLOCKABLE_ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]

var towers := {
	"archer": {
		"name": "Bogenschütze",
		"description": "Standard Turm",
		"cost": 25,
		"damage": [15, 25, 40],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.7, 0.6, 0.5],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.687, 0.947, 0.913),
		"upgrade_costs": [35, 70],
		"special": "",
		"is_base": true,  # Immer verfügbar
		"combinations": [],
		"animated": false  # Statisches 64x64 Asset
	},
	"water": {
		"name": "Wasser",
		"description": "Verlangsamt Gegner",
		"cost": 30,
		"damage": [20, 35, 50],
		"range": [120.0, 140.0, 160.0],
		"fire_rate": [1.0, 0.9, 0.8],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.3, 0.6, 1.0),
		"upgrade_costs": [40, 80],
		"special": "slow",
		"slow_amount": [0.3, 0.4, 0.5],
		"is_base": false,
		"combinations": ["steam", "ice"],
		"animated": true
	},
	"fire": {
		"name": "Feuer",
		"description": "Brennender Flächenschaden",
		"cost": 30,
		"damage": [25, 45, 70],
		"range": [100.0, 110.0, 120.0],
		"fire_rate": [1.2, 1.1, 1.0],
		"splash": [40.0, 50.0, 60.0],
		"color": Color(1.0, 0.4, 0.2),
		"upgrade_costs": [45, 90],
		"special": "burn",
		"burn_damage": [5, 10, 15],
		"is_base": false,
		"combinations": ["steam", "lava"],
		"animated": true
	},
	"earth": {
		"name": "Erde",
		"description": "Hoher Schaden, langsam",
		"cost": 30,
		"damage": [40, 70, 110],
		"range": [90.0, 100.0, 110.0],
		"fire_rate": [2.0, 1.8, 1.6],
		"splash": [0.0, 30.0, 50.0],
		"color": Color(0.6, 0.4, 0.2),
		"upgrade_costs": [50, 100],
		"special": "stun",
		"stun_chance": [0.1, 0.15, 0.2],
		"is_base": false,
		"combinations": ["lava", "nature"],
		"animated": true
	},
	"air": {
		"name": "Luft",
		"description": "Schnell, Kettenblitz",
		"cost": 30,
		"damage": [15, 25, 40],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.5, 0.4, 0.3],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.8, 0.9, 1.0),
		"upgrade_costs": [35, 70],
		"special": "chain",
		"chain_targets": [0, 2, 3],
		"is_base": false,
		"combinations": ["ice", "nature"],
		"animated": true
	}
}

var combinations := {
	"steam": {
		"name": "Dampf",
		"requires": ["water", "fire"],
		"description": "Nebel der Gegner verwirrt",
		"cost": 100,
		"damage": [60, 90, 130],
		"range": [130.0, 150.0, 170.0],
		"fire_rate": [1.0, 0.9, 0.8],
		"splash": [50.0, 60.0, 70.0],
		"color": Color(0.8, 0.8, 0.9),
		"upgrade_costs": [80, 150],
		"special": "confuse"
	},
	"ice": {
		"name": "Eis",
		"requires": ["water", "air"],
		"description": "Friert Gegner ein",
		"cost": 100,
		"damage": [30, 50, 75],
		"range": [140.0, 160.0, 180.0],
		"fire_rate": [1.2, 1.0, 0.8],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.7, 0.9, 1.0),
		"upgrade_costs": [75, 140],
		"special": "freeze"
	},
	"lava": {
		"name": "Lava",
		"requires": ["fire", "earth"],
		"description": "Hinterlässt brennende Pfützen",
		"cost": 120,
		"damage": [80, 120, 170],
		"range": [80.0, 90.0, 100.0],
		"fire_rate": [2.5, 2.2, 1.9],
		"splash": [60.0, 75.0, 90.0],
		"color": Color(1.0, 0.3, 0.0),
		"upgrade_costs": [100, 180],
		"special": "pool"
	},
	"nature": {
		"name": "Natur",
		"requires": ["earth", "air"],
		"description": "Ranken die Gegner festhalten",
		"cost": 100,
		"damage": [25, 40, 60],
		"range": [120.0, 140.0, 160.0],
		"fire_rate": [1.5, 1.3, 1.1],
		"splash": [30.0, 40.0, 50.0],
		"color": Color(0.3, 0.8, 0.2),
		"upgrade_costs": [70, 130],
		"special": "root"
	}
}

const MAX_LEVEL := 2


func _ready() -> void:
	print("[TowerData] %d Basis-Türme, %d Kombinationen geladen" % [towers.size(), combinations.size()])


# === UNLOCK SYSTEM ===

func unlock_element(element: String) -> bool:
	if element not in UNLOCKABLE_ELEMENTS:
		print("[TowerData] Ungültiges Element: %s" % element)
		return false
	
	if element in unlocked_elements:
		print("[TowerData] Element bereits freigeschaltet: %s" % element)
		return false
	
	if not GameState.spend_element_core():
		print("[TowerData] Keine Element-Kerne verfügbar")
		return false
	
	unlocked_elements.append(element)
	element_unlocked.emit(element)
	print("[TowerData] Element freigeschaltet: %s" % element)
	return true


func is_element_unlocked(element: String) -> bool:
	return element in unlocked_elements


func is_tower_available(tower_type: String) -> bool:
	# Archer immer verfügbar
	if tower_type == "archer":
		return true
	
	# Basis-Element?
	if towers.has(tower_type):
		return tower_type in unlocked_elements
	
	# Kombination? Prüfen ob beide Basis-Elemente freigeschaltet
	if combinations.has(tower_type):
		var requires: Array = combinations[tower_type].get("requires", [])
		for req in requires:
			if req not in unlocked_elements:
				return false
		return true
	
	return false


func get_available_tower_types() -> Array[String]:
	var available: Array[String] = ["archer"]
	
	# Freigeschaltete Basis-Elemente
	for element in unlocked_elements:
		if towers.has(element):
			available.append(element)
	
	# Verfügbare Kombinationen
	for combo_name in combinations:
		if is_tower_available(combo_name):
			available.append(combo_name)
	
	return available


func get_locked_elements() -> Array[String]:
	var locked: Array[String] = []
	for element in UNLOCKABLE_ELEMENTS:
		if element not in unlocked_elements:
			locked.append(element)
	return locked


func get_unlocked_count() -> int:
	return unlocked_elements.size()


func get_total_unlockable() -> int:
	return UNLOCKABLE_ELEMENTS.size()


func reset_unlocks() -> void:
	unlocked_elements.clear()
	print("[TowerData] Unlocks zurückgesetzt")


# === EXISTING FUNCTIONS ===

func get_stat(tower_type: String, stat: String, level: int = 0) -> Variant:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return null
	
	if not data.has(stat):
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


func get_base_tower_types() -> Array[String]:
	var types: Array[String] = []
	for key in towers.keys():
		types.append(key)
	return types


func get_upgrade_cost(tower_type: String, current_level: int) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return -1
	
	if current_level >= MAX_LEVEL:
		return -1
	
	var costs: Array = data.get("upgrade_costs", [])
	if current_level >= costs.size():
		return -1
	
	return costs[current_level]


func can_upgrade(tower_type: String, current_level: int) -> bool:
	return current_level < MAX_LEVEL and get_upgrade_cost(tower_type, current_level) > 0


func get_sell_value(tower_type: String, level: int, placed_this_wave: bool) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return 0
	
	var total_invested: int = data.get("cost", 0)
	
	var upgrade_costs: Array = data.get("upgrade_costs", [])
	for i in range(level):
		if i < upgrade_costs.size():
			total_invested += upgrade_costs[i]
	
	if placed_this_wave:
		return total_invested
	else:
		return total_invested / 2


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
		"color": data.get("color", Color.WHITE)
	}
