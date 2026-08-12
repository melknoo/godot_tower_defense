# tower_data.gd
# Mit Elemental Engraving und Supply-System
extends Node

signal element_unlocked(element: String)
signal element_upgraded(element: String, new_level: int)

var element_levels: Dictionary = {}

const UNLOCKABLE_ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]
const ENGRAVABLE_TOWERS: Array[String] = ["archer", "sword", "wizard", "cannon", "trapper"]
const SUPPLY_BUILDINGS: Array[String] = ["farm", "city"]  # Gebäude die max_supply erhöhen
const DEBUG_EXTRA_TOWERS := false

# Stadt: Sammelgebäude für Farmen. Ab diesem Supply-Maximum stehen genug Farmen
# auf dem Feld, dass ihr Platzbedarf zum Problem wird - dann wird sie freigeschaltet.
const CITY_UNLOCK_SUPPLY := 12
const CITY_CAPACITY := 6

# Supply-Kosten
const SUPPLY_COST_PLACE := 1      # Supply pro Tower-Platzierung
const SUPPLY_COST_UPGRADE := 1    # Supply pro Upgrade

var towers := {
	"archer": {
		"name": "Bogen",
		"description": "Standard Fernkampf-Turm\nKann elementar graviert werden!",
		"cost": 65,
		"damage": [38, 48, 60, 75, 93, 115, 143, 178],
		"range": [150.0, 170.0, 190.0, 210.0, 230.0, 250.0, 270.0, 290.0],
		"fire_rate": [0.75, 0.68, 0.61, 0.55, 0.50, 0.45, 0.41, 0.37],
		"splash": [0.0, 0.0, 0.0, 0.0, 0.0, 55.0, 62.0, 70.0],
		"color": Color(0.687, 0.947, 0.913),
		"upgrade_costs": [80, 170, 320, 560, 900, 1400, 2100],
		"special": "",
		"is_base": true,
		"engravable": true,
		"combinations": [],
		"animated": false,
		"attack_type": "projectile"
	},
	"sword": {
		"name": "Schwert",
		"description": "Nahkampf, trifft alle in Reichweite\nKann elementar graviert werden!",
		"cost": 45,
		"damage": [24, 30, 38, 48, 61, 78, 99, 126],
		"range": [80.0, 90.0, 110.0, 125.0, 145.0, 165.0, 185.0, 205.0],
		"fire_rate": [0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.56, 0.52],
		"splash": [70.0, 76.0, 82.0, 88.0, 94.0, 100.0, 106.0, 112.0],
		"color": Color(0.8, 0.7, 0.6),
		"upgrade_costs": [55, 115, 230, 420, 700, 1100, 1650],
		"special": "cleave",
		"cleave_angle": [360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0],
		"is_base": true,
		"engravable": true,
		"combinations": [],
		"animated": true,
		"attack_type": "melee"
	},
	"farm": {
		"name": "Farm",
		"description": "Erhöht max. Supply um 3\nKein Angriff",
		"cost": 75,
		"damage": [0],
		"range": [0.0],
		"fire_rate": [0.0],
		"splash": [0.0],
		"color": Color(0.6, 0.8, 0.4),
		"upgrade_costs": [],
		"special": "",
		"is_base": true,
		"is_supply_building": true,
		"supply_bonus": 3,
		"engravable": false,
		"combinations": [],
		"animated": false,
		"attack_type": "none"
	},
	"city": {
		"name": "Stadt",
		"description": "Nimmt Farmen auf und behält deren Supply\nMacht Platz auf dem Spielfeld",
		"cost": 150,
		"damage": [0],
		"range": [0.0],
		"fire_rate": [0.0],
		"splash": [0.0],
		"color": Color(0.75, 0.7, 0.55),
		"upgrade_costs": [],
		"special": "",
		"is_base": true,
		"is_supply_building": true,
		"supply_bonus": 4,   # eigener Basiswert, aufgenommene Farmen kommen obendrauf
		"engravable": false,
		"combinations": [],
		"animated": false,
		"attack_type": "none"
	},
	"wizard": {
		"name": "Zauberer",
		"description": "Schießt magische Projektile\nSpell ändert sich durch Gravur!",
		"cost": 80,
		"damage": [35, 46, 59, 75, 95, 120, 151, 190],
		"range": [180.0, 200.0, 220.0, 240.0, 260.0, 280.0, 300.0, 320.0],
		"fire_rate": [1.05, 0.96, 0.88, 0.80, 0.73, 0.66, 0.60, 0.55],
		"splash": [0.0, 0.0, 28.0, 38.0, 48.0, 60.0, 74.0, 90.0],
		"color": Color(0.6, 0.3, 0.9),
		"upgrade_costs": [70, 150, 300, 540, 880, 1350, 2050],
		"special": "spell",
		"is_base": true,
		"engravable": true,
		"animated": true,
		"attack_type": "projectile"
	},
	
	"cannon": {
		"name": "Kanone",
		"description": "Schwere Artillerie mit Explosion\nKann nahe Ziele NICHT treffen!",
		"cost": 120,
		"damage": [82, 108, 140, 180, 230, 290, 365, 460],
		"range": [250.0, 280.0, 310.0, 340.0, 370.0, 400.0, 430.0, 460.0],
		"min_range": [80.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0],
		"fire_rate": [2.5, 2.25, 2.05, 1.85, 1.68, 1.52, 1.38, 1.25],
		"splash": [76.0, 88.0, 102.0, 118.0, 136.0, 156.0, 180.0, 207.0],
		"color": Color(0.3, 0.3, 0.3),
		"upgrade_costs": [100, 220, 420, 720, 1150, 1800, 2700],
		"special": "explosive",
		"is_base": true,
		"engravable": true,
		"animated": false,
		"attack_type": "cannon"
	},
	
	"trapper": {
		"name": "Falle",
		"description": "Platziert Fallen auf dem Pfad\nFallen bleiben für 15s",
		"cost": 60,
		"damage": [36, 47, 60, 76, 95, 118, 147, 183],
		"range": [120.0, 145.0, 165.0, 190.0, 215.0, 240.0, 265.0, 290.0],
		"fire_rate": [2.5, 2.25, 2.0, 1.78, 1.58, 1.40, 1.25, 1.11],
		"trap_duration": [15.0, 17.0, 19.0, 22.0, 25.0, 28.0, 31.0, 34.0],
		# Stufe 8 bleibt bei 10 (statt 11 der reinen Reihe): 11 gleichzeitige Fallen à 34s
		# waeren am Bildschirm kaum noch auseinanderzuhalten.
		"max_traps": [4, 5, 6, 7, 8, 9, 10, 10],
		"splash": [30.0, 40.0, 50.0, 62.0, 75.0, 90.0, 106.0, 123.0],
		"slow_amount": [0.2, 0.23, 0.26, 0.29, 0.32, 0.35, 0.38, 0.41],
		"color": Color(0.4, 0.6, 0.3),
		"upgrade_costs": [50, 110, 220, 400, 680, 1050, 1600],
		"special": "trap",
		"is_base": true,
		"engravable": true,
		"animated": false,
		"attack_type": "trap"
	},
	
	"aura": {
		"name": "Aura-Turm",
		"description": "Verstärkt nahe Türme\nEffekt durch Gravur bestimmt!",
		"cost": 100,
		"range": [180.0, 205.0, 230.0, 255.0, 280.0, 305.0, 330.0, 355.0],
		"buff_strength": [0.12, 0.15, 0.18, 0.21, 0.24, 0.27, 0.30, 0.33],
		"color": Color(1.0, 0.9, 0.4),
		"upgrade_costs": [80, 170, 320, 560, 900, 1400, 2100],
		"special": "aura",
		"is_base": true,
		"engravable": true,
		"animated": false,
		"attack_type": "none",
		"damage": [0, 0, 0, 0, 0, 0, 0, 0],
		"fire_rate": [0, 0, 0, 0, 0, 0, 0, 0]
	},
	"water": {
		"name": "Wasser",
		"description": "Verlangsamt Gegner\nEffektiv gegen: 🔥",
		"cost": 50,
		"damage": [40, 55, 70],
		"range": [120.0, 140.0, 160.0],
		"fire_rate": [0.70, 0.65, 0.5],
		"splash": [45.0, 55.0, 70.0],
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
		"damage": [50, 65, 78],
		"range": [100.0, 110.0, 120.0],
		"fire_rate": [0.8, 0.7, 0.6],
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
		"fire_rate": [0.9, 0.8, 0.6],
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
		"name": "Dampf", 
		"requires": ["water", "fire"],
		#"requires": ["fire"],
		"description": "Nebel der Gegner verwirrt",
		"cost": 100, "damage": [75, 115, 165],
		"range": [140.0, 160.0, 180.0], "fire_rate": [0.95, 0.85, 0.75],
		"splash": [55.0, 70.0, 85.0], "color": Color(0.8, 0.8, 0.9),
		"upgrade_costs": [80, 150], "special": "confuse", "attack_type": "projectile"
	},
	"ice": {
		"name": "Eis", 
		"requires": ["water", "air"],
		#"requires": ["fire"],
		"description": "Friert Gegner ein",
		"cost": 100, "damage": [55, 90, 130],
		"range": [150.0, 175.0, 200.0], "fire_rate": [1.0, 0.85, 0.7],
		"splash": [30.0, 40.0, 50.0], "color": Color(0.7, 0.9, 1.0),
		"upgrade_costs": [75, 140], "special": "freeze", "attack_type": "projectile"
	},
	"lava": {
		"name": "Lava", 
		"requires": ["fire", "earth"],
		#"requires": ["fire"],
		"description": "Hinterlässt brennende Pfützen",
		"cost": 120, "damage": [100, 150, 210],
		"range": [90.0, 105.0, 120.0], "fire_rate": [2.2, 1.9, 1.6],
		"splash": [70.0, 88.0, 106.0], "color": Color(1.0, 0.3, 0.0),
		"upgrade_costs": [100, 180], "special": "pool", "attack_type": "projectile"
	},
	"nature": {
		"name": "Natur", 
		"requires": ["earth", "air"],
		#"requires": ["fire"],
		"description": "Ranken die Gegner festhalten",
		"cost": 100, "damage": [55, 90, 135],
		"range": [130.0, 150.0, 170.0], "fire_rate": [1.3, 1.1, 0.9],
		"splash": [40.0, 52.0, 66.0], "color": Color(0.3, 0.8, 0.2),
		"upgrade_costs": [70, 130], "special": "root", "attack_type": "projectile"
	}
}

