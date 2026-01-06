# autoload/upgrade_system.gd
# Roguelike-Upgrade-System - Permanente Run-Upgrades
extends Node

signal upgrade_selected(upgrade_id: String)
signal upgrades_changed

# Aktive Upgrades für diesen Run (ID -> Anzahl/Stacks)
var active_upgrades: Dictionary = {}

# Alle verfügbaren Upgrades
const UPGRADES := {
	# === ELEMENT-SPEZIFISCH ===
	"fire_damage": {
		"name": "Feuersbrunst", "description": "+20% Schaden für Feuer-Türme",
		"icon": "🔥", "category": "element", "element": "fire",
		"stat": "damage", "bonus": 0.20, "stackable": true, "max_stacks": 3
	},
	"water_slow": {
		"name": "Tiefkühlung", "description": "+25% Slow-Effekt für Wasser-Türme",
		"icon": "💧", "category": "element", "element": "water",
		"stat": "slow", "bonus": 0.25, "stackable": true, "max_stacks": 3
	},
	"earth_stun": {
		"name": "Erschütterung", "description": "+5% Stun-Chance für Erde-Türme",
		"icon": "🪨", "category": "element", "element": "earth",
		"stat": "stun_chance", "bonus": 0.05, "stackable": true, "max_stacks": 3
	},
	"air_chain": {
		"name": "Kettenblitz", "description": "+1 Chain-Target für Luft-Türme",
		"icon": "💨", "category": "element", "element": "air",
		"stat": "chain", "bonus": 1, "stackable": true, "max_stacks": 3
	},
	"archer_speed": {
		"name": "Schnellfeuer", "description": "+15% Angriffsgeschwindigkeit für Bogen",
		"icon": "🏹", "category": "tower_type", "tower_type": "archer",
		"stat": "fire_rate", "bonus": 0.15, "stackable": true, "max_stacks": 3
	},
	"sword_cleave": {
		"name": "Wirbelwind", "description": "+15% Reichweite für Schwert-Türme",
		"icon": "⚔️", "category": "tower_type", "tower_type": "sword",
		"stat": "range", "bonus": 0.15, "stackable": true, "max_stacks": 3
	},
	# === WIRTSCHAFT ===
	"interest_bonus": {
		"name": "Zinseszins", "description": "+10 maximale Zinsen pro Welle",
		"icon": "💰", "category": "economy", "stat": "max_interest",
		"bonus": 10, "stackable": true, "max_stacks": 5
	},
	"flat_bonus": {
		"name": "Kriegskasse", "description": "+8 Gold Flat-Bonus pro Welle",
		"icon": "🪙", "category": "economy", "stat": "flat_bonus",
		"bonus": 8, "stackable": true, "max_stacks": 5
	},
	"interest_rate": {
		"name": "Investmentfonds", "description": "+2% Zinsrate",
		"icon": "📈", "category": "economy", "stat": "interest_rate",
		"bonus": 0.02, "stackable": true, "max_stacks": 3
	},
	"tower_discount": {
		"name": "Großhandel", "description": "-10% Tower-Baukosten",
		"icon": "🏷️", "category": "economy", "stat": "tower_cost",
		"bonus": 0.10, "stackable": true, "max_stacks": 3
	},
	"sell_value": {
		"name": "Rückgaberecht", "description": "+15% Verkaufswert",
		"icon": "💵", "category": "economy", "stat": "sell_value",
		"bonus": 0.15, "stackable": true, "max_stacks": 2
	},
	# === SUPPLY ===
	"supply_max": {
		"name": "Nachschub", "description": "+2 maximales Supply",
		"icon": "⛺", "category": "supply", "stat": "supply_max",
		"bonus": 2, "stackable": true, "max_stacks": 5
	},
	"farm_bonus": {
		"name": "Landwirtschaft", "description": "Farmen geben +1 zusätzliches Supply",
		"icon": "🌾", "category": "supply", "stat": "farm_supply",
		"bonus": 1, "stackable": true, "max_stacks": 3
	},
	# === GLOBAL TOWER ===
	"global_damage": {
		"name": "Waffenschmiede", "description": "+10% Schaden für ALLE Türme",
		"icon": "🗡️", "category": "global", "stat": "damage",
		"bonus": 0.10, "stackable": true, "max_stacks": 5
	},
	"global_range": {
		"name": "Adleraugen", "description": "+10% Reichweite für ALLE Türme",
		"icon": "👁️", "category": "global", "stat": "range",
		"bonus": 0.10, "stackable": true, "max_stacks": 3
	},
	"global_fire_rate": {
		"name": "Adrenalin", "description": "+10% Angriffsgeschwindigkeit für ALLE",
		"icon": "⚡", "category": "global", "stat": "fire_rate",
		"bonus": 0.10, "stackable": true, "max_stacks": 3
	},
	# === SPEZIAL ===
	"crit_chance": {
		"name": "Präzision", "description": "10% Chance auf Crit (+50% Schaden)",
		"icon": "🎯", "category": "special", "stat": "crit_chance",
		"bonus": 0.10, "stackable": true, "max_stacks": 3
	},
	"splash_bonus": {
		"name": "Explosiv", "description": "+20% Splash-Radius",
		"icon": "💥", "category": "special", "stat": "splash",
		"bonus": 0.20, "stackable": true, "max_stacks": 3
	},
	"enemy_gold": {
		"name": "Plünderer", "description": "+1 Gold pro getötetem Gegner",
		"icon": "💀", "category": "special", "stat": "enemy_gold",
		"bonus": 1, "stackable": true, "max_stacks": 5
	},
	"starting_gold": {
		"name": "Erbschaft", "description": "Sofort +50 Gold",
		"icon": "🎁", "category": "instant", "stat": "instant_gold",
		"bonus": 50, "stackable": true, "max_stacks": 99
	}
}

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	print("[UpgradeSystem] Initialisiert mit %d Upgrades" % UPGRADES.size())

