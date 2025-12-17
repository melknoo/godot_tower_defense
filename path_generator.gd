# path_generator.gd
# Generiert zufällige, spielbare Pfade für Tower Defense
extends Node
class_name PathGenerator

const GRID_SIZE := 64
const MAP_WIDTH := 30
const MAP_HEIGHT := 15

# Pfad-Einstellungen
const MIN_PATH_LENGTH := 35  # Mindestlänge für interessante Pfade
const MAX_STRAIGHT := 4      # Max Zellen in eine Richtung bevor Kurve
const MIN_STRAIGHT := 2      # Min Zellen geradeaus

# Richtungen: rechts, runter, hoch (kein links - wir wollen nach rechts)
enum Dir { RIGHT, DOWN, UP }

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func generate() -> Dictionary:
	# Mehrere Versuche für validen Pfad
	for attempt in range(50):
		var result := _try_generate_path()
		if result["valid"]:
			print("[PathGenerator] Pfad generiert nach %d Versuchen, Länge: %d" % [attempt + 1, result["cells"].size()])
			return result
	
	# Fallback: Einfacher S-Kurven-Pfad
	print("[PathGenerator] Fallback-Pfad verwendet")
	return _generate_fallback_path()


func _try_generate_path() -> Dictionary:
	var cells: Array[Vector2i] = []
	var visited: Dictionary = {}
	
	# Startpunkt: Zufällig am linken Rand (mit Abstand zu Rändern)
	var start_y := rng.randi_range(2, MAP_HEIGHT - 3)
	var current := Vector2i(0, start_y)
	
	cells.append(current)
	visited[current] = true
	
	var last_dir := Dir.RIGHT
	var straight_count := 0
	var forced_straight := rng.randi_range(MIN_STRAIGHT, MAX_STRAIGHT)
	
	while current.x < MAP_WIDTH - 1:
		var next_dir := _choose_direction(current, last_dir, straight_count, forced_straight, visited)
		var next_cell := _move(current, next_dir)
		
		# Validierung
		if not _is_valid_cell(next_cell, visited):
			# Versuche andere Richtung
			var alternatives := _get_alternative_dirs(next_dir)
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
	var points := _cells_to_points(cells)
	
	return {
		"valid": true,
		"cells": cells,
		"points": points,
		"start_y": start_y,
		"end_y": current.y
	}


func _choose_direction(pos: Vector2i, last_dir: Dir, straight: int, forced: int, visited: Dictionary) -> Dir:
	# Müssen wir geradeaus?
	if straight < forced and last_dir == Dir.RIGHT:
		return Dir.RIGHT
	
	# Gewichtete Zufallswahl
	var weights := {
		Dir.RIGHT: 60,  # Rechts bevorzugt (Fortschritt)
		Dir.DOWN: 20,
		Dir.UP: 20
	}
	
	# Anpassungen basierend auf Position
	if pos.y <= 2:
		weights[Dir.UP] = 0
		weights[Dir.DOWN] = 35
	elif pos.y >= MAP_HEIGHT - 3:
		weights[Dir.DOWN] = 0
		weights[Dir.UP] = 35
	
	# Nicht sofort zurück
	if last_dir == Dir.UP:
		weights[Dir.DOWN] = 5
	elif last_dir == Dir.DOWN:
		weights[Dir.UP] = 5
	
	# Zu viel geradeaus? Kurve erzwingen
	if straight >= MAX_STRAIGHT and last_dir == Dir.RIGHT:
		weights[Dir.RIGHT] = 10
		weights[Dir.DOWN] = 45
		weights[Dir.UP] = 45
	
	return _weighted_random(weights)


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
		Dir.DOWN: return pos + Vector2i(0, 1)
		Dir.UP: return pos + Vector2i(0, -1)
	return pos


func _get_alternative_dirs(primary: Dir) -> Array[Dir]:
	match primary:
		Dir.RIGHT: return [Dir.DOWN, Dir.UP] as Array[Dir]
		Dir.DOWN: return [Dir.RIGHT, Dir.UP] as Array[Dir]
		Dir.UP: return [Dir.RIGHT, Dir.DOWN] as Array[Dir]
	return [Dir.RIGHT] as Array[Dir]


func _is_valid_cell(cell: Vector2i, visited: Dictionary) -> bool:
	# Innerhalb der Map?
	if cell.x < 0 or cell.x >= MAP_WIDTH:
		return false
	if cell.y < 1 or cell.y >= MAP_HEIGHT - 1:
		return false
	
	# Schon besucht?
	if visited.has(cell):
		return false
	
	# Keine diagonalen Nachbarn die besucht sind (verhindert Pfad-Kreuzungen)
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
	
	# Maximal 1 diagonaler Nachbar erlaubt
	if adjacent_visited > 1:
		return false
	
	return true


func _cells_to_points(cells: Array[Vector2i]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var half := Vector2(GRID_SIZE / 2, GRID_SIZE / 2)
	
	for cell in cells:
		points.append(Vector2(cell) * GRID_SIZE + half)
	
	# Endpunkt außerhalb der Map für Enemy-Exit
	var last_cell: Vector2i = cells[cells.size() - 1]
	points.append(Vector2(MAP_WIDTH, last_cell.y) * GRID_SIZE + half)
	
	return points


func _generate_fallback_path() -> Dictionary:
	# Einfacher S-Kurven Pfad als Fallback
	var cells: Array[Vector2i] = []
	var y := 5
	
	# Erste horizontale Linie
	for x in range(0, 8):
		cells.append(Vector2i(x, y))
	
	# Runter
	for dy in range(1, 5):
		cells.append(Vector2i(7, y + dy))
	y += 4
	
	# Zweite horizontale Linie
	for x in range(8, 16):
		cells.append(Vector2i(x, y))
	
	# Hoch
	for dy in range(1, 5):
		cells.append(Vector2i(15, y - dy))
	y -= 4
	
	# Dritte horizontale Linie
	for x in range(16, 24):
		cells.append(Vector2i(x, y))
	
	# Runter
	for dy in range(1, 4):
		cells.append(Vector2i(23, y + dy))
	y += 3
	
	# Finale horizontale Linie
	for x in range(24, MAP_WIDTH):
		cells.append(Vector2i(x, y))
	
	return {
		"valid": true,
		"cells": cells,
		"points": _cells_to_points(cells),
		"start_y": 5,
		"end_y": y
	}


# Hilfsfunktion: Seed setzen für reproduzierbare Pfade
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


# Debug: Pfad-Info ausgeben
func print_path_info(path_data: Dictionary) -> void:
	if not path_data["valid"]:
		print("[PathGenerator] Ungültiger Pfad")
		return
	
	var cells: Array = path_data["cells"]
	print("[PathGenerator] Pfad-Info:")
	print("  - Länge: %d Zellen" % cells.size())
	print("  - Start: (%d, %d)" % [cells[0].x, cells[0].y])
	print("  - Ende: (%d, %d)" % [cells[cells.size()-1].x, cells[cells.size()-1].y])
	
	# Richtungswechsel zählen
	var turns := 0
	var last_dir := Vector2i(1, 0)
	for i in range(1, cells.size()):
		var dir: Vector2i = cells[i] - cells[i-1]
		if dir != last_dir:
			turns += 1
			last_dir = dir
	print("  - Kurven: %d" % turns)