# Von 5 auf 7 angehoben (Index 0..7, 8 Stufen): ein tiefer Run soll am Ende
# noch etwas zu kaufen haben. Betrifft nur die sechs Arrays mit 8 Eintraegen unten
# (archer/sword/wizard/cannon/trapper/aura) - Elementtuerme und Kombinationen
# sind zusaetzlich ueber get_max_tower_level_for_element() gedeckelt.
const MAX_LEVEL := 7
const MAX_ELEMENT_LEVEL := 3
const ENGRAVING_COST := 30


func _ready() -> void:
	for element in UNLOCKABLE_ELEMENTS:
		element_levels[element] = 0
	print("[TowerData] %d Basis-Türme, %d Kombinationen geladen" % [towers.size(), combinations.size()])


# === SUPPLY HELPERS ===

func get_supply_cost_place() -> int:
	return SUPPLY_COST_PLACE


func get_supply_cost_upgrade() -> int:
	return SUPPLY_COST_UPGRADE


func is_supply_building(tower_type: String) -> bool:
	var data := get_tower_data(tower_type)
	return data.get("is_supply_building", false)



func get_supply_bonus(tower_type: String) -> int:
	var data := get_tower_data(tower_type)
	var base_bonus: int = data.get("supply_bonus", 0)
	
	# Upgrade-Bonus für Farmen
	if tower_type == "farm" and UpgradeSystem:
		base_bonus += UpgradeSystem.get_farm_supply_bonus()
	
	return base_bonus


