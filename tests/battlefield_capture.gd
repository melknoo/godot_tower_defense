extends Node

## Rendert das Spielfeld mit allen Turm- und Gegnertypen fuer die visuelle Pruefung
## der Pixelart (einheitliche Dichte, Sockel, Wegzonen, Freund/Feind-Lesbarkeit).
## Aufruf:
##   godot --path . res://tests/battlefield_capture.tscn
## Ergebnis: user://ui_audit/battlefield.png

const OUTPUT_DIR := "user://ui_audit"
const TOWER_TYPES := ["sword", "archer", "wizard", "cannon", "trapper", "aura", "farm", "city",
	"water", "fire", "earth", "air", "ice", "steam", "lava", "nature"]
const ENEMY_TYPES := ["normal", "swift", "tank", "ethereal", "brute", "burrower", "boss"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().process_frame
	await get_tree().process_frame
	var main := get_parent()

	_place_towers(main)
	_spawn_enemies(main)
	await get_tree().create_timer(0.4).timeout
	get_tree().paused = true
	await _capture("battlefield")
	get_tree().quit(0)


# Tuerme direkt instanziieren (ohne Freischalt-/Gold-Pruefung) - je einer pro Typ
# auf freie Felder direkt neben dem Weg, mit ein paar Stufen fuer die Pips.
func _place_towers(main: Node) -> void:
	var manager = main.tower_manager
	var path_cells: Array[Vector2i] = main.path_cells
	var used := {}
	var type_index := 0
	for i in range(2, path_cells.size(), 2):
		if type_index >= TOWER_TYPES.size():
			break
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var cell: Vector2i = path_cells[i] + offset
			if used.has(cell) or cell in path_cells:
				continue
			if cell.x < 0 or cell.y < 0 or cell.x >= manager.map_width or cell.y >= manager.map_height:
				continue
			var tower_type: String = TOWER_TYPES[type_index]
			var tower = manager.tower_scene.instantiate()
			tower.position = Vector2(cell) * manager.grid_size + Vector2(manager.grid_size / 2, manager.grid_size / 2)
			tower.level = type_index % 4
			tower.setup(TowerData.get_legacy_data(tower_type, tower.level), tower_type)
			manager.add_child(tower)
			manager.placed_towers[cell] = tower
			used[cell] = true
			type_index += 1
			break


func _spawn_enemies(main: Node) -> void:
	var wave_manager = main.wave_manager
	var points: Array[Vector2] = wave_manager.path_points
	var elements := ["neutral", "fire", "water", "earth", "air", "neutral", "fire"]
	for i in range(ENEMY_TYPES.size()):
		wave_manager.current_wave_element = elements[i]
		var data: Dictionary = wave_manager._create_enemy_data(ENEMY_TYPES[i], 5)
		wave_manager._spawn_enemy(data)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for i in range(enemies.size()):
		var idx := mini(4 + i * 4, points.size() - 2)
		enemies[i].position = points[idx]
		enemies[i].path_index = idx + 1


func _capture(file_stem: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := image.save_png(path)
	if error != OK:
		push_error("[Battlefield Capture] Screenshot fehlgeschlagen: %s (%s)" % [path, error])
	else:
		print("[Battlefield Capture] %s" % ProjectSettings.globalize_path(path))
