# path_generator.gd
# Generiert zufällige, spielbare Pfade für Tower Defense
extends Node
class_name PathGenerator

const GRID_SIZE := 64
const MAP_WIDTH := 30
const MAP_HEIGHT := 15

# Pfad-Einstellungen
const MIN_PATH_LENGTH := 35  # Mindestlänge für interessante Pfade
const MAX_STRAIGHT := 5      # Max Zellen in eine Richtung bevor Kurve
const MIN_STRAIGHT := 2      # Min Zellen geradeaus

# Alle 4 Richtungen möglich
enum Dir { RIGHT, LEFT, DOWN, UP }

# Verschiedene Start/End-Kombinationen
enum PathType {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT,
	TOP_TO_BOTTOM,
	BOTTOM_TO_TOP,
	LEFT_TO_BOTTOM,
	LEFT_TO_TOP,
	RIGHT_TO_BOTTOM,
	RIGHT_TO_TOP,
	TOP_TO_RIGHT,
	TOP_TO_LEFT,
	BOTTOM_TO_RIGHT,
	BOTTOM_TO_LEFT
}

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func generate() -> Dictionary:
	# Mehrere Versuche für validen Pfad
	for attempt in range(50):
		var result := _try_generate_path()
		if result["valid"]:
			print("[PathGenerator] Pfad generiert nach %d Versuchen, Länge: %d, Typ: %s" % 
				[attempt + 1, result["cells"].size(), _get_path_type_name(result["path_type"])])
			return result
	
	# Fallback: Einfacher S-Kurven-Pfad
	print("[PathGenerator] Fallback-Pfad verwendet")
	return _generate_fallback_path()


func _try_generate_path() -> Dictionary:
	# Wähle zufälligen Pfad-Typ
	var path_type: PathType = rng.randi_range(0, PathType.size() - 1)
	
	var cells: Array[Vector2i] = []
	var visited: Dictionary = {}
	
	# Start und Ziel basierend auf Pfad-Typ
	var start_pos := _get_start_position(path_type)
	var target_edge := _get_target_edge(path_type)
	var primary_dir := _get_primary_direction(path_type)
	
	var current := start_pos
	cells.append(current)
	visited[current] = true
	
	var last_dir := primary_dir
	var straight_count := 0
	var forced_straight := rng.randi_range(MIN_STRAIGHT, MAX_STRAIGHT)
	
	var max_iterations := MAP_WIDTH * MAP_HEIGHT
	var iterations := 0
	
	while not _reached_target_edge(current, target_edge) and iterations < max_iterations:
		iterations += 1
		
		var next_dir := _choose_direction(current, last_dir, straight_count, forced_straight, 
										  visited, target_edge, primary_dir)
		var next_cell := _move(current, next_dir)
		
		# Validierung
		if not _is_valid_cell(next_cell, visited):
			# Versuche andere Richtung
			var alternatives := _get_alternative_dirs(next_dir, primary_dir)
			var found := false
			for alt_dir in alternatives:
				var alt_cell := _move(current, alt_dir)
				if _is_valid_cell(alt_cell, visited):
					next_cell = alt_cell
					next_dir = alt_dir
					found = true
					break
			if not found:
				return {"valid": false, "cells": [], "points": []}
		
		cells.append(next_cell)
		visited[next_cell] = true
		
		# Richtungswechsel tracken
		if next_dir == last_dir:
			straight_count += 1
		else:
			straight_count = 1
			forced_straight = rng.randi_range(MIN_STRAIGHT, MAX_STRAIGHT)
		
		last_dir = next_dir
		current = next_cell
	
	# Pfad lang genug?
	if cells.size() < MIN_PATH_LENGTH:
		return {"valid": false, "cells": [], "points": []}
	
	# Pfad in Weltkoordinaten umwandeln
	var points := _cells_to_points(cells, target_edge)
	
	return {
		"valid": true,
		"cells": cells,
		"points": points,
		"start_pos": start_pos,
		"end_pos": current,
		"path_type": path_type
	}


