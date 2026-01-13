# autoload/item_system.gd
# Item-Drop und Equipment-System für Tower Defense
extends Node

signal item_dropped(item: Dictionary, world_pos: Vector2)
signal item_collected(item: Dictionary)
signal item_equipped(tower: Node2D, item: Dictionary, slot: int)
signal item_unequipped(tower: Node2D, item: Dictionary, slot: int)
signal inventory_changed

const ITEM_ICON_PATH := "res://assets/items/"


# Inventar für gesammelte Items
var inventory: Array[Dictionary] = []
const MAX_INVENTORY := 20

# Item-Definitionen
const RARITIES := {
	"common": {"color": Color(0.8, 0.8, 0.8), "weight": 60, "multiplier": 1.0},
	"uncommon": {"color": Color(0.3, 0.9, 0.3), "weight": 25, "multiplier": 1.5},
	"rare": {"color": Color(0.3, 0.5, 1.0), "weight": 12, "multiplier": 2.0},
	"epic": {"color": Color(0.7, 0.3, 0.9), "weight": 3, "multiplier": 3.0}
}


const DROP_CHANCES := {
	"normal": 0.03,
	"fast": 0.05,
	"tank": 0.10,
	"boss": 1.0
}

# Item-Templates - sprite_index bezieht sich auf Position im Sheet
const ITEMS := {
	# === WAFFEN ===
	"sharp_blade": {
		"name": "Scharfe Klinge", "category": "weapon",
		"description": "+{value}% Schaden",
		"stat": "damage", "base_value": 8,
		"icon": "sharp_blade",  # lädt sharp_blade.png
		"allowed_towers": ["sword", "archer"]
	},
	"heavy_hammer": {
		"name": "Schwerer Hammer", "category": "weapon",
		"description": "+{value}% Schaden, -{penalty}% Feuerrate",
		"stat": "damage", "base_value": 15, 
		"penalty_stat": "fire_rate", "penalty_value": 10,
		"icon": "heavy_hammer",
		"allowed_towers": ["sword", "earth"]
	},
	"precision_bow": {
		"name": "Präzisions Bogen", "category": "weapon",
		"description": "+{value}% Crit-Chance",
		"stat": "crit_chance", "base_value": 5,
		"icon": "precision_bow",
		"allowed_towers": ["archer", "air"]
	},
	"piercing_tip": {
		"name": "Durchbohrende Spitze", "category": "weapon",
		"description": "Ignoriert {value}% Gegner-Resistenz",
		"stat": "armor_pen", "base_value": 15,
		"icon": "piercing_tip",
		"allowed_towers": ["archer", "fire"]
	},
	
	# === ACCESSOIRES ===
	"swift_boots": {
		"name": "Flinke Stiefel", "category": "accessory",
		"description": "+{value}% Feuerrate",
		"stat": "fire_rate", "base_value": 10,
		"icon": "swift_boots",
		"allowed_towers": []
	},
	"archer_hood": {
		"name": "Bogenschützen Haube", "category": "accessory",
		"description": "+{value}% Reichweite",
		"stat": "range", "base_value": 12,
		"icon": "archer_hood",
		"allowed_towers": ["archer"]
	},
	"blast_powder": {
		"name": "Sprengpulver", "category": "accessory",
		"description": "+{value}% Splash-Radius",
		"stat": "splash", "base_value": 20,
		"icon": "blast_powder",
		"allowed_towers": ["fire", "earth"]
	},
	
	# === ELEMENTAR-GEMS ===
	"fire_gem": {
		"name": "Feuerrubin", "category": "elemental",
		"description": "+{value}% Feuer-Schaden",
		"stat": "fire_damage", "base_value": 12,
		"icon": "fire_gem",
		"allowed_towers": ["fire", "archer", "sword"],
		"element": "fire"
	},
	"ice_shard": {
		"name": "Eissplitter", "category": "elemental",
		"description": "+{value}% Verlangsamung",
		"stat": "slow_bonus", "base_value": 15,
		"icon": "ice_shard",
		"allowed_towers": ["ice", "water"],
		"element": "ice"
	},
	"lightning_crystal": {
		"name": "Blitzkristall", "category": "elemental",
		"description": "+{value}% Kettenblitz-Schaden",
		"stat": "chain_damage", "base_value": 10,
		"icon": "lightning_crystal",
		"allowed_towers": ["lightning", "air"],
		"element": "lightning"
	},
	"earth_core": {
		"name": "Erdkern", "category": "elemental",
		"description": "+{value}% Stun-Chance",
		"stat": "stun_chance", "base_value": 8,
		"icon": "earth_core",
		"allowed_towers": ["earth", "sword"],
		"element": "earth"
	},
	"wind_essence": {
		"name": "Windessenz", "category": "elemental",
		"description": "+{value} Chain-Targets",
		"stat": "chain_bonus", "base_value": 1,
		"icon": "wind_essence",
		"allowed_towers": ["air", "ice"],
		"element": "air"
	},
	
	# === SPEZIAL (nur Rare/Epic) ===
	"vampiric_fang": {
		"name": "Vampirzahn", "category": "special",
		"description": "Heilt {value} Leben pro Kill",
		"stat": "life_steal", "base_value": 1,
		"icon": "vampiric_fang",
		"min_rarity": "rare",
		"allowed_towers": ["sword"]
	},
	"chain_link": {
		"name": "Kettenglied", "category": "special",
		"description": "Projektile springen zu {value} weiteren Zielen",
		"stat": "chain", "base_value": 1,
		"icon": "chain_link",
		"min_rarity": "rare",
		"allowed_towers": ["archer", "air"]
	},
	"golden_touch": {
		"name": "Goldene Berührung", "category": "special",
		"description": "+{value} Gold pro Kill durch diesen Turm",
		"stat": "gold_bonus", "base_value": 1,
		"icon": "golden_touch",
		"min_rarity": "rare",
		"allowed_towers": []
	},
	"multishot_rune": {
		"name": "Mehrfachschuss-Rune", "category": "special",
		"description": "Feuert {value} zusätzliche Projektile",
		"stat": "multishot", "base_value": 1,
		"icon": "multishot_rune",
		"min_rarity": "epic",
		"allowed_towers": ["archer", "water", "fire"]
	},
	"berserker_mark": {
		"name": "Berserker-Mal", "category": "special",
		"description": "+{value}% Schaden pro fehlendem Leben",
		"stat": "berserker", "base_value": 2,
		"icon": "berserker_mark",
		"min_rarity": "epic",
		"allowed_towers": ["sword", "fire"]
	}
}

