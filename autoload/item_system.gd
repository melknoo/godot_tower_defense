# autoload/item_system.gd
# Item-Drop und Equipment-System für Tower Defense
extends Node

signal item_dropped(item: Dictionary, world_pos: Vector2)
signal item_collected(item: Dictionary)
signal item_equipped(tower: Node2D, item: Dictionary, slot: int)
signal item_unequipped(tower: Node2D, item: Dictionary, slot: int)
signal inventory_changed

const ITEM_ICON_PATH := "res://assets/items/"

# Sammelicons je Kategorie - letzte Fallback-Stufe fuer Items, deren eigenes
# Icon noch nicht gezeichnet ist (siehe ASSETS_TODO.md).
const CATEGORY_FALLBACK_ICONS := {
	"weapon": "weapons",
	"accessory": "accessories",
	"elemental": "gems",
	"special": "special",
}


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


# Reihenfolge der Raritäten - Basis für Auf-/Abstieg (z.B. beim Kombinieren)
const RARITY_ORDER := ["common", "uncommon", "rare", "epic"]

# === TUNABLES KOMBINIEREN ===
# Gewicht der min_rarity beim Bestimmen des "besseren" Ausgangs-Items.
# Hoch genug, damit ein exklusiveres Template immer vor dem Basiswert gewinnt.
const COMBINE_MIN_RARITY_WEIGHT := 1000.0

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
	"assassins_blade": {
		"name": "Assassinen Klinge", "category": "weapon",
		"description": "+{value}% Crit-Chance",
		"stat": "crit_chance", "base_value": 6,
		"icon": "assassins_blade",
		"allowed_towers": ["sword", "archer"]
	},
	"lucky_charm": {
		"name": "Glücksbringer", "category": "accessory",
		"description": "+{value}% Crit-Chance",
		"stat": "crit_chance", "base_value": 4,
		"icon": "lucky_charm",
		"allowed_towers": []  # Alle Tower
	},
	"hawks_eye": {
		"name": "Falkenauge", "category": "accessory",
		"description": "+{value}% Crit-Chance, +{value2}% Reichweite",
		"stat": "crit_chance", "base_value": 3,
		"stat2": "range", "value2": 8,
		"icon": "hawks_eye",
		"allowed_towers": ["archer", "sniper", "air"],
		"min_rarity": "uncommon"
	},
	"brutal_edge": {
		"name": "Brutale Schneide", "category": "weapon",
		"description": "+{value}% Crit-Chance, -{penalty}% Feuerrate",
		"stat": "crit_chance", "base_value": 10,
		"penalty_stat": "fire_rate", "penalty_value": 15,
		"icon": "brutal_edge",
		"allowed_towers": ["sword", "earth"],
		"min_rarity": "rare"
	},
	"critical_cape": {
		"name": "Kritischer Cape", "category": "special",
		"description": "+{value}% Crit-Chance, +{value2}% Crit-Schaden",
		"stat": "crit_chance", "base_value": 5,
		"stat2": "crit_damage", "value2": 15,
		"icon": "critical_cape",
		"allowed_towers": ["archer", "wizard"],
		"min_rarity": "rare"
	},
	"vorpal_blade": {
		"name": "Vorpal Klinge", "category": "weapon",
		"description": "+{value}% Crit-Chance, +{value2}% Crit-Schaden",
		"stat": "crit_chance", "base_value": 8,
		"stat2": "crit_damage", "value2": 25,
		"icon": "vorpal_blade",
		"allowed_towers": ["sword", "archer"],
		"min_rarity": "epic"
	},
	"longrange_bow": {
		"name": "Langstrecken Bonge", "category": "accessory",
		"description": "+{value}% Crit-Chance, aber nur auf große Distanz",
		"stat": "crit_chance", "base_value": 15,
		"icon": "longrange_bow",
		"allowed_towers": ["archer", "sniper"],
		"min_rarity": "rare"
	},
	
	# NEU - Crit-Damage Items (braucht Crit-Damage System aus upgrade_system):
	"executioners_axe": {
		"name": "Henkers Axt", "category": "accessory",
		"description": "+{value}% Crit-Schaden",
		"stat": "crit_damage", "base_value": 20,
		"icon": "executioners_axe",
		"allowed_towers": [],
		"min_rarity": "uncommon"
	},
	"death_mark": {
		"name": "Todessiegel", "category": "special",
		"description": "+{value}% Crit-Schaden",
		"stat": "crit_damage", "base_value": 30,
		"icon": "death_mark",
		"allowed_towers": ["sword", "archer"],
		"min_rarity": "rare"
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
		"allowed_towers": ["fire", "earth", "cannon"]
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
		"stat": "stun_bonus", "base_value": 8,
		"icon": "earth_core",
		"allowed_towers": ["earth", "sword"],
		"element": "earth"
	},
	"wind_essence": {
		"name": "Windessenz", "category": "elemental",
		"description": "+{value} Chain-Targets",
		"stat": "chain_bonus", "base_value": 1,
		"icon": "wind_essence",
		"allowed_towers": ["air"],
		"element": "air"
	},
	
	# === SPEZIAL (nur Rare/Epic) ===
	"life_amulet": {
		"name": "Amulett des Lebens", "category": "special",
		"description": "Heilt {value} Leben pro Kill",
		"stat": "life_steal", "base_value": 1,
		"icon": "life_amulet",
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
	},

	# === SITUATIVE ITEMS (Gegner-Zustand) ===
	# Der Schadensbonus (stat/base_value) wirkt NUR, wenn die condition erfüllt ist.
	"frost_breaker": {
		"name": "Frostbrecher", "category": "special",
		"description": "+{value}% Schaden gegen eingefrorene Gegner",
		"stat": "damage", "base_value": 50,
		"condition": {"type": "enemy_frozen"},
		"icon": "frost_breaker",
		"min_rarity": "uncommon",
		"allowed_towers": []
	},
	"ember_lance": {
		"name": "Glutlanze", "category": "special",
		"description": "+{value}% Schaden gegen brennende Gegner",
		"stat": "damage", "base_value": 40,
		"condition": {"type": "enemy_burning"},
		"icon": "ember_lance",
		"min_rarity": "uncommon",
		"allowed_towers": []
	},
	"undertow_blade": {
		"name": "Sog-Klinge", "category": "special",
		"description": "+{value}% Schaden gegen verlangsamte Gegner",
		"stat": "damage", "base_value": 30,
		"condition": {"type": "enemy_slowed"},
		"icon": "undertow_blade",
		"min_rarity": "uncommon",
		"allowed_towers": []
	},
	"first_strike": {
		"name": "Erstschlag", "category": "special",
		"description": "+{value}% Schaden gegen Gegner mit voller Gesundheit",
		"stat": "damage", "base_value": 35,
		"condition": {"type": "enemy_full_hp"},
		"icon": "first_strike",
		"min_rarity": "uncommon",
		"allowed_towers": ["archer", "cannon", "sniper"]
	},

	# === PROC / TRIGGER ITEMS ===
	# proc: trigger every_n_shots | on_crit | chance_on_hit | on_hit; effect explosion|burn|freeze|execute
	"blast_bolt": {
		"name": "Sprengbolzen", "category": "special",
		"description": "Jeder 5. Schuss löst eine Explosion aus ({value} Schaden)",
		"stat": "proc", "base_value": 60,
		"proc": {"trigger": "every_n_shots", "n": 5, "effect": "explosion", "value": 60, "radius": 70},
		"icon": "blast_bolt",
		"min_rarity": "rare",
		"allowed_towers": ["archer", "cannon", "wizard"]
	},
	"ember_core": {
		"name": "Zunderkern", "category": "special",
		"description": "Crits entzünden den Gegner ({value} Brennschaden/s)",
		"stat": "proc", "base_value": 12,
		"proc": {"trigger": "on_crit", "effect": "burn", "value": 12},
		"icon": "ember_core",
		"min_rarity": "uncommon",
		"allowed_towers": []
	},
	"frost_splinter": {
		"name": "Frostsplitter", "category": "special",
		"description": "12% Chance pro Treffer, den Gegner einzufrieren",
		"stat": "proc", "base_value": 1,
		"proc": {"trigger": "chance_on_hit", "chance": 0.12, "effect": "freeze", "value": 1.0},
		"icon": "frost_splinter",
		"min_rarity": "rare",
		"allowed_towers": ["water", "ice", "archer"]
	},
	"executioner": {
		"name": "Henker", "category": "special",
		"description": "Tötet Gegner unter 12% Gesundheit sofort",
		"stat": "proc", "base_value": 12,
		"proc": {"trigger": "on_hit", "effect": "execute", "value": 0.12},
		"icon": "executioner",
		"min_rarity": "epic",
		"allowed_towers": ["sword", "archer", "cannon"]
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
	var rarity_index := RARITY_ORDER.find(rarity)

	for item_id in ITEMS:
		var template: Dictionary = ITEMS[item_id]

		# Min-Rarity Check
		var min_rarity: String = template.get("min_rarity", "common")
		var min_index := RARITY_ORDER.find(min_rarity)
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
		"icon": template.get("icon", template_id),
		"allowed_towers": template.get("allowed_towers", []),
		"element": template.get("element", "")
	}
	
	# Penalty Stats
	if template.has("penalty_stat"):
		var penalty_value := int(template["penalty_value"] * rarity_data["multiplier"])
		item["penalty_stat"] = template["penalty_stat"]
		item["penalty_value"] = penalty_value
		item["description"] = item["description"].replace("{penalty}", str(penalty_value))
	
	# NEU: Zweiter Stat (für Dual-Stat Items)
	if template.has("stat2"):
		var value2 := int(template.get("value2", 10) * rarity_data["multiplier"])
		item["stat2"] = template["stat2"]
		item["value2"] = value2
		item["description"] = item["description"].replace("{value2}", str(value2))

	# NEU: Situative Bedingung (Gegner-Zustand) — Bonus wirkt nur bei erfüllter condition
	if template.has("condition"):
		item["condition"] = template["condition"].duplicate(true)

	# NEU: Proc/Trigger-Effekt — Wert skaliert mit Rarität
	if template.has("proc"):
		var proc: Dictionary = template["proc"].duplicate(true)
		if proc.has("value"):
			proc["value"] = proc["value"] * rarity_data["multiplier"]
		item["proc"] = proc

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


