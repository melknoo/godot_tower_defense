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

# Aktuell ausgewählter Turmtyp
var selected_tower_type := "archer"

# Turmdaten
var tower_data := {
	"archer": {"cost": 25, "damage": 15, "range": 150.0, "fire_rate": 0.6, "color": Color(0.2, 0.7, 0.3), "splash": 0.0},
	"cannon": {"cost": 50, "damage": 40, "range": 120.0, "fire_rate": 1.5, "color": Color(0.7, 0.4, 0.2), "splash": 60.0},
	"sniper": {"cost": 75, "damage": 80, "range": 250.0, "fire_rate": 2.0, "color": Color(0.3, 0.3, 0.8), "splash": 0.0}
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

var placed_towers: Dictionary = {}

@onready var gold_label: Label = $UI/GoldLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var start_button: Button = $UI/StartWaveButton
@onready var archer_btn: Button = $UI/TowerButtons/ArcherBtn
@onready var cannon_btn: Button = $UI/TowerButtons/CannonBtn
@onready var sniper_btn: Button = $UI/TowerButtons/SniperBtn

func _ready() -> void:
	tower_scene = preload("res://tower.tscn")
	enemy_scene = preload("res://enemy.tscn")
	
	# Button-Signale verbinden
	archer_btn.pressed.connect(_on_archer_selected)
	cannon_btn.pressed.connect(_on_cannon_selected)
	sniper_btn.pressed.connect(_on_sniper_selected)
	
	update_ui()
	update_tower_buttons()
	draw_grid()
	draw_path()

func _on_archer_selected() -> void:
	selected_tower_type = "archer"
	update_tower_buttons()

func _on_cannon_selected() -> void:
	selected_tower_type = "cannon"
	update_tower_buttons()

func _on_sniper_selected() -> void:
	selected_tower_type = "sniper"
	update_tower_buttons()

func update_tower_buttons() -> void:
	# Alle Buttons zurücksetzen
	archer_btn.modulate = Color(1, 1, 1)
	cannon_btn.modulate = Color(1, 1, 1)
	sniper_btn.modulate = Color(1, 1, 1)
	
	# Ausgewählten markieren
	match selected_tower_type:
		"archer": archer_btn.modulate = Color(0.5, 1, 0.5)
		"cannon": cannon_btn.modulate = Color(0.5, 1, 0.5)
		"sniper": sniper_btn.modulate = Color(0.5, 1, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_place_tower(event.position)

func try_place_tower(pos: Vector2) -> void:
	var grid_pos := Vector2i(int(pos.x / GRID_SIZE), int(pos.y / GRID_SIZE))
	
	if grid_pos.x < 0 or grid_pos.x >= MAP_WIDTH: return
	if grid_pos.y < 0 or grid_pos.y >= MAP_HEIGHT: return
	if is_on_path(grid_pos): return
	if placed_towers.has(grid_pos): return
	
	var cost: int = tower_data[selected_tower_type]["cost"]
	if gold < cost: return
	
	var tower := tower_scene.instantiate()
	tower.position = Vector2(grid_pos) * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
	tower.setup(tower_data[selected_tower_type], selected_tower_type)
	add_child(tower)
	
	placed_towers[grid_pos] = tower
	gold -= cost
	update_ui()

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
