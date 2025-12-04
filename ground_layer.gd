# ground_layer.gd
# Verwaltet die Boden-Tiles (Gras, Pfad, Übergänge)
# Als Node2D in Main einbinden, muss erstes Child sein
extends Node2D
class_name GroundLayer

const TILE_PATH := "res://assets/tiles/"

@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var tiles: Dictionary = {}
var path_cells: Array[Vector2i] = []


func _ready() -> void:
	_load_tiles()


func _load_tiles() -> void:
	var tile_names: Array[String] = [
		"grass",
		"path_up", "path_down", "path_left", "path_right",
		"path_corner_left_up", "path_corner_left_down",
		"path_corner_right_up", "path_corner_right_down",
		"path_corner_inner_left_up", "path_corner_inner_left_down",
		"path_corner_inner_right_up", "path_corner_inner_right_down"
	]
	
	for tile_name in tile_names:
		var file_path: String = TILE_PATH + tile_name + ".png"
		if ResourceLoader.exists(file_path):
			tiles[tile_name] = load(file_path)
		else:
			push_warning("[GroundLayer] Tile nicht gefunden: " + file_path)
	
	print("[GroundLayer] %d Tiles geladen" % tiles.size())


func setup(cells: Array[Vector2i]) -> void:
	path_cells = cells
	_draw_tiles()


func _draw_tiles() -> void:
	# Alte Tiles entfernen
	for child in get_children():
		child.queue_free()
	
	for x in range(map_width):
		for y in range(map_height):
			var cell := Vector2i(x, y)
			var tile_name := _get_tile_for_cell(cell)
			_create_tile_sprite(cell, tile_name)


func _create_tile_sprite(cell: Vector2i, tile_name: String) -> void:
	var sprite := Sprite2D.new()
	sprite.position = Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	sprite.centered = true
	
	if tiles.has(tile_name):
		sprite.texture = tiles[tile_name]
	elif tiles.has("grass"):
		sprite.texture = tiles["grass"]
	else:
		# Fallback: ColorRect
		var is_path := cell in path_cells
		var rect := ColorRect.new()
		rect.color = Color(0.55, 0.35, 0.2) if is_path else Color(0.3, 0.6, 0.2)
		rect.size = Vector2(grid_size, grid_size)
		rect.position = Vector2(cell) * grid_size
		add_child(rect)
		return
	
	add_child(sprite)


func _get_tile_for_cell(cell: Vector2i) -> String:
	var is_path := cell in path_cells
	
	# Nachbarn prüfen
	var up := Vector2i(cell.x, cell.y - 1) in path_cells
	var down := Vector2i(cell.x, cell.y + 1) in path_cells
	var left := Vector2i(cell.x - 1, cell.y) in path_cells
	var right := Vector2i(cell.x + 1, cell.y) in path_cells
	
	# Diagonale Nachbarn
	var up_left := Vector2i(cell.x - 1, cell.y - 1) in path_cells
	var up_right := Vector2i(cell.x + 1, cell.y - 1) in path_cells
	var down_left := Vector2i(cell.x - 1, cell.y + 1) in path_cells
	var down_right := Vector2i(cell.x + 1, cell.y + 1) in path_cells
	
	# Pfad-Zellen bekommen erstmal Gras (werden von Rand-Tiles visuell überdeckt)
	if is_path:
		return "grass"
	
	# === GRAS-ZELLEN: Prüfen welches Tile passt ===
	
	# Innere Ecken (Gras mit Pfad nur diagonal)
	if not up and not left and up_left:
		return "path_corner_inner_right_down"
	if not up and not right and up_right:
		return "path_corner_inner_left_down"
	if not down and not left and down_left:
		return "path_corner_inner_right_up"
	if not down and not right and down_right:
		return "path_corner_inner_left_up"
	
	# Äußere Ecken (Pfad an zwei angrenzenden Seiten)
	if up and left:
		return "path_corner_left_up"
	if up and right:
		return "path_corner_right_up"
	if down and left:
		return "path_corner_left_down"
	if down and right:
		return "path_corner_right_down"
	
	# Gerade Kanten (Pfad an einer Seite)
	if up:
		return "path_up"
	if down:
		return "path_down"
	if left:
		return "path_left"
	if right:
		return "path_right"
	
	# Reines Gras (kein Pfad in der Nähe)
	return "grass"
