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
var path_line: Line2D
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
var ability_bar: AbilityBar
var ability_target_preview: Node2D
var ability_range_circle: Line2D
var item_inventory_ui: ItemInventoryUI
var ability_upgrade_ui: CanvasLayer



func _ready() -> void:
	_setup_path_generator()
	_generate_new_path()
	_setup_ground()
	_setup_managers()
	_setup_wave_upgrade_ui()
	_setup_upgrade_overview_ui()
	_setup_item_inventory_ui()
	_setup_element_unlock_ui()
	_setup_ability_upgrade_ui()
	_setup_ability_bar()
	_setup_ability_preview()
	_connect_signals()
	_setup_hover_preview()


func _setup_path_generator() -> void:
	path_generator = PathGenerator.new()
	path_generator.name = "PathGenerator"
	add_child(path_generator)


# Neue Funktion:
func _setup_ability_upgrade_ui() -> void:
	var ui_script := preload("res://ui/ability_upgrade_ui.gd")
	ability_upgrade_ui = CanvasLayer.new()
	ability_upgrade_ui.set_script(ui_script)
	ability_upgrade_ui.name = "AbilityUpgradeUI"
	add_child(ability_upgrade_ui)
	ability_upgrade_ui.upgrade_selected.connect(_on_ability_upgrade_selected)
	ability_upgrade_ui.panel_closed.connect(_on_ability_upgrade_closed)

func _on_ability_upgrade_selected(choice: Dictionary) -> void:
	print("[Main] Ability Upgrade gewählt: ", choice)

func _on_ability_upgrade_closed() -> void:
	print("[Main] Ability Upgrade Panel geschlossen")


func _setup_item_inventory_ui() -> void:
	item_inventory_ui = ItemInventoryUI.new()
	item_inventory_ui.name = "ItemInventoryUI"
	add_child(item_inventory_ui)
	item_inventory_ui.item_selected.connect(_on_inventory_item_selected)
	print("[Main] ItemInventoryUI erstellt")

# Neue Callback-Funktion:
func _on_inventory_item_selected(item: Dictionary) -> void:
	print("[Main] item_selected:", item.get("name","?"), " uid=", item.get("uid",""))
	print("[Main] tower_info.visible=", tower_info.visible, " tower=", tower_info.current_tower)
	print("[Main] tower_manager.has_selection=", tower_manager.has_selection())
	
	# Priorität: Wenn TowerInfo offen ist UND einen pending_equip_slot hat -> TowerInfo machen lassen
	if tower_info and tower_info.visible and tower_info.current_tower:
		if tower_info.has_method("_on_inventory_item_selected"):
			# TowerInfo hat die komplette Slot-Verwaltung -> dort machen lassen
			tower_info._on_inventory_item_selected(item)
			return
	
	# Fallback: Pending Equip über Main Metas (sollte normalerweise nicht mehr vorkommen)
	var pending_tower: Node2D = get_meta("pending_equip_tower", null) as Node2D
	var pending_slot: int = int(get_meta("pending_equip_slot", -1))

	if pending_tower != null and is_instance_valid(pending_tower) and pending_slot >= 0 and ItemSystem:
		var uid: String = item.get("uid", "")
		if uid == "":
			# pending zurücksetzen
			set_meta("pending_equip_tower", null)
			set_meta("pending_equip_slot", -1)
			return

		if not ItemSystem.can_equip_on_tower(item, pending_tower):
			Sound.play_error()
			# pending zurücksetzen
			set_meta("pending_equip_tower", null)
			set_meta("pending_equip_slot", -1)
			return

		if ItemSystem.equip_item(pending_tower, uid, pending_slot):
			Sound.play_place()
			item_inventory_ui.deselect_item()

		# pending IMMER zurücksetzen (egal ob equip true/false)
		set_meta("pending_equip_tower", null)
		set_meta("pending_equip_slot", -1)
		return
	
	# 2) Fallback: TowerInfo ist offen aber kein pending_equip_slot
	if tower_info and tower_info.visible and tower_info.current_tower and ItemSystem:
		var uid: String = item.get("uid", "")
		if uid == "":
			return

		# Fallback: wenn kein TowerInfo-Handler existiert -> Slot 0
		if ItemSystem.can_equip_on_tower(item, tower_info.current_tower):
			ItemSystem.equip_item(tower_info.current_tower, uid, 0)
			Sound.play_place()
			item_inventory_ui.deselect_item()
		return

	# 3) Fallback: altes Verhalten (nur wenn wirklich ein Tower im TowerManager selektiert ist)
	if tower_manager.has_selection():
		var selected_tower := tower_manager.get_selected_tower()
		if selected_tower and ItemSystem:
			var uid2: String = item.get("uid", "")
			if uid2 == "":
				return

			var equipped := ItemSystem.get_tower_equipped_items(selected_tower)
			var slot := 0
			for i in range(equipped.size()):
				if equipped[i].is_empty():
					slot = i
					break

			if not ItemSystem.can_equip_on_tower(item, selected_tower):
				Sound.play_error()
				return

			if ItemSystem.equip_item(selected_tower, uid2, slot):
				Sound.play_place()
				item_inventory_ui.deselect_item()


