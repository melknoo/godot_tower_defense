# main.gd
extends Node2D

const GRID_SIZE := 64
const MAP_WIDTH := 30
const MAP_HEIGHT := 15

const ARCHER_FRAME_SIZE := Vector2(192, 192)
const ARCHER_COLUMNS := 8
const SWORD_FRAME_SIZE := Vector2(192, 192)
const SWORD_COLUMNS := 6

@onready var ground_layer: GroundLayer = $GroundLayer
@onready var wave_manager: WaveManager = $WaveManager
@onready var tower_manager: TowerManager = $TowerManager
@onready var hud: HUD = $UI/HUD
@onready var tower_shop: TowerShop = $UI/TowerShop
@onready var tower_info: TowerInfo = $UI/TowerInfo

var element_unlock_ui: ElementUnlockUI
var wave_upgrade_ui: WaveUpgradeUI
var upgrade_overview_ui: UpgradeOverviewUI
var path_generator: PathGenerator

var path_points: Array[Vector2] = []
var path_cells: Array[Vector2i] = []
var current_seed: int = 0

var pending_element_core := false

var hover_preview: Node2D
var hover_range_circle: Line2D
var hover_sprite: Node2D

var is_showing_pickup_preview := false

var is_drag_potential := false
var is_dragging := false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_grid: Vector2i = Vector2i(-1, -1)
const DRAG_THRESHOLD := 8.0


func _ready() -> void:
	_setup_path_generator()
	_generate_new_path()
	_setup_ground()
	_setup_managers()
	_setup_element_unlock_ui()
	_setup_wave_upgrade_ui()
	_setup_upgrade_overview_ui()
	_connect_signals()
	_setup_hover_preview()


func _setup_path_generator() -> void:
	path_generator = PathGenerator.new()
	path_generator.name = "PathGenerator"
	add_child(path_generator)


func _generate_new_path(seed_value: int = -1) -> void:
	if seed_value >= 0:
		current_seed = seed_value
		path_generator.set_seed(seed_value)
	else:
		current_seed = randi()
		path_generator.set_seed(current_seed)
	
	var path_data := path_generator.generate()
	path_generator.print_path_info(path_data)
	
	path_cells.clear()
	path_points.clear()
	
	for cell in path_data["cells"]:
		path_cells.append(cell)
	
	for point in path_data["points"]:
		path_points.append(point)
	
	print("[Main] Neuer Pfad generiert - Seed: %d" % current_seed)


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


func _setup_wave_upgrade_ui() -> void:
	wave_upgrade_ui = WaveUpgradeUI.new()
	wave_upgrade_ui.name = "WaveUpgradeUI"
	add_child(wave_upgrade_ui)
	wave_upgrade_ui.upgrade_chosen.connect(_on_upgrade_chosen)
	print("[Main] WaveUpgradeUI erstellt und Signal verbunden")


func _setup_upgrade_overview_ui() -> void:
	upgrade_overview_ui = UpgradeOverviewUI.new()
	upgrade_overview_ui.name = "UpgradeOverviewUI"
	add_child(upgrade_overview_ui)
	print("[Main] UpgradeOverviewUI erstellt")


