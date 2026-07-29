# Einheitlicher Cursor fuer Menue und Spiel, mit kontextabhaengigen Varianten.
#
# Frueher war dieselbe Textur auf ARROW, POINTING_HAND, DRAG und CAN_DROP registriert.
# Ein Shape-Wechsel war dadurch unsichtbar - der Cursor sah ueberall gleich aus. Jetzt
# bekommt jeder Kontext eine eigene, aus demselben Asset eingefaerbte Variante: die
# Bildsprache bleibt gleich, der Zustand ist aber ablesbar.
#
# Verwendung:
#   Cursor.set_context(Cursor.CTX_PLACE)      # Spielfeld, in main.gd
#   btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND   # UI, via UITheme
# Controls mit eigenem `mouse_default_cursor_shape` gewinnen automatisch gegen den
# per set_context gesetzten Default - deshalb muss das HUD nichts zuruecksetzen.
extends Node

const CURSOR_PATH := "res://assets/ui/arcane_cursor.svg"
const HOTSPOT := Vector2(2, 2)

# Kontextnamen fuer Aufrufer (Strings statt Enum, damit Aufrufer keinen Typ importieren).
const CTX_DEFAULT := "default"
const CTX_HOVER_UI := "hover_ui"
const CTX_PLACE := "place"
const CTX_DRAG := "drag"
const CTX_TARGET := "target"
const CTX_INVALID := "invalid"

# Kontext -> [Godot-Cursor-Shape, Farbton]. Der Farbton wird in die Cursor-Grafik
# gemischt; `Color.WHITE` laesst sie unveraendert.
const CONTEXTS := {
	CTX_DEFAULT: {"shape": Input.CURSOR_ARROW, "tint": Color.WHITE},
	CTX_HOVER_UI: {"shape": Input.CURSOR_POINTING_HAND, "tint": Color(1.0, 0.85, 0.45)},
	CTX_PLACE: {"shape": Input.CURSOR_CAN_DROP, "tint": Color(0.55, 1.0, 0.55)},
	CTX_DRAG: {"shape": Input.CURSOR_DRAG, "tint": Color(0.6, 0.8, 1.0)},
	CTX_TARGET: {"shape": Input.CURSOR_CROSS, "tint": Color(0.85, 0.6, 1.0)},
	CTX_INVALID: {"shape": Input.CURSOR_FORBIDDEN, "tint": Color(1.0, 0.45, 0.4)}
}

# Wie stark der Farbton eingemischt wird. Hoch genug, um den Zustand zu erkennen,
# niedrig genug, dass die Cursor-Form erhalten bleibt.
const TINT_STRENGTH := 0.6

var _current_context := CTX_DEFAULT
var _base_image: Image = null


func _ready() -> void:
	_base_image = _load_base_image()
	if _base_image == null:
		return
	for ctx in CONTEXTS:
		var data: Dictionary = CONTEXTS[ctx]
		var texture := _make_variant(data["tint"])
		if texture:
			Input.set_custom_mouse_cursor(texture, data["shape"], HOTSPOT)
	set_context(CTX_DEFAULT)


# Setzt den Cursor fuer alles, was kein eigenes `mouse_default_cursor_shape` hat.
# Wiederholte Aufrufe mit demselben Kontext sind billig (pro Frame aufrufbar).
func set_context(ctx: String) -> void:
	if ctx == _current_context:
		return
	if not CONTEXTS.has(ctx):
		push_warning("[CursorManager] Unbekannter Cursor-Kontext: %s" % ctx)
		return
	_current_context = ctx
	Input.set_default_cursor_shape(CONTEXTS[ctx]["shape"])


func get_context() -> String:
	return _current_context


func _load_base_image() -> Image:
	var file := FileAccess.open(CURSOR_PATH, FileAccess.READ)
	if not file:
		push_warning("[CursorManager] Cursor-Asset konnte nicht geladen werden.")
		return null
	var image := Image.new()
	if image.load_svg_from_string(file.get_as_text()) != OK:
		push_warning("[CursorManager] Cursor-SVG ist ungültig.")
		return null
	return image


# Mischt den Farbton in die Grafik, ohne die Silhouette anzutasten: Alpha bleibt
# unveraendert, nur der Farbanteil wandert Richtung `tint`.
func _make_variant(tint: Color) -> ImageTexture:
	if _base_image == null:
		return null
	if tint == Color.WHITE:
		return ImageTexture.create_from_image(_base_image)

	var image := _base_image.duplicate() as Image
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var px := image.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			px.r = lerpf(px.r, px.r * tint.r, TINT_STRENGTH)
			px.g = lerpf(px.g, px.g * tint.g, TINT_STRENGTH)
			px.b = lerpf(px.b, px.b * tint.b, TINT_STRENGTH)
			image.set_pixel(x, y, px)
	return ImageTexture.create_from_image(image)
