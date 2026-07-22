# autoload/upgrade_system.gd
# Erweitert mit neuen Perk-Typen und besserer Organisation
extends Node

signal upgrade_selected(upgrade_id: String)
signal upgrades_changed

var active_upgrades: Dictionary = {}

# === UPGRADE-DEFINITIONEN ===
const UPGRADES := {
	# === ECONOMY ===
	"interest_bonus": {
		"name": "Schatzkammer", "description": "+10 Gold maximal aus Zinsen",
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
	"enemy_gold": {
		"name": "Plünderer", "description": "+1 Gold pro getötetem Gegner",
		"icon": "💀", "category": "economy", "stat": "enemy_gold",
		"bonus": 1, "stackable": true, "max_stacks": 5
	},
	"starting_gold": {
		"name": "Erbschaft", "description": "Sofort +50 Gold",
		"icon": "🎁", "category": "instant", "stat": "instant_gold",
		"bonus": 50, "stackable": true, "max_stacks": 99
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
	
	# === NEU: ISOLIERTE TÜRME ===
	"isolated_damage": {
		"name": "Einsiedler", "description": "+15% Schaden für isolierte Türme",
		"icon": "🏔️", "category": "special", "stat": "isolated_damage",
		"bonus": 0.15, "stackable": true, "max_stacks": 4,
		"tooltip": "Türme ohne benachbarte Türme im Radius von 120"
	},
	"isolated_range": {
		"name": "Fernspäher", "description": "+20% Reichweite für isolierte Türme",
		"icon": "🔭", "category": "special", "stat": "isolated_range",
		"bonus": 0.20, "stackable": true, "max_stacks": 3,
		"tooltip": "Türme ohne benachbarte Türme im Radius von 120"
	},
	
	# === NEU: ELEMENT-SPAWN-RATE ===
	"fire_spawn_rate": {
		"name": "Feuerwelle", "description": "+30% Feuer-Gegner in Wellen",
		"icon": "🔥", "category": "wave", "stat": "spawn_rate",
		"element": "fire", "bonus": 0.30, "stackable": true, "max_stacks": 3
		},
	"water_spawn_rate": {
		"name": "Flut", "description": "+30% Wasser-Gegner in Wellen",
		"icon": "💧", "category": "wave", "stat": "spawn_rate",
		"element": "water", "bonus": 0.30, "stackable": true, "max_stacks": 3
	},
	"earth_spawn_rate": {
		"name": "Erdrutsch", "description": "+30% Erd-Gegner in Wellen",
		"icon": "🪨", "category": "wave", "stat": "spawn_rate",
		"element": "earth", "bonus": 0.30, "stackable": true, "max_stacks": 3
	},
	"air_spawn_rate": {
		"name": "Sturm", "description": "+30% Luft-Gegner in Wellen",
		"icon": "💨", "category": "wave", "stat": "spawn_rate",
		"element": "air", "bonus": 0.30, "stackable": true, "max_stacks": 3
	},
	
	# === NEU: ELEMENT-DAMAGE ===
	"fire_damage": {
		"name": "Pyromanie", "description": "+15% Schaden für Feuer-Türme",
		"icon": "🔥", "category": "element", "stat": "damage",
		"element": "fire", "bonus": 0.15, "stackable": true, "max_stacks": 4
	},
	"water_damage": {
		"name": "Sturmflut", "description": "+15% Schaden für Wasser-Türme",
		"icon": "🌊", "category": "element", "stat": "damage",
		"element": "water", "bonus": 0.15, "stackable": true, "max_stacks": 4
	},
	"earth_damage": {
		"name": "Seismik", "description": "+15% Schaden für Erd-Türme",
		"icon": "⛰️", "category": "element", "stat": "damage",
		"element": "earth", "bonus": 0.15, "stackable": true, "max_stacks": 4
	},
	"air_damage": {
		"name": "Wirbelwind", "description": "+15% Schaden für Luft-Türme",
		"icon": "🌪️", "category": "element", "stat": "damage",
		"element": "air", "bonus": 0.15, "stackable": true, "max_stacks": 4
	},
	
	# === SPEZIAL ===
	"crit_chance": {
		"name": "Präzision", "description": "10% Chance auf Crit (+50% Schaden)",
		"icon": "🎯", "category": "special", "stat": "crit_chance",
		"bonus": 0.10, "stackable": true, "max_stacks": 3
	},
	 "crit_damage": {
		 "name": "Brutaler Treffer", "description": "+25% Crit-Schaden",
		 "icon": "💢", "category": "special", "stat": "crit_damage",
		 "bonus": 0.25, "stackable": true, "max_stacks": 4
 	},
	"splash_bonus": {
		"name": "Explosiv", "description": "+20% Splash-Radius",
		"icon": "💥", "category": "special", "stat": "splash",
		"bonus": 0.20, "stackable": true, "max_stacks": 3
	},
	
	# === TOWER-TYPE SPEZIFISCH ===
	"archer_damage": {
		"name": "Bogenschule", "description": "+20% Schaden für Bogenschützen",
		"icon": "🏹", "category": "tower_type", "stat": "damage",
		"tower_type": "archer", "bonus": 0.20, "stackable": true, "max_stacks": 3
	},
	"wizard_damage": {
		"name": "Arkane Macht", "description": "+20% Schaden für Zauberer",
		"icon": "🔮", "category": "tower_type", "stat": "damage",
		"tower_type": "wizard", "bonus": 0.20, "stackable": true, "max_stacks": 3
	},
	"sword_damage": {
		"name": "Klingentanz", "description": "+20% Schaden für Schwertkämpfer",
		"icon": "⚔️", "category": "tower_type", "stat": "damage",
		"tower_type": "sword", "bonus": 0.20, "stackable": true, "max_stacks": 3
	}
}

const BASE_CRIT_MULTIPLIER := 1.5 

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

	var result: Array[String] = []

	# Slot 1 bleibt rein zufällig, damit die Auswahl nicht deterministisch wird.
	available.shuffle()
	if not available.is_empty():
		result.append(available.pop_front())

	# Restliche Slots: gewichtet nach Meisterschaft (Build-Path-Bias).
	while result.size() < count and not available.is_empty():
		var pick := _weighted_pick(available)
		result.append(pick)
		available.erase(pick)

	return result


# Wählt eine Perk-ID gewichtet nach SynergySystem-Meisterschaft.
func _weighted_pick(pool: Array[String]) -> String:
	if not SynergySystem:
		return pool[rng.randi() % pool.size()]

	var total := 0.0
	for id in pool:
		total += SynergySystem.get_tag_draw_weight(SynergySystem.get_perk_tags(id))

	var roll := rng.randf() * total
	var cumulative := 0.0
	for id in pool:
		cumulative += SynergySystem.get_tag_draw_weight(SynergySystem.get_perk_tags(id))
		if roll <= cumulative:
			return id
	return pool[pool.size() - 1]

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
	if SynergySystem:
		SynergySystem.on_perk_selected(upgrade_id)
	upgrade_selected.emit(upgrade_id)
	upgrades_changed.emit()	
	print("[UpgradeSystem] Aktiviert: %s (Stack %d/%d)" % [data.get("name", upgrade_id), active_upgrades[upgrade_id], max_s])
	return true

func _apply_instant_effect(id: String, data: Dictionary) -> void:
	match data.get("stat"):
		"instant_gold": GameState.gold += int(data.get("bonus", 0))

# === BONUS-GETTER ===

func get_damage_multiplier(tower_type: String, element: String) -> float:
	var mult := 1.0
	mult += get_upgrade_bonus("global_damage")
	if ProgressionSystem:
		mult += ProgressionSystem.get_global_damage_bonus()
	if element != "":
		mult += get_element_bonus(element, "damage")
	mult += get_tower_type_bonus(tower_type, "damage")
	return mult

func get_isolated_damage_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("isolated_damage")

func get_isolated_range_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("isolated_range")

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

# === NEU: ELEMENT SPAWN RATE ===
func get_element_spawn_rate_bonus(element: String) -> float:
	"""Gibt zurück wie viel öfter ein Element spawnen soll (0.0 = normal, 0.3 = 30% mehr)"""
	var total := 0.0
	for id in active_upgrades:
		var data: Dictionary = UPGRADES.get(id, {})
		if data.get("category") == "wave" and data.get("stat") == "spawn_rate":
			if data.get("element") == element:
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
	
func get_crit_multiplier() -> float:
	var multiplier := BASE_CRIT_MULTIPLIER
	
	# Bonus durch Crit-Damage Upgrades
	var stacks: int = 0
	for upgrade_id in active_upgrades.keys():
		var upgrade: Dictionary = UPGRADES.get(upgrade_id, {})
		if upgrade.get("stat", "") == "crit_damage":
			stacks += active_upgrades[upgrade_id]
	
	if stacks > 0:
		var bonus_per_stack: float = UPGRADES.get("crit_damage", {}).get("bonus", 0.25)
		multiplier += bonus_per_stack * stacks
	
	return multiplier


func reset() -> void:
	active_upgrades.clear()
	upgrades_changed.emit()
	print("[UpgradeSystem] Reset für neuen Run")
