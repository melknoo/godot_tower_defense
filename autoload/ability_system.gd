# autoload/ability_system.gd
# Erweitertes Ability-System mit Charakteren, Slots und Upgrades
extends Node

signal ability_used(ability_id: String)
signal ability_ready(ability_id: String)
signal cooldown_updated(ability_id: String, remaining: float, total: float)
signal ability_unlocked(ability_id: String, slot: int)
signal ability_upgraded(ability_id: String, stat: String, new_value: float)
signal abilities_changed

# === KONSTANTEN ===
const MAX_ABILITY_SLOTS := 4
const MAX_UPGRADE_STACKS := 5

# === CHARAKTER-DEFINITIONEN ===
const CHARACTERS := {
	"pyromancer": {
		"name": "Pyromant",
		"description": "Meister des Feuers. Startet mit Meteor.",
		"icon_name": "char_pyromancer",
		"element": "fire",
		"starting_ability": "meteor",
		"color": Color(1.0, 0.4, 0.2),
		"unlocked": true  # Standardmäßig verfügbar
	},
	"cryomancer": {
		"name": "Kryomant",
		"description": "Beherrscher des Eises. Startet mit Frostnova.",
		"icon_name": "char_cryomancer",
		"element": "water",
		"starting_ability": "frost_nova",
		"color": Color(0.3, 0.6, 1.0),
		"unlocked": true
	},
	"geomancer": {
		"name": "Geomant",
		"description": "Herr der Erde. Startet mit Erdbeben.",
		"icon_name": "char_geomancer",
		"element": "earth",
		"starting_ability": "earthquake",
		"color": Color(0.6, 0.4, 0.2),
		"unlocked": true
	},
	"aeromancer": {
		"name": "Aeromant",
		"description": "Windläufer. Startet mit Blitzschlag.",
		"icon_name": "char_aeromancer",
		"element": "air",
		"starting_ability": "lightning",
		"color": Color(0.8, 0.9, 1.0),
		"unlocked": true
	}
}