var _icon_cache: Dictionary = {}


# Sprite-Sheets Cache
var sprite_sheets: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	# _load_sprite_sheets() nicht mehr nötig
	print("[ItemSystem] Initialisiert mit %d Item-Templates" % ITEMS.size())


func _load_sprite_sheets() -> void:
	var sheets := ["weapons", "accessories", "gems", "special"]
	for sheet_name in sheets:
		var path := "res://assets/items/%s.png" % sheet_name
		if ResourceLoader.exists(path):
			sprite_sheets[sheet_name] = load(path)
			print("[ItemSystem] Sheet geladen: %s" % sheet_name)


# === DROP SYSTEM ===

func try_drop_item(enemy_type: String, world_pos: Vector2, enemy_element: String = "") -> Dictionary:
	var drop_chance: float = DROP_CHANCES.get(enemy_type, 0.03)
	
	# Bonus für elementare Gegner
	if enemy_element != "" and enemy_element != "neutral":
		drop_chance *= 1.25
	
	if randf() > drop_chance:
		return {}
	
	var item := _generate_random_item(enemy_type, enemy_element)
	if item.is_empty():
		return {}
	
	# Einzigartige ID für dieses Item
	item["uid"] = _generate_uid()
	item["world_pos"] = world_pos
	
	item_dropped.emit(item, world_pos)
	return item


func _generate_random_item(enemy_type: String, enemy_element: String) -> Dictionary:
	var rarity := _roll_rarity(enemy_type)
	var valid_items := _get_valid_items_for_rarity(rarity, enemy_element)
	
	if valid_items.is_empty():
		return {}
	
	var template_id: String = valid_items[rng.randi() % valid_items.size()]
	var template: Dictionary = ITEMS[template_id]
	
	return _create_item_instance(template_id, template, rarity)


