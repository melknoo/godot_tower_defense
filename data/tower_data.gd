# tower_data.gd
extends Node

signal element_unlocked(element: String)
signal element_upgraded(element: String, new_level: int)

# Statt nur freigeschaltet: Speichert das MAX LEVEL pro Element (0 = nicht freigeschaltet)
# Level 1 = kann bauen, Level 2 = kann auf Stufe 2 upgraden, Level 3 = kann auf Stufe 3 upgraden
var element_levels: Dictionary = {}

# Basis-Elemente die freigeschaltet werden können
const UNLOCKABLE_ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]

var towers := {
	"archer": {
		"name": "Base",
		"description": "Standard Turm",
		"cost": 35,
		"damage": [25, 45, 60],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.7, 0.8, 0.5],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.687, 0.947, 0.913),
		"upgrade_costs": [50, 110],
		"special": "",
		"is_base": true,
		"combinations": [],
		"animated": false
	},
	"water": {
		"name": "Wasser",
		"description": "Verlangsamt Gegner",
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
		"animated": true
	},
	"fire": {
		"name": "Feuer",
		"description": "Brennender Flächenschaden",
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
		"animated": true
	},
	"earth": {
		"name": "Erde",
		"description": "Hoher Schaden, langsam",
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
		"animated": true
	},
	"air": {
		"name": "Luft",
		"description": "Schnell, Kettenblitz",
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

const MAX_LEVEL := 2  # 0, 1, 2 = 3 Stufen
const MAX_ELEMENT_LEVEL := 3  # Wie viele Kerne man in ein Element stecken kann


func _ready() -> void:
	# Initialisiere alle Elemente mit Level 0
	for element in UNLOCKABLE_ELEMENTS:
		element_levels[element] = 0
	print("[TowerData] %d Basis-Türme, %d Kombinationen geladen" % [towers.size(), combinations.size()])


# === NEUES KERN-SYSTEM ===

# Element freischalten ODER upgraden
func invest_core_in_element(element: String) -> bool:
	if element not in UNLOCKABLE_ELEMENTS:
		print("[TowerData] Ungültiges Element: %s" % element)
		return false
	
	var current_level: int = element_levels.get(element, 0)
	
	if current_level >= MAX_ELEMENT_LEVEL:
		print("[TowerData] Element bereits auf Max-Level: %s" % element)
		return false
	
	if not GameState.spend_element_core():
		print("[TowerData] Keine Element-Kerne verfügbar")
		return false
	
	element_levels[element] = current_level + 1
	var new_level: int = element_levels[element]
	
	if new_level == 1:
		element_unlocked.emit(element)
		print("[TowerData] Element freigeschaltet: %s (Level 1)" % element)
	else:
		element_upgraded.emit(element, new_level)
		print("[TowerData] Element aufgewertet: %s -> Level %d" % [element, new_level])
	
	return true


# Gibt das aktuelle Level eines Elements zurück (0 = nicht freigeschaltet)
func get_element_level(element: String) -> int:
	return element_levels.get(element, 0)


# Prüft ob ein Element freigeschaltet ist (Level >= 1)
func is_element_unlocked(element: String) -> bool:
	return get_element_level(element) >= 1


# Gibt das maximale Tower-Upgrade-Level für ein Element zurück
# Element Level 1 = Tower kann gebaut werden (Level 0)
# Element Level 2 = Tower kann auf Level 1 geupgradet werden
# Element Level 3 = Tower kann auf Level 2 geupgradet werden
func get_max_tower_level_for_element(element: String) -> int:
	var elem_level := get_element_level(element)
	if elem_level == 0:
		return -1  # Nicht freigeschaltet
	return elem_level - 1  # Element Level 1 = Tower Level 0, etc.


# Prüft ob ein Tower noch geupgradet werden kann (basierend auf Element-Level)
func can_upgrade(tower_type: String, current_tower_level: int) -> bool:
	# Archer hat keine Element-Beschränkung
	if tower_type == "archer":
		return current_tower_level < MAX_LEVEL
	
	# Für Basis-Elemente
	if towers.has(tower_type) and tower_type in UNLOCKABLE_ELEMENTS:
		var max_allowed := get_max_tower_level_for_element(tower_type)
		return current_tower_level < max_allowed and current_tower_level < MAX_LEVEL
	
	# Für Kombinationen: Minimum der beiden Element-Levels
	if combinations.has(tower_type):
		var requires: Array = combinations[tower_type].get("requires", [])
		var min_level := MAX_ELEMENT_LEVEL
		for req in requires:
			min_level = mini(min_level, get_element_level(req))
		var max_allowed := min_level - 1
		return current_tower_level < max_allowed and current_tower_level < MAX_LEVEL
	
	return current_tower_level < MAX_LEVEL


func is_tower_available(tower_type: String) -> bool:
	if tower_type == "archer":
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
	var available: Array[String] = ["archer"]
	
	for element in UNLOCKABLE_ELEMENTS:
		if is_element_unlocked(element):
			available.append(element)
	
	for combo_name in combinations:
		if is_tower_available(combo_name):
			available.append(combo_name)
	
	return available


# Gibt Elemente zurück die noch nicht auf Max sind
func get_upgradeable_elements() -> Array[String]:
	var upgradeable: Array[String] = []
	for element in UNLOCKABLE_ELEMENTS:
		if get_element_level(element) < MAX_ELEMENT_LEVEL:
			upgradeable.append(element)
	return upgradeable


# Für Anzeige: Wie viele Kerne wurden insgesamt investiert?
func get_total_cores_invested() -> int:
	var total := 0
	for element in UNLOCKABLE_ELEMENTS:
		total += get_element_level(element)
	return total


# Für Kompatibilität
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
	
	if not can_upgrade(tower_type, current_level):
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


func get_save_data() -> Dictionary:
	return {
		"element_levels": element_levels.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("element_levels"):
		element_levels = data["element_levels"].duplicate()
