# wave_manager.gd
# Generiert Wellen mit elementaren Gegnern
extends Node
class_name WaveManager

signal wave_spawning_finished
signal enemy_spawned(enemy: Node2D)

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 0.8
@export var path_points: Array[Vector2] = []

var is_spawning := false
var spawn_queue: Array[Dictionary] = []
var current_spawn_index := 0

# Wave-Element tracking
var current_wave_element := "neutral"

# Gegner-Typen Definition
var enemy_types := {
	"normal": {
		"health_base": 50, "health_per_wave": 10,
		"speed_base": 80.0, "speed_per_wave": 5.0,
		"reward": 2, "color": Color(0.8, 0.2, 0.2), "scale": 0.5
	},
	"fast": {
		"health_base": 30, "health_per_wave": 5,
		"speed_base": 140.0, "speed_per_wave": 8.0,
		"reward": 5, "color": Color(0.2, 0.8, 0.2), "scale": 0.4
	},
	"tank": {
		"health_base": 150, "health_per_wave": 30,
		"speed_base": 50.0, "speed_per_wave": 2.0,
		"reward": 10, "color": Color(0.4, 0.4, 0.8), "scale": 0.7
	},
	"boss": {
		"health_base": 700, "health_per_wave": 100,
		"speed_base": 40.0, "speed_per_wave": 1.0,
		"reward": 100, "color": Color(0.8, 0.2, 0.8), "scale": 1.0
	}
}

const ELEMENTS: Array[String] = ["water", "fire", "earth", "air"]


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://enemy.tscn")
	print("[WaveManager] Initialisiert mit Elementar-System")


func start_wave(wave_number: int) -> void:
	if is_spawning:
		return
	
	spawn_queue = generate_wave_composition(wave_number)
	GameState.enemies_remaining = spawn_queue.size()
	current_spawn_index = 0
	is_spawning = true
	
	print("[WaveManager] Wave %d: %d Gegner - Element: %s" % [wave_number, spawn_queue.size(), current_wave_element])
	_spawn_next()


# Bestimmt das Element für eine Welle
func _determine_wave_element(wave: int) -> String:
	# Wave 1-2: Nur neutrale Gegner (Tutorial)
	if wave <= 2:
		return "neutral"
	
	# Wave 3-5: Ein zufälliges Element für die ganze Welle
	if wave <= 5:
		return ELEMENTS[randi() % ELEMENTS.size()]
	
	# Wave 6-10: Hauptsächlich ein Element
	if wave <= 10:
		return ELEMENTS[randi() % ELEMENTS.size()]
	
	# Wave 11+: Gemischt (return "mixed" als Signal)
	return "mixed"


func generate_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	
	# Wave-Element bestimmen
	current_wave_element = _determine_wave_element(wave)
	
	var total_enemies := 5 + wave * 2
	
	# Gegner-Typen verteilen
	var fast_count := 0
	if wave >= 3:
		fast_count = mini(wave - 2, total_enemies / 3)
	
	var tank_count := 0
	if wave >= 5:
		tank_count = mini((wave - 4) / 2, total_enemies / 4)
	
	var boss_count := 0
	if wave > 0 and wave % 5 == 0:
		boss_count = wave / 5
	
	var normal_count := maxi(1, total_enemies - fast_count - tank_count - boss_count)
	
	# Queue aufbauen
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
	
	# Element basierend auf Wave-Phase bestimmen
	var element := _get_enemy_element(wave)
	
	# Elementare Gegner sind etwas stärker
	var elem_bonus := 1.0
	if element != "neutral":
		elem_bonus = 1.15
	
	return {
		"type": type,
		"health": int((base["health_base"] + base["health_per_wave"] * wave) * elem_bonus),
		"speed": base["speed_base"] + base["speed_per_wave"] * wave,
		"reward": base["reward"] + (2 if element != "neutral" else 0),
		"color": base["color"],
		"scale": base["scale"],
		"element": element
	}


func _get_enemy_element(wave: int) -> String:
	# Wenn ein festes Element für die Welle gesetzt ist
	if current_wave_element != "mixed":
		return current_wave_element
	
	# Gemischte Wellen (Wave 11+)
	# 20% Chance auf neutral, sonst zufälliges Element
	if randf() < 0.2:
		return "neutral"
	return ELEMENTS[randi() % ELEMENTS.size()]


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
	
	if enemy.has_method("setup_extended"):
		enemy.setup_extended(path_points, data)
	else:
		enemy.setup(path_points, data["health"], data["speed"])
	
	enemy_spawned.emit(enemy)
	get_parent().add_child(enemy)


func cancel_wave() -> void:
	is_spawning = false
	spawn_queue.clear()
	current_spawn_index = 0


func set_spawn_speed(multiplier: float) -> void:
	spawn_interval = 0.8 / multiplier


func get_wave_preview(wave_number: int) -> Dictionary:
	# Element für Preview bestimmen (ohne current_wave_element zu ändern)
	var preview_element := _determine_wave_element(wave_number)
	
	var total: int = 5 + wave_number * 2
	
	var preview := {
		"total": total,
		"normal": 0, "fast": 0, "tank": 0, "boss": 0,
		"wave_element": preview_element
	}
	
	# Grobe Schätzung der Gegner-Typen
	var fast := 0
	if wave_number >= 3:
		fast = mini(wave_number - 2, total / 3)
	var tank := 0
	if wave_number >= 5:
		tank = mini((wave_number - 4) / 2, total / 4)
	var boss := 0
	if wave_number > 0 and wave_number % 5 == 0:
		boss = wave_number / 5
	
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


# NEU: Gibt Element-Info für die Wave-Preview zurück
func get_wave_element_info(wave_number: int) -> String:
	var preview := get_wave_preview(wave_number)
	var wave_elem: String = preview["wave_element"]
	
	if wave_elem == "neutral":
		return "○ Neutral"
	elif wave_elem == "mixed":
		return "🌀 Gemischt"
	else:
		var symbol: String = ""
		var name: String = ""
		if ElementalSystem:
			symbol = ElementalSystem.get_element_symbol(wave_elem)
			# Effektives Element anzeigen
			var effective: String = ElementalSystem.get_effective_element(wave_elem)
			var eff_symbol: String = ElementalSystem.get_element_symbol(effective) if effective != "neutral" else ""
			name = wave_elem.capitalize()
			if eff_symbol != "":
				return "%s %s (schwach gegen %s)" % [symbol, name, eff_symbol]
		else:
			symbol = wave_elem.substr(0, 1).to_upper()
			name = wave_elem.capitalize()
		return "%s %s" % [symbol, name]