# Tower-Kosten mit Upgrade-Discount
func get_tower_cost(tower_type: String) -> int:
	var base_cost: int = get_stat(tower_type, "cost")
	if base_cost == null:
		return 0
	
	var discount := 0.0
	if UpgradeSystem:
		discount = UpgradeSystem.get_tower_cost_discount()
	
	return int(base_cost * (1.0 - discount))


func is_attackable_tower(tower_type: String) -> bool:
	var data := get_tower_data(tower_type)
	return data.get("attack_type", "projectile") != "none"


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
	if SynergySystem:
		SynergySystem.on_core_invested(element)
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
	# Farm kann nicht geupgradet werden
	if is_supply_building(tower_type):
		return false
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
	# Der erste Run beginnt bewusst nur mit Schwert und Farm.
	if tower_type in ["sword", "farm"]:
		return true
	if tower_type in ENGRAVABLE_TOWERS:
		return ProgressionSystem.is_tower_unlocked(tower_type) if ProgressionSystem else false
	if tower_type == "aura":
		return ProgressionSystem.is_tower_unlocked(tower_type) if ProgressionSystem else false
	if tower_type == "city":
		return GameState.get_effective_supply_max() >= CITY_UNLOCK_SUPPLY
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
	var available: Array[String] = []
	for tower_type in ["sword", "farm", "city", "archer", "wizard", "trapper", "cannon", "aura"]:
		if is_tower_available(tower_type):
			available.append(tower_type)
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


