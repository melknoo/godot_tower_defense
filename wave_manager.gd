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

# Gegner-Typen Definition
var enemy_types := {
	"normal": {
		"health_base": 50,
		"health_per_wave": 10,
		"speed_base": 80.0,
		"speed_per_wave": 5.0,
		"reward": 2,
		"color": Color(0.8, 0.2, 0.2),
		"scale": 0.5
	},
	"fast": {
		"health_base": 30,
		"health_per_wave": 5,
		"speed_base": 140.0,
		"speed_per_wave": 8.0,
		"reward": 5,
		"color": Color(0.2, 0.8, 0.2),
		"scale": 0.4
	},
	"tank": {
		"health_base": 150,
		"health_per_wave": 30,
		"speed_base": 50.0,
		"speed_per_wave": 2.0,
		"reward": 10,
		"color": Color(0.4, 0.4, 0.8),
		"scale": 0.7
	},
	"boss": {
		"health_base": 700,
		"health_per_wave": 100,
		"speed_base": 40.0,
		"speed_per_wave": 1.0,
		"reward": 100,
		"color": Color(0.8, 0.2, 0.8),
		"scale": 1.0
	}
}


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://enemy.tscn")
	print("[WaveManager] Initialisiert mit %d Gegner-Typen" % enemy_types.size())


# Wave starten - generiert Spawn-Queue basierend auf Wave-Nummer
func start_wave(wave_number: int) -> void:
	if is_spawning:
		return
	
	spawn_queue = generate_wave_composition(wave_number)
	GameState.enemies_remaining = spawn_queue.size()
	current_spawn_index = 0
	is_spawning = true
	
	print("[WaveManager] Wave %d: %d Gegner" % [wave_number, spawn_queue.size()])
	_spawn_next()


# Wave-Zusammensetzung generieren
func generate_wave_composition(wave: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	
	# Basis-Anzahl Gegner
	var total_enemies := 5 + wave * 2
	
	# Ab Wave 3: Fast Enemies
	var fast_count := 0
	if wave >= 3:
		fast_count = mini(wave - 2, total_enemies / 3)
	
	# Ab Wave 5: Tank Enemies
	var tank_count := 0
	if wave >= 5:
		tank_count = mini((wave - 4) / 2, total_enemies / 4)
	
	# Alle 5 Wellen: Boss
	var boss_count := 0
	if wave > 0 and wave % 5 == 0:
		boss_count = wave / 5
	
	# Rest sind normale Gegner
	var normal_count := total_enemies - fast_count - tank_count - boss_count
	normal_count = maxi(normal_count, 1)
	
	# Queue aufbauen mit Mischung
	for i in range(normal_count):
		composition.append(_create_enemy_data("normal", wave))
	
	for i in range(fast_count):
		# Fast Enemies in Gruppen einfügen
		var pos := randi() % (composition.size() + 1)
		composition.insert(pos, _create_enemy_data("fast", wave))
	
	for i in range(tank_count):
		# Tanks eher in der Mitte/Ende
		var pos := (composition.size() / 2) + randi() % (composition.size() / 2 + 1)
		composition.insert(pos, _create_enemy_data("tank", wave))
	
	for i in range(boss_count):
		# Boss am Ende
		composition.append(_create_enemy_data("boss", wave))
	
	return composition


# Enemy-Daten für Spawn erstellen
func _create_enemy_data(type: String, wave: int) -> Dictionary:
	var base: Dictionary = enemy_types[type]
	
	return {
		"type": type,
		"health": base["health_base"] + base["health_per_wave"] * wave,
		"speed": base["speed_base"] + base["speed_per_wave"] * wave,
		"reward": base["reward"],
		"color": base["color"],
		"scale": base["scale"]
	}


# Nächsten Gegner spawnen
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
	
	# Nächsten Spawn planen
	var delay := spawn_interval
	
	# Kürzerer Abstand für Fast Enemies
	if enemy_data["type"] == "fast":
		delay *= 0.5
	# Längerer Abstand vor Boss
	elif enemy_data["type"] == "boss":
		delay *= 2.0
	
	await get_tree().create_timer(delay).timeout
	
	if is_inside_tree():
		_spawn_next()


# Einzelnen Gegner spawnen
func _spawn_enemy(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	
	var enemy := enemy_scene.instantiate()
	
	# Setup mit erweiterten Daten
	if enemy.has_method("setup_extended"):
		enemy.setup_extended(path_points, data)
	else:
		# Fallback für altes Enemy-Script
		enemy.setup(path_points, data["health"], data["speed"])
	
	enemy_spawned.emit(enemy)
	get_parent().add_child(enemy)


# Wave abbrechen (z.B. bei Game Over)
func cancel_wave() -> void:
	is_spawning = false
	spawn_queue.clear()
	current_spawn_index = 0


# Spawn-Geschwindigkeit anpassen (für Fast-Forward Feature)
func set_spawn_speed(multiplier: float) -> void:
	spawn_interval = 0.8 / multiplier


# Vorschau der nächsten Wave
func get_wave_preview(wave_number: int) -> Dictionary:
	var composition := generate_wave_composition(wave_number)
	
	var preview := {
		"total": composition.size(),
		"normal": 0,
		"fast": 0,
		"tank": 0,
		"boss": 0
	}
	
	for enemy_data in composition:
		preview[enemy_data["type"]] += 1
	
	return preview


# Info-String für UI
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
