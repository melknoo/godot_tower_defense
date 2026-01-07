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
		"health_base": 80, "health_per_wave": 18,
		"speed_base": 85.0, "speed_per_wave": 6.0,
		"reward": 1, "color": Color(0.8, 0.2, 0.2), "scale": 0.5
	},
	"fast": {
		"health_base": 45, "health_per_wave": 10,
		"speed_base": 160.0, "speed_per_wave": 10.0,
		"reward": 2, "color": Color(0.2, 0.8, 0.2), "scale": 0.4
	},
	"tank": {
		"health_base": 250, "health_per_wave": 50,
		"speed_base": 50.0, "speed_per_wave": 2.0,
		"reward": 5, "color": Color(0.4, 0.4, 0.8), "scale": 0.7
	},
	"boss": {
		"health_base": 1200, "health_per_wave": 180,
		"speed_base": 45.0, "speed_per_wave": 1.5,
		"reward": 50, "color": Color(0.8, 0.2, 0.8), "scale": 1.0
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
	if wave <= 2:
		return "neutral"
	var current_seed := _get_current_map_seed()
	_rng.seed = current_seed + wave * 7919
	return ELEMENTS[_rng.randi_range(0, ELEMENTS.size() - 1)]


func generate_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	
	# Mehr Gegner pro Welle
	var total_enemies := 8 + wave * 3
	
	var fast_count := 0
	if wave >= 3:
		fast_count = mini(wave - 1, total_enemies / 3)
	
	var tank_count := 0
	if wave >= 4:
		tank_count = mini((wave - 2) / 2, total_enemies / 4)
	
	var boss_count := 0
	if wave > 0 and wave % 5 == 0:
		boss_count = 1 + wave / 10
	
	var normal_count := maxi(1, total_enemies - fast_count - tank_count - boss_count)
	
	for i in range(normal_count):
		composition.append(_create_enemy_data("normal", wave))
	
	for i in range(fast_count):
		var pos := randi() % (composition.size() + 1)
		composition.insert(pos, _create_enemy_data("fast", wave))
	
	for i in range(tank_count):
		var pos := (composition.size() / 2) + randi() % (composition.size() / 2 + 1)
		composition.insert(pos, _create_enemy_data("tank", wave))
	
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
		"type": type,
		"health": int((base["health_base"] + base["health_per_wave"] * wave) * elem_bonus),
		"speed": base["speed_base"] + base["speed_per_wave"] * wave,
		"reward": base["reward"] + (1 if element != "neutral" else 0),
		"color": base["color"],
		"scale": base["scale"],
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
	if enemy_data["type"] == "fast":
		delay *= 0.5
	elif enemy_data["type"] == "boss":
		delay *= 2.0
	
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
	
	var preview := {
		"total": total,
		"normal": 0, "fast": 0, "tank": 0, "boss": 0,
		"wave_element": preview_element
	}
	
	var fast := 0
	if wave_number >= 3:
		fast = mini(wave_number - 1, total / 3)
	var tank := 0
	if wave_number >= 4:
		tank = mini((wave_number - 2) / 2, total / 4)
	var boss := 0
	if wave_number > 0 and wave_number % 5 == 0:
		boss = 1 + wave_number / 10
	
	preview["normal"] = maxi(1, total - fast - tank - boss)
	preview["fast"] = fast
	preview["tank"] = tank
	preview["boss"] = boss
	
	return preview


func get_wave_info(wave_number: int) -> String:
	var preview := get_wave_preview(wave_number)
	var parts: Array[String] = []
	
	if preview["normal"] > 0:
		parts.append("%d Normal" % preview["normal"])
	if preview["fast"] > 0:
		parts.append("%d Schnelle" % preview["fast"])
	if preview["tank"] > 0:
		parts.append("%d Tanks" % preview["tank"])
	if preview["boss"] > 0:
		parts.append("%d Boss" % preview["boss"])
	
	return ", ".join(parts)


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
