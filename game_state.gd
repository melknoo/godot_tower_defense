# game_state.gd
extends Node

signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_over_triggered
signal enemy_count_changed(count: int)
signal element_cores_changed(new_amount: int)
signal element_core_earned  # Für UI-Popup

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

var element_cores := 0:
	set(value):
		element_cores = max(0, value)
		element_cores_changed.emit(element_cores)

var current_wave := 0
var wave_active := false
var enemies_remaining := 0:
	set(value):
		enemies_remaining = max(0, value)
		enemy_count_changed.emit(enemies_remaining)

var stats := {
	"towers_placed": 0,
	"towers_sold": 0,
	"enemies_killed": 0,
	"gold_earned": 0,
	"damage_dealt": 0,
	"elements_unlocked": 0
}

const DEFAULT_GOLD := 100
const DEFAULT_LIVES := 20

# Wellen nach denen man Element-Kerne bekommt
# Wave 1 = erster Kern, dann nach jedem Boss (5, 10, 15...)
func _get_core_reward_waves() -> Array[int]:
	var waves: Array[int] = [1]
	# Boss-Wellen: 5, 10, 15, 20...
	for i in range(5, 101, 5):
		waves.append(i)
	return waves


func _ready() -> void:
	print("[GameState] Initialisiert")


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
		
		# Element-Kern prüfen
		if current_wave in _get_core_reward_waves():
			element_cores += 1
			element_core_earned.emit()
			print("[GameState] Element-Kern erhalten! Gesamt: %d" % element_cores)
		
		wave_completed.emit(current_wave)
		print("[GameState] Wave %d abgeschlossen - Bonus: %d Gold" % [current_wave, bonus])


func spend_element_core() -> bool:
	if element_cores > 0:
		element_cores -= 1
		stats["elements_unlocked"] += 1
		return true
	return false


func has_element_cores() -> bool:
	return element_cores > 0


func tower_placed(cost: int) -> void:
	gold -= cost
	stats["towers_placed"] += 1


func tower_sold(sell_value: int) -> void:
	gold += sell_value
	stats["towers_sold"] += 1


func record_damage(amount: int) -> void:
	stats["damage_dealt"] += amount


func can_afford(cost: int) -> bool:
	return gold >= cost


func is_game_over() -> bool:
	return lives <= 0


func reset() -> void:
	gold = DEFAULT_GOLD
	lives = DEFAULT_LIVES
	element_cores = 0
	current_wave = 0
	wave_active = false
	enemies_remaining = 0
	stats = {
		"towers_placed": 0,
		"towers_sold": 0,
		"enemies_killed": 0,
		"gold_earned": 0,
		"damage_dealt": 0,
		"elements_unlocked": 0
	}
	# TowerData auch zurücksetzen
	if TowerData:
		TowerData.reset_unlocks()
	print("[GameState] Zurückgesetzt")


func get_save_data() -> Dictionary:
	return {
		"gold": gold,
		"lives": lives,
		"element_cores": element_cores,
		"current_wave": current_wave,
		"stats": stats,
		"unlocked_elements": TowerData.unlocked_elements.duplicate() if TowerData else []
	}


func load_save_data(data: Dictionary) -> void:
	gold = data.get("gold", DEFAULT_GOLD)
	lives = data.get("lives", DEFAULT_LIVES)
	element_cores = data.get("element_cores", 0)
	current_wave = data.get("current_wave", 0)
	stats = data.get("stats", stats)
	if TowerData and data.has("unlocked_elements"):
		TowerData.unlocked_elements = data.get("unlocked_elements", [])
