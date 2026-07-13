# tower_manager.gd
# Verwaltet Tower-Platzierung, Verkauf, Upgrades mit Supply-System und Relocate
extends Node2D
class_name TowerManager

signal tower_placed(tower: Node2D, grid_pos: Vector2i)
signal tower_sold(grid_pos: Vector2i, sell_value: int)
signal tower_upgraded(tower: Node2D, new_level: int)
signal tower_combined(new_tower: Node2D, grid_pos: Vector2i)
signal tower_selected(tower: Node2D, grid_pos: Vector2i)
signal tower_deselected
signal tower_picked_up(tower: Node2D, grid_pos: Vector2i)
signal tower_relocated(tower: Node2D, old_pos: Vector2i, new_pos: Vector2i)
signal blocked_towers_changed(count: int)

@export var tower_scene: PackedScene
@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var tower_info: TowerInfo = null  # Referenz zum TowerInfo Panel

var placed_towers: Dictionary = {}
var tower_placed_wave: Dictionary = {}
var tower_levels: Dictionary = {}
var selected_grid_pos: Vector2i = Vector2i(-1, -1)
var blocked_cells: Array[Vector2i] = []

# Pickup/Relocate System
var picked_up_tower: Node2D = null
var picked_up_from_pos: Vector2i = Vector2i(-1, -1)
var blocked_tower_positions: Array[Vector2i] = []  # Türme die auf Pfad stehen


func _ready() -> void:
	if tower_scene == null:
		tower_scene = preload("res://tower.tscn")
	print("[TowerManager] Initialisiert")


func set_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells = cells
	_update_blocked_towers()

# Dann neue Funktion hinzufügen:
func set_tower_info(info: TowerInfo) -> void:
	tower_info = info

func _update_blocked_towers() -> void:
	var old_count := blocked_tower_positions.size()
	blocked_tower_positions.clear()
	
	for grid_pos in placed_towers:
		if grid_pos in blocked_cells:
			blocked_tower_positions.append(grid_pos)
			var tower: Node2D = placed_towers[grid_pos]
			if tower.has_method("set_blocked"):
				tower.set_blocked(true)
		else:
			var tower: Node2D = placed_towers[grid_pos]
			if tower.has_method("set_blocked"):
				tower.set_blocked(false)
	
	if blocked_tower_positions.size() != old_count:
		blocked_towers_changed.emit(blocked_tower_positions.size())


func get_blocked_tower_count() -> int:
	return blocked_tower_positions.size()


func has_blocked_towers() -> bool:
	return blocked_tower_positions.size() > 0


func refresh_farm_supply_bonuses() -> void:
	"""Berechnet alle Farm Supply-Boni neu (für Perk-Updates)"""
	var total_farm_bonus := 0
	
	for grid_pos in placed_towers:
		var tower: Node2D = placed_towers[grid_pos]
		if TowerData.is_supply_building(tower.tower_type):
			var bonus := TowerData.get_supply_bonus(tower.tower_type)
			total_farm_bonus += bonus
	
	# Setze supply_max neu basierend auf allen Farmen
	var archive_bonus := GameState.archive_supply_bonus
	var base_supply := GameState.STARTING_MAX_SUPPLY + archive_bonus
	GameState.supply_max = base_supply + total_farm_bonus
	GameState.supply_changed.emit(GameState.supply_used, GameState.supply_max)
	
	print("[TowerManager] Supply neu: %d Basis + %d Archiv + %d Farmen" % [
		GameState.STARTING_MAX_SUPPLY, archive_bonus, total_farm_bonus
	])


func get_farm_count() -> int:
	var count := 0
	for grid_pos in placed_towers:
		var tower: Node2D = placed_towers[grid_pos]
		if TowerData.is_supply_building(tower.tower_type):
			count += 1
	return count
	

func can_place_at(grid_pos: Vector2i, tower_type: String) -> bool:
	if not TowerData.is_tower_available(tower_type):
		return false
	if grid_pos.x < 0 or grid_pos.x >= map_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= map_height:
		return false
	if grid_pos in blocked_cells:
		return false
	if placed_towers.has(grid_pos):
		# Erlaubt wenn wir einen Turm aufgenommen haben und das sein alter Platz ist
		if picked_up_tower and grid_pos == picked_up_from_pos:
			return false  # Kann nicht auf den gleichen Platz zurück während pickup
		return false
	if GameState.wave_active:
		return false
	
	# Beim Relocate keine Kosten prüfen
	if picked_up_tower:
		return true
	
	var cost: int = TowerData.get_tower_cost(tower_type)
	if not GameState.can_afford(cost):
		return false
	if not TowerData.is_supply_building(tower_type):
		if not GameState.can_use_supply(TowerData.get_supply_cost_place()):
			return false
	return true


func can_relocate_to(grid_pos: Vector2i) -> bool:
	if not picked_up_tower:
		return false
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
	return true


# === PICKUP SYSTEM ===

