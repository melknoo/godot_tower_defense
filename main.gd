# main.gd
extends Node2D

const GRID_SIZE := 64
const MAP_WIDTH := 30
const MAP_HEIGHT := 15

@onready var ground_layer: GroundLayer = $GroundLayer
@onready var wave_manager: WaveManager = $WaveManager
@onready var tower_manager: TowerManager = $TowerManager
@onready var hud: HUD = $UI/HUD
@onready var tower_shop: TowerShop = $UI/TowerShop
@onready var tower_info: TowerInfo = $UI/TowerInfo

var element_unlock_ui: ElementUnlockUI

var path_points: Array[Vector2] = [
	Vector2(0, 7) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(4, 7) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(4, 3) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(10, 3) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(10, 10) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(15, 10) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(15, 5) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(20, 5) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(20, 12) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(30, 12) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
]

var path_cells: Array[Vector2i] = [
	# Start links
	Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
	# Hoch
	Vector2i(4, 6), Vector2i(4, 5), Vector2i(4, 4), Vector2i(4, 3),
	# Rechts
	Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3),
	# Runter
	Vector2i(10, 4), Vector2i(10, 5), Vector2i(10, 6), Vector2i(10, 7), Vector2i(10, 8), Vector2i(10, 9), Vector2i(10, 10),
	# Rechts
	Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10), Vector2i(14, 10), Vector2i(15, 10),
	# Hoch
	Vector2i(15, 9), Vector2i(15, 8), Vector2i(15, 7), Vector2i(15, 6), Vector2i(15, 5),
	# Rechts
	Vector2i(16, 5), Vector2i(17, 5), Vector2i(18, 5), Vector2i(19, 5), Vector2i(20, 5),
	# Runter
	Vector2i(20, 6), Vector2i(20, 7), Vector2i(20, 8), Vector2i(20, 9), Vector2i(20, 10), Vector2i(20, 11), Vector2i(20, 12),
	# Rechts zum Ziel
	Vector2i(21, 12), Vector2i(22, 12), Vector2i(23, 12), Vector2i(24, 12), Vector2i(25, 12),
	Vector2i(26, 12), Vector2i(27, 12), Vector2i(28, 12), Vector2i(29, 12)
]

var hover_preview: Node2D
var hover_range_circle: Line2D
var hover_sprite: Node2D


func _ready() -> void:
	_setup_ground()
	_setup_managers()
	_setup_element_unlock_ui()
	_connect_signals()
	_setup_hover_preview()
	#_draw_grid()


func _setup_ground() -> void:
	ground_layer.grid_size = GRID_SIZE
	ground_layer.map_width = MAP_WIDTH
	ground_layer.map_height = MAP_HEIGHT
	ground_layer.setup(path_cells)


func _setup_managers() -> void:
	wave_manager.path_points = path_points
	tower_manager.grid_size = GRID_SIZE
	tower_manager.map_width = MAP_WIDTH
	tower_manager.map_height = MAP_HEIGHT
	tower_manager.set_blocked_cells(path_cells)
	tower_info.set_tower_manager(tower_manager)


func _setup_element_unlock_ui() -> void:
	element_unlock_ui = get_node_or_null("UI/ElementUnlockUI") as ElementUnlockUI
	if not element_unlock_ui:
		element_unlock_ui = ElementUnlockUI.new()
		element_unlock_ui.name = "ElementUnlockUI"
		$UI.add_child(element_unlock_ui)
	
	var viewport_size := get_viewport_rect().size
	element_unlock_ui.position = Vector2(
		(viewport_size.x - 350) / 2,
		(viewport_size.y - 220) / 2
	)


func _connect_signals() -> void:
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.wave_started.connect(_on_wave_started)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.open_element_panel_pressed.connect(_on_open_element_panel)
	tower_shop.tower_selected.connect(_on_shop_tower_selected)
	tower_shop.tower_deselected.connect(_on_shop_tower_deselected)
	tower_manager.tower_selected.connect(_on_tower_selected)
	tower_manager.tower_deselected.connect(_on_tower_deselected)
	tower_info.sell_pressed.connect(_on_tower_info_sell)
	tower_info.upgrade_pressed.connect(_on_tower_info_upgrade)
	tower_info.close_pressed.connect(_on_tower_info_close)
	if element_unlock_ui:
		element_unlock_ui.element_selected.connect(_on_element_unlocked)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if element_unlock_ui:
			element_unlock_ui.toggle_panel()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if element_unlock_ui and element_unlock_ui.visible:
			element_unlock_ui.hide_panel()
			return
		_deselect_all()
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_click(event)
	elif event is InputEventMouseMotion:
		_update_hover_preview(event.position)


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if element_unlock_ui and element_unlock_ui.visible:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_deselect_all()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _is_over_ui(event.position):
			return
		var grid_pos := Vector2i(int(event.position.x / GRID_SIZE), int(event.position.y / GRID_SIZE))
		var tower := tower_manager.get_tower_at(grid_pos)
		if tower:
			_handle_tower_click(grid_pos)
		else:
			_handle_empty_cell_click(grid_pos, event.position)


