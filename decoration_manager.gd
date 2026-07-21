# decoration_manager.gd
# Verwaltet prozedurale Platzierung von Deko-Assets
extends Node
class_name DecorationManager

const DECO_PATH := "res://assets/decorations/"
const DECO_COUNT := 15  # 01.png bis 15.png

var decorations: Dictionary = {}
var decoration_sprites: Array[Sprite2D] = []
var rng := RandomNumberGenerator.new()

# Gewichtungen für häufigeres Spawning
const SPAWN_WEIGHTS := {
	4: 3.0,  # 04.png - häufiger
	5: 3.0,  # 05.png - häufiger
	6: 3.0,  # 06.png - häufiger
	7: 3.0,  # 07.png - häufiger
	8: 3.0,  # 08.png - häufiger
	9: 3.0,  # 09.png - häufiger
}

# Dichte-Einstellungen
const DECO_DENSITY := 0.06  # Chance pro freier Zelle (reduziert von 0.15)
const MIN_PATH_DISTANCE := 1  # Mindestabstand zu Pfad-Zellen
const EDGE_SPAWN_CHANCE := 0.12  # Höhere Chance am Pfad-Rand (reduziert von 0.3)


func _ready() -> void:
	rng.randomize()
	_load_decorations()


func _load_decorations() -> void:
	for i in range(1, DECO_COUNT + 1):
		var filename := "%02d.png" % i
		var file_path := DECO_PATH + filename
		
		if ResourceLoader.exists(file_path):
			decorations[i] = load(file_path)
		else:
			push_warning("[DecorationManager] Nicht gefunden: %s" % file_path)
	
	print("[DecorationManager] %d Dekorationen geladen" % decorations.size())


func place_decorations(
	path_cells: Array[Vector2i],
	grid_size: int,
	map_width: int,
	map_height: int,
	parent: Node2D
) -> void:
	# Alte Dekorationen entfernen
	clear_decorations()
	
	# Erstelle Set für schnelle Pfad-Lookups
	var path_set := {}
	for cell in path_cells:
		path_set[cell] = true
	
	# Finde Pfad-Randkanten
	var edge_cells := _find_path_edges(path_cells, map_width, map_height)
	
	# Platziere Dekorationen auf freien Zellen
	for x in range(map_width):
		for y in range(map_height):
			var cell := Vector2i(x, y)
			
			# Skip Pfad-Zellen
			if path_set.has(cell):
				continue
			
			# Zu nah am Pfad?
			var dist := _distance_to_path(cell, path_cells)
			if dist < MIN_PATH_DISTANCE:
				continue
			
			# Spawn-Chance
			var spawn_chance := DECO_DENSITY
			if cell in edge_cells:
				spawn_chance = EDGE_SPAWN_CHANCE
			
			if rng.randf() > spawn_chance:
				continue
			
			# Wähle gewichtetes Deko-Asset
			var deco_id := _weighted_random_decoration()
			if not decorations.has(deco_id):
				continue
			
			_spawn_decoration(cell, deco_id, grid_size, parent)
	
	print("[DecorationManager] %d Dekorationen platziert" % decoration_sprites.size())


func _find_path_edges(path_cells: Array[Vector2i], map_width: int, map_height: int) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var path_set := {}
	
	for cell in path_cells:
		path_set[cell] = true
	
	# Finde alle Zellen neben dem Pfad
	var neighbors := [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for cell in path_cells:
		for offset in neighbors:
			var neighbor: Vector2i = cell + offset
			
			# In Bounds?
			if neighbor.x < 0 or neighbor.x >= map_width:
				continue
			if neighbor.y < 0 or neighbor.y >= map_height:
				continue
			
			# Nicht auf Pfad?
			if not path_set.has(neighbor) and neighbor not in edges:
				edges.append(neighbor)
	
	return edges


func _distance_to_path(cell: Vector2i, path_cells: Array[Vector2i]) -> int:
	var min_dist := 999
	
	for path_cell in path_cells:
		var dx: int = abs(cell.x - path_cell.x)
		var dy: int = abs(cell.y - path_cell.y)
		var dist: int = max(dx, dy)  # Chebyshev distance
		min_dist = min(min_dist, dist)
	
	return min_dist


func _weighted_random_decoration() -> int:
	var total_weight := 0.0
	
	# Berechne Gesamtgewicht
	for id in decorations.keys():
		total_weight += SPAWN_WEIGHTS.get(id, 1.0)
	
	# Zufallswahl
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	
	for id in decorations.keys():
		cumulative += SPAWN_WEIGHTS.get(id, 1.0)
		if roll <= cumulative:
			return id
	
	# Fallback
	return decorations.keys()[0]


func _spawn_decoration(cell: Vector2i, deco_id: int, grid_size: int, parent: Node2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = decorations[deco_id]
	sprite.centered = true
	
	# Position: Zellenmitte mit kleiner Zufallsverschiebung
	var offset := Vector2(
		rng.randf_range(-grid_size * 0.2, grid_size * 0.2),
		rng.randf_range(-grid_size * 0.2, grid_size * 0.2)
	)
	
	sprite.position = Vector2(cell) * grid_size + Vector2(grid_size / 2, grid_size / 2) + offset
	
	# Z-Index für korrekte Layering:
	# Ground = -100, Decorations = -50, Pfad = -10, Tower/Enemies = 0+
	sprite.z_index = -50
	
	# Leichte Zufallsrotation für Variation
	sprite.rotation = rng.randf_range(-0.1, 0.1)
	
	parent.add_child(sprite)
	decoration_sprites.append(sprite)


func clear_decorations() -> void:
	for sprite in decoration_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	decoration_sprites.clear()


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value