# Icon eines Turmtyps fuer UI-Listen. Liegt hier statt im Shop, damit Shop und
# Turm-Statistik dieselben Bilder benutzen.
func get_tower_icon_texture(tower_type: String) -> Texture2D:
	# Archer/Sword: ersten Frame aus dem Spritesheet ausschneiden
	if tower_type == "archer" or tower_type == "sword":
		var spritesheet_path := "res://assets/elemental_tower/%s_spritesheet.png" % tower_type
		if ResourceLoader.exists(spritesheet_path):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(spritesheet_path)
			var margin := 66.0
			atlas.region = Rect2(margin, margin + 10, 60, 60)
			return atlas

	# Farm: 32x48 Asset - oberen Bereich als Icon
	if tower_type == "farm":
		var farm_path := "res://assets/elemental_tower/farm.png"
		if ResourceLoader.exists(farm_path):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(farm_path)
			atlas.region = Rect2(0, 0, 32, 48)
			return atlas
		return null

	# Standard Tower Textur
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % tower_type
	if ResourceLoader.exists(texture_path):
		var full_tex: Texture2D = load(texture_path)
		if get_tower_data(tower_type).get("animated", true):
			var atlas := AtlasTexture.new()
			atlas.atlas = full_tex
			atlas.region = Rect2(0, 0, 16, 16)
			return atlas
		return full_tex

	return null


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
	var result := {
		"cost": data.get("cost", 0),
		"damage": get_stat(tower_type, "damage", level),
		"range": get_stat(tower_type, "range", level),
		"fire_rate": get_stat(tower_type, "fire_rate", level),
		"splash": get_stat(tower_type, "splash", level),
		"color": data.get("color", Color.WHITE),
		"attack_type": data.get("attack_type", "projectile")
	}
	
	# ✅ NEU: Spezielle Stats für neue Türme
	if data.has("min_range"):
		result["min_range"] = get_stat(tower_type, "min_range", level)
	if data.has("max_traps"):
		result["max_traps"] = get_stat(tower_type, "max_traps", level)
	if data.has("trap_duration"):
		result["trap_duration"] = get_stat(tower_type, "trap_duration", level)
	if data.has("buff_strength"):
		result["buff_strength"] = get_stat(tower_type, "buff_strength", level)
	
	return result


func get_save_data() -> Dictionary:
	return {"element_levels": element_levels.duplicate()}


func load_save_data(data: Dictionary) -> void:
	if data.has("element_levels"):
		element_levels = data["element_levels"].duplicate()