# === ABILITY-DEFINITIONEN (erweitert) ===
const ABILITIES := {
	# --- STARTER ABILITIES ---
	"lightning": {
		"name": "Blitzschlag",
		"description": "Schlägt mit Blitz ein und springt zu nahen Gegnern",
		"icon_name": "ability_lightning",
		"element": "air",
		"cooldown": 8.0,
		"base_damage": 80,
		"radius": 40.0,
		"chain_count": 3,
		"chain_range": 120.0,
		"hotkey": KEY_1,
		"is_starter": true,
		"upgradeable_stats": ["cooldown", "damage", "chain_count", "chain_range"]
	},
	"frost_nova": {
		"name": "Frostnova",
		"description": "Friert alle Gegner im Bereich ein",
		"icon_name": "ability_frost",
		"element": "water",
		"cooldown": 12.0,
		"base_damage": 30,
		"radius": 100.0,
		"freeze_duration": 2.5,
		"hotkey": KEY_2,
		"is_starter": true,
		"upgradeable_stats": ["cooldown", "damage", "radius", "freeze_duration"]
	},
	"meteor": {
		"name": "Meteor",
		"description": "Ruft einen Meteor herbei (0.8s Verzögerung)",
		"icon_name": "ability_meteor",
		"element": "fire",
		"cooldown": 15.0,
		"base_damage": 200,
		"radius": 80.0,
		"impact_delay": 0.8,
		"burn_damage": 15,
		"burn_duration": 3.0,
		"hotkey": KEY_3,
		"is_starter": true,
		"upgradeable_stats": ["cooldown", "damage", "radius", "burn_damage", "burn_duration"]
	},
	"earthquake": {
		"name": "Erdbeben",
		"description": "Stunt alle Gegner auf dem Bildschirm",
		"icon_name": "ability_earthquake",
		"element": "earth",
		"cooldown": 20.0,
		"base_damage": 50,
		"stun_duration": 1.5,
		"hotkey": KEY_4,
		"is_starter": true,
		"upgradeable_stats": ["cooldown", "damage", "stun_duration"]
	},
	
	# --- ZUSÄTZLICHE ABILITIES ---
	"inferno": {
		"name": "Inferno",
		"description": "Erzeugt ein Flammenfeld das über Zeit Schaden macht",
		"icon_name": "ability_inferno",
		"element": "fire",
		"cooldown": 18.0,
		"base_damage": 25,  # Pro Tick
		"radius": 120.0,
		"duration": 4.0,
		"tick_rate": 0.5,
		"hotkey": KEY_1,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "radius", "duration"]
	},
	"tsunami": {
		"name": "Tsunami",
		"description": "Welle die Gegner zurückschiebt und verlangsamt",
		"icon_name": "ability_tsunami",
		"element": "water",
		"cooldown": 22.0,
		"base_damage": 60,
		"width": 200.0,
		"push_distance": 80.0,
		"slow_amount": 0.5,
		"slow_duration": 3.0,
		"hotkey": KEY_2,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "push_distance", "slow_amount", "slow_duration"]
	},
	"sandstorm": {
		"name": "Sandsturm",
		"description": "Reduziert Gegner-Geschwindigkeit im Bereich drastisch",
		"icon_name": "ability_sandstorm",
		"element": "air",
		"cooldown": 16.0,
		"base_damage": 15,
		"radius": 150.0,
		"duration": 5.0,
		"slow_amount": 0.6,
		"hotkey": KEY_1,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "radius", "duration", "slow_amount"]
	},
	"meteor_shower": {
		"name": "Meteorregen",
		"description": "Lässt mehrere kleine Meteore über Zeit regnen",
		"icon_name": "ability_meteor_shower",
		"element": "fire",
		"cooldown": 25.0,
		"base_damage": 50,  # Pro Meteor
		"radius": 40.0,  # Pro Meteor
		"area_radius": 180.0,  # Gesamtbereich
		"meteor_count": 6,
		"duration": 3.0,
		"hotkey": KEY_3,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "meteor_count", "area_radius"]
	},
	"ice_wall": {
		"name": "Eiswand",
		"description": "Erschafft temporäre Blockade auf dem Pfad",
		"icon_name": "ability_ice_wall",
		"element": "water",
		"cooldown": 30.0,
		"base_damage": 0,
		"wall_duration": 4.0,
		"wall_health": 500,
		"hotkey": KEY_2,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "wall_duration", "wall_health"]
	},
	"fissure": {
		"name": "Erdspalte",
		"description": "Erzeugt Riss der Gegner bei Überquerung stunnt",
		"icon_name": "ability_fissure",
		"element": "earth",
		"cooldown": 20.0,
		"base_damage": 40,
		"length": 200.0,
		"width": 30.0,
		"duration": 6.0,
		"stun_duration": 1.0,
		"hotkey": KEY_4,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "length", "duration", "stun_duration"]
	},
	"chain_lightning": {
		"name": "Kettenblitz",
		"description": "Blitz der zwischen vielen Gegnern springt",
		"icon_name": "ability_chain_lightning",
		"element": "air",
		"cooldown": 14.0,
		"base_damage": 45,
		"chain_count": 8,
		"chain_range": 150.0,
		"damage_falloff": 0.85,  # Jeder Sprung macht 85% vom vorherigen
		"hotkey": KEY_1,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "damage", "chain_count", "chain_range"]
	},
	"stone_skin": {
		"name": "Steinhaut",
		"description": "Gibt allen Türmen temporär Schadensreduktion",
		"icon_name": "ability_stone_skin",
		"element": "earth",
		"cooldown": 35.0,
		"base_damage": 0,
		"duration": 8.0,
		"damage_reduction": 0.3,  # 30% weniger Schaden an Base
		"tower_damage_bonus": 0.15,  # +15% Tower-Schaden
		"hotkey": KEY_4,
		"is_starter": false,
		"upgradeable_stats": ["cooldown", "duration", "damage_reduction", "tower_damage_bonus"]
	}
}