func _handle_tower_click(grid_pos: Vector2i) -> void:
	tower_shop.deselect()
	hover_preview.visible = false
	if tower_manager.selected_grid_pos == grid_pos:
		tower_manager.deselect_tower()
	else:
		tower_manager.select_tower(grid_pos)


func _handle_empty_cell_click(grid_pos: Vector2i, world_pos: Vector2) -> void:
	tower_manager.deselect_tower()
	if tower_shop.has_selection():
		var tower_type := tower_shop.get_selected_type()
		if tower_manager.can_place_at(grid_pos, tower_type):
			tower_manager.place_tower(grid_pos, tower_type)
			_update_hover_preview(world_pos)


func _is_over_ui(pos: Vector2) -> bool:
	if tower_info.visible and tower_info.get_global_rect().has_point(pos):
		return true
	if element_unlock_ui and element_unlock_ui.visible:
		return true
	return false


func _deselect_all() -> void:
	tower_shop.deselect()
	tower_manager.deselect_tower()
	hover_preview.visible = false


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
	if element_unlock_ui and element_unlock_ui.visible:
		hover_preview.visible = false
		return
	var grid_pos := Vector2i(int(mouse_pos.x / GRID_SIZE), int(mouse_pos.y / GRID_SIZE))
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH or grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT:
		hover_preview.visible = false
		return
	var tower_type := tower_shop.get_selected_type()
	_update_hover_appearance(tower_type)
	hover_preview.visible = true
	hover_preview.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	var can_place := tower_manager.can_place_at(grid_pos, tower_type)
	if can_place:
		hover_range_circle.default_color = Color(0, 1, 0, 0.4)
		hover_sprite.modulate = Color(1, 1, 1, 0.7)
	else:
		hover_range_circle.default_color = Color(1, 0, 0, 0.4)
		hover_sprite.modulate = Color(1, 0.3, 0.3, 0.7)


func _update_hover_appearance(tower_type: String) -> void:
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
	hover_range_circle.clear_points()
	var range_val: float = TowerData.get_stat(tower_type, "range", 0)
	for i in range(33):
		var angle := i * TAU / 32
		hover_range_circle.add_point(Vector2(cos(angle), sin(angle)) * range_val)


func _on_start_wave_pressed() -> void:
	GameState.start_wave()

func _on_wave_started(wave: int) -> void:
	wave_manager.start_wave(wave)

func _on_game_over() -> void:
	get_tree().paused = true
	hud.show_game_over()

func _on_open_element_panel() -> void:
	if element_unlock_ui:
		element_unlock_ui.show_panel()

func _on_element_unlocked(element: String) -> void:
	print("[Main] Element freigeschaltet: %s" % element)

func _on_shop_tower_selected(_tower_type: String) -> void:
	tower_manager.deselect_tower()
	_update_hover_preview(get_viewport().get_mouse_position())

func _on_shop_tower_deselected() -> void:
	hover_preview.visible = false

func _on_tower_selected(tower: Node2D, grid_pos: Vector2i) -> void:
	tower_info.show_tower(tower, grid_pos)

func _on_tower_deselected() -> void:
	tower_info.hide_panel()

func _on_tower_info_sell() -> void:
	tower_manager.sell_tower(tower_manager.selected_grid_pos)

func _on_tower_info_upgrade() -> void:
	var grid_pos := tower_manager.selected_grid_pos
	if tower_manager.upgrade_tower(grid_pos):
		var tower := tower_manager.get_tower_at(grid_pos)
		if tower:
			tower_info.show_tower(tower, grid_pos)

func _on_tower_info_close() -> void:
	tower_manager.deselect_tower()


func _draw_grid() -> void:
	for x in range(MAP_WIDTH + 1):
		var line := Line2D.new()
		line.add_point(Vector2(x * GRID_SIZE, 0))
		line.add_point(Vector2(x * GRID_SIZE, MAP_HEIGHT * GRID_SIZE))
		line.default_color = Color(0.2, 0.2, 0.2, 0.25)
		line.width = 1
		add_child(line)
	for y in range(MAP_HEIGHT + 1):
		var line := Line2D.new()
		line.add_point(Vector2(0, y * GRID_SIZE))
		line.add_point(Vector2(MAP_WIDTH * GRID_SIZE, y * GRID_SIZE))
		line.default_color = Color(0.2, 0.2, 0.2, 0.25)
		line.width = 1
		add_child(line)
