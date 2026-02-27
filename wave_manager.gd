# wave_manager.gd
# Generiert Wellen mit elementaren Gegnern
extends Node
class_name WaveManager

signal wave_spawning_finished
signal enemy_spawned(enemy: Node2D)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.6
@export var path_points: Array[Vector2] = []

var is_spawning := false
var spawn_queue: Array[Dictionary] = []
var current_spawn_index := 0
var _rng := RandomNumberGenerator.new()

var current_wave_element := "neutral"

var _cached_next_wave_number: int = -1
var _cached_next_wave_element: String = ""

# Gegner-Typen Definition
var enemy_types := {
	"normal": {
		"health_base": 80,   "health_per_wave": 18,
		"speed_base": 85.0,  "speed_per_wave": 6.0,
		"reward": 1, "scale": 0.5
	},
	"swift": {
		"health_base": 45,   "health_per_wave": 10,
		"speed_base": 160.0, "speed_per_wave": 10.0,
		"reward": 2, "scale": 0.4
	},
	"tank": {
		"health_base": 280,  "health_per_wave": 55,
		"speed_base": 50.0,  "speed_per_wave": 2.0,
		"reward": 5, "scale": 0.7
	},
	"ethereal": {
		"health_base": 120,  "health_per_wave": 22,
		"speed_base": 75.0,  "speed_per_wave": 5.0,
		"reward": 6, "scale": 0.5
	},
	"brute": {
		"health_base": 350,  "health_per_wave": 65,
		"speed_base": 55.0,  "speed_per_wave": 2.5,
		"reward": 7, "scale": 0.8
	},
	"burrower": {
		"health_base": 100,  "health_per_wave": 20,
		"speed_base": 90.0,  "speed_per_wave": 7.0,
		"reward": 4, "scale": 0.45
	},
	"boss": {
		"health_base": 1200, "health_per_wave": 180,
		"speed_base": 45.0,  "speed_per_wave": 1.5,
		"reward": 50, "scale": 1.0
	}
}

const ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]

# Welche Typen in welcher Phase erlaubt sind
const LIGHT_TYPES:  Array[String] = ["normal", "swift", "burrower"]
const ALL_TYPES:    Array[String] = ["normal", "swift", "tank", "ethereal", "brute", "burrower"]

# Ab dieser Welle werden gemischte Wellen gespielt (nach dem ersten Boss = Welle 5)
const MIXED_WAVE_START := 6


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://enemy.tscn")
	print("[WaveManager] Initialisiert mit randomisiertem Wellensystem")


func _get_current_map_seed() -> int:
	var main := get_node_or_null("/root/Main")
	if main and main.has_method("get_current_seed"):
		return int(main.get_current_seed())
	return 0


func start_wave(wave_number: int) -> void:
	if is_spawning:
		return

	if _cached_next_wave_number == wave_number and _cached_next_wave_element != "":
		current_wave_element = _cached_next_wave_element
	else:
		current_wave_element = _determine_wave_element(wave_number)

	if _cached_next_wave_number == wave_number:
		_cached_next_wave_number = -1
		_cached_next_wave_element = ""

	spawn_queue = generate_wave_composition(wave_number)
	GameState.enemies_remaining = spawn_queue.size()
	current_spawn_index = 0
	is_spawning = true

	print("[WaveManager] Wave %d: %d Gegner – Element: %s (Seed: %d)" % [
		wave_number, spawn_queue.size(), current_wave_element, _get_current_map_seed()
	])
	_spawn_next()


func _determine_wave_element(wave: int) -> String:
	if wave <= 2:
		return "neutral"

	var current_seed := _get_current_map_seed()
	_rng.seed = current_seed + wave * 7919

	var element_weights := { "fire": 1.0, "water": 1.0, "earth": 1.0, "air": 1.0 }

	if UpgradeSystem:
		for element in element_weights.keys():
			var bonus := UpgradeSystem.get_element_spawn_rate_bonus(element)
			if bonus > 0:
				element_weights[element] += bonus

	var wave_mod := (wave - 3) % 4
	match wave_mod:
		0: element_weights["fire"]  *= 1.3
		1: element_weights["water"] *= 1.3
		2: element_weights["earth"] *= 1.3
		3: element_weights["air"]   *= 1.3

	var total_weight := 0.0
	for w in element_weights.values():
		total_weight += w

	var rand := _rng.randf() * total_weight
	var accumulated := 0.0
	for element in element_weights:
		accumulated += element_weights[element]
		if rand <= accumulated:
			return element

	return ELEMENTS[_rng.randi_range(0, ELEMENTS.size() - 1)]