func _get_start_position(path_type: PathType) -> Vector2i:
	var margin := 2  # Abstand vom Rand
	match path_type:
		PathType.LEFT_TO_RIGHT, PathType.LEFT_TO_BOTTOM, PathType.LEFT_TO_TOP:
			return Vector2i(0, rng.randi_range(margin, MAP_HEIGHT - margin - 1))
		PathType.RIGHT_TO_LEFT, PathType.RIGHT_TO_BOTTOM, PathType.RIGHT_TO_TOP:
			return Vector2i(MAP_WIDTH - 1, rng.randi_range(margin, MAP_HEIGHT - margin - 1))
		PathType.TOP_TO_BOTTOM, PathType.TOP_TO_RIGHT, PathType.TOP_TO_LEFT:
			return Vector2i(rng.randi_range(margin, MAP_WIDTH - margin - 1), 0)
		PathType.BOTTOM_TO_TOP, PathType.BOTTOM_TO_RIGHT, PathType.BOTTOM_TO_LEFT:
			return Vector2i(rng.randi_range(margin, MAP_WIDTH - margin - 1), MAP_HEIGHT - 1)
	return Vector2i(0, MAP_HEIGHT / 2)


func _get_target_edge(path_type: PathType) -> String:
	match path_type:
		PathType.LEFT_TO_RIGHT, PathType.TOP_TO_RIGHT, PathType.BOTTOM_TO_RIGHT:
			return "right"
		PathType.RIGHT_TO_LEFT, PathType.TOP_TO_LEFT, PathType.BOTTOM_TO_LEFT:
			return "left"
		PathType.TOP_TO_BOTTOM, PathType.LEFT_TO_BOTTOM, PathType.RIGHT_TO_BOTTOM:
			return "bottom"
		PathType.BOTTOM_TO_TOP, PathType.LEFT_TO_TOP, PathType.RIGHT_TO_TOP:
			return "top"
	return "right"


func _get_primary_direction(path_type: PathType) -> Dir:
	match path_type:
		PathType.LEFT_TO_RIGHT, PathType.TOP_TO_RIGHT, PathType.BOTTOM_TO_RIGHT:
			return Dir.RIGHT
		PathType.RIGHT_TO_LEFT, PathType.TOP_TO_LEFT, PathType.BOTTOM_TO_LEFT:
			return Dir.LEFT
		PathType.TOP_TO_BOTTOM, PathType.LEFT_TO_BOTTOM, PathType.RIGHT_TO_BOTTOM:
			return Dir.DOWN
		PathType.BOTTOM_TO_TOP, PathType.LEFT_TO_TOP, PathType.RIGHT_TO_TOP:
			return Dir.UP
	return Dir.RIGHT


func _reached_target_edge(pos: Vector2i, target_edge: String) -> bool:
	match target_edge:
		"right": return pos.x >= MAP_WIDTH - 1
		"left": return pos.x <= 0
		"bottom": return pos.y >= MAP_HEIGHT - 1
		"top": return pos.y <= 0
	return false


