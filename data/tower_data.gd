extends Node

# Alle verfügbaren Tower-Typen mit Stats pro Level
# Level 0 = Basis, Level 1 = Upgrade 1, Level 2 = Upgrade 2
var towers := {
	"water": {
		"name": "Wasser",
		"description": "Verlangsamt Gegner",
		"cost": 25,
		"damage": [20, 35, 50],
		"range": [120.0, 140.0, 160.0],
		"fire_rate": [1.0, 0.9, 0.8],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.3, 0.6, 1.0),
		"upgrade_costs": [40, 80],
		"special": "slow",
		"slow_amount": [0.3, 0.4, 0.5],
		"combinations": ["steam", "ice"]
	},
	"fire": {
		"name": "Feuer",
		"description": "Brennender Flächenschaden",
		"cost": 25,
		"damage": [25, 45, 70],
		"range": [100.0, 310.0, 320.0],
		"fire_rate": [1.2, 1.1, 1.0],
		"splash": [40.0, 50.0, 60.0],
		"color": Color(1.0, 0.4, 0.2),
		"upgrade_costs": [45, 90],
		"special": "burn",
		"burn_damage": [5, 10, 15],
		"combinations": ["steam", "lava"]
	},
	"earth": {
		"name": "Erde",
		"description": "Hoher Schaden, langsam",
		"cost": 25,
		"damage": [40, 70, 110],
		"range": [90.0, 100.0, 110.0],
		"fire_rate": [2.0, 1.8, 1.6],
		"splash": [0.0, 30.0, 50.0],
		"color": Color(0.6, 0.4, 0.2),
		"upgrade_costs": [50, 100],
		"special": "stun",
		"stun_chance": [0.1, 0.15, 0.2],
		"combinations": ["lava", "nature"]
	},
	"air": {
		"name": "Luft",
		"description": "Schnell, trifft fliegende Gegner",
		"cost": 25,
		"damage": [15, 25, 40],
		"range": [150.0, 170.0, 190.0],
		"fire_rate": [0.5, 0.4, 0.3],
		"splash": [0.0, 0.0, 0.0],
		"color": Color(0.8, 0.9, 1.0),
		"upgrade_costs": [35, 70],
		"special": "chain",
		"chain_targets": [0, 2, 3],
		"combinations": ["ice", "nature"]
	}
}

# Kombinationstürme (für später)
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

# Max Upgrade Level
const MAX_LEVEL := 2


func _ready() -> void:
	print("[TowerData] %d Basis-Türme, %d Kombinationen geladen" % [towers.size(), combinations.size()])


# Stat für einen Tower auf bestimmtem Level abrufen
func get_stat(tower_type: String, stat: String, level: int = 0) -> Variant:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return null
	
	if not data.has(stat):
		return null
	
	var value = data[stat]
	
	# Wenn es ein Array ist, Level-Wert zurückgeben
	if value is Array:
		level = clampi(level, 0, value.size() - 1)
		return value[level]
	
	return value


# Komplette Tower-Daten holen (prüft auch Kombinationen)
func get_tower_data(tower_type: String) -> Dictionary:
	if towers.has(tower_type):
		return towers[tower_type]
	if combinations.has(tower_type):
		return combinations[tower_type]
	return {}


# Prüfen ob Tower existiert
func has_tower(tower_type: String) -> bool:
	return towers.has(tower_type) or combinations.has(tower_type)


# Ist es ein Kombinations-Tower?
func is_combination(tower_type: String) -> bool:
	return combinations.has(tower_type)


# Basis-Tower-Typen für Shop
func get_base_tower_types() -> Array[String]:
	var types: Array[String] = []
	for key in towers.keys():
		types.append(key)
	return types


# Upgrade-Kosten für nächstes Level
func get_upgrade_cost(tower_type: String, current_level: int) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return -1
	
	if current_level >= MAX_LEVEL:
		return -1  # Bereits max Level
	
	var costs: Array = data.get("upgrade_costs", [])
	if current_level >= costs.size():
		return -1
	
	return costs[current_level]


# Kann Tower weiter upgraden?
func can_upgrade(tower_type: String, current_level: int) -> bool:
	return current_level < MAX_LEVEL and get_upgrade_cost(tower_type, current_level) > 0


# Verkaufswert berechnen
func get_sell_value(tower_type: String, level: int, placed_this_wave: bool) -> int:
	var data := get_tower_data(tower_type)
	if data.is_empty():
		return 0
	
	var total_invested: int = data.get("cost", 0)
	
	# Upgrade-Kosten addieren
	var upgrade_costs: Array = data.get("upgrade_costs", [])
	for i in range(level):
		if i < upgrade_costs.size():
			total_invested += upgrade_costs[i]
	
	# 100% wenn diese Runde platziert, sonst 50%
	if placed_this_wave:
		return total_invested
	else:
		return total_invested / 2


# Kombination finden für zwei Tower-Typen
func find_combination(type1: String, type2: String) -> String:
	for combo_name in combinations:
		var requires: Array = combinations[combo_name].get("requires", [])
		if type1 in requires and type2 in requires:
			return combo_name
	return ""


# Dictionary im alten Format für Kompatibilität (bis alles migriert ist)
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