# === KOMBINIEREN ===
# Regel: Zwei Items derselben Rarität ergeben ein Item der nächsthöheren Rarität.
# Kategorie/Typ spielt keine Rolle. Kostenlos - der Verzicht auf den Verkaufserlös
# ist der Preis. Items der höchsten Rarität sind nicht weiter kombinierbar.

func get_next_rarity(rarity: String) -> String:
	var idx := RARITY_ORDER.find(rarity)
	if idx < 0 or idx >= RARITY_ORDER.size() - 1:
		return ""
	return RARITY_ORDER[idx + 1]


func is_max_rarity(rarity: String) -> bool:
	return get_next_rarity(rarity) == ""


func can_combine(item_a: Dictionary, item_b: Dictionary) -> bool:
	if item_a.is_empty() or item_b.is_empty():
		return false
	# Nicht dasselbe Item zweimal
	if item_a.get("uid", "") == item_b.get("uid", ""):
		return false
	var rarity: String = item_a.get("rarity", "common")
	if rarity != item_b.get("rarity", ""):
		return false
	return not is_max_rarity(rarity)


# Für die UI: Item ist kombinierbar, wenn ein Partner derselben Rarität im Inventar liegt
func is_item_combinable(item: Dictionary) -> bool:
	if item.is_empty() or is_max_rarity(item.get("rarity", "common")):
		return false
	for other in inventory:
		if can_combine(item, other):
			return true
	return false


