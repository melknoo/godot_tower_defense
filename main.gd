extends Node2D

const GRID_SIZE := 64
const MAP_WIDTH := 12
const MAP_HEIGHT := 8

var tower_scene: PackedScene
var enemy_scene: PackedScene

var gold := 100
var lives := 20
var current_wave := 0
var enemies_in_wave := 0
var wave_active := false

var selected_tower_type := ""

var tower_data := {
	"archer": {"cost": 25, "damage": 15, "range": 150.0, "fire_rate": 0.6, "color": Color(0.2, 0.7, 0.3), "splash": 0.0},
	"cannon": {"cost": 50, "damage": 40, "range": 120.0, "fire_rate": 1.5, "color": Color(0.7, 0.4, 0.2), "splash": 60.0},
	"sniper": {"cost": 75, "damage": 80, "range": 250.0, "fire_rate": 2.0, "color": Color(0.3, 0.3, 0.8), "splash": 0.0},
	"water": {"cost": 25, "damage": 100, "range": 450.0, "fire_rate": 1.0, "color": Color(0.3, 0.6, 1.0), "splash": 0.0},
	"fire": {"cost": 25, "damage": 100, "range": 450.0, "fire_rate": 1.0, "color": Color(1.0, 0.4, 0.2), "splash": 0.0},
	"earth": {"cost": 25, "damage": 100, "range": 450.0, "fire_rate": 1.0, "color": Color(0.6, 0.4, 0.2), "splash": 0.0},
	"air": {"cost": 25, "damage": 100, "range": 450.0, "fire_rate": 1.0, "color": Color(0.8, 0.9, 1.0), "splash": 0.0}
}