# === UPGRADE-DEFINITIONEN ===
const UPGRADE_VALUES := {
	"cooldown": {"per_stack": -0.10, "display": "-10% Cooldown", "format": "%.1fs"},
	"damage": {"per_stack": 0.20, "display": "+20% Schaden", "format": "+%d"},
	"radius": {"per_stack": 0.15, "display": "+15% Radius", "format": "+%.0f"},
	"chain_count": {"per_stack": 1, "display": "+1 Chain", "format": "+%d"},
	"chain_range": {"per_stack": 0.20, "display": "+20% Chain-Reichweite", "format": "+%.0f"},
	"freeze_duration": {"per_stack": 0.25, "display": "+25% Einfrier-Dauer", "format": "+%.1fs"},
	"burn_damage": {"per_stack": 0.25, "display": "+25% Brennschaden", "format": "+%d"},
	"burn_duration": {"per_stack": 0.20, "display": "+20% Brenndauer", "format": "+%.1fs"},
	"stun_duration": {"per_stack": 0.20, "display": "+20% Stun-Dauer", "format": "+%.1fs"},
	"duration": {"per_stack": 0.25, "display": "+25% Dauer", "format": "+%.1fs"},
	"slow_amount": {"per_stack": 0.15, "display": "+15% Slow", "format": "+%.0f%%"},
	"slow_duration": {"per_stack": 0.20, "display": "+20% Slow-Dauer", "format": "+%.1fs"},
	"push_distance": {"per_stack": 0.20, "display": "+20% Rückstoß", "format": "+%.0f"},
	"meteor_count": {"per_stack": 1, "display": "+1 Meteor", "format": "+%d"},
	"area_radius": {"per_stack": 0.15, "display": "+15% Bereich", "format": "+%.0f"},
	"wall_duration": {"per_stack": 0.25, "display": "+25% Wand-Dauer", "format": "+%.1fs"},
	"wall_health": {"per_stack": 0.30, "display": "+30% Wand-HP", "format": "+%d"},
	"length": {"per_stack": 0.20, "display": "+20% Länge", "format": "+%.0f"},
	"damage_reduction": {"per_stack": 0.10, "display": "+10% Schadensred.", "format": "+%.0f%%"},
	"tower_damage_bonus": {"per_stack": 0.10, "display": "+10% Tower-Bonus", "format": "+%.0f%%"}
}

# === RUNTIME STATE ===
var selected_character: String = ""
var unlocked_abilities: Array[String] = []  # Alle freigeschalteten Abilities
var equipped_abilities: Array[String] = []  # Aktuelle Slots (max 4)
var ability_upgrades: Dictionary = {}  # ability_id -> {stat: stacks}
var cooldowns: Dictionary = {}

var selected_ability: String = ""
var is_targeting := false

# Charakter-Freischaltungen (für Meta-Progression später)
var unlocked_characters: Dictionary = {}


func _ready() -> void:
	_init_character_unlocks()
	print("[AbilitySystem] Initialisiert mit %d Abilities, %d Charakteren" % [ABILITIES.size(), CHARACTERS.size()])


func _init_character_unlocks() -> void:
	for char_id in CHARACTERS:
		unlocked_characters[char_id] = CHARACTERS[char_id].get("unlocked", false)


func _process(delta: float) -> void:
	if not GameState or not GameState.wave_active:
		return
	
	for ability_id in cooldowns:
		if cooldowns[ability_id] > 0:
			cooldowns[ability_id] = maxf(0.0, cooldowns[ability_id] - delta)
			var total_cd := get_effective_cooldown(ability_id)
			cooldown_updated.emit(ability_id, cooldowns[ability_id], total_cd)
			
			if cooldowns[ability_id] <= 0:
				ability_ready.emit(ability_id)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	# Hotkeys basierend auf Slot-Position (1-4)
	var slot := -1
	match event.keycode:
		KEY_1: slot = 0
		KEY_2: slot = 1
		KEY_3: slot = 2
		KEY_4: slot = 3
	
	if slot >= 0 and slot < equipped_abilities.size():
		_on_ability_hotkey(equipped_abilities[slot])


# === CHARAKTER-SYSTEM ===

func select_character(char_id: String) -> bool:
	if not CHARACTERS.has(char_id):
		return false
	if not is_character_unlocked(char_id):
		return false
	
	selected_character = char_id
	_setup_starting_abilities()
	return true


func _setup_starting_abilities() -> void:
	equipped_abilities.clear()
	ability_upgrades.clear()
	cooldowns.clear()
	
	if selected_character.is_empty():
		return
	
	var char_data: Dictionary = CHARACTERS[selected_character]
	var starting_ability: String = char_data.get("starting_ability", "")
	
	if not starting_ability.is_empty():
		equipped_abilities.append(starting_ability)
		ability_upgrades[starting_ability] = {}
		cooldowns[starting_ability] = 0.0
	
	# Alle Starter-Abilities als "bekannt" markieren
	unlocked_abilities.clear()
	for ability_id in ABILITIES:
		if ABILITIES[ability_id].get("is_starter", false):
			unlocked_abilities.append(ability_id)
	
	abilities_changed.emit()
	print("[AbilitySystem] Charakter '%s' gewählt, Start-Ability: %s" % [char_data["name"], starting_ability])