func _connect_signals() -> void:
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.element_core_earned.connect(_on_element_core_earned)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.open_element_panel_pressed.connect(_on_open_element_panel)
	hud.open_upgrades_panel_pressed.connect(_on_open_upgrades_panel)
	tower_shop.tower_selected.connect(_on_shop_tower_selected)
	tower_shop.tower_deselected.connect(_on_shop_tower_deselected)
	tower_manager.tower_selected.connect(_on_tower_selected)
	tower_manager.tower_deselected.connect(_on_tower_deselected)
	tower_manager.tower_picked_up.connect(_on_tower_picked_up)
	tower_manager.tower_relocated.connect(_on_tower_relocated)
	tower_manager.blocked_towers_changed.connect(_on_blocked_towers_changed)
	tower_info.sell_pressed.connect(_on_tower_info_sell)
	tower_info.upgrade_pressed.connect(_on_tower_info_upgrade)
	tower_info.close_pressed.connect(_on_tower_info_close)
	tower_info.pickup_pressed.connect(_on_tower_info_pickup)
	if element_unlock_ui:
		element_unlock_ui.element_selected.connect(_on_element_unlocked)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if element_unlock_ui:
			element_unlock_ui.toggle_panel()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		if upgrade_overview_ui:
			upgrade_overview_ui.toggle_panel()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if element_unlock_ui and element_unlock_ui.visible:
			element_unlock_ui.hide_panel()
			return
		if upgrade_overview_ui and upgrade_overview_ui.visible:
			upgrade_overview_ui.hide_panel()
			return
		if is_dragging or is_drag_potential or tower_manager.has_picked_up_tower():
			_cancel_drag_or_pickup()
			is_drag_potential = false
			return
		_deselect_all()
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_click(event)
	elif event is InputEventMouseMotion:
		_update_hover_preview(event.position)


func _regenerate_map() -> void:
	_cancel_drag_or_pickup()
	is_drag_potential = false
	_generate_new_path()
	ground_layer.setup(path_cells)
	wave_manager.path_points = path_points
	tower_manager.set_blocked_cells(path_cells)
	if VFX:
		VFX.screen_flash(Color(1, 1, 1), 0.2)
	print("[Main] Map regeneriert! Blockierte Türme: %d" % tower_manager.get_blocked_tower_count())


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if element_unlock_ui and element_unlock_ui.visible:
		return
	if wave_upgrade_ui and wave_upgrade_ui.visible:
		return
	if upgrade_overview_ui and upgrade_overview_ui.visible:
		return
	
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_cancel_drag_or_pickup()
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_mouse_pressed(event.position)
		else:
			_on_left_mouse_released(event.position)


func _on_left_mouse_pressed(pos: Vector2) -> void:
	if _is_over_ui(pos):
		return
	
	var game_area_height := MAP_HEIGHT * GRID_SIZE
	if pos.y > game_area_height:
		return
	
	var grid_pos := Vector2i(int(pos.x / GRID_SIZE), int(pos.y / GRID_SIZE))
	
	if tower_manager.has_picked_up_tower():
		_handle_relocate_click(grid_pos)
		return
	
	if tower_shop.has_selection():
		tower_manager.deselect_tower()
		var tower_type := tower_shop.get_selected_type()
		if tower_manager.can_place_at(grid_pos, tower_type):
			tower_manager.place_tower(grid_pos, tower_type)
			_update_hover_preview(pos)
		return
	
	var tower := tower_manager.get_tower_at(grid_pos)
	if tower:
		if not GameState.wave_active:
			# Drag nur außerhalb von Wellen möglich
			is_drag_potential = true
			drag_start_pos = pos
			drag_start_grid = grid_pos
		else:
			# Während Welle: Direkt selektieren (kein Drag)
			_handle_tower_click(grid_pos)
		return
	
	tower_manager.deselect_tower()


func _on_left_mouse_released(pos: Vector2) -> void:
	var game_area_height := MAP_HEIGHT * GRID_SIZE
	var grid_pos := Vector2i(int(pos.x / GRID_SIZE), int(pos.y / GRID_SIZE))
	
	if is_dragging:
		if pos.y <= game_area_height and tower_manager.can_relocate_to(grid_pos):
			tower_manager.relocate_tower(grid_pos)
			_end_pickup_preview()
			tower_manager.deselect_tower()
		else:
			tower_manager.cancel_pickup()
			_end_pickup_preview()
		is_dragging = false
		is_drag_potential = false
		drag_start_grid = Vector2i(-1, -1)
		return
	
	if is_drag_potential:
		is_drag_potential = false
		_handle_tower_click(drag_start_grid)
		drag_start_grid = Vector2i(-1, -1)
		return