func pickup_tower(grid_pos: Vector2i) -> bool:
	if not placed_towers.has(grid_pos):
		return false
	if GameState.wave_active:
		return false
	if picked_up_tower:
		# Bereits einen Turm aufgenommen - erst ablegen
		return false
	
	var tower: Node2D = placed_towers[grid_pos]
	
	# ZUERST deselektieren (bevor wir aus placed_towers entfernen!)
	if selected_grid_pos == grid_pos:
		deselect_tower()
	
	picked_up_tower = tower
	picked_up_from_pos = grid_pos
	
	# Turm unsichtbar machen (wird als Preview angezeigt)
	tower.visible = false
	
	# Aus placed_towers entfernen (temporär)
	placed_towers.erase(grid_pos)
	
	tower_picked_up.emit(tower, grid_pos)
	Sound.play_click()
	print("[TowerManager] Turm aufgenommen von %s" % grid_pos)
	return true


func cancel_pickup() -> void:
	if not picked_up_tower:
		return
	
	# Turm zurück an alte Position
	picked_up_tower.visible = true
	placed_towers[picked_up_from_pos] = picked_up_tower
	
	# Blocked-Status aktualisieren
	if picked_up_from_pos in blocked_cells:
		if picked_up_tower.has_method("set_blocked"):
			picked_up_tower.set_blocked(true)
	
	print("[TowerManager] Pickup abgebrochen, Turm zurück bei %s" % picked_up_from_pos)
	
	picked_up_tower = null
	picked_up_from_pos = Vector2i(-1, -1)
	
	_update_blocked_towers()