func is_character_unlocked(char_id: String) -> bool:
	return unlocked_characters.get(char_id, false)


func unlock_character(char_id: String) -> bool:
	if not CHARACTERS.has(char_id):
		return false
	unlocked_characters[char_id] = true
	return true


func get_unlocked_characters() -> Array[String]:
	var result: Array[String] = []
	for char_id in CHARACTERS:
		if is_character_unlocked(char_id):
			result.append(char_id)
	return result


func get_character_data(char_id: String) -> Dictionary:
	return CHARACTERS.get(char_id, {})


# === ABILITY SLOTS ===

func can_add_ability() -> bool:
	return equipped_abilities.size() < MAX_ABILITY_SLOTS


func add_ability_to_slot(ability_id: String) -> bool:
	if not can_add_ability():
		return false
	if ability_id in equipped_abilities:
		return false
	if not ABILITIES.has(ability_id):
		return false
	
	equipped_abilities.append(ability_id)
	ability_upgrades[ability_id] = {}
	cooldowns[ability_id] = 0.0
	
	ability_unlocked.emit(ability_id, equipped_abilities.size() - 1)
	abilities_changed.emit()
	return true


func remove_ability_from_slot(slot: int) -> bool:
	if slot < 0 or slot >= equipped_abilities.size():
		return false
	
	var ability_id: String = equipped_abilities[slot]
	equipped_abilities.remove_at(slot)
	ability_upgrades.erase(ability_id)
	cooldowns.erase(ability_id)
	
	abilities_changed.emit()
	return true


func swap_ability_slots(slot1: int, slot2: int) -> bool:
	if slot1 < 0 or slot1 >= equipped_abilities.size():
		return false
	if slot2 < 0 or slot2 >= equipped_abilities.size():
		return false
	
	var temp: String = equipped_abilities[slot1]
	equipped_abilities[slot1] = equipped_abilities[slot2]
	equipped_abilities[slot2] = temp
	
	abilities_changed.emit()
	return true


func get_equipped_abilities() -> Array[String]:
	return equipped_abilities.duplicate()


func get_ability_slot(ability_id: String) -> int:
	return equipped_abilities.find(ability_id)


func is_ability_equipped(ability_id: String) -> bool:
	return ability_id in equipped_abilities


# === ABILITY UPGRADES ===

func upgrade_ability_stat(ability_id: String, stat: String) -> bool:
	if not ability_id in equipped_abilities:
		return false
	if not ABILITIES.has(ability_id):
		return false
	
	var ability_data: Dictionary = ABILITIES[ability_id]
	var upgradeable: Array = ability_data.get("upgradeable_stats", [])
	if not stat in upgradeable:
		return false
	
	if not ability_upgrades.has(ability_id):
		ability_upgrades[ability_id] = {}
	
	var current_stacks: int = ability_upgrades[ability_id].get(stat, 0)
	if current_stacks >= MAX_UPGRADE_STACKS:
		return false
	
	ability_upgrades[ability_id][stat] = current_stacks + 1
	
	var new_value := get_effective_stat(ability_id, stat)
	ability_upgraded.emit(ability_id, stat, new_value)
	abilities_changed.emit()
	return true


func get_ability_upgrade_stacks(ability_id: String, stat: String) -> int:
	if not ability_upgrades.has(ability_id):
		return 0
	return ability_upgrades[ability_id].get(stat, 0)


func get_total_upgrade_stacks(ability_id: String) -> int:
	if not ability_upgrades.has(ability_id):
		return 0
	var total := 0
	for stat in ability_upgrades[ability_id]:
		total += ability_upgrades[ability_id][stat]
	return total


func can_upgrade_stat(ability_id: String, stat: String) -> bool:
	if not ability_id in equipped_abilities:
		return false
	var current := get_ability_upgrade_stacks(ability_id, stat)
	return current < MAX_UPGRADE_STACKS


# === EFFECTIVE STATS (mit Upgrades) ===

