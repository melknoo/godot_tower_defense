# tilemap_slicer.gd
# Tool-Script zum Zerschneiden der Tilemap in einzelne Tiles
@tool
extends EditorScript

const TILEMAP_PATH := "res://assets/tiles/tilemap.png"
const OUTPUT_DIR := "res://assets/tiles/sliced/"
const TILE_SIZE := 16
const COLUMNS := 40
const ROWS := 16  # 256 / 16 = 16


func _run() -> void:
	print("[TilemapSlicer] Starte Tilemap-Zerschneidung...")
	
	# Prüfe ob Tilemap existiert
	if not ResourceLoader.exists(TILEMAP_PATH):
		push_error("[TilemapSlicer] Tilemap nicht gefunden: %s" % TILEMAP_PATH)
		return
	
	# Lade Tilemap
	var tilemap: Texture2D = load(TILEMAP_PATH)
	var image: Image = tilemap.get_image()
	
	print("[TilemapSlicer] Tilemap geladen: %dx%d" % [image.get_width(), image.get_height()])
	
	# Erstelle Output-Verzeichnis
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)
		print("[TilemapSlicer] Verzeichnis erstellt: %s" % OUTPUT_DIR)
	
	var tiles_saved := 0
	var tiles_skipped := 0
	
	# Iteriere durch alle Tiles
	for row in range(ROWS):
		for col in range(COLUMNS):
			var tile_image := _extract_tile(image, col, row)
			
			# Prüfe ob Tile leer ist (alle Pixel transparent oder schwarz)
			if _is_tile_empty(tile_image):
				tiles_skipped += 1
				continue
			
			# Speichere Tile
			var filename := "tile_%02d_%02d.png" % [col, row]
			var filepath := OUTPUT_DIR + filename
			
			var err := tile_image.save_png(filepath)
			if err == OK:
				tiles_saved += 1
			else:
				push_warning("[TilemapSlicer] Fehler beim Speichern: %s" % filepath)
	
	print("[TilemapSlicer] Fertig!")
	print("  - Gespeichert: %d Tiles" % tiles_saved)
	print("  - Übersprungen: %d leere Tiles" % tiles_skipped)
	print("  - Ausgabe: %s" % OUTPUT_DIR)


func _extract_tile(source: Image, col: int, row: int) -> Image:
	var tile := Image.create(TILE_SIZE, TILE_SIZE, false, source.get_format())
	
	var src_x := col * TILE_SIZE
	var src_y := row * TILE_SIZE
	
	# Kopiere Pixel
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var pixel := source.get_pixel(src_x + x, src_y + y)
			tile.set_pixel(x, y, pixel)
	
	return tile


func _is_tile_empty(tile: Image) -> bool:
	var transparent_threshold := 0.1  # Tiles mit < 10% Deckkraft = leer
	
	var total_alpha := 0.0
	var pixel_count := TILE_SIZE * TILE_SIZE
	
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var pixel := tile.get_pixel(x, y)
			total_alpha += pixel.a
	
	var avg_alpha := total_alpha / pixel_count
	return avg_alpha < transparent_threshold
