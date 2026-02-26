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

# Gegner-Typen Definition - SCHWERER
var enemy_types := {
	"normal": {
		"health_base": 80,   "health_per_wave": 18,
		"speed_base": 85.0,  "speed_per_wave": 6.0,
		"reward": 1, "scale": 0.5
	},
	"swift": {                          # früher "fast"
		"health_base": 45,   "health_per_wave": 10,
		"speed_base": 160.0, "speed_per_wave": 10.0,
		"reward": 2, "scale": 0.4
	},
	"tank": {
		"health_base": 280,  "health_per_wave": 55,
		"speed_base": 50.0,  "speed_per_wave": 2.0,
		"reward": 5, "scale": 0.7
	},
	"ethereal": {                       # NEU – schwach gegen Wizard
		"health_base": 120,  "health_per_wave": 22,
		"speed_base": 75.0,  "speed_per_wave": 5.0,
		"reward": 6, "scale": 0.5
	},
	"brute": {                          # NEU – schwach gegen Cannon
		"health_base": 350,  "health_per_wave": 65,
		"speed_base": 55.0,  "speed_per_wave": 2.5,
		"reward": 7, "scale": 0.8
	},
	"burrower": {                       # NEU – schwach gegen Trapper
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


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://enemy.tscn")
	print("[WaveManager] Initialisiert mit Elementar-System")


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
	
	print("[WaveManager] Wave %d: %d Gegner - Element: %s (Seed: %d)" % [
		wave_number, spawn_queue.size(), current_wave_element, _get_current_map_seed()
	])
	_spawn_next()


func _determine_wave_element(wave: int) -> String:
	"""Bestimmt das Element der Welle - mit Perk-Boni"""
	if wave <= 2:
		return "neutral"
	
	var current_seed := _get_current_map_seed()
	_rng.seed = current_seed + wave * 7919
	
	# Basis-Gewichte für alle Elemente
	var element_weights := {
		"fire": 1.0,
		"water": 1.0,
		"earth": 1.0,
		"air": 1.0
	}
	
	# NEU: Perk-Boni anwenden
	if UpgradeSystem:
		for element in element_weights.keys():
			var bonus := UpgradeSystem.get_element_spawn_rate_bonus(element)
			if bonus > 0:
				element_weights[element] += bonus
				print("[WaveManager] Element %s: +%.0f%% spawn chance" % [element, bonus * 100])
	
	# Wellen-basierte Modifikation (alle 4 Wellen rotiert)
	var wave_mod := (wave - 3) % 4  # Startet bei Welle 3
	match wave_mod:
		0: element_weights["fire"] *= 1.3
		1: element_weights["water"] *= 1.3
		2: element_weights["earth"] *= 1.3
		3: element_weights["air"] *= 1.3
	
	# Gewichtete Zufallsauswahl
	var total_weight := 0.0
	for weight in element_weights.values():
		total_weight += weight
	
	var rand := _rng.randf() * total_weight
	var accumulated := 0.0
	
	for element in element_weights:
		accumulated += element_weights[element]
		if rand <= accumulated:
			return element
	
	# Fallback (sollte nie erreicht werden)
	return ELEMENTS[_rng.randi_range(0, ELEMENTS.size() - 1)]


func generate_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	var total_enemies := 8 + wave * 3

	# --- Anteile berechnen ---
	# Swift ab Welle 3 (wie vorher "fast")
	var swift_count := 0
	if wave >= 3:
		swift_count = mini(wave - 1, total_enemies / 3)

	# Tank ab Welle 4 (unverändert)
	var tank_count := 0
	if wave >= 4:
		tank_count = mini((wave - 2) / 2, total_enemies / 4)

	# Ethereal ab Welle 5 (1 pro 2 Wellen, max 3)
	var ethereal_count := 0
	if wave >= 5:
		ethereal_count = mini((wave - 3) / 2, 3)

	# Brute ab Welle 6 (1 alle 3 Wellen, max 2)
	var brute_count := 0
	if wave >= 6:
		brute_count = mini((wave - 4) / 3, 2)

	# Burrower ab Welle 7 (1 alle 2 Wellen, max 3)
	var burrower_count := 0
	if wave >= 7:
		burrower_count = mini((wave - 5) / 2, 3)

	# Boss alle 5 Wellen
	var boss_count := 0
	if wave > 0 and wave % 5 == 0:
		boss_count = 1 + wave / 10

	# Normal füllt den Rest auf (mindestens 1)
	var special_total := swift_count + tank_count + ethereal_count + brute_count + burrower_count + boss_count
	var normal_count := maxi(1, total_enemies - special_total)

	# --- Composition aufbauen ---
	for i in range(normal_count):
		composition.append(_create_enemy_data("normal", wave))

	# Spezialtypen an zufälligen Positionen einfügen
	for i in range(swift_count):
		var pos := randi() % (composition.size() + 1)
		composition.insert(pos, _create_enemy_data("swift", wave))

	for i in range(ethereal_count):
		var pos := randi() % (composition.size() + 1)
		composition.insert(pos, _create_enemy_data("ethereal", wave))

	for i in range(burrower_count):
		var pos := randi() % (composition.size() + 1)
		composition.insert(pos, _create_enemy_data("burrower", wave))

	# Tanks und Brutes in der zweiten Hälfte (sie sind langsam/groß)
	for i in range(tank_count):
		var pos := (composition.size() / 2) + randi() % (composition.size() / 2 + 1)
		composition.insert(pos, _create_enemy_data("tank", wave))

	for i in range(brute_count):
		var pos := (composition.size() / 2) + randi() % (composition.size() / 2 + 1)
		composition.insert(pos, _create_enemy_data("brute", wave))

	# Boss immer am Ende
	for i in range(boss_count):
		composition.append(_create_enemy_data("boss", wave))

	return composition



func _create_enemy_data(type: String, wave: int) -> Dictionary:
	var base: Dictionary = enemy_types[type]
	var element := current_wave_element

	var elem_bonus := 1.0
	if element != "neutral":
		elem_bonus = 1.25

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
		"brute":    delay *= 1.5   # kurze Pause vor großen Gegnern
		"ethereal": delay *= 0.8   # leicht schneller (kommt in Gruppen besser)
		_:          pass           # normal, tank, burrower: unverändert
	
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


func cancel_wave() -> void:
	is_spawning = false
	spawn_queue.clear()
	current_spawn_index = 0


func set_spawn_speed(multiplier: float) -> void:
	spawn_interval = 0.6 / multiplier


func get_wave_preview(wave_number: int) -> Dictionary:
	var preview_element: String
	if _cached_next_wave_number == wave_number:
		preview_element = _cached_next_wave_element
	else:
		preview_element = _determine_wave_element(wave_number)
		_cached_next_wave_number = wave_number
		_cached_next_wave_element = preview_element

	var total: int = 8 + wave_number * 3

	var swift := 0
	if wave_number >= 3:
		swift = mini(wave_number - 1, total / 3)
	var tank := 0
	if wave_number >= 4:
		tank = mini((wave_number - 2) / 2, total / 4)
	var ethereal := 0
	if wave_number >= 5:
		ethereal = mini((wave_number - 3) / 2, 3)
	var brute := 0
	if wave_number >= 6:
		brute = mini((wave_number - 4) / 3, 2)
	var burrower := 0
	if wave_number >= 7:
		burrower = mini((wave_number - 5) / 2, 3)
	var boss := 0
	if wave_number > 0 and wave_number % 5 == 0:
		boss = 1 + wave_number / 10

	var special_total := swift + tank + ethereal + brute + burrower + boss
	var normal := maxi(1, total - special_total)

	return {
		"total":        total,
		"normal":       normal,
		"swift":        swift,       # früher "fast"
		"tank":         tank,
		"ethereal":     ethereal,
		"brute":        brute,
		"burrower":     burrower,
		"boss":         boss,
		"wave_element": preview_element
	}



func get_wave_info(wave_number: int) -> String:
	var preview := get_wave_preview(wave_number)
	var parts: Array[String] = []

	if preview["normal"]   > 0: parts.append("%dx Norm"   % preview["normal"])
	if preview["swift"]    > 0: parts.append("%dx Flink"  % preview["swift"])
	if preview["tank"]     > 0: parts.append("%dx Tank"   % preview["tank"])
	if preview["ethereal"] > 0: parts.append("%dx Äther"  % preview["ethereal"])
	if preview["brute"]    > 0: parts.append("%dx Brute"  % preview["brute"])
	if preview["burrower"] > 0: parts.append("%dx Grab"   % preview["burrower"])
	if preview["boss"]     > 0: parts.append("%dx Boss"   % preview["boss"])

	return " | ".join(parts)



func get_path_points_in_range(tower_pos: Vector2, range_radius: float) -> Array[Vector2]:
	"""Gibt Pfad-Punkte zurück die in Reichweite des Turms sind"""
	if path_points.is_empty():
		return []
	
	var points_in_range: Array[Vector2] = []
	
	# Iteriere durch alle Pfad-Punkte
	for point in path_points:
		var dist := tower_pos.distance_to(point)
		if dist <= range_radius:
			points_in_range.append(point)
	
	# Wenn wir nicht genug Punkte haben, sample zwischen den Punkten
	if points_in_range.size() < 3 and path_points.size() > 1:
		# Sample zusätzliche Punkte zwischen den Pfad-Punkten
		for i in range(path_points.size() - 1):
			var start := path_points[i]
			var end := path_points[i + 1]
			var segment_length := start.distance_to(end)
			var num_samples := int(segment_length / 30.0)  # Alle 30 Pixel
			
			for j in range(1, num_samples):
				var t := float(j) / float(num_samples)
				var sample_point := start.lerp(end, t)
				var dist := tower_pos.distance_to(sample_point)
				if dist <= range_radius:
					points_in_range.append(sample_point)
	
	return points_in_range


func get_wave_element_info(wave_number: int) -> String:
	var preview := get_wave_preview(wave_number)
	var wave_elem: String = preview["wave_element"]
	
	if wave_elem == "neutral":
		return "◯ Neutral"
	else:
		var symbol := ""
		var name := ""
		if ElementalSystem:
			symbol = ElementalSystem.get_element_symbol(wave_elem)
			var effective := ElementalSystem.get_effective_element(wave_elem)
			var eff_symbol := ElementalSystem.get_element_symbol(effective) if effective != "neutral" else ""
			name = wave_elem.capitalize()
			if eff_symbol != "":
				return "%s %s (schwach gegen %s)" % [symbol, name, eff_symbol]
		else:
			symbol = wave_elem.substr(0, 1).to_upper()
			name = wave_elem.capitalize()
		return "%s %s" % [symbol, name]
