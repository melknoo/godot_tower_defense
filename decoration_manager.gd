# decoration_manager.gd
# Verwaltet prozedurale Platzierung von Deko-Assets
extends Node
class_name DecorationManager

# 16-px-Deko aus dem Ninja-Adventure-Pack (Buesche, Blumen, Steine) als Atlas,
# erzeugt von tools/ninja_import/build_assets.py. Laeuft wie alle Welt-Pixelart x4.
const DECO_ATLAS_PATH := "res://assets/decorations/nature_atlas.png"
const ART_TILE := 16
const WORLD_SCALE := 4.0

# Dichte-Einstellungen
const DECO_DENSITY := 0.07      # Chance pro freier Zelle
# Direkt am Weg stehen die Tuerme - dort keine Deko, sonst Verwechslungsgefahr
const MIN_PATH_DISTANCE := 2
# Verschiebung innerhalb der Zelle in ganzen Art-Pixeln (bleibt im Pixelraster)
const MAX_OFFSET_ART_PX := 3

var atlas: Texture2D
var variant_count := 0
var decoration_sprites: Array[Sprite2D] = []
var sprites_by_cell := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_load_decorations()


func _load_decorations() -> void:
	if not ResourceLoader.exists(DECO_ATLAS_PATH):
		push_warning("[DecorationManager] Nicht gefunden: %s" % DECO_ATLAS_PATH)
		return
	atlas = load(DECO_ATLAS_PATH)
	variant_count = atlas.get_width() / ART_TILE
	print("[DecorationManager] %d Dekorationen geladen" % variant_count)


func place_decorations(
	path_cells: Array[Vector2i],
	grid_size: int,
	map_width: int,
	map_height: int,
	parent: Node2D
) -> void:
	clear_decorations()
	if atlas == null or variant_count == 0:
		return

	for x in range(map_width):
		for y in range(map_height):
			var cell := Vector2i(x, y)
			if _distance_to_path(cell, path_cells) < MIN_PATH_DISTANCE:
				continue
			if rng.randf() > DECO_DENSITY:
				continue
			_spawn_decoration(cell, rng.randi_range(0, variant_count - 1), grid_size, parent)

	print("[DecorationManager] %d Dekorationen platziert" % decoration_sprites.size())


func _distance_to_path(cell: Vector2i, path_cells: Array[Vector2i]) -> int:
	var min_dist := 999
	for path_cell in path_cells:
		var dist: int = maxi(absi(cell.x - path_cell.x), absi(cell.y - path_cell.y))  # Chebyshev
		min_dist = mini(min_dist, dist)
	return min_dist


func _spawn_decoration(cell: Vector2i, variant: int, grid_size: int, parent: Node2D) -> void:
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2(variant * ART_TILE, 0, ART_TILE, ART_TILE)

	var sprite := Sprite2D.new()
	sprite.texture = region
	sprite.centered = true
	sprite.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	var offset := Vector2(
		rng.randi_range(-MAX_OFFSET_ART_PX, MAX_OFFSET_ART_PX),
		rng.randi_range(-MAX_OFFSET_ART_PX, MAX_OFFSET_ART_PX)
	) * WORLD_SCALE
	sprite.position = Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2) + offset
	# Ground = -100, Decorations = -50, Tower/Enemies = 0+
	sprite.z_index = -50

	parent.add_child(sprite)
	decoration_sprites.append(sprite)
	sprites_by_cell[cell] = sprite


# Wird ein Turm auf ein Deko-Feld gestellt, verschwindet die Deko darunter
func hide_at(cell: Vector2i) -> void:
	var sprite: Sprite2D = sprites_by_cell.get(cell)
	if is_instance_valid(sprite):
		sprite.visible = false


func clear_decorations() -> void:
	for sprite in decoration_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	decoration_sprites.clear()
	sprites_by_cell.clear()


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value
