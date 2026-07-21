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
var path_visuals: Node2D
var visual_seed := 0

# Größe der kachelbaren Textur
const TILEABLE_SIZE := Vector2(152, 160)


func _ready() -> void:
	_load_grass_texture()
	_setup_decoration_manager()


func _load_grass_texture() -> void:
	if ResourceLoader.exists(GRASS_TILEABLE_PATH):
		grass_texture = load(GRASS_TILEABLE_PATH)
	else:
		push_error("[GroundLayer] Gras-Textur nicht gefunden: %s" % GRASS_TILEABLE_PATH)
	
	# Lade auch das Original Pfad-Tile
	if ResourceLoader.exists(PATH_TILE_PATH):
		path_tile_texture = load(PATH_TILE_PATH)
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
	visual_seed = seed_value
	if decoration_manager:
		decoration_manager.set_seed(seed_value)


func _draw_path_tiles() -> void:
	# Zeichne Pfad-Tiles wie in der alten Version
	if not path_tile_texture:
		return
	if is_instance_valid(path_visuals):
		path_visuals.queue_free()
	path_visuals = Node2D.new()
	path_visuals.name = "PathVisuals"
	add_child(path_visuals)

	var path_lookup := {}
	for path_cell in path_cells:
		path_lookup[path_cell] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed + 104729
	
	for cell in path_cells:
		var sprite := Sprite2D.new()
		sprite.texture = path_tile_texture
		sprite.centered = true
		sprite.position = Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2)
		sprite.z_index = -80  # Über Ground (-100), unter Decorations (-50)
		var shade := rng.randf_range(0.94, 1.04)
		sprite.modulate = Color(shade, shade * 0.99, shade * 0.96)
		path_visuals.add_child(sprite)
		_add_path_details(cell, rng)
		_add_exposed_path_edges(cell, path_lookup)
	
	print("[GroundLayer] Pfad gezeichnet: %d Tiles" % path_cells.size())


func _add_path_details(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var origin := Vector2(cell) * grid_size
	for i in range(rng.randi_range(1, 3)):
		var point := Polygon2D.new()
		var radius := rng.randi_range(1, 3)
		point.polygon = PackedVector2Array([
			Vector2(-radius, 0), Vector2(0, -radius),
			Vector2(radius, 0), Vector2(0, radius)
		])
		point.position = origin + Vector2(rng.randi_range(9, grid_size - 9), rng.randi_range(9, grid_size - 9))
		point.color = Color(0.27, 0.16, 0.09, rng.randf_range(0.16, 0.3))
		point.z_index = -78
		path_visuals.add_child(point)


func _add_exposed_path_edges(cell: Vector2i, path_lookup: Dictionary) -> void:
	var origin := Vector2(cell) * grid_size
	var edges := [
		{"neighbor": cell + Vector2i.UP, "from": origin, "to": origin + Vector2(grid_size, 0), "inset": Vector2(0, 2)},
		{"neighbor": cell + Vector2i.DOWN, "from": origin + Vector2(0, grid_size), "to": origin + Vector2(grid_size, grid_size), "inset": Vector2(0, -2)},
		{"neighbor": cell + Vector2i.LEFT, "from": origin, "to": origin + Vector2(0, grid_size), "inset": Vector2(2, 0)},
		{"neighbor": cell + Vector2i.RIGHT, "from": origin + Vector2(grid_size, 0), "to": origin + Vector2(grid_size, grid_size), "inset": Vector2(-2, 0)}
	]
	for edge in edges:
		if path_lookup.has(edge.neighbor):
			continue
		var shadow := Line2D.new()
		shadow.points = PackedVector2Array([edge.from, edge.to])
		shadow.width = 4.0
		shadow.default_color = Color(0.22, 0.12, 0.06, 0.62)
		shadow.z_index = -77
		shadow.antialiased = false
		path_visuals.add_child(shadow)
		var highlight := Line2D.new()
		highlight.points = PackedVector2Array([edge.from + edge.inset, edge.to + edge.inset])
		highlight.width = 1.0
		highlight.default_color = Color(0.86, 0.65, 0.36, 0.5)
		highlight.z_index = -76
		highlight.antialiased = false
		path_visuals.add_child(highlight)