func _cancel_drag_or_pickup() -> void:
	if is_dragging:
		tower_manager.cancel_pickup()
		_end_pickup_preview()
		is_dragging = false
		is_drag_potential = false
		drag_start_grid = Vector2i(-1, -1)
	elif tower_manager.has_picked_up_tower():
		tower_manager.cancel_pickup()
		_end_pickup_preview()
	else:
		_deselect_all()


func _check_drag_start(current_pos: Vector2) -> void:
	if not is_drag_potential:
		return
	var distance := current_pos.distance_to(drag_start_pos)
	if distance >= DRAG_THRESHOLD:
		is_drag_potential = false
		is_dragging = true
		if tower_manager.pickup_tower(drag_start_grid):
			_start_pickup_preview()
		else:
			is_dragging = false


func _handle_relocate_click(grid_pos: Vector2i) -> void:
	if tower_manager.can_relocate_to(grid_pos):
		tower_manager.relocate_tower(grid_pos)
		_end_pickup_preview()
	else:
		Sound.play_error()


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
	if wave_upgrade_ui and wave_upgrade_ui.visible:
		return true
	if upgrade_overview_ui and upgrade_overview_ui.visible:
		return true
	var viewport_size := get_viewport_rect().size
	if pos.y > viewport_size.y - 105:
		return true
	return false


func _deselect_all() -> void:
	tower_shop.deselect()
	tower_manager.deselect_tower()
	hover_preview.visible = false
	is_drag_potential = false
	is_dragging = false
	drag_start_grid = Vector2i(-1, -1)


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
	_check_drag_start(mouse_pos)
	
	if tower_manager.has_picked_up_tower() or is_dragging:
		_update_pickup_hover_preview(mouse_pos)
		return
	
	if not tower_shop.has_selection():
		hover_preview.visible = false
		return
	if element_unlock_ui and element_unlock_ui.visible:
		hover_preview.visible = false
		return
	if wave_upgrade_ui and wave_upgrade_ui.visible:
		hover_preview.visible = false
		return
	if upgrade_overview_ui and upgrade_overview_ui.visible:
		hover_preview.visible = false
		return
	
	var game_area_height := MAP_HEIGHT * GRID_SIZE
	if mouse_pos.y > game_area_height:
		hover_preview.visible = false
		return
	
	var grid_pos := Vector2i(int(mouse_pos.x / GRID_SIZE), int(mouse_pos.y / GRID_SIZE))
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH or grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT:
		hover_preview.visible = false
		return
	var tower_type := tower_shop.get_selected_type()
	_update_hover_appearance(tower_type, 0)
	hover_preview.visible = true
	hover_preview.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	var can_place := tower_manager.can_place_at(grid_pos, tower_type)
	if can_place:
		hover_range_circle.default_color = Color(0, 1, 0, 0.4)
		hover_sprite.modulate = Color(1, 1, 1, 0.7)
	else:
		hover_range_circle.default_color = Color(1, 0, 0, 0.4)
		hover_sprite.modulate = Color(1, 0.3, 0.3, 0.7)


func _update_pickup_hover_preview(mouse_pos: Vector2) -> void:
	var game_area_height := MAP_HEIGHT * GRID_SIZE
	if mouse_pos.y > game_area_height:
		hover_preview.visible = false
		return
	
	var grid_pos := Vector2i(int(mouse_pos.x / GRID_SIZE), int(mouse_pos.y / GRID_SIZE))
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH or grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT:
		hover_preview.visible = false
		return
	
	var tower_type := tower_manager.get_picked_up_tower_type()
	var tower_level := tower_manager.get_picked_up_tower_level()
	
	_update_hover_appearance(tower_type, tower_level)
	hover_preview.visible = true
	hover_preview.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	
	var can_relocate := tower_manager.can_relocate_to(grid_pos)
	if can_relocate:
		hover_range_circle.default_color = Color(0, 1, 0, 0.4)
		hover_sprite.modulate = Color(1, 1, 1, 0.7)
	else:
		hover_range_circle.default_color = Color(1, 0, 0, 0.4)
		hover_sprite.modulate = Color(1, 0.3, 0.3, 0.7)