func _choose_direction(pos: Vector2i, last_dir: Dir, straight: int, forced: int, 
					  visited: Dictionary, target_edge: String, primary_dir: Dir) -> Dir:
	# Müssen wir geradeaus?
	if straight < forced and last_dir == primary_dir:
		return primary_dir
	
	# Gewichtete Zufallswahl mit Fortschritt zum Ziel
	var weights := {
		Dir.RIGHT: 20,
		Dir.LEFT: 20,
		Dir.DOWN: 20,
		Dir.UP: 20
	}
	
	# Primärrichtung stark bevorzugen
	weights[primary_dir] = 60
	
	# Entgegengesetzte Richtung reduzieren (aber nicht verbieten!)
	var opposite := _get_opposite_dir(primary_dir)
	weights[opposite] = 10
	
	# Anpassungen basierend auf Position und Ziel
	match target_edge:
		"right":
			if pos.x < 5:
				weights[Dir.RIGHT] = 70
				weights[Dir.LEFT] = 5
		"left":
			if pos.x > MAP_WIDTH - 5:
				weights[Dir.LEFT] = 70
				weights[Dir.RIGHT] = 5
		"bottom":
			if pos.y < 5:
				weights[Dir.DOWN] = 70
				weights[Dir.UP] = 5
		"top":
			if pos.y > MAP_HEIGHT - 5:
				weights[Dir.UP] = 70
				weights[Dir.DOWN] = 5
	
	# Rand-Nähe beachten
	if pos.y <= 2:
		weights[Dir.UP] = 0
		weights[Dir.DOWN] += 20
	elif pos.y >= MAP_HEIGHT - 3:
		weights[Dir.DOWN] = 0
		weights[Dir.UP] += 20
	
	if pos.x <= 2:
		weights[Dir.LEFT] = 0
		weights[Dir.RIGHT] += 20
	elif pos.x >= MAP_WIDTH - 3:
		weights[Dir.RIGHT] = 0
		weights[Dir.LEFT] += 20
	
	# Nicht sofort zurück (aber erlaubt nach ein paar Schritten)
	if straight < 3:
		var back_dir := _get_opposite_dir(last_dir)
		weights[back_dir] = max(weights[back_dir] / 3, 5)
	
	# Zu viel geradeaus? Kurve erzwingen
	if straight >= MAX_STRAIGHT:
		weights[last_dir] = 5
		for dir in [Dir.RIGHT, Dir.LEFT, Dir.DOWN, Dir.UP]:
			if dir != last_dir:
				weights[dir] = 30
	
	return _weighted_random(weights)


func _get_opposite_dir(dir: Dir) -> Dir:
	match dir:
		Dir.RIGHT: return Dir.LEFT
		Dir.LEFT: return Dir.RIGHT
		Dir.DOWN: return Dir.UP
		Dir.UP: return Dir.DOWN
	return Dir.RIGHT


func _weighted_random(weights: Dictionary) -> Dir:
	var total := 0
	for w in weights.values():
		total += w
	
	var roll := rng.randi_range(0, total - 1)
	var cumulative := 0
	
	for dir in weights:
		cumulative += weights[dir]
		if roll < cumulative:
			return dir
	
	return Dir.RIGHT


func _move(pos: Vector2i, dir: Dir) -> Vector2i:
	match dir:
		Dir.RIGHT: return pos + Vector2i(1, 0)
		Dir.LEFT: return pos + Vector2i(-1, 0)
		Dir.DOWN: return pos + Vector2i(0, 1)
		Dir.UP: return pos + Vector2i(0, -1)
	return pos


func _get_alternative_dirs(primary: Dir, preferred: Dir) -> Array[Dir]:
	var all_dirs: Array[Dir] = [Dir.RIGHT, Dir.LEFT, Dir.DOWN, Dir.UP]
	all_dirs.erase(primary)
	
	# Bevorzuge primäre Richtung
	if preferred in all_dirs:
		all_dirs.erase(preferred)
		all_dirs.insert(0, preferred)
	
	return all_dirs


func _is_valid_cell(cell: Vector2i, visited: Dictionary) -> bool:
	# Innerhalb der Map?
	if cell.x < 0 or cell.x >= MAP_WIDTH:
		return false
	if cell.y < 1 or cell.y >= MAP_HEIGHT - 1:
		return false
	
	# Schon besucht?
	if visited.has(cell):
		return false
	
	# Keine diagonalen Nachbarn die besucht sind
	var diagonals := [
		cell + Vector2i(1, 1),
		cell + Vector2i(1, -1),
		cell + Vector2i(-1, 1),
		cell + Vector2i(-1, -1)
	]
	
	var adjacent_visited := 0
	for diag in diagonals:
		if visited.has(diag):
			adjacent_visited += 1
	
	if adjacent_visited > 1:
		return false
	
	return true


