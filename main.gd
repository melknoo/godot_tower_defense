# main.gd
# Hauptszene - koordiniert alle Manager und UI-Komponenten
extends Node2D

const GRID_SIZE := 64
const MAP_WIDTH := 12
const MAP_HEIGHT := 8

# Manager Referenzen
@onready var wave_manager: WaveManager = $WaveManager
@onready var tower_manager: TowerManager = $TowerManager

# UI Referenzen
@onready var hud: HUD = $UI/HUD
@onready var tower_shop: TowerShop = $UI/TowerShop
@onready var tower_info: TowerInfo = $UI/TowerInfo

# Pfad-Definition
var path_points: Array[Vector2] = [
	Vector2(0, 4) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(3, 4) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(3, 1) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(7, 1) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(7, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(11, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(12, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
]

var path_cells: Array[Vector2i] = [
	Vector2i(0,4), Vector2i(1,4), Vector2i(2,4), Vector2i(3,4),
	Vector2i(3,3), Vector2i(3,2), Vector2i(3,1),
	Vector2i(4,1), Vector2i(5,1), Vector2i(6,1), Vector2i(7,1),
	Vector2i(7,2), Vector2i(7,3), Vector2i(7,4), Vector2i(7,5), Vector2i(7,6),
	Vector2i(8,6), Vector2i(9,6), Vector2i(10,6), Vector2i(11,6)
]

# Hover Preview
var hover_preview: Node2D
var hover_range_circle: Line2D
var hover_sprite: Node2D


func _ready() -> void:
	_setup_managers()
	_connect_signals()
	_setup_hover_preview()
	_draw_grid()
	_draw_path()


func _setup_managers() -> void:
	# WaveManager konfigurieren
	wave_manager.path_points = path_points
	
	# TowerManager konfigurieren
	tower_manager.grid_size = GRID_SIZE
	tower_manager.map_width = MAP_WIDTH
	tower_manager.map_height = MAP_HEIGHT
	tower_manager.set_blocked_cells(path_cells)
	
	# TowerInfo mit TowerManager verbinden
	tower_info.set_tower_manager(tower_manager)


func _connect_signals() -> void:
	# GameState Signals
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.wave_started.connect(_on_wave_started)
	
	# HUD Signals
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	
	# TowerShop Signals
	tower_shop.tower_selected.connect(_on_shop_tower_selected)
	tower_shop.tower_deselected.connect(_on_shop_tower_deselected)
	
	# TowerManager Signals
	tower_manager.tower_selected.connect(_on_tower_selected)
	tower_manager.tower_deselected.connect(_on_tower_deselected)
	
	# TowerInfo Signals
	tower_info.sell_pressed.connect(_on_tower_info_sell)
	tower_info.upgrade_pressed.connect(_on_tower_info_upgrade)
	tower_info.close_pressed.connect(_on_tower_info_close)


# === INPUT HANDLING ===

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_click(event)
	elif event is InputEventMouseMotion:
		_update_hover_preview(event.position)


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	
	# Rechtsklick: Deselektieren
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_deselect_all()
		return
	
	# Linksklick
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Ignorieren wenn über UI
		if _is_over_ui(event.position):
			return
		
		var grid_pos := Vector2i(int(event.position.x / GRID_SIZE), int(event.position.y / GRID_SIZE))
		
		# Klick auf existierenden Tower?
		var tower := tower_manager.get_tower_at(grid_pos)
		if tower:
			_handle_tower_click(grid_pos)
		else:
			_handle_empty_cell_click(grid_pos, event.position)


func _handle_tower_click(grid_pos: Vector2i) -> void:
	# Shop-Auswahl aufheben
	tower_shop.deselect()
	hover_preview.visible = false
	
	# Tower auswählen/deselektieren
	if tower_manager.selected_grid_pos == grid_pos:
		tower_manager.deselect_tower()
	else:
		tower_manager.select_tower(grid_pos)


func _handle_empty_cell_click(grid_pos: Vector2i, world_pos: Vector2) -> void:
	# TowerInfo schließen
	tower_manager.deselect_tower()
	
	# Tower platzieren wenn einer ausgewählt ist
	if tower_shop.has_selection():
		var tower_type := tower_shop.get_selected_type()
		if tower_manager.can_place_at(grid_pos, tower_type):
			tower_manager.place_tower(grid_pos, tower_type)
			_update_hover_preview(world_pos)


func _is_over_ui(pos: Vector2) -> bool:
	# TowerInfo Panel
	if tower_info.visible and tower_info.get_global_rect().has_point(pos):
		return true
	
	# Weitere UI-Elemente können hier geprüft werden
	return false


func _deselect_all() -> void:
	tower_shop.deselect()
	tower_manager.deselect_tower()
	hover_preview.visible = false


# === HOVER PREVIEW ===

func _setup_hover_preview() -> void:
	hover_preview = Node2D.new()
	hover_preview.visible = false
	add_child(hover_preview)
	
	hover_sprite = Node2D.new()
	hover_preview.add_child(hover_sprite)
	
	hover_range_circle = Line2D.new()
	hover_range_circle.width = 2
	hover_preview.add_child(hover_range_circle)


func _update_hover_preview(mouse_pos: Vector2) -> void:
	if not tower_shop.has_selection():
		hover_preview.visible = false
		return
	
	var grid_pos := Vector2i(int(mouse_pos.x / GRID_SIZE), int(mouse_pos.y / GRID_SIZE))
	
	# Außerhalb der Map?
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH or grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT:
		hover_preview.visible = false
		return
	
	var tower_type := tower_shop.get_selected_type()
	_update_hover_appearance(tower_type)
	
	hover_preview.visible = true
	hover_preview.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	
	# Farbe je nach Platzierbarkeit
	var can_place := tower_manager.can_place_at(grid_pos, tower_type)
	if can_place:
		hover_range_circle.default_color = Color(0, 1, 0, 0.4)
		hover_sprite.modulate = Color(1, 1, 1, 0.7)
	else:
		hover_range_circle.default_color = Color(1, 0, 0, 0.4)
		hover_sprite.modulate = Color(1, 0.3, 0.3, 0.7)


func _update_hover_appearance(tower_type: String) -> void:
	# Sprite aktualisieren
	for child in hover_sprite.get_children():
		child.queue_free()
	
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % tower_type
	if ResourceLoader.exists(texture_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.vframes = 4
		sprite.hframes = 1
		sprite.frame = 0
		sprite.scale = Vector2(3, 3)
		sprite.modulate.a = 0.6
		hover_sprite.add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
			Vector2(0, -25), Vector2(-20, -10)
		])
		var color: Color = TowerData.get_stat(tower_type, "color")
		poly.color = color
		poly.color.a = 0.6
		hover_sprite.add_child(poly)
	
	# Range Circle aktualisieren
	hover_range_circle.clear_points()
	var range_val: float = TowerData.get_stat(tower_type, "range", 0)
	for i in range(33):
		var angle := i * TAU / 32
		hover_range_circle.add_point(Vector2(cos(angle), sin(angle)) * range_val)


# === SIGNAL HANDLERS ===

func _on_start_wave_pressed() -> void:
	GameState.start_wave()


func _on_wave_started(wave: int) -> void:
	wave_manager.start_wave(wave)


func _on_game_over() -> void:
	get_tree().paused = true
	hud.show_game_over()


func _on_shop_tower_selected(tower_type: String) -> void:
	# TowerInfo schließen wenn Shop-Auswahl
	tower_manager.deselect_tower()
	_update_hover_preview(get_viewport().get_mouse_position())


func _on_shop_tower_deselected() -> void:
	hover_preview.visible = false


func _on_tower_selected(tower: Node2D, grid_pos: Vector2i) -> void:
	tower_info.show_tower(tower, grid_pos)


func _on_tower_deselected() -> void:
	tower_info.hide_panel()


func _on_tower_info_sell() -> void:
	var grid_pos := tower_manager.selected_grid_pos
	tower_manager.sell_tower(grid_pos)


func _on_tower_info_upgrade() -> void:
	var grid_pos := tower_manager.selected_grid_pos
	if tower_manager.upgrade_tower(grid_pos):
		# Display aktualisieren
		var tower := tower_manager.get_tower_at(grid_pos)
		if tower:
			tower_info.show_tower(tower, grid_pos)


func _on_tower_info_close() -> void:
	tower_manager.deselect_tower()


# === DRAWING ===

func _draw_grid() -> void:
	for x in range(MAP_WIDTH + 1):
		var line := Line2D.new()
		line.add_point(Vector2(x * GRID_SIZE, 0))
		line.add_point(Vector2(x * GRID_SIZE, MAP_HEIGHT * GRID_SIZE))
		line.default_color = Color(0.3, 0.3, 0.3, 0.5)
		line.width = 1
		add_child(line)
	
	for y in range(MAP_HEIGHT + 1):
		var line := Line2D.new()
		line.add_point(Vector2(0, y * GRID_SIZE))
		line.add_point(Vector2(MAP_WIDTH * GRID_SIZE, y * GRID_SIZE))
		line.default_color = Color(0.3, 0.3, 0.3, 0.5)
		line.width = 1
		add_child(line)


func _draw_path() -> void:
	var path_line := Line2D.new()
	for point in path_points:
		path_line.add_point(point)
	path_line.default_color = Color(0.6, 0.4, 0.2)
	path_line.width = 40
	add_child(path_line)
	move_child(path_line, 0)