func get_random_upgrades(count: int = 3) -> Array[String]:
	var available: Array[String] = []
	for id in UPGRADES:
		var data: Dictionary = UPGRADES[id]
		var current: int = active_upgrades.get(id, 0)
		var max_s: int = data.get("max_stacks", 1)
		if current < max_s:
			available.append(id)
	available.shuffle()
	var result: Array[String] = []
	for i in range(mini(count, available.size())):
		result.append(available[i])
	return result

func activate_upgrade(upgrade_id: String) -> bool:
	if not UPGRADES.has(upgrade_id):
		return false
	var data: Dictionary = UPGRADES[upgrade_id]
	var current: int = active_upgrades.get(upgrade_id, 0)
	var max_s: int = data.get("max_stacks", 1)
	if current >= max_s:
		return false
	active_upgrades[upgrade_id] = current + 1
	if data.get("category") == "instant":
		_apply_instant_effect(upgrade_id, data)
	upgrade_selected.emit(upgrade_id)
	upgrades_changed.emit()
	print("[UpgradeSystem] Aktiviert: %s (Stack %d/%d)" % [data.get("name", upgrade_id), active_upgrades[upgrade_id], max_s])
	return true

func _apply_instant_effect(id: String, data: Dictionary) -> void:
	match data.get("stat"):
		"instant_gold": GameState.gold += int(data.get("bonus", 0))

func get_damage_multiplier(tower_type: String, element: String) -> float:
	var mult := 1.0
	mult += get_upgrade_bonus("global_damage")
	if element != "":
		mult += get_element_bonus(element, "damage")
	mult += get_tower_type_bonus(tower_type, "damage")
	return mult

func get_range_multiplier(tower_type: String) -> float:
	var mult := 1.0
	mult += get_upgrade_bonus("global_range")
	mult += get_tower_type_bonus(tower_type, "range")
	return mult

func get_fire_rate_multiplier(tower_type: String) -> float:
	var mult := 1.0
	mult += get_upgrade_bonus("global_fire_rate")
	mult += get_tower_type_bonus(tower_type, "fire_rate")
	return mult

func get_splash_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("splash_bonus")

func get_crit_chance() -> float:
	return get_upgrade_bonus("crit_chance")

func get_max_interest_bonus() -> int:
	return int(get_upgrade_bonus("interest_bonus"))

func get_flat_bonus_addition() -> int:
	return int(get_upgrade_bonus("flat_bonus"))

func get_interest_rate_bonus() -> float:
	return get_upgrade_bonus("interest_rate")

func get_tower_cost_discount() -> float:
	return get_upgrade_bonus("tower_discount")

func get_sell_value_bonus() -> float:
	return get_upgrade_bonus("sell_value")

func get_enemy_gold_bonus() -> int:
	return int(get_upgrade_bonus("enemy_gold"))

func get_supply_max_bonus() -> int:
	return int(get_upgrade_bonus("supply_max"))

func get_farm_supply_bonus() -> int:
	return int(get_upgrade_bonus("farm_bonus"))

func get_element_bonus(element: String, stat: String) -> float:
	var total := 0.0
	for id in active_upgrades:
		var data: Dictionary = UPGRADES.get(id, {})
		if data.get("category") == "element" and data.get("element") == element:
			if data.get("stat") == stat:
				total += data.get("bonus", 0.0) * active_upgrades[id]
	return total

func get_slow_bonus(element: String) -> float:
	if element != "water": return 0.0
	return get_upgrade_bonus("water_slow")

func get_stun_bonus(element: String) -> float:
	if element != "earth": return 0.0
	return get_upgrade_bonus("earth_stun")

func get_chain_bonus(element: String) -> int:
	if element != "air": return 0
	return int(get_upgrade_bonus("air_chain"))

func get_tower_type_bonus(tower_type: String, stat: String) -> float:
	var total := 0.0
	for id in active_upgrades:
		var data: Dictionary = UPGRADES.get(id, {})
		if data.get("category") == "tower_type" and data.get("tower_type") == tower_type:
			if data.get("stat") == stat:
				total += data.get("bonus", 0.0) * active_upgrades[id]
	return total

func get_upgrade_bonus(upgrade_id: String) -> float:
	if not active_upgrades.has(upgrade_id): return 0.0
	var data: Dictionary = UPGRADES.get(upgrade_id, {})
	return data.get("bonus", 0.0) * active_upgrades[upgrade_id]

func get_upgrade_stacks(upgrade_id: String) -> int:
	return active_upgrades.get(upgrade_id, 0)

func get_upgrade_data(upgrade_id: String) -> Dictionary:
	return UPGRADES.get(upgrade_id, {})

func get_active_upgrades() -> Dictionary:
	return active_upgrades.duplicate()

func get_active_upgrade_count() -> int:
	var total := 0
	for id in active_upgrades:
		total += active_upgrades[id]
	return total

func reset() -> void:
	active_upgrades.clear()
	upgrades_changed.emit()
	print("[UpgradeSystem] Reset für neuen Run")
