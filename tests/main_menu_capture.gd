extends Node

const OUTPUT_DIR := "user://ui_audit"
const OUTPUT_PATH := OUTPUT_DIR + "/10_main_menu.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var image := get_tree().root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("[UI Capture] Hauptmenue-Screenshot fehlgeschlagen: %s" % error)
		get_tree().quit(1)
		return
	print("[UI Capture] %s" % OUTPUT_PATH)
	get_tree().quit(0)