func _start_pickup_preview() -> void:
	is_showing_pickup_preview = true
	tower_shop.deselect()
	tower_info.hide_panel()


func _end_pickup_preview() -> void:
	is_showing_pickup_preview = false
	hover_preview.visible = false


func _update_hover_appearance(tower_type: String, level: int = 0) -> void:
	for child in hover_sprite.get_children():
		child.queue_free()
	
	var data := TowerData.get_tower_data(tower_type)
	
	if tower_type == "archer":
		var spritesheet_path := "res://assets/elemental_tower/archer_spritesheet.png"
		if ResourceLoader.exists(spritesheet_path):
			var sprite := Sprite2D.new()
			sprite.texture = load(spritesheet_path)
			sprite.hframes = ARCHER_COLUMNS
			sprite.vframes = 7
			sprite.frame = 0
			var desired_size := 128.0
			var scale_factor := desired_size / ARCHER_FRAME_SIZE.x
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.modulate.a = 0.6
			hover_sprite.add_child(sprite)
		else:
			_create_fallback_preview(tower_type)
	elif tower_type == "sword":
		var spritesheet_path := "res://assets/elemental_tower/sword_spritesheet.png"
		if ResourceLoader.exists(spritesheet_path):
			var sprite := Sprite2D.new()
			sprite.texture = load(spritesheet_path)
			sprite.hframes = SWORD_COLUMNS
			sprite.vframes = 8
			sprite.frame = 0
			var desired_size := 128.0
			var scale_factor := desired_size / SWORD_FRAME_SIZE.x
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.modulate.a = 0.6
			hover_sprite.add_child(sprite)
		else:
			_create_fallback_preview(tower_type)
	elif tower_type == "farm":
		var texture_path := "res://assets/elemental_tower/farm.png"
		if ResourceLoader.exists(texture_path):
			var sprite := Sprite2D.new()
			sprite.texture = load(texture_path)
			sprite.scale = Vector2(2.0, 2.0)
			sprite.offset.y = -8
			sprite.modulate.a = 0.6
			hover_sprite.add_child(sprite)
		else:
			_create_fallback_preview(tower_type)
	else:
		var texture_path := "res://assets/elemental_tower/tower_%s.png" % tower_type
		var is_animated: bool = data.get("animated", true)
		
		if ResourceLoader.exists(texture_path):
			var sprite := Sprite2D.new()
			sprite.texture = load(texture_path)
			if is_animated:
				sprite.vframes = 4
				sprite.hframes = 1
				sprite.frame = 0
				sprite.scale = Vector2(3, 3)
			else:
				sprite.vframes = 1
				sprite.hframes = 1
				sprite.scale = Vector2(3, 3)
			sprite.modulate.a = 0.6
			hover_sprite.add_child(sprite)
		else:
			_create_fallback_preview(tower_type)
	
	if level > 0:
		var level_label := Label.new()
		level_label.text = "★".repeat(level)
		level_label.position = Vector2(15, -25)
		level_label.add_theme_font_size_override("font_size", 10)
		level_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
		hover_sprite.add_child(level_label)
	
	hover_range_circle.clear_points()
	var attack_type: String = data.get("attack_type", "projectile")
	if attack_type != "none":
		var range_val: float = TowerData.get_stat(tower_type, "range", level)
		for i in range(33):
			var angle := i * TAU / 32
			hover_range_circle.add_point(Vector2(cos(angle), sin(angle)) * range_val)


func _create_fallback_preview(tower_type: String) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
		Vector2(0, -25), Vector2(-20, -10)
	])
	var color: Color = TowerData.get_stat(tower_type, "color")
	poly.color = color
	poly.color.a = 0.6
	hover_sprite.add_child(poly)


