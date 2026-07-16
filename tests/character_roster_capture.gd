extends Node

const OUTPUT_DIR := "user://ui_audit"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout
	var menu := get_parent()
	if not menu.character_roster_ui:
		push_error("[UI Capture] CharacterRosterUI fehlt im Hauptmenue")
		get_tree().quit(1)
		return
	menu.character_roster_ui.show_panel()
	await get_tree().create_timer(0.4, true).timeout
	if not menu.character_roster_ui.visible:
		push_error("[UI Capture] Charakter-Roster ist nicht sichtbar")
		get_tree().quit(1)
		return
	if not await _save_view("16_character_roster"):
		get_tree().quit(1)
		return
	menu.character_roster_ui.hide_panel()
	await get_tree().process_frame
	get_tree().quit(0)


func _save_view(file_stem: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("[UI Capture] Roster-Screenshot fehlgeschlagen: %s" % error)
		return false
	print("[UI Capture] %s" % output_path)
	return true
