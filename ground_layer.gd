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
		"grass", "ground"
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
	

	if is_path:
		result.append("ground")  
		return result
	
	result.append("grass")

	
	
	return result