func relocate_tower(new_grid_pos: Vector2i) -> bool:
	if not picked_up_tower:
		return false
	if not can_relocate_to(new_grid_pos):
		return false
	
	var tower := picked_up_tower
	var old_pos := picked_up_from_pos
	
	# Neue Position setzen
	tower.position = Vector2(new_grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	tower.visible = true
	
	# In placed_towers eintragen
	placed_towers[new_grid_pos] = tower
	
	# Metadata übertragen
	if tower_levels.has(old_pos):
		tower_levels[new_grid_pos] = tower_levels[old_pos]
		tower_levels.erase(old_pos)
	if tower_placed_wave.has(old_pos):
		tower_placed_wave[new_grid_pos] = tower_placed_wave[old_pos]
		tower_placed_wave.erase(old_pos)
	
	# Blocked-Status aktualisieren
	if tower.has_method("set_blocked"):
		tower.set_blocked(false)
	
	# VFX
	if VFX:
		VFX.spawn_place_effect(tower.position, tower.tower_type)
	
	Sound.play_place()
	
	tower_relocated.emit(tower, old_pos, new_grid_pos)
	print("[TowerManager] Turm umplatziert von %s nach %s" % [old_pos, new_grid_pos])
	
	# Pickup beenden
	picked_up_tower = null
	picked_up_from_pos = Vector2i(-1, -1)
	_recalculate_all_tower_stats()
	_update_blocked_towers()
	return true


func has_picked_up_tower() -> bool:
	return picked_up_tower != null


func get_picked_up_tower() -> Node2D:
	return picked_up_tower


func get_picked_up_tower_type() -> String:
	if picked_up_tower:
		return picked_up_tower.tower_type
	return ""


func get_picked_up_tower_level() -> int:
	if picked_up_tower and tower_levels.has(picked_up_from_pos):
		return tower_levels[picked_up_from_pos]
	return 0


# === STANDARD PLACEMENT ===

func place_tower(grid_pos: Vector2i, tower_type: String) -> Node2D:
	if not can_place_at(grid_pos, tower_type):
		return null
	
	var cost: int = TowerData.get_tower_cost(tower_type)
	var tower_data := TowerData.get_legacy_data(tower_type, 0)
	
	var tower := tower_scene.instantiate()
	tower.position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	tower.level = 0  # ✅ WICHTIG: Level explizit setzen!
	tower.setup(tower_data, tower_type)
	add_child(tower)
	
	placed_towers[grid_pos] = tower
	tower_placed_wave[grid_pos] = GameState.current_wave
	tower_levels[grid_pos] = 0
	
	GameState.tower_placed(cost)
	
	if not TowerData.is_supply_building(tower_type):
		GameState.use_supply(TowerData.get_supply_cost_place())
	
	if TowerData.is_supply_building(tower_type):
		var bonus := TowerData.get_supply_bonus(tower_type)
		GameState.add_max_supply(bonus)
		if VFX:
			VFX.spawn_status_text(tower.position, "+%d SUPPLY" % bonus, Color("8fe88b"))
	
	_recalculate_all_tower_stats()
	tower_placed.emit(tower, grid_pos)
	_update_blocked_towers()
	print("[TowerManager] %s platziert bei %s (Supply: %d/%d)" % [
		tower_type, grid_pos, GameState.supply_used, GameState.supply_max
	])
	
	return tower



func sell_tower(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Node2D = placed_towers[grid_pos]
	var tower_pos: Vector2 = tower.position
	var tower_type: String = tower.tower_type
	var level: int = tower_levels.get(grid_pos, 0)
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	var placed_this_wave := placed_wave == GameState.current_wave
	
	var sell_value := TowerData.get_sell_value(tower_type, level, placed_this_wave)
	
	
	if VFX:
		VFX.spawn_sell_effect(tower_pos)
		VFX.spawn_gold_number(tower_pos, sell_value)
	
	if not TowerData.is_supply_building(tower_type):
		var supply_to_free := TowerData.get_supply_cost_place() + (level * TowerData.get_supply_cost_upgrade())
		GameState.free_supply(supply_to_free)
	
	if TowerData.is_supply_building(tower_type):
		var bonus := TowerData.get_supply_bonus(tower_type)
		var minimum_supply := GameState.STARTING_MAX_SUPPLY + GameState.archive_supply_bonus
		GameState.supply_max = max(minimum_supply, GameState.supply_max - bonus)
		GameState.supply_changed.emit(GameState.supply_used, GameState.supply_max)
	
	tower.queue_free()
	placed_towers.erase(grid_pos)
	tower_placed_wave.erase(grid_pos)
	tower_levels.erase(grid_pos)
	
	GameState.tower_sold(sell_value)
	
	if selected_grid_pos == grid_pos:
		deselect_tower()
	
	_recalculate_all_tower_stats()

	tower_sold.emit(grid_pos, sell_value)
	print("[TowerManager] Tower verkauft für %d Gold (Supply: %d/%d)" % [
		sell_value, GameState.supply_used, GameState.supply_max
	])
	Sound.play_sell()
	_update_blocked_towers()
	
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
	
	# ✅ KRITISCH: Verwende tower.level als Source of Truth!
	var current_level: int = tower.level
	
	# ✅ Sync-Check: Stelle sicher dass tower_levels synchron ist
	if tower_levels.get(grid_pos, -1) != current_level:
		push_warning("[TowerManager] Level-Desync! tower.level=%d aber tower_levels=%d - Korrigiere..." % [current_level, tower_levels.get(grid_pos, -1)])
		tower_levels[grid_pos] = current_level
	
	if not TowerData.can_upgrade(tower.tower_type, current_level):
		return false
	
	var upgrade_cost := TowerData.get_upgrade_cost(tower.tower_type, current_level)
	
	if not GameState.can_afford(upgrade_cost):
		return false
	
	if GameState.wave_active:
		return false
	
	if not GameState.can_use_supply(TowerData.get_supply_cost_upgrade()):
		return false
	
	var new_level := current_level + 1
	
	# ✅ WICHTIG: Level ZUERST in beiden Orten setzen!
	tower.level = new_level
	tower_levels[grid_pos] = new_level
	
	GameState.tower_placed(upgrade_cost)
	GameState.use_supply(TowerData.get_supply_cost_upgrade())
	
	var new_data := TowerData.get_legacy_data(tower.tower_type, new_level)
	if tower.has_method("upgrade"):
		tower.upgrade(new_data, new_level)
	else:
		tower.setup(new_data, tower.tower_type)
	
	tower_upgraded.emit(tower, new_level)
	print("[TowerManager] %s upgraded zu Level %d (Supply: %d/%d)" % [
		tower.tower_type, new_level, GameState.supply_used, GameState.supply_max
	])
	Sound.play_upgrade()
	
	# ✅ Tower-Info aktualisieren, falls dieser Tower gerade angezeigt wird
	if tower_info and tower_info.visible and tower_info.current_tower == tower:
		tower_info.show_tower(tower, grid_pos)
	
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
	if not GameState.can_afford(cost):
		return false
	
	if not GameState.can_use_supply(TowerData.get_supply_cost_upgrade()):
		return false
	
	return true


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
	
	if VFX:
		VFX.spawn_pixel_burst(tower1.position, tower1.tower_type, 8)
		VFX.spawn_pixel_burst(tower2.position, tower2.tower_type, 8)
	
	var level1: int = tower_levels.get(pos1, 0)
	var level2: int = tower_levels.get(pos2, 0)
	var supply_freed := (TowerData.get_supply_cost_place() * 2) + ((level1 + level2) * TowerData.get_supply_cost_upgrade())
	GameState.free_supply(supply_freed)
	
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
	GameState.use_supply(TowerData.get_supply_cost_place())
	
	if VFX:
		VFX.spawn_pixel_ring(combine_pos, combo_type, 60.0)
		VFX.screen_flash(Color(1, 1, 1), 0.1)
	
	tower_combined.emit(new_tower, new_pos)
	print("[TowerManager] Kombination: %s + %s = %s" % [tower1.tower_type, tower2.tower_type, combo_type])
	
	return new_tower


func select_tower(grid_pos: Vector2i) -> void:
	if not placed_towers.has(grid_pos):
		return
	
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


func is_tower_blocked(grid_pos: Vector2i) -> bool:
	return grid_pos in blocked_tower_positions


func _recalculate_all_tower_stats() -> void:
	for tower in placed_towers.values():
		if tower and is_instance_valid(tower) and tower.has_method("recalculate_stats"):
			tower.recalculate_stats()