func _cells_to_points(cells: Array[Vector2i], target_edge: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var half := Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	
	for cell in cells:
		points.append(Vector2(cell) * GRID_SIZE + half)
	
	# Endpunkt außerhalb der Map basierend auf Zielrand
	var last_cell: Vector2i = cells[cells.size() - 1]
	match target_edge:
		"right":
			points.append(Vector2(MAP_WIDTH, last_cell.y) * GRID_SIZE + half)
		"left":
			points.append(Vector2(-1, last_cell.y) * GRID_SIZE + half)
		"bottom":
			points.append(Vector2(last_cell.x, MAP_HEIGHT) * GRID_SIZE + half)
		"top":
			points.append(Vector2(last_cell.x, -1) * GRID_SIZE + half)
	
	return points


func _generate_fallback_path() -> Dictionary:
	# Einfacher S-Kurven Pfad als Fallback (links nach rechts)
	var cells: Array[Vector2i] = []
	var y := 5
	
	for x in range(0, 8):
		cells.append(Vector2i(x, y))
	
	for dy in range(1, 5):
		cells.append(Vector2i(7, y + dy))
	y += 4
	
	for x in range(8, 16):
		cells.append(Vector2i(x, y))
	
	for dy in range(1, 5):
		cells.append(Vector2i(15, y - dy))
	y -= 4
	
	for x in range(16, 24):
		cells.append(Vector2i(x, y))
	
	for dy in range(1, 4):
		cells.append(Vector2i(23, y + dy))
	y += 3
	
	for x in range(24, MAP_WIDTH):
		cells.append(Vector2i(x, y))
	
	return {
		"valid": true,
		"cells": cells,
		"points": _cells_to_points(cells, "right"),
		"start_pos": Vector2i(0, 5),
		"end_pos": Vector2i(MAP_WIDTH - 1, y),
		"path_type": PathType.LEFT_TO_RIGHT
	}


func _get_path_type_name(path_type: PathType) -> String:
	match path_type:
		PathType.LEFT_TO_RIGHT: return "Links→Rechts"
		PathType.RIGHT_TO_LEFT: return "Rechts→Links"
		PathType.TOP_TO_BOTTOM: return "Oben→Unten"
		PathType.BOTTOM_TO_TOP: return "Unten→Oben"
		PathType.LEFT_TO_BOTTOM: return "Links→Unten"
		PathType.LEFT_TO_TOP: return "Links→Oben"
		PathType.RIGHT_TO_BOTTOM: return "Rechts→Unten"
		PathType.RIGHT_TO_TOP: return "Rechts→Oben"
		PathType.TOP_TO_RIGHT: return "Oben→Rechts"
		PathType.TOP_TO_LEFT: return "Oben→Links"
		PathType.BOTTOM_TO_RIGHT: return "Unten→Rechts"
		PathType.BOTTOM_TO_LEFT: return "Unten→Links"
	return "Unbekannt"


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func print_path_info(path_data: Dictionary) -> void:
	if not path_data["valid"]:
		print("[PathGenerator] Ungültiger Pfad")
		return
	
	var cells: Array = path_data["cells"]
	print("[PathGenerator] Pfad-Info:")
	print("  - Länge: %d Zellen" % cells.size())
	print("  - Start: (%d, %d)" % [cells[0].x, cells[0].y])
	print("  - Ende: (%d, %d)" % [cells[cells.size()-1].x, cells[cells.size()-1].y])
	print("  - Typ: %s" % _get_path_type_name(path_data.get("path_type", 0)))
	
	var turns := 0
	var last_dir := Vector2i(1, 0)
	for i in range(1, cells.size()):
		var dir: Vector2i = cells[i] - cells[i-1]
		if dir != last_dir:
			turns += 1
			last_dir = dir
	print("  - Kurven: %d" % turns)