func _generate_new_path() -> void:
	if not path_generator:
		return
	
	current_seed = randi()
	path_generator.set_seed(current_seed)
	
	var path_data := path_generator.generate()
	
	if not path_data["valid"]:
		push_error("[Main] Konnte keinen validen Pfad generieren")
		return
	
	path_points = path_data["points"]
	path_cells = path_data["cells"]
	
	# *** NEU: Setze auch Decoration-Seed ***
	if ground_layer:
		ground_layer.set_decoration_seed(current_seed)
	
	print("[Main] Neuer Pfad generiert (Seed: %d, Länge: %d)" % [current_seed, path_cells.size()])


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
	tower_manager.set_tower_info(tower_info)
	tower_info.set_tower_manager(tower_manager)


func _setup_element_unlock_ui() -> void:
	element_unlock_ui = ElementUnlockUI.new()
	element_unlock_ui.name = "ElementUnlockUI"
	add_child(element_unlock_ui)
	print("[Main] ElementUnlockUI erstellt")


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


func _setup_ability_bar() -> void:
	ability_bar = AbilityBar.new()
	ability_bar.name = "AbilityBar"
	$UI.add_child(ability_bar)
	var viewport_size := get_viewport_rect().size
	ability_bar.position = Vector2(5, viewport_size.y - 205)
	print("[Main] AbilityBar erstellt")


func _setup_ability_preview() -> void:
	ability_target_preview = Node2D.new()
	ability_target_preview.visible = false
	add_child(ability_target_preview)
	
	ability_range_circle = Line2D.new()
	ability_range_circle.width = 2
	ability_range_circle.default_color = Color(1, 1, 1, 0.5)
	ability_target_preview.add_child(ability_range_circle)
	

func _connect_signals() -> void:
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.element_core_earned.connect(_on_element_core_earned)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.open_element_panel_pressed.connect(_on_open_element_panel)
	hud.open_upgrades_panel_pressed.connect(_on_open_upgrades_panel)
	hud.open_inventory_pressed.connect(_on_open_inventory)
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

func _on_open_inventory() -> void:
	if item_inventory_ui:
		item_inventory_ui.toggle_panel()



func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if element_unlock_ui:
			element_unlock_ui.toggle_panel()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		if upgrade_overview_ui:
			upgrade_overview_ui.toggle_panel()
		return
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		if item_inventory_ui:
			item_inventory_ui.toggle_panel()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if element_unlock_ui and element_unlock_ui.visible:
			element_unlock_ui.hide_panel()
			return
		if upgrade_overview_ui and upgrade_overview_ui.visible:
			upgrade_overview_ui.hide_panel()
			return
		if AbilitySystem and AbilitySystem.is_targeting:
			AbilitySystem.cancel_targeting()
			ability_target_preview.visible = false
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


# === WELLEN-EREIGNIS LOGIK ===

# Pfad-Regenerierung: Nach Runde 2, dann alle 3 Runden (2, 5, 8, 11...)
func should_regenerate_path(wave: int) -> bool:
	if wave < 2:
		return false
	return (wave - 2) % 3 == 0

# Upgrade-Auswahl: Nach Runde 3, dann alle 3 Runden (3, 6, 9, 12...)
func should_show_upgrades(wave: int) -> bool:
	if wave < 3:
		return false
	return wave % 3 == 0

# Nächste Runde mit Pfad-Regenerierung
func get_next_path_regen_wave(current_wave: int) -> int:
	if current_wave < 2:
		return 2
	var waves_since_2 := current_wave - 2
	var next_cycle := ((waves_since_2 / 3) + 1) * 3
	return 2 + next_cycle

# Nächste Runde mit Upgrade-Auswahl
func get_next_upgrade_wave(current_wave: int) -> int:
	if current_wave < 3:
		return 3
	return ((current_wave / 3) + 1) * 3