func _roll_rarity(enemy_type: String) -> String:
	var weights := RARITIES.duplicate(true)
	
	# Bosse haben bessere Chancen
	if enemy_type == "boss":
		weights["common"]["weight"] = 0
		weights["uncommon"]["weight"] = 30
		weights["rare"]["weight"] = 50
		weights["epic"]["weight"] = 20
	elif enemy_type == "tank":
		weights["uncommon"]["weight"] = 35
		weights["rare"]["weight"] = 18
	
	var total := 0
	for r in weights:
		total += weights[r]["weight"]
	
	var roll := rng.randi() % total
	var cumulative := 0
	
	for r in ["epic", "rare", "uncommon", "common"]:
		cumulative += weights[r]["weight"]
		if roll < cumulative:
			return r
	
	return "common"


func _get_valid_items_for_rarity(rarity: String, enemy_element: String) -> Array[String]:
	var valid: Array[String] = []
	var rarity_index := ["common", "uncommon", "rare", "epic"].find(rarity)
	
	for item_id in ITEMS:
		var template: Dictionary = ITEMS[item_id]
		
		# Min-Rarity Check
		var min_rarity: String = template.get("min_rarity", "common")
		var min_index := ["common", "uncommon", "rare", "epic"].find(min_rarity)
		if rarity_index < min_index:
			continue
		
		# Element-Bonus: Höhere Chance für passende Items
		if enemy_element != "" and enemy_element != "neutral":
			var item_elem: String = template.get("element", "")
			if item_elem == enemy_element:
				valid.append(item_id)
				valid.append(item_id)  # Doppelte Chance
		
		valid.append(item_id)
	
	return valid


func _create_item_instance(template_id: String, template: Dictionary, rarity: String) -> Dictionary:
	var rarity_data: Dictionary = RARITIES[rarity]
	var base_value: float = template.get("base_value", 10)
	var final_value := int(base_value * rarity_data["multiplier"])
	
	var item := {
		"id": template_id,
		"name": template["name"],
		"description": template["description"].replace("{value}", str(final_value)),
		"category": template["category"],
		"rarity": rarity,
		"color": rarity_data["color"],
		"stat": template["stat"],
		"value": final_value,
		"icon": template.get("icon", template_id),  # Fallback auf template_id
		"allowed_towers": template.get("allowed_towers", []),
		"element": template.get("element", "")
	}
	
	# Penalty Stats
	if template.has("penalty_stat"):
		var penalty_value := int(template["penalty_value"] * rarity_data["multiplier"])
		item["penalty_stat"] = template["penalty_stat"]
		item["penalty_value"] = penalty_value
		item["description"] = item["description"].replace("{penalty}", str(penalty_value))
	
	return item


func _generate_uid() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), rng.randi()]


# === INVENTORY ===

