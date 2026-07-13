# Einheitlicher Cursor fuer Menue und Spiel.
extends Node

const CURSOR_PATH := "res://assets/ui/arcane_cursor.svg"
const HOTSPOT := Vector2(2, 2)


func _ready() -> void:
	var file := FileAccess.open(CURSOR_PATH, FileAccess.READ)
	if not file:
		push_warning("[CursorManager] Cursor-Asset konnte nicht geladen werden.")
		return
	var image := Image.new()
	if image.load_svg_from_string(file.get_as_text()) != OK:
		push_warning("[CursorManager] Cursor-SVG ist ungültig.")
		return
	var texture := ImageTexture.create_from_image(image)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_DRAG, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_CAN_DROP, HOTSPOT)