func _regenerate_map() -> void:
	_cancel_drag_or_pickup()
	is_drag_potential = false
	_generate_new_path()
	
	# Setup Ground Layer (inkl. Dekorationen)
	ground_layer.setup(path_cells)
	
	wave_manager.path_points = path_points
	tower_manager.set_blocked_cells(path_cells)
	
	if VFX:
		VFX.screen_flash(Color(1, 1, 1), 0.2)
	
	print("[Main] Map regeneriert mit Dekorationen!")


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if AbilitySystem and AbilitySystem.is_targeting:
				AbilitySystem.cancel_targeting()
				ability_target_preview.visible = false
				return
			if tower_info.visible and tower_info.get_global_rect().has_point(event.position):
				return
			_cancel_drag_or_pickup()
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Ability ausführen wenn Targeting aktiv
			if AbilitySystem and AbilitySystem.is_targeting:
				var ability_id := AbilitySystem.selected_ability
				if AbilitySystem.execute_ability(ability_id, event.position):
					ability_target_preview.visible = false
				return
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
			is_drag_potential = true
			drag_start_pos = pos
			drag_start_grid = grid_pos
		else:
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
	# Tower Info Panel (hat feste Position)
	if tower_info.visible and tower_info.get_global_rect().has_point(pos):
		return true
	
	# wave_upgrade_ui blockiert auch, aber das ist ein modales Panel
	if wave_upgrade_ui and wave_upgrade_ui.visible:
		return true
	
	# Untere UI-Leiste (Shop, HUD)
	var viewport_size := get_viewport_rect().size
	if pos.y > viewport_size.y - 105:
		return true
	
	# Item Inventory Panel (hat feste Position)
	if item_inventory_ui and item_inventory_ui.visible:
		var panel := item_inventory_ui.panel
		var detail := item_inventory_ui.detail_panel
		if panel and panel.get_global_rect().has_point(pos):
			return true
		if detail and detail.visible and detail.get_global_rect().has_point(pos):
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

func _update_ability_preview(mouse_pos: Vector2) -> void:
	if not AbilitySystem or not AbilitySystem.is_targeting:
		ability_target_preview.visible = false
		return
	
	var ability_id := AbilitySystem.selected_ability
	var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
	var radius: float = data.get("radius", 50.0)
	
	# Für Earthquake: Kein Kreis, da global
	if ability_id == "earthquake":
		ability_target_preview.visible = false
		return
	
	ability_target_preview.visible = true
	ability_target_preview.position = mouse_pos
	
	var element: String = data.get("element", "")
	var elem_color := Color.WHITE
	match element:
		"air": elem_color = Color(0.7, 0.85, 1.0)
		"water": elem_color = Color(0.4, 0.7, 1.0)
		"fire": elem_color = Color(1.0, 0.5, 0.2)
		"earth": elem_color = Color(0.7, 0.5, 0.3)
	
	ability_range_circle.clear_points()
	ability_range_circle.default_color = elem_color
	ability_range_circle.default_color.a = 0.6
	
	for i in range(33):
		var angle := i * TAU / 32
		ability_range_circle.add_point(Vector2(cos(angle), sin(angle)) * radius)


func _update_hover_preview(mouse_pos: Vector2) -> void:
	_check_drag_start(mouse_pos)
	
	# Ability Targeting Preview
	if AbilitySystem and AbilitySystem.is_targeting:
		_update_ability_preview(mouse_pos)
		hover_preview.visible = false
		return
	else:
		ability_target_preview.visible = false
	
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
	print("[Main] Welle %d abgeschlossen" % wave)
	
	# 1. Pfad-Regenerierung (Runde 2, 5, 8, 11...)
	if should_regenerate_path(wave):
		print("[Main] Regeneriere Pfad nach Welle %d..." % wave)
		_regenerate_map()
		if hud:
			hud.update_wave_preview_after_regen()
	
	# 2. Ability-Upgrades (Runde 4, 7, 10, 13...)
	if AbilitySystem.should_show_ability_upgrades(wave):
		print("[Main] Zeige Ability-Upgrade-Panel nach Welle %d..." % wave)
		ability_upgrade_ui.show_panel()
		return  # Wichtig: Nicht auch noch Perks zeigen!
	
	# 3. Perk-Auswahl (Runde 3, 6, 9, 12...)
	if should_show_upgrades(wave):
		print("[Main] Zeige Perk-Panel nach Welle %d..." % wave)
		if wave_upgrade_ui:
			wave_upgrade_ui.show_upgrades(wave)
		return
	
	# 4. Element-Core Dialog wenn nichts anderes angezeigt wird
	if pending_element_core:
		pending_element_core = false
		await get_tree().create_timer(0.3).timeout
		if element_unlock_ui and GameState.has_element_cores():
			element_unlock_ui.show_panel()
	
	# HUD über Wellen-Events informieren
	if hud:
		hud.update_wave_events_preview(wave + 1)


func _on_element_core_earned() -> void:
	pending_element_core = true


func _on_upgrade_chosen(upgrade_id: String) -> void:
	if upgrade_id != "":
		print("[Main] Upgrade gewählt: %s" % upgrade_id)
		_refresh_all_tower_stats()
		tower_manager.refresh_farm_supply_bonuses()
		if hud:
			hud._on_supply_changed(GameState.supply_used, GameState.supply_max)
			
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
		tower.level = level  
		var tower_data := TowerData.get_legacy_data(tower.tower_type, level)
		if tower.has_method("setup"):
			tower.setup(tower_data, tower.tower_type)


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
	if AbilitySystem and AbilitySystem.is_targeting:
		AbilitySystem.cancel_targeting()
		ability_target_preview.visible = false
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
