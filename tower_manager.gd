# tower_manager.gd
# Verwaltet Tower-Platzierung, Verkauf, Upgrades und Kombinationen (mit VFX)
extends Node2D
class_name TowerManager

signal tower_placed(tower: Node2D, grid_pos: Vector2i)
signal tower_sold(grid_pos: Vector2i, sell_value: int)
signal tower_upgraded(tower: Node2D, new_level: int)
signal tower_combined(new_tower: Node2D, grid_pos: Vector2i)
signal tower_selected(tower: Node2D, grid_pos: Vector2i)
signal tower_deselected

@export var tower_scene: PackedScene
@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var placed_towers: Dictionary = {}
var tower_placed_wave: Dictionary = {}
var tower_levels: Dictionary = {}
var selected_grid_pos: Vector2i = Vector2i(-1, -1)
var blocked_cells: Array[Vector2i] = []


func _ready() -> void:
	if tower_scene == null:
		tower_scene = preload("res://tower.tscn")
	print("[TowerManager] Initialisiert")


func set_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells = cells


func can_place_at(grid_pos: Vector2i, tower_type: String) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= map_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= map_height:
		return false
	if grid_pos in blocked_cells:
		return false
	if placed_towers.has(grid_pos):
		return false
	if GameState.wave_active:
		return false
	var cost: int = TowerData.get_stat(tower_type, "cost")
	if not GameState.can_afford(cost):
		return false
	return true


func place_tower(grid_pos: Vector2i, tower_type: String) -> Node2D:
	if not can_place_at(grid_pos, tower_type):
		return null
	
	var cost: int = TowerData.get_stat(tower_type, "cost")
	var tower_data := TowerData.get_legacy_data(tower_type, 0)
	
	var tower := tower_scene.instantiate()
	tower.position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	tower.setup(tower_data, tower_type)
	add_child(tower)
	
	placed_towers[grid_pos] = tower
	tower_placed_wave[grid_pos] = GameState.current_wave
	tower_levels[grid_pos] = 0
	
	GameState.tower_placed(cost)
	
	tower_placed.emit(tower, grid_pos)
	print("[TowerManager] %s platziert bei %s" % [tower_type, grid_pos])
	
	return tower