var path_points: Array[Vector2] = [
	Vector2(0, 4) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(3, 4) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(3, 1) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(7, 1) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(7, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(11, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2),
	Vector2(12, 6) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
]

var placed_towers: Dictionary = {}  # grid_pos -> Tower
var tower_placed_wave: Dictionary = {}  # grid_pos -> wave when placed
var selected_placed_tower: Vector2i = Vector2i(-1, -1)  # Aktuell ausgewählter platzierter Turm

var hover_preview: Node2D
var hover_range_circle: Line2D
var hover_sprite: Node2D

var tower_buttons: Dictionary = {}
var sell_panel: PanelContainer
var sell_label: Label

@onready var gold_label: Label = $UI/GoldLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var start_button: Button = $UI/StartWaveButton
@onready var tower_button_container: VBoxContainer = $UI/TowerButtons

func _ready() -> void:
	tower_scene = preload("res://tower.tscn")
	enemy_scene = preload("res://enemy.tscn")
	
	create_tower_buttons()
	create_sell_panel()
	create_hover_preview()
	update_ui()
	draw_grid()
	draw_path()

func create_tower_buttons() -> void:
	# Alte Buttons entfernen falls vorhanden
	for child in tower_button_container.get_children():
		child.queue_free()
	
	var tower_types := ["water", "fire", "earth", "air"]
	
	for type in tower_types:
		var btn := create_tower_button(type)
		tower_button_container.add_child(btn)
		tower_buttons[type] = btn

func create_tower_button(type: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 80)
	btn.flat = true
	
	# Container für Sprite + Kosten
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	# TextureRect für den Tower-Sprite (erster Frame)
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_path := "res://assets/elemental_tower/tower_" + type + ".png"
	if ResourceLoader.exists(texture_path):
		var full_tex: Texture2D = load(texture_path)
		# AtlasTexture für ersten Frame (16x16 aus 16x64)
		var atlas := AtlasTexture.new()
		atlas.atlas = full_tex
		atlas.region = Rect2(0, 0, 16, 16)  # Erster Frame oben
		tex_rect.texture = atlas
	
	vbox.add_child(tex_rect)
	
	# Kosten-Label
	var cost_label := Label.new()
	cost_label.text = str(tower_data[type]["cost"]) + "g"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	
	# StyleBox für Hintergrund
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	hover_style.border_color = Color(0.6, 0.6, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
	pressed_style.border_color = Color(0.4, 0.8, 0.4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.pressed.connect(_on_tower_selected.bind(type))
	
	return btn

func create_sell_panel() -> void:
	sell_panel = PanelContainer.new()
	sell_panel.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.2, 0.2, 0.9)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.8, 0.4, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	sell_panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	sell_panel.add_child(vbox)
	
	sell_label = Label.new()
	sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sell_label)
	
	var sell_btn := Button.new()
	sell_btn.text = "Verkaufen"
	sell_btn.pressed.connect(_on_sell_pressed)
	vbox.add_child(sell_btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Abbrechen"
	cancel_btn.pressed.connect(deselect_placed_tower)
	vbox.add_child(cancel_btn)
	
	$UI.add_child(sell_panel)

func get_sell_value(grid_pos: Vector2i) -> int:
	if not placed_towers.has(grid_pos):
		return 0
	
	var tower: Tower = placed_towers[grid_pos]
	var base_cost: int = tower_data[tower.tower_type]["cost"]
	var placed_wave: int = tower_placed_wave.get(grid_pos, -1)
	
	# 100% nur wenn in aktueller Runde platziert UND noch keine Welle gestartet wurde
	# Sobald eine Welle startet (current_wave erhöht sich), ist es immer 50%
	if placed_wave == current_wave:
		return base_cost
	else:
		return base_cost / 2

func select_placed_tower(grid_pos: Vector2i) -> void:
	selected_placed_tower = grid_pos
	selected_tower_type = ""
	update_tower_buttons()
	hover_preview.visible = false
	
	var tower: Tower = placed_towers[grid_pos]
	var sell_value := get_sell_value(grid_pos)
	var percent := 100 if sell_value == tower_data[tower.tower_type]["cost"] else 50
	
	sell_label.text = tower.tower_type.capitalize() + "\nVerkaufen: " + str(sell_value) + "g (" + str(percent) + "%)"
	sell_panel.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE + 10, 0)
	sell_panel.visible = true
	
	# Turm hervorheben
	tower.range_circle.default_color = Color(1, 0.5, 0.5, 0.3)

func deselect_placed_tower() -> void:
	if selected_placed_tower != Vector2i(-1, -1) and placed_towers.has(selected_placed_tower):
		var tower: Tower = placed_towers[selected_placed_tower]
		tower.range_circle.default_color = Color(1, 1, 1, 0.15)
	
	selected_placed_tower = Vector2i(-1, -1)
	sell_panel.visible = false

func _on_sell_pressed() -> void:
	if selected_placed_tower == Vector2i(-1, -1):
		return
	
	var sell_value := get_sell_value(selected_placed_tower)
	gold += sell_value
	
	var tower: Tower = placed_towers[selected_placed_tower]
	tower.queue_free()
	placed_towers.erase(selected_placed_tower)
	tower_placed_wave.erase(selected_placed_tower)
	
	deselect_placed_tower()
	update_ui()

func _on_tower_selected(type: String) -> void:
	selected_tower_type = type
	update_tower_buttons()
	update_hover_appearance()

func update_tower_buttons() -> void:
	for type in tower_buttons:
		var btn: Button = tower_buttons[type]
		var style: StyleBoxFlat
		
		if type == selected_tower_type:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
			style.border_width_bottom = 2
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_color = Color(0.4, 1.0, 0.4)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
		else:
			style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			style.border_width_bottom = 2
			style.border_width_top = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_color = Color(0.4, 0.4, 0.4)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
		
		btn.add_theme_stylebox_override("normal", style)

func create_hover_preview() -> void:
	hover_preview = Node2D.new()
	hover_preview.visible = false
	add_child(hover_preview)
	
	hover_sprite = Node2D.new()
	hover_preview.add_child(hover_sprite)
	
	hover_range_circle = Line2D.new()
	hover_range_circle.width = 2
	hover_preview.add_child(hover_range_circle)
	
	update_hover_appearance()

func update_hover_appearance() -> void:
	for child in hover_sprite.get_children():
		child.queue_free()
	
	if selected_tower_type == "":
		hover_range_circle.clear_points()
		return
	
	var texture_path := "res://assets/elemental_tower/tower_" + selected_tower_type + ".png"
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
		poly.color = tower_data[selected_tower_type]["color"]
		poly.color.a = 0.6
		hover_sprite.add_child(poly)
	
	hover_range_circle.clear_points()
	var range_val: float = tower_data[selected_tower_type]["range"]
	for i in range(33):
		var angle := i * TAU / 32
		hover_range_circle.add_point(Vector2(cos(angle), sin(angle)) * range_val)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Ignorieren wenn Maus über UI ist
			if sell_panel.visible and sell_panel.get_global_rect().has_point(event.position):
				return
			
			var grid_pos := Vector2i(int(event.position.x / GRID_SIZE), int(event.position.y / GRID_SIZE))
			
			# Prüfen ob auf platzierten Turm geklickt
			if placed_towers.has(grid_pos):
				if selected_placed_tower == grid_pos:
					deselect_placed_tower()
				else:
					deselect_placed_tower()
					select_placed_tower(grid_pos)
			else:
				deselect_placed_tower()
				try_place_tower(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			deselect_tower()
			deselect_placed_tower()
	
	if event is InputEventMouseMotion:
		update_hover_preview(event.position)

func deselect_tower() -> void:
	selected_tower_type = ""
	update_tower_buttons()
	hover_preview.visible = false

func update_hover_preview(mouse_pos: Vector2) -> void:
	if selected_tower_type == "":
		hover_preview.visible = false
		return
	
	var grid_pos := Vector2i(int(mouse_pos.x / GRID_SIZE), int(mouse_pos.y / GRID_SIZE))
	
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH or grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT:
		hover_preview.visible = false
		return
	
	hover_preview.visible = true
	hover_preview.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	
	var can_place := can_place_at(grid_pos)
	if can_place:
		hover_range_circle.default_color = Color(0, 1, 0, 0.4)
		hover_sprite.modulate = Color(1, 1, 1, 0.7)
	else:
		hover_range_circle.default_color = Color(1, 0, 0, 0.4)
		hover_sprite.modulate = Color(1, 0.3, 0.3, 0.7)

func can_place_at(grid_pos: Vector2i) -> bool:
	if selected_tower_type == "": return false
	if wave_active: return false
	if is_on_path(grid_pos): return false
	if placed_towers.has(grid_pos): return false
	if gold < tower_data[selected_tower_type]["cost"]: return false
	return true

func try_place_tower(pos: Vector2) -> void:
	var grid_pos := Vector2i(int(pos.x / GRID_SIZE), int(pos.y / GRID_SIZE))
	
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH: return
	if grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT: return
	if not can_place_at(grid_pos): return
	
	var cost: int = tower_data[selected_tower_type]["cost"]
	
	var tower := tower_scene.instantiate()
	tower.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	tower.setup(tower_data[selected_tower_type], selected_tower_type)
	add_child(tower)
	
	placed_towers[grid_pos] = tower
	tower_placed_wave[grid_pos] = current_wave
	gold -= cost
	update_ui()
	update_hover_preview(pos)

func is_on_path(grid_pos: Vector2i) -> bool:
	var path_cells := [
		Vector2i(0,4), Vector2i(1,4), Vector2i(2,4), Vector2i(3,4),
		Vector2i(3,3), Vector2i(3,2), Vector2i(3,1),
		Vector2i(4,1), Vector2i(5,1), Vector2i(6,1), Vector2i(7,1),
		Vector2i(7,2), Vector2i(7,3), Vector2i(7,4), Vector2i(7,5), Vector2i(7,6),
		Vector2i(8,6), Vector2i(9,6), Vector2i(10,6), Vector2i(11,6)
	]
	return grid_pos in path_cells

func start_wave() -> void:
	if wave_active: return
	
	current_wave += 1
	wave_active = true
	enemies_in_wave = 5 + current_wave * 2
	start_button.disabled = true
	update_ui()
	spawn_enemies()

func spawn_enemies() -> void:
	for i in range(enemies_in_wave):
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree(): return
		
		var enemy := enemy_scene.instantiate()
		enemy.setup(path_points, 50 + current_wave * 10, 80 + current_wave * 5)
		enemy.died.connect(_on_enemy_died)
		enemy.reached_end.connect(_on_enemy_reached_end)
		add_child(enemy)

func _on_enemy_died(reward: int) -> void:
	gold += reward
	enemies_in_wave -= 1
	check_wave_end()
	update_ui()

func _on_enemy_reached_end() -> void:
	lives -= 1
	enemies_in_wave -= 1
	check_wave_end()
	update_ui()
	if lives <= 0:
		game_over()

func check_wave_end() -> void:
	if enemies_in_wave <= 0 and wave_active:
		wave_active = false
		start_button.disabled = false
		gold += 25 + current_wave * 5
		update_ui()

func game_over() -> void:
	get_tree().paused = true
	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: " + str(current_wave)
	game_over_label.position = Vector2(300, 200)
	game_over_label.add_theme_font_size_override("font_size", 48)
	$UI.add_child(game_over_label)

func update_ui() -> void:
	gold_label.text = "Gold: " + str(gold)
	lives_label.text = "Leben: " + str(lives)
	wave_label.text = "Welle: " + str(current_wave)

func draw_grid() -> void:
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

func draw_path() -> void:
	var path_line := Line2D.new()
	for point in path_points:
		path_line.add_point(point)
	path_line.default_color = Color(0.6, 0.4, 0.2)
	path_line.width = 40
	add_child(path_line)
	move_child(path_line, 0)
