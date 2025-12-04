# tower_manager.gd
# Verwaltet Tower-Platzierung, Verkauf, Upgrades und Kombinationen
# Als Child-Node von Main einbinden
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

# Platzierte Türme: grid_pos -> Tower Node
var placed_towers: Dictionary = {}

# Tracking wann Tower platziert wurde: grid_pos -> wave number
var tower_placed_wave: Dictionary = {}

# Tower Levels: grid_pos -> level (0, 1, 2)
var tower_levels: Dictionary = {}

# Aktuell ausgewählter Tower
var selected_grid_pos: Vector2i = Vector2i(-1, -1)

# Path-Zellen wo keine Türme platziert werden können
var blocked_cells: Array[Vector2i] = []


func _ready() -> void:
	if tower_scene == null:
		tower_scene = preload("res://tower.tscn")
	print("[TowerManager] Initialisiert")


# Blockierte Zellen setzen (Pfad)
func set_blocked_cells(cells: Array[Vector2i]) -> void:
	blocked_cells = cells


# Kann an Position platziert werden?
func can_place_at(grid_pos: Vector2i, tower_type: String) -> bool:
	# Außerhalb der Map?
	if grid_pos.x < 0 or grid_pos.x >= map_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= map_height:
		return false
	
	# Auf dem Pfad?
	if grid_pos in blocked_cells:
		return false
	
	# Bereits ein Tower dort?
	if placed_towers.has(grid_pos):
		return false
	
	# Während einer Wave?
	if GameState.wave_active:
		return false
	
	# Genug Gold?
	var cost: int = TowerData.get_stat(tower_type, "cost")
	if not GameState.can_afford(cost):
		return false
	
	return true


# Tower platzieren
func place_tower(grid_pos: Vector2i, tower_type: String) -> Node2D:
	if not can_place_at(grid_pos, tower_type):
		return null
	
	var cost: int = TowerData.get_stat(tower_type, "cost")
	var tower_data := TowerData.get_legacy_data(tower_type, 0)
	
	var tower := tower_scene.instantiate()
	tower.position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	tower.setup(tower_data, tower_type)
	add_child(tower)
	
	# Tracking
	placed_towers[grid_pos] = tower
	tower_placed_wave[grid_pos] = GameState.current_wave
	tower_levels[grid_pos] = 0
	
	# Gold abziehen
	GameState.tower_placed(cost)
	
	tower_placed.emit(tower, grid_pos)
	print("[TowerManager] %s platziert bei %s" % [tower_type, grid_pos])
	
	return tower


