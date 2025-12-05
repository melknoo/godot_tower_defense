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
		"grass", "ground",
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
			var tile_names := _get_tiles_for_cell(cell)
			for tile_name in tile_names:
				_create_tile_sprite(cell, tile_name)


func _create_tile_sprite(cell: Vector2i, tile_name: String) -> void:
	var pos := Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2)
	
	var sprite := Sprite2D.new()
	sprite.position = pos
	sprite.centered = true
	
	if tiles.has(tile_name):
		sprite.texture = tiles[tile_name]
	elif tiles.has("grass"):
		sprite.texture = tiles["grass"]
	else:
		return
	
	add_child(sprite)


func _get_tiles_for_cell(cell: Vector2i) -> Array[String]:
	var is_path := cell in path_cells
	var result: Array[String] = []
	
	# Nachbarn (ist dort Pfad?)
	var path_up := Vector2i(cell.x, cell.y - 1) in path_cells
	var path_down := Vector2i(cell.x, cell.y + 1) in path_cells
	var path_left := Vector2i(cell.x - 1, cell.y) in path_cells
	var path_right := Vector2i(cell.x + 1, cell.y) in path_cells
	var path_up_left := Vector2i(cell.x - 1, cell.y - 1) in path_cells
	var path_up_right := Vector2i(cell.x + 1, cell.y - 1) in path_cells
	var path_down_left := Vector2i(cell.x - 1, cell.y + 1) in path_cells
	var path_down_right := Vector2i(cell.x + 1, cell.y + 1) in path_cells
	
	# === PFAD-ZELLE ===
	if is_path:
		result.append("ground")  # Braunes Tile
		return result
	
	# === GRAS-ZELLE ===
	
	# Zähle angrenzende Pfad-Zellen
	var adjacent := int(path_up) + int(path_down) + int(path_left) + int(path_right)
	
	# Kein Pfad direkt daneben - prüfe diagonal
	if adjacent == 0:
		if path_up_left:
			result.append("path_corner_right_down")
		elif path_up_right:
			result.append("path_corner_left_down")
		elif path_down_left:
			result.append("path_corner_right_up")
		elif path_down_right:
			result.append("path_corner_left_up")
		else:
			result.append("grass")
		return result
	
	# Pfad an zwei Seiten
	if path_up and path_left:
		result.append("path_corner_inner_left_up")
		return result
	if path_up and path_right:
		result.append("path_corner_inner_right_up")
		return result
	if path_down and path_left:
		result.append("path_corner_inner_left_down")
		return result
	if path_down and path_right:
		result.append("path_corner_inner_right_down")
		return result
	
	# Pfad an einer Seite - gerade Kante
	if path_up:
		result.append("path_up")
	elif path_down:
		result.append("path_down")
	elif path_left:
		result.append("path_left")
	elif path_right:
		result.append("path_right")
	else:
		result.append("grass")
	
	return result