func sell_tower(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Node2D = placed_towers[grid_pos]
	var tower_pos: Vector2 = tower.position
	var level: int = tower_levels.get(grid_pos, 0)
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	var placed_this_wave := placed_wave == GameState.current_wave
	
	var sell_value := TowerData.get_sell_value(tower.tower_type, level, placed_this_wave)
	
	# VFX vor dem Löschen
	if VFX:
		VFX.spawn_sell_effect(tower_pos)
		VFX.spawn_gold_number(tower_pos, sell_value)
	
	tower.queue_free()
	placed_towers.erase(grid_pos)
	tower_placed_wave.erase(grid_pos)
	tower_levels.erase(grid_pos)
	
	GameState.tower_sold(sell_value)
	
	if selected_grid_pos == grid_pos:
		deselect_tower()
	
	tower_sold.emit(grid_pos, sell_value)
	print("[TowerManager] Tower verkauft für %d Gold" % sell_value)
	
	return sell_value


func get_sell_value(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Node2D = placed_towers[grid_pos]
	var level: int = tower_levels.get(grid_pos, 0)
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	var placed_this_wave := placed_wave == GameState.current_wave
	
	return TowerData.get_sell_value(tower.tower_type, level, placed_this_wave)


func get_sell_percent(grid_pos: Vector2i) -> int:
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	return 100 if placed_wave == GameState.current_wave else 50


func upgrade_tower(grid_pos: Vector2i) -> bool:
	if not placed_towers.has(grid_pos):
		return false
	
	var tower: Node2D = placed_towers[grid_pos]
	var current_level: int = tower_levels.get(grid_pos, 0)
	
	if not TowerData.can_upgrade(tower.tower_type, current_level):
		return false
	
	var upgrade_cost := TowerData.get_upgrade_cost(tower.tower_type, current_level)
	
	if not GameState.can_afford(upgrade_cost):
		return false
	
	if GameState.wave_active:
		return false
	
	var new_level := current_level + 1
	tower_levels[grid_pos] = new_level
	GameState.tower_placed(upgrade_cost)
	
	var new_data := TowerData.get_legacy_data(tower.tower_type, new_level)
	if tower.has_method("upgrade"):
		tower.upgrade(new_data, new_level)
	else:
		tower.setup(new_data, tower.tower_type)
	
	tower_upgraded.emit(tower, new_level)
	print("[TowerManager] %s upgraded zu Level %d" % [tower.tower_type, new_level])
	
	return true


func get_upgrade_cost(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return -1
	
	var tower: Node2D = placed_towers[grid_pos]
	var current_level: int = tower_levels.get(grid_pos, 0)
	
	return TowerData.get_upgrade_cost(tower.tower_type, current_level)


func can_upgrade_at(grid_pos: Vector2i) -> bool:
	if not placed_towers.has(grid_pos):
		return false
	if GameState.wave_active:
		return false
	
	var tower: Node2D = placed_towers[grid_pos]
	var current_level: int = tower_levels.get(grid_pos, 0)
	
	if not TowerData.can_upgrade(tower.tower_type, current_level):
		return false
	
	var cost := TowerData.get_upgrade_cost(tower.tower_type, current_level)
	return GameState.can_afford(cost)


func combine_towers(pos1: Vector2i, pos2: Vector2i) -> Node2D:
	if not placed_towers.has(pos1) or not placed_towers.has(pos2):
		return null
	
	var tower1: Node2D = placed_towers[pos1]
	var tower2: Node2D = placed_towers[pos2]
	
	var combo_type := TowerData.find_combination(tower1.tower_type, tower2.tower_type)
	if combo_type.is_empty():
		return null
	
	var combo_cost: int = TowerData.get_stat(combo_type, "cost")
	if not GameState.can_afford(combo_cost):
		return null
	
	if GameState.wave_active:
		return null
	
	var new_pos := pos1
	var combine_pos: Vector2 = tower1.position
	
	# VFX für Kombination
	if VFX:
		VFX.spawn_pixel_burst(tower1.position, tower1.tower_type, 8)
		VFX.spawn_pixel_burst(tower2.position, tower2.tower_type, 8)
	
	placed_towers[pos1].queue_free()
	placed_towers[pos2].queue_free()
	placed_towers.erase(pos1)
	placed_towers.erase(pos2)
	tower_placed_wave.erase(pos1)
	tower_placed_wave.erase(pos2)
	tower_levels.erase(pos1)
	tower_levels.erase(pos2)
	
	var tower_data := TowerData.get_legacy_data(combo_type, 0)
	var new_tower := tower_scene.instantiate()
	new_tower.position = Vector2(new_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	new_tower.setup(tower_data, combo_type)
	add_child(new_tower)
	
	placed_towers[new_pos] = new_tower
	tower_placed_wave[new_pos] = GameState.current_wave
	tower_levels[new_pos] = 0
	
	GameState.tower_placed(combo_cost)
	
	# Extra VFX für neuen kombinierten Tower
	if VFX:
		VFX.spawn_pixel_ring(combine_pos, combo_type, 60.0)
		VFX.screen_flash(Color(1, 1, 1), 0.1)
	
	tower_combined.emit(new_tower, new_pos)
	print("[TowerManager] Kombination: %s + %s = %s" % [tower1.tower_type, tower2.tower_type, combo_type])
	
	return new_tower


func select_tower(grid_pos: Vector2i) -> void:
	if not placed_towers.has(grid_pos):
		return
	
	# Click Sound
	Sound.play_click()

	
	deselect_tower()
	
	selected_grid_pos = grid_pos
	var tower: Node2D = placed_towers[grid_pos]
	
	if tower.has_method("select"):
		tower.select()
	else:
		if tower.get("range_circle"):
			tower.range_circle.default_color = Color(1, 0.5, 0.5, 0.3)
	
	tower_selected.emit(tower, grid_pos)


func deselect_tower() -> void:
	if selected_grid_pos != Vector2i(-1, -1) and placed_towers.has(selected_grid_pos):
		var tower: Node2D = placed_towers[selected_grid_pos]
		
		if tower.has_method("deselect"):
			tower.deselect()
		else:
			if tower.get("range_circle"):
				tower.range_circle.default_color = Color(1, 1, 1, 0.15)
	
	selected_grid_pos = Vector2i(-1, -1)
	tower_deselected.emit()


func has_selection() -> bool:
	return selected_grid_pos != Vector2i(-1, -1)


func get_selected_tower() -> Node2D:
	if selected_grid_pos == Vector2i(-1, -1):
		return null
	return placed_towers.get(selected_grid_pos)


func get_tower_at(grid_pos: Vector2i) -> Node2D:
	return placed_towers.get(grid_pos)


func get_tower_level(grid_pos: Vector2i) -> int:
	return tower_levels.get(grid_pos, 0)


func get_all_towers() -> Array[Node2D]:
	var towers: Array[Node2D] = []
	for tower in placed_towers.values():
		towers.append(tower)
	return towers


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / grid_size), int(world_pos.y / grid_size))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