# ---------------------------------------------------------------------------
#  Kern: Wellen-Komposition
# ---------------------------------------------------------------------------
func generate_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []

	# Seed pro Welle – reproduzierbar für Preview
	var current_seed := _get_current_map_seed()
	_rng.seed = current_seed + wave * 1337

	var total := 8 + wave * 3

	# Boss alle 5 Wellen – immer ans Ende, nicht in den Pool
	var boss_count := 0
	if wave > 0 and wave % 5 == 0:
		boss_count = 1 + wave / 10
		total -= boss_count

	if wave < MIXED_WAVE_START:
		# ---- Einzeltyp-Wellen (Welle 1–5) --------------------------------
		var pool: Array[String] = LIGHT_TYPES if wave == 1 else ALL_TYPES
		var chosen_type := pool[_rng.randi_range(0, pool.size() - 1)]

		for i in range(total):
			composition.append(_create_enemy_data(chosen_type, wave))

		print("[WaveManager] Einzeltyp-Welle: %s" % chosen_type)
	else:
		# ---- Gemischte Wellen (ab Welle 6) --------------------------------
		# Dominant (~70 %)
		var dom_idx   := _rng.randi_range(0, ALL_TYPES.size() - 1)
		var dominant  := ALL_TYPES[dom_idx]
		var dom_count := int(total * 0.70)
		var sub_total := total - dom_count

		# Subtypen-Pool (ohne Dominant)
		var sub_pool: Array[String] = []
		for t in ALL_TYPES:
			if t != dominant:
				sub_pool.append(t)

		# 1–2 zufällige Subtypen wählen
		var num_subs := _rng.randi_range(1, 2)
		var sub_types: Array[String] = []
		for i in range(num_subs):
			var pick := _rng.randi_range(0, sub_pool.size() - 1)
			sub_types.append(sub_pool[pick])
			sub_pool.remove_at(pick)

		# Gegner aufbauen
		for i in range(dom_count):
			composition.append(_create_enemy_data(dominant, wave))

		var per_sub := sub_total / num_subs
		for sub_t in sub_types:
			for i in range(per_sub):
				composition.append(_create_enemy_data(sub_t, wave))

		# Rest (Rundungsdiff) mit Dominant auffüllen
		while composition.size() < total:
			composition.append(_create_enemy_data(dominant, wave))

		# Mischen – ergibt natürlicheren Spawn-Strom
		composition.shuffle()

		print("[WaveManager] Mix-Welle: %s (dominant) + %s" % [dominant, str(sub_types)])

	# Boss ans Ende
	for i in range(boss_count):
		composition.append(_create_enemy_data("boss", wave))

	return composition


# ---------------------------------------------------------------------------
#  Hilfsfunktionen
# ---------------------------------------------------------------------------
func _create_enemy_data(type: String, wave: int) -> Dictionary:
	var base: Dictionary = enemy_types[type]
	var element := current_wave_element
	var elem_bonus := 1.25 if element != "neutral" else 1.0

	return {
		"type":    type,
		"health":  int((base["health_base"] + base["health_per_wave"] * wave) * elem_bonus),
		"speed":   base["speed_base"] + base["speed_per_wave"] * wave,
		"reward":  base["reward"] + (1 if element != "neutral" else 0),
		"scale":   base["scale"],
		"element": element
	}


func _spawn_next() -> void:
	if not is_spawning:
		return

	if current_spawn_index >= spawn_queue.size():
		is_spawning = false
		wave_spawning_finished.emit()
		print("[WaveManager] Alle Gegner gespawnt")
		return

	var enemy_data: Dictionary = spawn_queue[current_spawn_index]
	_spawn_enemy(enemy_data)
	current_spawn_index += 1

	var delay := spawn_interval
	match enemy_data["type"]:
		"swift":    delay *= 0.5
		"boss":     delay *= 2.0
		"brute":    delay *= 1.5
		"ethereal": delay *= 0.8

	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		_spawn_next()