# Gibt es überhaupt ein kombinierbares Paar? (Panel sonst gar nicht erst öffnen)
func has_combinable_pair() -> bool:
	var counts := {}
	for item in inventory:
		var rarity: String = item.get("rarity", "common")
		if is_max_rarity(rarity):
			continue
		counts[rarity] = int(counts.get(rarity, 0)) + 1
		if counts[rarity] >= 2:
			return true
	return false


# Kombiniert zwei Inventar-Items zu einem Item der nächsthöheren Rarität.
# An Türmen ausgerüstete Items liegen nicht im Inventar und sind damit automatisch ausgeschlossen.
# Rückgabe: das neue Item, oder ein leeres Dictionary wenn die Kombination ungültig ist.
func combine_items(uid_a: String, uid_b: String) -> Dictionary:
	if uid_a.is_empty() or uid_b.is_empty() or uid_a == uid_b:
		return {}

	var item_a := get_item_by_uid(uid_a)
	var item_b := get_item_by_uid(uid_b)
	if not can_combine(item_a, item_b):
		return {}

	var new_rarity := get_next_rarity(item_a.get("rarity", "common"))
	if new_rarity.is_empty():
		return {}

	var source := _pick_combine_source(item_a, item_b)
	var template_id: String = source.get("id", "")
	if not ITEMS.has(template_id):
		return {}

	# Ergebnis wird komplett neu aus dem Template gerollt, damit alle abgeleiteten
	# Werte (Beschreibung, value/value2, Penalty, Proc) zur neuen Rarität passen.
	# Stats der Ausgangs-Items werden bewusst NICHT addiert.
	var result := _create_item_instance(template_id, ITEMS[template_id], new_rarity)
	result["uid"] = _generate_uid()

	_remove_item_silent(uid_a)
	_remove_item_silent(uid_b)
	inventory.append(result)
	inventory_changed.emit()

	print("[ItemSystem] Kombiniert: %s + %s -> %s (%s)" % [
		item_a.get("name", "?"), item_b.get("name", "?"), result["name"], new_rarity
	])
	return result