func get_effective_stat(ability_id: String, stat: String) -> float:
	if not ABILITIES.has(ability_id):
		return 0.0
	
	var base_value: float
	var ability_data: Dictionary = ABILITIES[ability_id]
	
	# Basis-Wert ermitteln
	if stat == "damage":
		base_value = ability_data.get("base_damage", 0)
	elif stat == "cooldown":
		base_value = ability_data.get("cooldown", 10.0)
	else:
		base_value = ability_data.get(stat, 0)
	
	# Upgrade-Bonus anwenden
	var stacks := get_ability_upgrade_stacks(ability_id, stat)
	if stacks > 0 and UPGRADE_VALUES.has(stat):
		var per_stack: float = UPGRADE_VALUES[stat]["per_stack"]
		if stat == "chain_count" or stat == "meteor_count":
			# Additive für Ganzzahlen
			base_value += per_stack * stacks
		else:
			# Multiplikativ für Prozente
			base_value *= (1.0 + per_stack * stacks)
	
	return base_value


func get_effective_cooldown(ability_id: String) -> float:
	return get_effective_stat(ability_id, "cooldown")


func get_effective_damage(ability_id: String) -> float:
	return get_effective_stat(ability_id, "damage")


# === ABILITY USAGE ===

func _on_ability_hotkey(ability_id: String) -> void:
	if selected_ability == ability_id:
		cancel_targeting()
		return
	
	if not can_use_ability(ability_id):
		if Sound:
			Sound.play_error()
		return
	
	start_targeting(ability_id)


func start_targeting(ability_id: String) -> void:
	selected_ability = ability_id
	is_targeting = true
	if Sound:
		Sound.play_click()


func cancel_targeting() -> void:
	selected_ability = ""
	is_targeting = false


func can_use_ability(ability_id: String) -> bool:
	if not ability_id in equipped_abilities:
		return false
	if cooldowns.get(ability_id, 0.0) > 0:
		return false
	if not GameState or not GameState.wave_active:
		return false
	return true


func is_ability_ready(ability_id: String) -> bool:
	return cooldowns.get(ability_id, 0.0) <= 0


func get_cooldown_percent(ability_id: String) -> float:
	var total := get_effective_cooldown(ability_id)
	var remaining: float = cooldowns.get(ability_id, 0.0)
	if total <= 0:
		return 0.0
	return remaining / total


func get_remaining_cooldown(ability_id: String) -> float:
	return cooldowns.get(ability_id, 0.0)


# === ABILITY EXECUTION ===

func execute_ability(ability_id: String, target_pos: Vector2) -> bool:
	if not can_use_ability(ability_id):
		return false
	
	# Cooldown starten (mit Upgrades)
	cooldowns[ability_id] = get_effective_cooldown(ability_id)
	
	var power_mult := get_ability_power_multiplier(ability_id)
	
	match ability_id:
		"lightning":
			_execute_lightning(target_pos, power_mult)
		"frost_nova":
			_execute_frost_nova(target_pos, power_mult)
		"meteor":
			_execute_meteor(target_pos, power_mult)
		"earthquake":
			_execute_earthquake(power_mult)
		"inferno":
			_execute_inferno(target_pos, power_mult)
		"tsunami":
			_execute_tsunami(target_pos, power_mult)
		"sandstorm":
			_execute_sandstorm(target_pos, power_mult)
		"meteor_shower":
			_execute_meteor_shower(target_pos, power_mult)
		"ice_wall":
			_execute_ice_wall(target_pos)
		"fissure":
			_execute_fissure(target_pos, power_mult)
		"chain_lightning":
			_execute_chain_lightning(target_pos, power_mult)
		"stone_skin":
			_execute_stone_skin()
	
	is_targeting = false
	selected_ability = ""
	ability_used.emit(ability_id)
	
	if Sound:
		Sound.play_ability(ability_id)
	
	return true


func get_ability_power_multiplier(ability_id: String) -> float:
	var mult := 1.0
	if not ABILITIES.has(ability_id):
		return mult
	
	var element: String = ABILITIES[ability_id].get("element", "")
	if element.is_empty():
		return mult
	
	# Bonus von Element-Upgrades
	if UpgradeSystem:
		mult *= UpgradeSystem.get_damage_multiplier("", element)
	
	return mult


# === ABILITY IMPLEMENTATIONS ===
# (Diese Funktionen müssen mit effektiven Stats arbeiten)

