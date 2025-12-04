extends Node

# Signals für UI-Updates und andere Reaktionen
signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_over_triggered
signal enemy_count_changed(count: int)

# Spielressourcen mit Settern für automatische Signal-Emission
var gold := 100:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)

var lives := 20:
	set(value):
		var old_lives = lives
		lives = max(0, value)
		lives_changed.emit(lives)
		if lives <= 0 and old_lives > 0:
			game_over_triggered.emit()

# Wave-Status
var current_wave := 0
var wave_active := false
var enemies_remaining := 0:
	set(value):
		enemies_remaining = max(0, value)
		enemy_count_changed.emit(enemies_remaining)

# Statistiken (für Endscreen oder Achievements)
var stats := {
	"towers_placed": 0,
	"towers_sold": 0,
	"enemies_killed": 0,
	"gold_earned": 0,
	"damage_dealt": 0
}

# Startwerte für Reset
const DEFAULT_GOLD := 100
const DEFAULT_LIVES := 20


func _ready() -> void:
	print("[GameState] Initialisiert")


# Wave-Management
func start_wave() -> void:
	if wave_active:
		return
	current_wave += 1
	wave_active = true
	enemies_remaining = calculate_enemies_for_wave(current_wave)
	wave_started.emit(current_wave)
	print("[GameState] Wave %d gestartet - %d Gegner" % [current_wave, enemies_remaining])


func calculate_enemies_for_wave(wave: int) -> int:
	return 5 + wave * 2


func enemy_died(reward: int) -> void:
	gold += reward
	enemies_remaining -= 1
	stats["enemies_killed"] += 1
	stats["gold_earned"] += reward
	_check_wave_end()


func enemy_reached_end() -> void:
	lives -= 1
	enemies_remaining -= 1
	_check_wave_end()


func _check_wave_end() -> void:
	if enemies_remaining <= 0 and wave_active:
		wave_active = false
		var bonus := 25 + current_wave * 5
		gold += bonus
		stats["gold_earned"] += bonus
		wave_completed.emit(current_wave)
		print("[GameState] Wave %d abgeschlossen - Bonus: %d Gold" % [current_wave, bonus])


# Tower-Aktionen tracken
func tower_placed(cost: int) -> void:
	gold -= cost
	stats["towers_placed"] += 1


func tower_sold(sell_value: int) -> void:
	gold += sell_value
	stats["towers_sold"] += 1


func record_damage(amount: int) -> void:
	stats["damage_dealt"] += amount


# Hilfsfunktionen
func can_afford(cost: int) -> bool:
	return gold >= cost


func is_game_over() -> bool:
	return lives <= 0


# Spiel zurücksetzen (für Neustart)
func reset() -> void:
	gold = DEFAULT_GOLD
	lives = DEFAULT_LIVES
	current_wave = 0
	wave_active = false
	enemies_remaining = 0
	stats = {
		"towers_placed": 0,
		"towers_sold": 0,
		"enemies_killed": 0,
		"gold_earned": 0,
		"damage_dealt": 0
	}
	print("[GameState] Zurückgesetzt")


# Speichern/Laden (für später)
func get_save_data() -> Dictionary:
	return {
		"gold": gold,
		"lives": lives,
		"current_wave": current_wave,
		"stats": stats
	}


func load_save_data(data: Dictionary) -> void:
	gold = data.get("gold", DEFAULT_GOLD)
	lives = data.get("lives", DEFAULT_LIVES)
	current_wave = data.get("current_wave", 0)
	stats = data.get("stats", stats)
