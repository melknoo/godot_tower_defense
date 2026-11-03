# ground_layer.gd
extends Node2D
class_name GroundLayer

# Boden aus dem Ninja-Adventure-Pack (tools/ninja_import/build_assets.py):
# - grass_atlas.png: Grasvarianten, Spalte 0 = schlicht, Rest = Details
# - path_atlas.png:  Zeile = Wegmaterial (Erde, Schlamm, Furt, Asche, Windpass),
#                    Spalte = Quellkachel, aus deren 8x8-Vierteln der Weg entsteht
const GRASS_ATLAS_PATH := "res://assets/tiles/grass_atlas.png"
const PATH_ATLAS_PATH := "res://assets/tiles/path_atlas.png"
const ART_TILE := 16
const GRASS_DETAIL_CHANCE := 0.26

# Spalten im Pfad-Atlas (Reihenfolge wie PATH_SOURCES im Build-Skript)
const SRC_ISO := 0      # Einzelfeld: vier Aussenecken
const SRC_HMID := 1     # waagrecht: Ober-/Unterkante
const SRC_VMID := 2     # senkrecht: linke/rechte Kante
const SRC_INNER_BR := 4
const SRC_INNER_BL := 5
const SRC_INNER_TR := 6
const SRC_INNER_TL := 7
const MATERIAL_ROWS := {"": 0, "dirt": 0, "mud": 1, "ford": 2, "ash": 3, "windpass": 4}

const CONN_L := 1
const CONN_R := 2
const CONN_U := 4
const CONN_D := 8

@export var grid_size: int = 64
@export var map_width: int = 12
@export var map_height: int = 8

var path_cells: Array[Vector2i] = []
var path_terrain: Array = []   # parallel zu path_cells; "" = normaler Erdweg
var decoration_manager: DecorationManager
var ground_sprite: Sprite2D
var visual_seed := 0


func _ready() -> void:
	_setup_decoration_manager()


func _setup_decoration_manager() -> void:
	decoration_manager = DecorationManager.new()
	decoration_manager.name = "DecorationManager"
	add_child(decoration_manager)


func setup(cells: Array[Vector2i], terrain: Array = []) -> void:
	path_cells = cells
	path_terrain = terrain
	_draw_ground()
	_place_decorations()


# Die ganze Karte wird einmal als 16-px-Bild komponiert und x4 angezeigt: ein Sprite
# statt hunderter, und Gras, Weg und Zonen liegen garantiert im selben Pixelraster.
func _draw_ground() -> void:
	if is_instance_valid(ground_sprite):
		ground_sprite.queue_free()
		ground_sprite = null
	var grass_img := _load_image(GRASS_ATLAS_PATH)
	var path_img := _load_image(PATH_ATLAS_PATH)
	if grass_img == null or path_img == null:
		_create_fallback_background()
		return

	var img := Image.create(map_width * ART_TILE, map_height * ART_TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed + 7919
	var grass_variants := grass_img.get_width() / ART_TILE
	for y in range(map_height):
		for x in range(map_width):
			var gi := 0
			if grass_variants > 1 and rng.randf() < GRASS_DETAIL_CHANCE:
				gi = rng.randi_range(1, grass_variants - 1)
			img.blit_rect(grass_img, Rect2i(gi * ART_TILE, 0, ART_TILE, ART_TILE), Vector2i(x, y) * ART_TILE)

	var connections := _path_connections()
	for i in range(path_cells.size()):
		var mat_row: int = MATERIAL_ROWS.get(get_terrain_at(i), 0)
		_compose_path_cell(img, path_img, path_cells[i], connections[i], mat_row)

	ground_sprite = Sprite2D.new()
	ground_sprite.name = "Ground"
	ground_sprite.texture = ImageTexture.create_from_image(img)
	ground_sprite.centered = false
	var s := float(grid_size) / ART_TILE
	ground_sprite.scale = Vector2(s, s)
	ground_sprite.z_index = -100
	add_child(ground_sprite)
	print("[GroundLayer] Boden komponiert: %dx%d Zellen, %d Wegfelder" % [map_width, map_height, path_cells.size()])


func get_terrain_at(index: int) -> String:
	if index < 0 or index >= path_terrain.size():
		return ""
	return String(path_terrain[index])


func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		push_error("[GroundLayer] Textur nicht gefunden: %s" % path)
		return null
	# Die Atlanten sind als "Image" importiert (.import: importer="image"): so liegt das
	# Bild im RAM vor. Texture2D.get_image() muesste im Browser (GL Compatibility) erst
	# von der GPU zurueckgelesen werden.
	var res = load(path)
	var image: Image = null
	if res is Image:
		image = (res as Image).duplicate()
	elif res is Texture2D:
		image = (res as Texture2D).get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


# Jede Wegzelle entsteht aus vier 8x8-Vierteln. Pro Viertel entscheiden die zwei
# angrenzenden Seiten: keine offen = Aussenecke, eine offen = Kante, beide = Innenecke.
# Verbindungen kommen aus der Pfad-Reihenfolge, nicht aus blosser Nachbarschaft.
func _compose_path_cell(img: Image, atlas: Image, cell: Vector2i, conn: int, mat_row: int) -> void:
	var half := ART_TILE / 2
	var inner := [SRC_INNER_TL, SRC_INNER_TR, SRC_INNER_BL, SRC_INNER_BR]
	for q in range(4):
		var qx := q % 2
		var qy := q / 2
		var has_h := (conn & (CONN_R if qx == 1 else CONN_L)) != 0
		var has_v := (conn & (CONN_D if qy == 1 else CONN_U)) != 0
		var src := SRC_ISO
		if has_h and has_v:
			src = inner[q]
		elif has_h:
			src = SRC_HMID
		elif has_v:
			src = SRC_VMID
		var from := Rect2i(src * ART_TILE + qx * half, mat_row * ART_TILE + qy * half, half, half)
		img.blit_rect(atlas, from, cell * ART_TILE + Vector2i(qx * half, qy * half))


func _path_connections() -> Array[int]:
	var result: Array[int] = []
	for i in range(path_cells.size()):
		var cell := path_cells[i]
		var mask := 0
		mask |= _dir_bit(path_cells[i - 1] - cell) if i > 0 else _edge_bit(cell)
		mask |= _dir_bit(path_cells[i + 1] - cell) if i + 1 < path_cells.size() else _edge_bit(cell)
		result.append(mask)
	return result


func _dir_bit(d: Vector2i) -> int:
	if d == Vector2i.LEFT:
		return CONN_L
	if d == Vector2i.RIGHT:
		return CONN_R
	if d == Vector2i.UP:
		return CONN_U
	if d == Vector2i.DOWN:
		return CONN_D
	return 0


# Start- und Endfeld oeffnen sich zum naechsten Kartenrand (Spawn bzw. Ausgang)
func _edge_bit(cell: Vector2i) -> int:
	var dists := {
		CONN_L: cell.x, CONN_R: map_width - 1 - cell.x,
		CONN_U: cell.y, CONN_D: map_height - 1 - cell.y,
	}
	var best := CONN_L
	for bit in dists:
		if dists[bit] < dists[best]:
			best = bit
	return best


func _create_fallback_background() -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(map_width * grid_size, map_height * grid_size)
	rect.color = Color(0.3, 0.5, 0.3)
	rect.z_index = -100
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