func _execute_lightning(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("lightning") * power_mult)
	var chain_count := int(get_effective_stat("lightning", "chain_count"))
	var chain_range := get_effective_stat("lightning", "chain_range")
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist := 9999.0
	
	for enemy in enemies:
		var dist: float = enemy.position.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	
	if closest and closest.has_method("take_damage"):
		closest.take_damage(damage, true, "air")
		if VFX:
			VFX.spawn_lightning_strike(pos, closest.position)
		
		var hit_enemies: Array[Node2D] = [closest]
		var last_target := closest
		
		for i in range(chain_count):
			var next_target: Node2D = null
			var next_dist := chain_range
			
			for enemy in enemies:
				if enemy in hit_enemies:
					continue
				var dist: float = enemy.position.distance_to(last_target.position)
				if dist < next_dist:
					next_dist = dist
					next_target = enemy
			
			if next_target:
				var chain_damage := int(damage * pow(0.8, i + 1))
				next_target.take_damage(chain_damage, true, "air")
				if VFX:
					VFX.spawn_lightning_chain(last_target.position, next_target.position)
				hit_enemies.append(next_target)
				last_target = next_target


func _execute_frost_nova(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("frost_nova") * power_mult)
	var radius := get_effective_stat("frost_nova", "radius")
	var freeze_dur := get_effective_stat("frost_nova", "freeze_duration")
	
	if VFX:
		VFX.spawn_frost_nova(pos, radius)
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, true, "water")
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(freeze_dur)


func _execute_meteor(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("meteor") * power_mult)
	var radius := get_effective_stat("meteor", "radius")
	var burn_dmg := int(get_effective_stat("meteor", "burn_damage") * power_mult)
	var burn_dur := get_effective_stat("meteor", "burn_duration")
	var delay: float = ABILITIES["meteor"].get("impact_delay", 0.8)
	
	if VFX:
		VFX.spawn_meteor_warning(pos, radius)
	
	await get_tree().create_timer(delay).timeout
	
	if VFX:
		VFX.spawn_meteor_impact(pos, radius)
		VFX.screen_shake(8.0, 0.3)
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, true, "fire")
			if enemy.has_method("apply_burn"):
				enemy.apply_burn(burn_dmg, burn_dur)


func _execute_earthquake(power_mult: float) -> void:
	var damage := int(get_effective_damage("earthquake") * power_mult)
	var stun_dur := get_effective_stat("earthquake", "stun_duration")
	
	if VFX:
		VFX.screen_shake(12.0, 0.5)
		VFX.spawn_earthquake_effect()
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, true, "earth")
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(stun_dur)


func _execute_inferno(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("inferno") * power_mult)
	var radius := get_effective_stat("inferno", "radius")
	var duration := get_effective_stat("inferno", "duration")
	var tick_rate: float = ABILITIES["inferno"].get("tick_rate", 0.5)
	
	if VFX:
		VFX.spawn_inferno_field(pos, radius, duration)
	
	var ticks := int(duration / tick_rate)
	for i in range(ticks):
		await get_tree().create_timer(tick_rate).timeout
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.position.distance_to(pos) <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, true, "fire")


func _execute_tsunami(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("tsunami") * power_mult)
	var push_dist := get_effective_stat("tsunami", "push_distance")
	var slow_amt := get_effective_stat("tsunami", "slow_amount")
	var slow_dur := get_effective_stat("tsunami", "slow_duration")
	var width: float = ABILITIES["tsunami"].get("width", 200.0)
	
	if VFX:
		VFX.spawn_tsunami_wave(pos, width)
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if abs(enemy.position.y - pos.y) <= width / 2:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, true, "water")
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(push_dist)
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_amt, slow_dur)


func _execute_sandstorm(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("sandstorm") * power_mult)
	var radius := get_effective_stat("sandstorm", "radius")
	var duration := get_effective_stat("sandstorm", "duration")
	var slow_amt := get_effective_stat("sandstorm", "slow_amount")
	
	if VFX:
		VFX.spawn_sandstorm(pos, radius, duration)
	
	var tick_rate := 0.5
	var ticks := int(duration / tick_rate)
	for i in range(ticks):
		await get_tree().create_timer(tick_rate).timeout
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.position.distance_to(pos) <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, true, "air")
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(slow_amt, tick_rate + 0.1)


