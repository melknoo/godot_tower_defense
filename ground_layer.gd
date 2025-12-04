# ground_layer.gd
extends Node2D
class_name GroundLayer

const TILE_PATH := "res://assets/tiles/"

@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var tiles: Dictionary = {}
var path_cells: Array[Vector2i] = []


func _ready() -> void:
	z_index = -10
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
	
	print("[GroundLayer] %d Tiles geladen" % tiles.size())


func setup(cells: Array[Vector2i]) -> void:
	path_cells = cells
	_draw_tiles()


func _draw_tiles() -> void:
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
	else:
		sprite.texture = tiles.get("grass")
	
	add_child(sprite)


func _get_tile_for_cell(cell: Vector2i) -> String:
	var is_path := cell in path_cells
	
	# Nachbarn
	var up := Vector2i(cell.x, cell.y - 1) in path_cells
	var down := Vector2i(cell.x, cell.y + 1) in path_cells
	var left := Vector2i(cell.x - 1, cell.y) in path_cells
	var right := Vector2i(cell.x + 1, cell.y) in path_cells
	var up_left := Vector2i(cell.x - 1, cell.y - 1) in path_cells
	var up_right := Vector2i(cell.x + 1, cell.y - 1) in path_cells
	var down_left := Vector2i(cell.x - 1, cell.y + 1) in path_cells
	var down_right := Vector2i(cell.x + 1, cell.y + 1) in path_cells
	
	# === PFAD-ZELLE ===
	if is_path:
		# Pfad mit Gras-Nachbarn braucht Rand-Tiles
		var grass_up := not up
		var grass_down := not down
		var grass_left := not left
		var grass_right := not right
		
		# Ecken des Pfades (äußere Kurven) - kleine Gras-Ecke
		# Prüfe ob Gras diagonal UND beide angrenzenden Seiten sind Pfad
		if not up_left and up and left:
			return "path_corner_inner_left_up"
		if not up_right and up and right:
			return "path_corner_inner_right_up"
		if not down_left and down and left:
			return "path_corner_inner_left_down"
		if not down_right and down and right:
			return "path_corner_inner_right_down"
		
		# Innere Kurven des Pfades - große Gras-Ecke
		if grass_up and grass_left and not grass_down and not grass_right:
			return "path_corner_left_up"
		if grass_up and grass_right and not grass_down and not grass_left:
			return "path_corner_right_up"
		if grass_down and grass_left and not grass_up and not grass_right:
			return "path_corner_left_down"
		if grass_down and grass_right and not grass_up and not grass_left:
			return "path_corner_right_down"
		
		# Gerade Kanten
		if grass_up and not grass_down:
			return "path_up"
		if grass_down and not grass_up:
			return "path_down"
		if grass_left and not grass_right:
			return "path_left"
		if grass_right and not grass_left:
			return "path_right"
		
		# Pfad ohne Gras-Nachbarn (Mitte) - hier nehmen wir einfach ein Rand-Tile
		# oder wir bräuchten ein reines Pfad-Tile
		return "path_up"  # Fallback
	
	# === GRAS-ZELLE ===
	return "grass"