# Das "bessere" der beiden Items liefert das Template fürs Ergebnis.
# Beide haben dieselbe Rarität, deshalb entscheidet zuerst die Exklusivität des
# Templates (min_rarity), danach der höhere Basiswert. Gleichstand -> item_a.
func _pick_combine_source(item_a: Dictionary, item_b: Dictionary) -> Dictionary:
	return item_b if _combine_source_score(item_b) > _combine_source_score(item_a) else item_a


func _combine_source_score(item: Dictionary) -> float:
	var template: Dictionary = ITEMS.get(item.get("id", ""), {})
	var min_index := RARITY_ORDER.find(template.get("min_rarity", "common"))
	return float(maxi(min_index, 0)) * COMBINE_MIN_RARITY_WEIGHT + float(template.get("base_value", 0))


# Entfernt ohne inventory_changed - für Operationen, die am Ende einmal sammeln melden
func _remove_item_silent(uid: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("uid") == uid:
			inventory.remove_at(i)
			return true
	return false


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
		# Situative Items werden nicht statisch verrechnet, sondern pro Treffer
		# über get_tower_conditional_mult() angewendet.
		if not item.get("condition", {}).is_empty():
			continue
		if item.get("stat") == stat:
			total += item.get("value", 0)
		# Penalty abziehen
		if item.get("penalty_stat") == stat:
			total -= item.get("penalty_value", 0)

	return total


# === SITUATIVE ITEMS (Gegner-Zustand) ===

# Multiplikator aus allen situativen Items, deren Bedingung der Gegner-Zustand erfüllt.
func get_tower_conditional_mult(tower: Node2D, enemy: Node2D) -> float:
	var mult := 1.0
	if not is_instance_valid(tower) or not is_instance_valid(enemy):
		return mult
	for item in get_tower_equipped_items(tower):
		if item.is_empty():
			continue
		var cond: Dictionary = item.get("condition", {})
		if cond.is_empty():
			continue
		if _enemy_matches_condition(enemy, cond.get("type", "")):
			mult *= 1.0 + float(item.get("value", 0)) / 100.0
	return mult


func _enemy_matches_condition(enemy: Node2D, cond_type: String) -> bool:
	match cond_type:
		"enemy_frozen":
			var v = enemy.get("is_frozen")
			return v != null and bool(v)
		"enemy_burning":
			var v = enemy.get("burn_timer")
			return v != null and float(v) > 0.0
		"enemy_slowed":
			var v = enemy.get("slow_timer")
			var f = enemy.get("is_frozen")
			return (v != null and float(v) > 0.0) or (f != null and bool(f))
		"enemy_full_hp":
			var hp = enemy.get("health")
			var mhp = enemy.get("max_health")
			return hp != null and mhp != null and float(hp) >= float(mhp) * 0.99
		"enemy_low_hp":
			var hp = enemy.get("health")
			var mhp = enemy.get("max_health")
			return hp != null and mhp != null and float(hp) <= float(mhp) * 0.30
	return false


# === PROC / TRIGGER ITEMS ===

# Schuss-basierte Procs (every_n_shots, on_crit). shot_count = laufende Schusszahl des Turms.
func on_tower_shot(tower: Node2D, target_enemy: Node2D, is_crit: bool, shot_count: int) -> void:
	if not is_instance_valid(tower):
		return
	for item in get_tower_equipped_items(tower):
		if item.is_empty():
			continue
		var proc: Dictionary = item.get("proc", {})
		if proc.is_empty():
			continue
		var trigger: String = proc.get("trigger", "")
		if trigger == "every_n_shots" and shot_count % int(proc.get("n", 5)) == 0:
			_fire_proc(tower, target_enemy, proc)
		elif trigger == "on_crit" and is_crit:
			_fire_proc(tower, target_enemy, proc)


# Treffer-basierte Procs (chance_on_hit, on_hit/execute). Pro getroffenem Gegner aufrufen.
func on_tower_hit(tower: Node2D, enemy: Node2D) -> void:
	if not is_instance_valid(tower) or not is_instance_valid(enemy):
		return
	for item in get_tower_equipped_items(tower):
		if item.is_empty():
			continue
		var proc: Dictionary = item.get("proc", {})
		if proc.is_empty():
			continue
		var trigger: String = proc.get("trigger", "")
		if trigger == "chance_on_hit" and randf() < float(proc.get("chance", 0.0)):
			_fire_proc(tower, enemy, proc)
		elif trigger == "on_hit":
			_fire_proc(tower, enemy, proc)


func _fire_proc(tower: Node2D, enemy: Node2D, proc: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	var effect: String = proc.get("effect", "")
	var value: float = float(proc.get("value", 0))
	match effect:
		"freeze":
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(value)
		"burn":
			if enemy.has_method("apply_burn"):
				enemy.apply_burn(int(value), 3.0)
		"explosion":
			_proc_explosion(tower, enemy.position, value, float(proc.get("radius", 70.0)))
		"execute":
			_try_execute(enemy, value)


func _try_execute(enemy: Node2D, hp_fraction: float) -> void:
	var hp = enemy.get("health")
	var mhp = enemy.get("max_health")
	if hp == null or mhp == null:
		return
	if float(hp) > 0.0 and float(hp) <= float(mhp) * hp_fraction:
		if enemy.has_method("take_damage"):
			enemy.take_damage(int(mhp) * 10, false, "")
		if VFX:
			VFX.spawn_pixel_burst(enemy.position, "crit", 12)


func _proc_explosion(tower: Node2D, pos: Vector2, dmg: float, radius: float) -> void:
	if not is_instance_valid(tower) or not tower.is_inside_tree():
		return
	for e in tower.get_tree().get_nodes_in_group("enemies"):
		if pos.distance_to(e.position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(int(dmg), false, "")
	if VFX:
		VFX.spawn_pixel_ring(pos, "fire", radius)
		VFX.screen_shake(2.0, 0.08)


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

	# 3. Fallback: Kategorie-Icon in Raritaetsfarbe. Ohne diese Stufe blieben Slots
	#    fuer Items ohne gezeichnetes Icon komplett leer (siehe ASSETS_TODO.md).
	var category: String = item.get("category", "")
	if category.is_empty():
		var template: Dictionary = ITEMS.get(item.get("id", ""), {})
		category = template.get("category", "")
	var tex := _create_category_fallback_texture(category, rarity)
	_icon_cache[cache_key] = tex
	return tex


# Faerbt das Kategorie-Sammelicon in der Raritaetsfarbe ein, damit Platzhalter
# trotzdem Kategorie und Wertigkeit eines Items kommunizieren.
func _create_category_fallback_texture(category: String, rarity: String) -> Texture2D:
	var path: String = ITEM_ICON_PATH + CATEGORY_FALLBACK_ICONS.get(category, "special") + ".png"
	if not ResourceLoader.exists(path):
		return null

	var source: Texture2D = load(path)
	var image := source.get_image()
	if image == null:
		return source
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()

	var tint: Color = RARITIES.get(rarity, RARITIES["common"])["color"]
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			# Helligkeit des Originals erhalten, Farbton aus der Raritaet nehmen.
			var value := maxf(pixel.r, maxf(pixel.g, pixel.b))
			image.set_pixel(x, y, Color(
				tint.r * value, tint.g * value, tint.b * value, pixel.a
			))

	return ImageTexture.create_from_image(image)




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