func _execute_meteor_shower(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("meteor_shower") * power_mult)
	var radius := get_effective_stat("meteor_shower", "radius")
	var area_radius := get_effective_stat("meteor_shower", "area_radius")
	var count := int(get_effective_stat("meteor_shower", "meteor_count"))
	var duration := get_effective_stat("meteor_shower", "duration")
	
	var interval := duration / count
	for i in range(count):
		var offset := Vector2(randf_range(-area_radius, area_radius), randf_range(-area_radius, area_radius))
		var meteor_pos := pos + offset
		
		if VFX:
			VFX.spawn_small_meteor(meteor_pos, radius)
		
		await get_tree().create_timer(0.3).timeout
		
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.position.distance_to(meteor_pos) <= radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, true, "fire")
		
		if i < count - 1:
			await get_tree().create_timer(interval - 0.3).timeout


func _execute_ice_wall(pos: Vector2) -> void:
	var duration := get_effective_stat("ice_wall", "wall_duration")
	var health := int(get_effective_stat("ice_wall", "wall_health"))
	
	# Ice Wall Entity spawnen (muss implementiert werden)
	if VFX:
		VFX.spawn_ice_wall(pos, duration, health)
	
	print("[AbilitySystem] Ice Wall spawned at %s, Duration: %.1f, HP: %d" % [pos, duration, health])


func _execute_fissure(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("fissure") * power_mult)
	var length := get_effective_stat("fissure", "length")
	var duration := get_effective_stat("fissure", "duration")
	var stun_dur := get_effective_stat("fissure", "stun_duration")
	var width: float = ABILITIES["fissure"].get("width", 30.0)
	
	if VFX:
		VFX.spawn_fissure(pos, length, width, duration)
	
	# Fissure bleibt für duration aktiv
	var tick_rate := 0.3
	var ticks := int(duration / tick_rate)
	var hit_enemies: Array[Node2D] = []
	
	for i in range(ticks):
		await get_tree().create_timer(tick_rate).timeout
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in hit_enemies:
				continue
			# Vereinfachte Kollision: Rechteck
			if abs(enemy.position.x - pos.x) <= length / 2 and abs(enemy.position.y - pos.y) <= width / 2:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, true, "earth")
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(stun_dur)
				hit_enemies.append(enemy)


func _execute_chain_lightning(pos: Vector2, power_mult: float) -> void:
	var damage := int(get_effective_damage("chain_lightning") * power_mult)
	var chain_count := int(get_effective_stat("chain_lightning", "chain_count"))
	var chain_range := get_effective_stat("chain_lightning", "chain_range")
	var falloff: float = ABILITIES["chain_lightning"].get("damage_falloff", 0.85)
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist := 9999.0
	
	for enemy in enemies:
		var dist: float = enemy.position.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	
	if not closest:
		return
	
	var hit_enemies: Array[Node2D] = [closest]
	var current_damage := damage
	var last_target := closest
	
	closest.take_damage(current_damage, true, "air")
	if VFX:
		VFX.spawn_lightning_strike(pos, closest.position)
	
	for i in range(chain_count - 1):
		current_damage = int(current_damage * falloff)
		var next_target: Node2D = null
		var next_dist := chain_range
		
		for enemy in enemies:
			if enemy in hit_enemies:
				continue
			var dist: float = enemy.position.distance_to(last_target.position)
			if dist < next_dist:
				next_dist = dist
				next_target = enemy
		
		if next_target:
			next_target.take_damage(current_damage, true, "air")
			if VFX:
				VFX.spawn_lightning_chain(last_target.position, next_target.position)
			hit_enemies.append(next_target)
			last_target = next_target
		else:
			break


func _execute_stone_skin() -> void:
	var duration := get_effective_stat("stone_skin", "duration")
	var dmg_reduction := get_effective_stat("stone_skin", "damage_reduction")
	var tower_bonus := get_effective_stat("stone_skin", "tower_damage_bonus")
	
	if VFX:
		VFX.spawn_stone_skin_effect(duration)
	
	# Buff auf GameState setzen (muss implementiert werden)
	if GameState and GameState.has_method("apply_stone_skin_buff"):
		GameState.apply_stone_skin_buff(duration, dmg_reduction, tower_bonus)
	
	print("[AbilitySystem] Stone Skin: %.1fs, %.0f%% reduction, %.0f%% tower bonus" % [duration, dmg_reduction * 100, tower_bonus * 100])


# === UTILITY ===

func get_available_abilities_for_unlock() -> Array[String]:
	"""Gibt Abilities zurück die noch nicht equipped sind"""
	var available: Array[String] = []
	for ability_id in ABILITIES:
		if ability_id in equipped_abilities:
			continue
		available.append(ability_id)
	return available


