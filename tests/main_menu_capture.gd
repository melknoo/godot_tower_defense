extends Node

const OUTPUT_DIR := "user://ui_audit"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout
	if not await _save_view("13_main_menu"):
		get_tree().quit(1)
		return
	var menu := get_parent()
	var options_button := _find_button(menu, "Optionen")
	if not options_button:
		push_error("[UI Capture] Optionen-Button im Hauptmenue nicht gefunden")
		get_tree().quit(1)
		return
	await _click_button(options_button)
	await get_tree().create_timer(0.25, true).timeout
	if not menu.options_overlay.visible or not menu.options_overlay.options_view.visible:
		push_error("[UI Capture] Optionen sind vom Hauptmenue aus nicht sichtbar")
		get_tree().quit(1)
		return
	if not await _save_view("14_main_menu_options"):
		get_tree().quit(1)
		return
	menu.options_overlay.hide_menu()
	await get_tree().process_frame
	get_tree().quit(0)


func _save_view(file_stem: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("[UI Capture] Hauptmenue-Screenshot fehlgeschlagen: %s" % error)
		return false
	print("[UI Capture] %s" % output_path)
	return true


func _find_button(root: Node, label: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text.strip_edges() == label:
			return child
		var nested := _find_button(child, label)
		if nested:
			return nested
	return null


func _click_button(button: Button) -> void:
	var click_position := button.get_global_rect().get_center()
	Input.warp_mouse(click_position)
	await get_tree().process_frame
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_position
		event.global_position = click_position
		event.pressed = is_pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
