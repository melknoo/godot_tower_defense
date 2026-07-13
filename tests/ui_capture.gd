extends Node

## Rendert zentrale UI-Zustaende des echten Spiels fuer visuelle Regressionstests.
## Aufruf:
##   godot --path . res://tests/ui_capture.tscn

const OUTPUT_DIR := "user://ui_audit"
var failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.75).timeout

	var main := get_parent()
	if not main:
		push_error("[UI Capture] Main-Szene konnte nicht geladen werden")
		get_tree().quit(1)
		return
	_assert_ui(main.item_inventory_ui.panel.get_theme_stylebox("panel") is StyleBoxTexture, "Inventar nutzt ein Panel-Asset")
	_assert_ui(main.element_unlock_ui.panel.get_theme_stylebox("panel") is StyleBoxTexture, "Element-Kerne nutzen ein Panel-Asset")
	_assert_ui(main.upgrade_overview_ui.panel.get_theme_stylebox("panel") is StyleBoxTexture, "Aktive Upgrades nutzen ein Panel-Asset")
	var ability_background := main.ability_bar.get_child(0) as PanelContainer
	_assert_ui(ability_background != null and ability_background.get_theme_stylebox("panel") is StyleBoxTexture, "Ability-Bar nutzt ein Panel-Asset")
	_assert_ui(main.hud.inventory_button.get_theme_constant("icon_max_width") == 26, "Inventar-Icon ist begrenzt")
	_assert_ui(main.hud.cores_button.get_theme_constant("icon_max_width") == 30, "Element-Icon ist begrenzt")
	_assert_ui(main.hud.upgrades_button.get_theme_constant("icon_max_width") == 26, "Upgrade-Icon ist begrenzt")
	_assert_ui(main.hud.research_button.custom_minimum_size.y >= 38, "Archiv-Button hat genug Asset-Hoehe")

	await _capture("01_gameplay")

	# Kontrollierter Tower-Zustand: genug Ressourcen, Bogen und Feuer freigeschaltet.
	GameState.gold = 10_000
	GameState.supply_max = 20
	ProgressionSystem.run_tower_unlocks["archer"] = true
	TowerData.element_levels["fire"] = 1
	main.tower_shop._create_tower_buttons()

	var tower_pos := _find_free_cell(main.tower_manager, "archer")
	if tower_pos.x >= 0:
		var tower: Node2D = main.tower_manager.place_tower(tower_pos, "archer")
		if tower:
			main.tower_info.show_tower(tower, tower_pos)
			await get_tree().process_frame
			_assert_ui("Schaden:" in main.tower_info.stats_label.text, "Tower-Stats sind sichtbar")
			_assert_ui(
				"Aktuelle Tower-Stats:" in main.tower_info.stats_label.tooltip_text,
				"Tower-Stat-Tooltip ist befuellt"
			)
			var has_engrave_icon := false
			for child in main.tower_info.engrave_container.get_children():
				if child is Button and child.icon:
					has_engrave_icon = true
					break
			_assert_ui(has_engrave_icon, "Element-Gravur besitzt ein Icon")
			await _capture("02_tower_info")
			Input.warp_mouse(main.tower_info.stats_label.global_position + Vector2(90, 20))
			await get_tree().create_timer(0.8).timeout
			await _capture("02b_tower_stats_tooltip")
	else:
		push_warning("[UI Capture] Kein freies Feld fuer Tower-Info gefunden")

	main.tower_info.hide_panel()
	main.meta_progression_ui.show_panel()
	await get_tree().create_timer(0.25, true).timeout
	await _capture("03_archive")
	main.meta_progression_ui.hide_panel()

	GameState.element_cores = 1
	main.element_unlock_ui.show_panel()
	await get_tree().create_timer(0.25, true).timeout
	await _capture("04_elements")
	main.element_unlock_ui.hide_panel()

	main.wave_upgrade_ui.show_upgrades(1)
	await get_tree().create_timer(0.25, true).timeout
	await _capture("05_wave_upgrades")
	main.wave_upgrade_ui.visible = false
	get_tree().paused = false

	var item: Dictionary = ItemSystem._create_item_instance(
		"sharp_blade", ItemSystem.ITEMS["sharp_blade"], "rare"
	)
	ItemSystem.collect_item(item)
	main.item_inventory_ui.show_panel()
	main.item_inventory_ui._show_item_detail(item)
	await get_tree().process_frame
	var first_slot: PanelContainer = main.item_inventory_ui.grid_container.get_child(0)
	main.item_inventory_ui._position_detail_panel_at_slot(first_slot)
	await get_tree().create_timer(0.55, true).timeout
	await _capture("06_inventory")
	main.item_inventory_ui.visible = false

	UpgradeSystem.activate_upgrade("global_damage")
	main.upgrade_overview_ui.show_panel()
	await get_tree().create_timer(0.25, true).timeout
	await _capture("07_upgrade_overview")
	main.upgrade_overview_ui.visible = false

	main.ability_upgrade_ui.show_panel()
	await get_tree().create_timer(0.25, true).timeout
	await _capture("08_ability_upgrades")
	main.ability_upgrade_ui.visible = false
	get_tree().paused = false

	await _press_escape()
	_assert_ui(main.pause_menu.visible, "Pausemenue ist sichtbar")
	_assert_ui(get_tree().paused, "Pausemenue pausiert den Spielbaum")
	await _capture("09_pause_menu")
	main.pause_menu._on_options_pressed()
	await get_tree().create_timer(0.2, true).timeout
	_assert_ui(main.pause_menu.options_view.visible, "Optionen sind im Pausemenue erreichbar")
	await _capture("10_pause_options")
	await _press_escape()
	_assert_ui(main.pause_menu.main_view.visible, "Esc fuehrt aus Optionen ins Pausemenue zurueck")
	main.pause_menu._on_main_menu_pressed()
	await get_tree().create_timer(0.2, true).timeout
	_assert_ui(main.pause_menu.confirm_view.visible, "Hauptmenue verlangt eine Run-Bestaetigung")
	_assert_ui(get_tree().paused, "Bestaetigungsdialog haelt den Run pausiert")
	await _capture("11_leave_confirmation")
	await _press_escape()
	_assert_ui(main.pause_menu.main_view.visible, "Esc bricht das Verlassen des Runs ab")
	await _press_escape()
	_assert_ui(not main.pause_menu.visible, "Esc setzt das Spiel fort")
	_assert_ui(not get_tree().paused, "Fortsetzen hebt die Pause auf")

	main.hud.show_game_over({
		"run_essence": 18,
		"run_xp": 42,
		"kills": 86,
		"max_streak": 17,
		"account_level": 2,
		"essence_total": 31
	})
	await get_tree().create_timer(0.35, true).timeout
	await _capture("12_run_summary")

	get_tree().paused = false
	print("[UI Capture] Screenshots gespeichert: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	get_tree().quit(1 if failed else 0)


func _find_free_cell(manager: TowerManager, tower_type: String) -> Vector2i:
	for y in range(manager.map_height):
		for x in range(manager.map_width):
			var cell := Vector2i(x, y)
			if manager.can_place_at(cell, tower_type):
				return cell
	return Vector2i(-1, -1)


func _capture(file_stem: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := image.save_png(path)
	if error != OK:
		push_error("[UI Capture] Screenshot fehlgeschlagen: %s (%s)" % [path, error])
	else:
		print("[UI Capture] %s" % path)


func _press_escape() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	release.physical_keycode = KEY_ESCAPE
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _assert_ui(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("[UI Capture] Assertion fehlgeschlagen: %s" % label)