func _spawn_enemy(data: Dictionary) -> void:
	if not is_inside_tree():
		return

	var enemy := enemy_scene.instantiate()
	get_parent().add_child(enemy)

	if enemy.has_method("setup_extended"):
		enemy.setup_extended(path_points, data)
	else:
		enemy.setup(path_points, data["health"], data["speed"])

	enemy_spawned.emit(enemy)


# ---------------------------------------------------------------------------
#  Preview / Info
# ---------------------------------------------------------------------------
func get_wave_preview(wave_number: int) -> Dictionary:
	# Element cachen
	var preview_element: String
	if _cached_next_wave_number == wave_number:
		preview_element = _cached_next_wave_element
	else:
		preview_element = _determine_wave_element(wave_number)
		_cached_next_wave_number = wave_number
		_cached_next_wave_element = preview_element

	# Komposition simulieren (gleicher Seed → deterministisch)
	var old_element := current_wave_element
	current_wave_element = preview_element
	var comp := generate_wave_composition(wave_number)
	current_wave_element = old_element

	# Zählen
	var counts: Dictionary = {
		"total": comp.size(), "wave_element": preview_element,
		"normal": 0, "swift": 0, "tank": 0,
		"ethereal": 0, "brute": 0, "burrower": 0, "boss": 0
	}
	for d in comp:
		var t: String = d["type"]
		if counts.has(t):
			counts[t] += 1

	return counts


func get_wave_info(wave_number: int) -> String:
	var p := get_wave_preview(wave_number)
	var parts: Array[String] = []

	if p["normal"]   > 0: parts.append("%dx Norm"  % p["normal"])
	if p["swift"]    > 0: parts.append("%dx Flink" % p["swift"])
	if p["tank"]     > 0: parts.append("%dx Tank"  % p["tank"])
	if p["ethereal"] > 0: parts.append("%dx Äther" % p["ethereal"])
	if p["brute"]    > 0: parts.append("%dx Brute" % p["brute"])
	if p["burrower"] > 0: parts.append("%dx Grab"  % p["burrower"])
	if p["boss"]     > 0: parts.append("%dx Boss"  % p["boss"])

	return " | ".join(parts)


func get_wave_element_info(wave_number: int) -> String:
	var preview := get_wave_preview(wave_number)
	var wave_elem: String = preview["wave_element"]

	if wave_elem == "neutral":
		return "◯ Neutral"

	if ElementalSystem:
		var symbol   := ElementalSystem.get_element_symbol(wave_elem)
		var effective := ElementalSystem.get_effective_element(wave_elem)
		var eff_sym  := ElementalSystem.get_element_symbol(effective) if effective != "neutral" else ""
		if eff_sym != "":
			return "%s %s (schwach gegen %s)" % [symbol, wave_elem.capitalize(), eff_sym]
		return "%s %s" % [symbol, wave_elem.capitalize()]

	return "%s %s" % [wave_elem.substr(0, 1).to_upper(), wave_elem.capitalize()]


# ---------------------------------------------------------------------------
#  Utility
# ---------------------------------------------------------------------------
func cancel_wave() -> void:
	is_spawning = false
	spawn_queue.clear()
	current_spawn_index = 0


func set_spawn_speed(multiplier: float) -> void:
	spawn_interval = 0.6 / multiplier


func get_path_points_in_range(tower_pos: Vector2, range_radius: float) -> Array[Vector2]:
	if path_points.is_empty():
		return []

	var points_in_range: Array[Vector2] = []
	for point in path_points:
		if tower_pos.distance_to(point) <= range_radius:
			points_in_range.append(point)

	if points_in_range.size() < 3 and path_points.size() > 1:
		for i in range(path_points.size() - 1):
			var start := path_points[i]
			var end   := path_points[i + 1]
			var num_samples := int(start.distance_to(end) / 30.0)
			for j in range(1, num_samples):
				var sample := start.lerp(end, float(j) / float(num_samples))
				if tower_pos.distance_to(sample) <= range_radius:
					points_in_range.append(sample)

	return points_in_range