func collect_item(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY:
		print("[ItemSystem] Inventar voll!")
		return false
	
	inventory.append(item)
	item_collected.emit(item)
	inventory_changed.emit()
	print("[ItemSystem] Item gesammelt: %s (%s)" % [item["name"], item["rarity"]])
	return true


func remove_item(uid: String) -> Dictionary:
	for i in range(inventory.size()):
		if inventory[i].get("uid") == uid:
			var item: Dictionary = inventory[i]
			inventory.remove_at(i)
			inventory_changed.emit()
			return item
	return {}


func get_inventory() -> Array[Dictionary]:
	return inventory


func get_item_by_uid(uid: String) -> Dictionary:
	for item in inventory:
		if item.get("uid") == uid:
			return item
	return {}


# === EQUIPMENT ===

func can_equip_on_tower(item: Dictionary, tower: Node2D) -> bool:
	if not tower:
		return false
	
	var allowed: Array = item.get("allowed_towers", [])
	if allowed.is_empty():
		return true  # Keine Einschränkung
	
	var tower_type: String = tower.tower_type if tower.has_method("get") else ""
	var tower_element: String = ""
	if tower.has_method("get_effective_element"):
		tower_element = tower.get_effective_element()
	
	return tower_type in allowed or tower_element in allowed


func equip_item(tower: Node2D, item_uid: String, slot: int = 0) -> bool:
	var item: Dictionary = remove_item(item_uid)
	if item.is_empty():
		return false

	if not can_equip_on_tower(item, tower):
	# wieder zurück, weil wir es schon removed haben
		inventory.append(item)
		inventory_changed.emit()
		return false
	
	# Am Tower speichern
	if not tower.has_meta("equipped_items"):
		tower.set_meta("equipped_items", [{}, {}])
	
	var equipped: Array = tower.get_meta("equipped_items")
	
	# Altes Item zurück ins Inventar
	if not equipped[slot].is_empty():
		inventory.append(equipped[slot])
	
	equipped[slot] = item
	tower.set_meta("equipped_items", equipped)
	
	# Tower-Stats aktualisieren
	_apply_item_effects(tower)
	
	item_equipped.emit(tower, item, slot)
	inventory_changed.emit()
	return true


func unequip_item(tower: Node2D, slot: int) -> bool:
	if not tower.has_meta("equipped_items"):
		return false
	
	var equipped: Array = tower.get_meta("equipped_items")
	if equipped[slot].is_empty():
		return false
	
	var item: Dictionary = equipped[slot]
	equipped[slot] = {}
	tower.set_meta("equipped_items", equipped)
	
	# Zurück ins Inventar
	if inventory.size() < MAX_INVENTORY:
		inventory.append(item)
	
	# Tower-Stats aktualisieren
	_apply_item_effects(tower)
	
	item_unequipped.emit(tower, item, slot)
	inventory_changed.emit()
	return true


func get_tower_equipped_items(tower: Node2D) -> Array:
	if not tower.has_meta("equipped_items"):
		return [{}, {}]
	return tower.get_meta("equipped_items")


func _apply_item_effects(tower: Node2D) -> void:
	# Reset und Neu-Berechnung passiert im Tower selbst
	if tower.has_method("recalculate_stats"):
		tower.recalculate_stats()


# === ITEM BONUSES ABFRAGEN ===

func get_tower_item_bonus(tower: Node2D, stat: String) -> float:
	var total := 0.0
	var equipped := get_tower_equipped_items(tower)
	
	for item in equipped:
		if item.is_empty():
			continue
		if item.get("stat") == stat:
			total += item.get("value", 0)
		# Penalty abziehen
		if item.get("penalty_stat") == stat:
			total -= item.get("penalty_value", 0)
	
	return total


func get_tower_item_bonus_percent(tower: Node2D, stat: String) -> float:
	return get_tower_item_bonus(tower, stat) / 100.0


# === SPRITE HELPERS ===

func get_item_texture(item: Dictionary) -> Texture2D:
	var icon_name: String = item.get("icon", "")
	var rarity: String = item.get("rarity", "common")
	
	# Fallback auf item id wenn kein icon definiert
	if icon_name.is_empty():
		icon_name = item.get("id", "")
	
	if icon_name.is_empty():
		return null
	
	# Cache-Key mit Rarity
	var cache_key := "%s_%s" % [icon_name, rarity]
	
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	
	# 1. Versuch: Rarity-spezifisches Icon (z.B. sharp_blade_rare.png)
	var rarity_path := ITEM_ICON_PATH + icon_name + "_" + rarity + ".png"
	if ResourceLoader.exists(rarity_path):
		var tex := load(rarity_path) as Texture2D
		_icon_cache[cache_key] = tex
		return tex
	
	# 2. Fallback: Basis-Icon (z.B. sharp_blade.png)
	var base_path := ITEM_ICON_PATH + icon_name + ".png"
	if ResourceLoader.exists(base_path):
		var tex := load(base_path) as Texture2D
		_icon_cache[cache_key] = tex
		return tex
	
	push_warning("[ItemSystem] Icon nicht gefunden: %s (weder %s noch %s)" % [icon_name, rarity_path, base_path])
	return null




# === SAVE/LOAD ===

func get_save_data() -> Dictionary:
	return {"inventory": inventory.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	inventory = data.get("inventory", [])
	inventory_changed.emit()


func reset() -> void:
	inventory.clear()
	inventory_changed.emit()
	print("[ItemSystem] Reset")