func get_abilities_by_element(element: String) -> Array[String]:
	var result: Array[String] = []
	for ability_id in ABILITIES:
		if ABILITIES[ability_id].get("element", "") == element:
			result.append(ability_id)
	return result


func get_ability_data(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


# === WELLEN-HELPER ===

# Ability-Upgrades: Nach Welle 4, 7, 10, 13... → (wave - 1) % 3 == 0 für wave > 3
static func should_show_ability_upgrades(wave: int) -> bool:
	if wave <= 3:
		return false
	return (wave - 1) % 3 == 0


static func get_next_ability_upgrade_wave(current_wave: int) -> int:
	if current_wave < 4:
		return 4
	var waves_since_4 := current_wave - 4
	var next_cycle := ((waves_since_4 / 3) + 1) * 3
	return 4 + next_cycle

func apply_ability_upgrade(ability_id: String, stat: String) -> bool:
	if not can_upgrade_stat(ability_id, stat):
		return false
	
	if not ability_upgrades.has(ability_id):
		ability_upgrades[ability_id] = {}
	
	if not ability_upgrades[ability_id].has(stat):
		ability_upgrades[ability_id][stat] = 0
	
	ability_upgrades[ability_id][stat] += 1
	
	# NEUE ZEILE - Signal emittieren:
	ability_upgraded.emit(ability_id)
	
	print("[AbilitySystem] Upgrade angewendet: %s.%s (Stufe %d)" % [
		ability_id, stat, ability_upgrades[ability_id][stat]
	])
	
	return true

func get_ability_upgrades(ability_id: String) -> Dictionary:
	"""Gibt Dictionary mit allen Upgrades für eine Ability zurück"""
	return ability_upgrades.get(ability_id, {}).duplicate()




func generate_ability_upgrade_choices(count: int = 3) -> Array[Dictionary]:
	"""Generiert Auswahl für Ability-Upgrade Screen"""
	var choices: Array[Dictionary] = []
	
	# Option 1: Neue Ability hinzufügen (wenn Slots frei)
	if can_add_ability():
		var available := get_available_abilities_for_unlock()
		available.shuffle()
		for ability_id in available.slice(0, 2):  # Max 2 neue Abilities anbieten
			choices.append({
				"type": "new_ability",
				"ability_id": ability_id,
				"data": ABILITIES[ability_id]
			})
	
	# Option 2: Bestehende Abilities upgraden
	for ability_id in equipped_abilities:
		var ability_data: Dictionary = ABILITIES[ability_id]
		if not ability_data.has("upgradeable_stats"):
			continue
		var upgradeable_stats: Array = ability_data["upgradeable_stats"]
		
		for stat: String in upgradeable_stats:
			if can_upgrade_stat(ability_id, stat):
				var current_stacks := get_ability_upgrade_stacks(ability_id, stat)
				choices.append({
					"type": "upgrade",
					"ability_id": ability_id,
					"stat": stat,
					"current_stacks": current_stacks,
					"upgrade_info": UPGRADE_VALUES.get(stat, {})
				})
	
	# Mischen und begrenzen
	choices.shuffle()
	return choices.slice(0, count) as Array[Dictionary]


# === SAVE/LOAD ===

func reset_for_new_run() -> void:
	equipped_abilities.clear()
	ability_upgrades.clear()
	cooldowns.clear()
	selected_ability = ""
	is_targeting = false
	
	if not selected_character.is_empty():
		_setup_starting_abilities()
	
	abilities_changed.emit()
	print("[AbilitySystem] Reset für neuen Run")


func get_save_data() -> Dictionary:
	return {
		"selected_character": selected_character,
		"equipped_abilities": equipped_abilities.duplicate(),
		"ability_upgrades": ability_upgrades.duplicate(true),
		"unlocked_characters": unlocked_characters.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	selected_character = data.get("selected_character", "")
	equipped_abilities.assign(data.get("equipped_abilities", []))
	ability_upgrades = data.get("ability_upgrades", {}).duplicate(true)
	unlocked_characters = data.get("unlocked_characters", {}).duplicate()
	
	# Cooldowns initialisieren
	cooldowns.clear()
	for ability_id in equipped_abilities:
		cooldowns[ability_id] = 0.0
	
	abilities_changed.emit()