func _on_start_wave_pressed() -> void:
	if tower_manager.has_blocked_towers():
		Sound.play_error()
		print("[Main] Kann Welle nicht starten - %d Türme auf Pfad!" % tower_manager.get_blocked_tower_count())
		return
	Sound.play_wave_start()
	GameState.start_wave()


func _on_wave_started(wave: int) -> void:
	wave_manager.start_wave(wave)


func _on_wave_completed(wave: int) -> void:
	print("[Main] Welle %d abgeschlossen - regeneriere Pfad..." % wave)
	_regenerate_map()
	
	if hud:
		hud.update_wave_preview_after_regen()
	
	print("[Main] wave_upgrade_ui existiert: %s" % (wave_upgrade_ui != null))
	if wave_upgrade_ui:
		print("[Main] Zeige Upgrade-Panel...")
		wave_upgrade_ui.show_upgrades(wave)
	else:
		push_error("[Main] wave_upgrade_ui ist null!")


func _on_element_core_earned() -> void:
	pending_element_core = true


func _on_upgrade_chosen(upgrade_id: String) -> void:
	if upgrade_id != "":
		print("[Main] Upgrade gewählt: %s" % upgrade_id)
		_refresh_all_tower_stats()
	
	tower_shop._create_tower_buttons()
	
	if pending_element_core:
		pending_element_core = false
		await get_tree().create_timer(0.3).timeout
		if element_unlock_ui and GameState.has_element_cores():
			element_unlock_ui.show_panel()


func _refresh_all_tower_stats() -> void:
	for grid_pos in tower_manager.placed_towers:
		var tower: Node2D = tower_manager.placed_towers[grid_pos]
		var level: int = tower_manager.tower_levels.get(grid_pos, 0)
		var tower_data := TowerData.get_legacy_data(tower.tower_type, level)
		if tower.has_method("setup"):
			tower.setup(tower_data, tower.tower_type)
			tower.level = level


func _on_game_over() -> void:
	get_tree().paused = true
	hud.show_game_over()


func _on_open_element_panel() -> void:
	if element_unlock_ui:
		element_unlock_ui.show_panel()


func _on_open_upgrades_panel() -> void:
	if upgrade_overview_ui:
		upgrade_overview_ui.show_panel()


func _on_element_unlocked(element: String) -> void:
	print("[Main] Element freigeschaltet: %s" % element)


func _on_shop_tower_selected(_tower_type: String) -> void:
	if is_dragging:
		tower_manager.cancel_pickup()
		_end_pickup_preview()
		is_dragging = false
	elif tower_manager.has_picked_up_tower():
		tower_manager.cancel_pickup()
		_end_pickup_preview()
	is_drag_potential = false
	drag_start_grid = Vector2i(-1, -1)
	tower_manager.deselect_tower()
	_update_hover_preview(get_viewport().get_mouse_position())


func _on_shop_tower_deselected() -> void:
	if not tower_manager.has_picked_up_tower():
		hover_preview.visible = false


func _on_tower_selected(tower: Node2D, grid_pos: Vector2i) -> void:
	tower_info.show_tower(tower, grid_pos)


func _on_tower_deselected() -> void:
	tower_info.hide_panel()


func _on_tower_picked_up(_tower: Node2D, _grid_pos: Vector2i) -> void:
	_start_pickup_preview()


func _on_tower_relocated(_tower: Node2D, _old_pos: Vector2i, _new_pos: Vector2i) -> void:
	_end_pickup_preview()
	tower_manager.deselect_tower()


func _on_blocked_towers_changed(count: int) -> void:
	print("[Main] Blockierte Türme geändert: %d" % count)
	if hud:
		hud.update_blocked_towers_warning(count)


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


func _on_tower_info_pickup() -> void:
	var grid_pos := tower_manager.selected_grid_pos
	if tower_manager.pickup_tower(grid_pos):
		_start_pickup_preview()


func get_current_seed() -> int:
	return current_seed
