# ground_layer.gd
extends Node2D
class_name GroundLayer

const GRASS_TILEABLE_PATH := "res://assets/tiles/grass_tileable.png"
const PATH_TILE_PATH := "res://assets/tiles/ground.png"  # Original Pfad-Tile

@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var grass_texture: Texture2D
var path_tile_texture: Texture2D  # Neues: Original ground.png
var path_cells: Array[Vector2i] = []
var decoration_manager: DecorationManager

# Größe der kachelbaren Textur
const TILEABLE_SIZE := Vector2(152, 160)


func _ready() -> void:
	_load_grass_texture()
	_setup_decoration_manager()


func _load_grass_texture() -> void:
	if ResourceLoader.exists(GRASS_TILEABLE_PATH):
		grass_texture = load(GRASS_TILEABLE_PATH)
		print("[GroundLayer] Gras-Textur geladen: %s" % GRASS_TILEABLE_PATH)
	else:
		push_error("[GroundLayer] Gras-Textur nicht gefunden: %s" % GRASS_TILEABLE_PATH)
	
	# Lade auch das Original Pfad-Tile
	if ResourceLoader.exists(PATH_TILE_PATH):
		path_tile_texture = load(PATH_TILE_PATH)
		print("[GroundLayer] Pfad-Tile geladen: %s" % PATH_TILE_PATH)
	else:
		push_error("[GroundLayer] Pfad-Tile nicht gefunden: %s" % PATH_TILE_PATH)


func _setup_decoration_manager() -> void:
	decoration_manager = DecorationManager.new()
	decoration_manager.name = "DecorationManager"
	add_child(decoration_manager)


func setup(cells: Array[Vector2i]) -> void:
	path_cells = cells
	_draw_background()
	_draw_path_tiles()  # Geändert: Zeichne Pfad als Tiles wie vorher
	_place_decorations()


func _draw_background() -> void:
	# Entferne alte Tiles
	for child in get_children():
		if child is Sprite2D or child is ColorRect:
			child.queue_free()
	
	if not grass_texture:
		_create_fallback_background()
		return
	
	# Berechne wie oft wir die Textur kacheln müssen
	var map_width_px := map_width * grid_size
	var map_height_px := map_height * grid_size
	
	# Wie viele Kacheln brauchen wir? (aufgerundet)
	var tiles_x := ceili(float(map_width_px) / TILEABLE_SIZE.x)
	var tiles_y := ceili(float(map_height_px) / TILEABLE_SIZE.y)
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# Platziere Kacheln ohne Variation (für nahtloses Tiling)
	for tile_x in range(tiles_x):
		for tile_y in range(tiles_y):
			var sprite := Sprite2D.new()
			sprite.texture = grass_texture
			sprite.centered = false
			sprite.position = Vector2(tile_x * TILEABLE_SIZE.x, tile_y * TILEABLE_SIZE.y)
			
			# Z-Index niedriger als alles andere
			sprite.z_index = -100
			
			add_child(sprite)
	
	print("[GroundLayer] Hintergrund: %dx%d Kacheln platziert" % [tiles_x, tiles_y])


func _create_fallback_background() -> void:
	# Fallback: Einfarbiger Hintergrund
	var rect := ColorRect.new()
	rect.size = Vector2(map_width * grid_size, map_height * grid_size)
	rect.position = Vector2.ZERO
	rect.color = Color(0.3, 0.5, 0.3)
	add_child(rect)


func _place_decorations() -> void:
	if decoration_manager:
		decoration_manager.place_decorations(
			path_cells,
			grid_size,
			map_width,
			map_height,
			self
		)


func set_decoration_seed(seed_value: int) -> void:
	if decoration_manager:
		decoration_manager.set_seed(seed_value)


func _draw_path_tiles() -> void:
	# Zeichne Pfad-Tiles wie in der alten Version
	if not path_tile_texture:
		return
	
	for cell in path_cells:
		var sprite := Sprite2D.new()
		sprite.texture = path_tile_texture
		sprite.centered = true
		sprite.position = Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2)
		sprite.z_index = -80  # Über Ground (-100), unter Decorations (-50)
		add_child(sprite)
	
	print("[GroundLayer] Pfad gezeichnet: %d Tiles" % path_cells.size())