# Tower verkaufen
func sell_tower(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Node2D = placed_towers[grid_pos]
	var level: int = tower_levels.get(grid_pos, 0)
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	var placed_this_wave := placed_wave == GameState.current_wave
	
	var sell_value := TowerData.get_sell_value(tower.tower_type, level, placed_this_wave)
	
	# Tower entfernen
	tower.queue_free()
	placed_towers.erase(grid_pos)
	tower_placed_wave.erase(grid_pos)
	tower_levels.erase(grid_pos)
	
	# Gold gutschreiben
	GameState.tower_sold(sell_value)
	
	# Deselektieren falls dieser Tower ausgewählt war
	if selected_grid_pos == grid_pos:
		deselect_tower()
	
	tower_sold.emit(grid_pos, sell_value)
	print("[TowerManager] Tower verkauft für %d Gold" % sell_value)
	
	return sell_value


# Verkaufswert berechnen (ohne zu verkaufen)
func get_sell_value(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Node2D = placed_towers[grid_pos]
	var level: int = tower_levels.get(grid_pos, 0)
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	var placed_this_wave := placed_wave == GameState.current_wave
	
	return TowerData.get_sell_value(tower.tower_type, level, placed_this_wave)


# Verkaufsprozent (100% oder 50%)
func get_sell_percent(grid_pos: Vector2i) -> int:
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	return 100 if placed_wave == GameState.current_wave else 50


# Tower upgraden
func upgrade_tower(grid_pos: Vector2i) -> bool:
	if not placed_towers.has(grid_pos):
		return false
	
	var tower: Node2D = placed_towers[grid_pos]
	var current_level: int = tower_levels.get(grid_pos, 0)
	
	# Kann upgraden?
	if not TowerData.can_upgrade(tower.tower_type, current_level):
		return false
	
	var upgrade_cost := TowerData.get_upgrade_cost(tower.tower_type, current_level)
	
	# Genug Gold?
	if not GameState.can_afford(upgrade_cost):
		return false
	
	# Während Wave kein Upgrade
	if GameState.wave_active:
		return false
	
	# Upgrade durchführen
	var new_level := current_level + 1
	tower_levels[grid_pos] = new_level
	GameState.tower_placed(upgrade_cost)  # Nutzt tower_placed für Gold-Abzug
	
	# Tower-Stats aktualisieren
	var new_data := TowerData.get_legacy_data(tower.tower_type, new_level)
	if tower.has_method("upgrade"):
		tower.upgrade(new_data, new_level)
	else:
		# Fallback: setup erneut aufrufen
		tower.setup(new_data, tower.tower_type)
	
	tower_upgraded.emit(tower, new_level)
	print("[TowerManager] %s upgraded zu Level %d" % [tower.tower_type, new_level])
	
	return true


# Upgrade-Kosten für Tower an Position
func get_upgrade_cost(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return -1
	
	var tower: Node2D = placed_towers[grid_pos]
	var current_level: int = tower_levels.get(grid_pos, 0)
	
	return TowerData.get_upgrade_cost(tower.tower_type, current_level)


# Kann Tower upgraden?
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


# Tower kombinieren (zwei benachbarte Türme)
func combine_towers(pos1: Vector2i, pos2: Vector2i) -> Node2D:
	if not placed_towers.has(pos1) or not placed_towers.has(pos2):
		return null
	
	var tower1: Node2D = placed_towers[pos1]
	var tower2: Node2D = placed_towers[pos2]
	
	# Kombination finden
	var combo_type := TowerData.find_combination(tower1.tower_type, tower2.tower_type)
	if combo_type.is_empty():
		return null
	
	# Kosten prüfen
	var combo_cost: int = TowerData.get_stat(combo_type, "cost")
	if not GameState.can_afford(combo_cost):
		return null
	
	# Nicht während Wave
	if GameState.wave_active:
		return null
	
	# Position für neuen Tower (Mitte zwischen beiden)
	var new_pos := pos1  # Oder: (pos1 + pos2) / 2 wenn diagonal erlaubt
	
	# Alte Türme entfernen (ohne Rückerstattung)
	placed_towers[pos1].queue_free()
	placed_towers[pos2].queue_free()
	placed_towers.erase(pos1)
	placed_towers.erase(pos2)
	tower_placed_wave.erase(pos1)
	tower_placed_wave.erase(pos2)
	tower_levels.erase(pos1)
	tower_levels.erase(pos2)
	
	# Neuen Kombinations-Tower erstellen
	var tower_data := TowerData.get_legacy_data(combo_type, 0)
	var new_tower := tower_scene.instantiate()
	new_tower.position = Vector2(new_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	new_tower.setup(tower_data, combo_type)
	add_child(new_tower)
	
	placed_towers[new_pos] = new_tower
	tower_placed_wave[new_pos] = GameState.current_wave
	tower_levels[new_pos] = 0
	
	GameState.tower_placed(combo_cost)
	
	tower_combined.emit(new_tower, new_pos)
	print("[TowerManager] Kombination: %s + %s = %s" % [tower1.tower_type, tower2.tower_type, combo_type])
	
	return new_tower


# Tower auswählen
func select_tower(grid_pos: Vector2i) -> void:
	if not placed_towers.has(grid_pos):
		return
	
	# Vorherige Auswahl aufheben
	deselect_tower()
	
	selected_grid_pos = grid_pos
	var tower: Node2D = placed_towers[grid_pos]
	
	# Visuelles Feedback
	if tower.has_node("RangeCircle") or tower.get("range_circle"):
		tower.range_circle.default_color = Color(1, 0.5, 0.5, 0.3)
	
	tower_selected.emit(tower, grid_pos)


# Tower deselektieren
func deselect_tower() -> void:
	if selected_grid_pos != Vector2i(-1, -1) and placed_towers.has(selected_grid_pos):
		var tower: Node2D = placed_towers[selected_grid_pos]
		if tower.get("range_circle"):
			tower.range_circle.default_color = Color(1, 1, 1, 0.15)
	
	selected_grid_pos = Vector2i(-1, -1)
	tower_deselected.emit()


# Ist Tower ausgewählt?
func has_selection() -> bool:
	return selected_grid_pos != Vector2i(-1, -1)


# Ausgewählten Tower holen
func get_selected_tower() -> Node2D:
	if selected_grid_pos == Vector2i(-1, -1):
		return null
	return placed_towers.get(selected_grid_pos)


# Tower an Position holen
func get_tower_at(grid_pos: Vector2i) -> Node2D:
	return placed_towers.get(grid_pos)


# Tower-Level an Position
func get_tower_level(grid_pos: Vector2i) -> int:
	return tower_levels.get(grid_pos, 0)


# Alle Türme zurückgeben
func get_all_towers() -> Array[Node2D]:
	var towers: Array[Node2D] = []
	for tower in placed_towers.values():
		towers.append(tower)
	return towers


# Grid-Position aus Welt-Position berechnen
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / grid_size), int(world_pos.y / grid_size))


# Welt-Position aus Grid-Position (Zellmitte)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * grid_size + Vector2(grid_size / 2, grid_size / 2)
