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
	# Die Panel-Buttons liegen ueber der HUD-Leiste. Auf Leistenhoehe verdeckt sie
	# der Tower-Shop, sobald genug Tuerme freigeschaltet sind.
	for button_entry in [
		["Inventar", main.hud.inventory_button], ["Kerne", main.hud.cores_button],
		["Upgrades", main.hud.upgrades_button], ["Synergien", main.hud.synergy_button],
		["Fahrplan", main.hud.schedule_button], ["Schmiede", main.hud.forge_button],
		["Statistik", main.hud.tower_stats_button],
	]:
		var button_rect: Rect2 = (button_entry[1] as Button).get_global_rect()
		_assert_ui(
			not button_rect.intersects(main.tower_shop.get_global_rect()),
			"%s-Button wird nicht vom Tower-Shop verdeckt" % button_entry[0]
		)
		_assert_ui(
			not button_rect.intersects(main.ability_bar.get_global_rect()),
			"%s-Button ueberlagert die Ability-Bar nicht" % button_entry[0]
		)

	_assert_ui(main.hud.wave_status_panel != null, "Wellenstatus besitzt ein gemeinsames Panel")
	_assert_ui(
		main.hud.wave_status_panel.get_global_rect().encloses(main.hud.start_button.get_global_rect()),
		"Wellenstart bleibt innerhalb des Statuspanels"
	)
	_assert_ui(
		not main.hud.start_button.get_global_rect().intersects(main.hud.wave_preview_label.get_global_rect()),
		"Wellenstart und Vorschau ueberlagern sich nicht"
	)
	_assert_ui("ELEMENT" in main.hud.wave_advice_label.text, "Element-Hinweis ist dauerhaft sichtbar")
	_assert_ui("TURM-TIPP" in main.hud.wave_advice_label.text, "Turm-Kontering ist dauerhaft sichtbar")
	_assert_ui(not main.hud.wave_element_area.visible, "Alte doppelte Elementzeile ist ausgeblendet")
	var wave_panel_style := main.hud.wave_status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert_ui(
		wave_panel_style != null and wave_panel_style.border_color.is_equal_approx(Color(0.4, 0.35, 0.3)),
		"Wellenstatus nutzt den braunen Rahmen der unteren HUD-Leiste"
	)
	_assert_ui(main.hud.wave_preview_label.size.x >= 500.0, "Wellenvorschau hat ausreichend Textbreite")
	_assert_ui(
		main.hud.wave_status_panel.get_global_rect().encloses(main.hud.wave_events_label.get_global_rect()),
		"Danach-Zeile bleibt vollstaendig innerhalb des Wellenstatus"
	)
	var wave_panel_rect: Rect2 = main.hud.wave_status_panel.get_global_rect()
	var viewport_bottom: float = main.get_viewport_rect().size.y
	_assert_ui(viewport_bottom - wave_panel_rect.end.y >= 8.0, "Wellenstatus hat sicheren Abstand zum unteren Fensterrand")
	_assert_ui(
		absf(wave_panel_rect.position.y - main.tower_shop.get_global_rect().position.y) <= 1.0,
		"Wellenstatus und Tower-Shop sind oben ausgerichtet"
	)

	await _capture("01_gameplay")

	GameState.current_wave = 1
	GameState.wave_active = true
	main.hud._on_wave_started(1)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_ui(main.hud.fast_forward_button.visible, "Tempo-Button ist waehrend der Welle sichtbar")
	_assert_ui(
		not main.hud.fast_forward_button.get_global_rect().intersects(main.hud.current_wave_info_label.get_global_rect()),
		"Tempo-Button und aktuelle Welle ueberlagern sich nicht"
	)
	_assert_ui(
		main.hud.wave_events_label.get_content_height() <= main.hud.wave_events_label.size.y,
		"Danach-Inhalt passt vollstaendig in seine Textzeile"
	)
	await _capture("01b_wave_hud_active")
	GameState.wave_active = false
	GameState.current_wave = 0
	main.hud._on_wave_completed(1)
	main.hud.update_all()

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
			_assert_ui(tower.get_range_cells() >= 1, "Tower-Reichweite ist in Rasterfeldern verfuegbar")
			_assert_ui(tower.range_visual.get_child_count() > 0, "Tower zeigt ein quadratisches Reichweitenraster")
			_assert_ui(tower.level_indicator.get_child_count() == 1, "Tower-Level ist direkt am Tower sichtbar")
			_assert_ui("Schaden:" in main.tower_info.stats_label.text, "Tower-Stats sind sichtbar")
			_assert_ui("Felder" in main.tower_info.stats_label.text, "Tower-Info zeigt Reichweite als Felder")
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

	# Aura-Turm: Buff-Auswahl und Statuszeile danach. Die Statuszeile hat das Panel
	# frueher in die Breite gezogen, deshalb bleibt sie als Regressionsfall drin.
	ProgressionSystem.run_tower_unlocks["aura"] = true
	main.tower_shop._create_tower_buttons()
	var aura_pos := _find_free_cell(main.tower_manager, "aura")
	if aura_pos.x >= 0:
		var aura_tower: Node2D = main.tower_manager.place_tower(aura_pos, "aura")
		if aura_tower:
			main.tower_info.show_tower(aura_tower, aura_pos)
			await get_tree().process_frame
			var width_before_choice: float = main.tower_info.size.x
			_assert_ui(main.tower_info.engrave_container.visible, "Aura-Turm bietet die Buff-Auswahl an")
			await _capture("02c_aura_choice")

			main.tower_info._on_aura_buff_button_pressed("fire_rate")
			await get_tree().process_frame
			await get_tree().process_frame
			_assert_ui(aura_tower.aura_buff_type == "fire_rate", "Aura-Buff ist gesetzt")
			_assert_ui(
				"Tempo" in main.tower_info.tower_name_label.text,
				"Aura-Turm zeigt den gravierten Buff im Titel"
			)
			_assert_ui(
				"Tempo" in main.tower_info.stats_label.text,
				"Aura-Turm zeigt den Buff in den Stats"
			)
			_assert_ui(
				main.tower_info.size.x <= width_before_choice + 8.0,
				"Statuszeile zieht das Aura-Panel nicht in die Breite (%.0f -> %.0f)" % [
					width_before_choice, main.tower_info.size.x
				]
			)
			await _capture("02d_aura_engraved")
			main.tower_info.hide_panel()
			main.tower_manager.sell_tower(aura_pos)

	# Glueh-Aura: macht die Upgrade-Stufe auf dem Spielfeld ablesbar.
	var glow_pos := _find_free_cell(main.tower_manager, "archer")
	if glow_pos.x >= 0:
		var glow_tower: Node2D = main.tower_manager.place_tower(glow_pos, "archer")
		if glow_tower:
			_assert_ui(not glow_tower.level_glow.visible, "Stufe 1 leuchtet noch nicht")
			while main.tower_manager.upgrade_tower(glow_pos):
				pass
			await get_tree().process_frame
			_assert_ui(glow_tower.level == TowerData.MAX_LEVEL, "Turm auf Maximalstufe gebracht")
			_assert_ui(glow_tower.level_glow.visible and glow_tower.level_glow.get_child_count() > 0,
				"Maximalstufe zeigt eine Glueh-Aura")
			await get_tree().create_timer(0.3, true).timeout
			await _capture("02e_level_glow")
			main.tower_manager.sell_tower(glow_pos)

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
	await get_tree().process_frame
	_assert_ui(main.hud.item_toast_container.get_child_count() == 1, "Item-Aufnahme erzeugt einen HUD-Toast")
	await get_tree().create_timer(0.2, true).timeout
	await _capture("05b_item_toast")
	main.item_inventory_ui.show_panel()
	main.item_inventory_ui._show_item_detail(item)
	await get_tree().process_frame
	var first_slot: PanelContainer = main.item_inventory_ui.grid_container.get_child(0)
	main.item_inventory_ui._position_detail_panel_at_slot(first_slot)
	await get_tree().create_timer(0.55, true).timeout
	await _capture("06_inventory")

	# Equip-Kontext: kompatible Items behalten ihren Raritaetsrahmen, sie werden
	# nur dicker umrandet. Frueher wurden sie pauschal gruen eingefaerbt.
	var equip_pos := _find_free_cell(main.tower_manager, "archer")
	if equip_pos.x >= 0:
		var equip_tower: Node2D = main.tower_manager.place_tower(equip_pos, "archer")
		if equip_tower:
			main.item_inventory_ui.set_filter_tower(equip_tower)
			await get_tree().process_frame
			var equip_slot: PanelContainer = main.item_inventory_ui.grid_container.get_child(0)
			var slot_style: StyleBoxFlat = equip_slot.get_meta("style")
			var slot_item: Dictionary = equip_slot.get_meta("item")
			var slot_rarity: Color = slot_item.get("color", Color.WHITE)
			_assert_ui(
				slot_style.border_color.is_equal_approx(slot_rarity.darkened(0.3)),
				"Kompatibles Item behaelt im Equip-Kontext seinen Raritaetsrahmen"
			)
			_assert_ui(slot_style.border_width_left == 3, "Kompatibles Item ist dicker umrandet")
			await _capture("06d_inventory_equip_context")
			main.item_inventory_ui.set_filter_tower(null)
			main.tower_manager.sell_tower(equip_pos)

	main.item_inventory_ui.visible = false

	# Schmiede: zwei Items derselben Vorlage ergeben ein garantiertes Ergebnis.
	var forge_a: Dictionary = ItemSystem._create_item_instance(
		"swift_boots", ItemSystem.ITEMS["swift_boots"], "uncommon"
	)
	forge_a["uid"] = "capture_forge_a"
	var forge_b: Dictionary = ItemSystem._create_item_instance(
		"swift_boots", ItemSystem.ITEMS["swift_boots"], "uncommon"
	)
	forge_b["uid"] = "capture_forge_b"
	ItemSystem.collect_item(forge_a)
	ItemSystem.collect_item(forge_b)
	main.hud._update_forge_button()
	await get_tree().process_frame
	_assert_ui(main.hud.forge_button.visible, "Schmiede-Button erscheint mit kombinierbarem Paar")
	main.item_combine_ui.show_panel(5)
	main.item_combine_ui._toggle_selection(forge_a)
	main.item_combine_ui._toggle_selection(forge_b)
	await get_tree().create_timer(0.35, true).timeout
	_assert_ui(not main.item_combine_ui.combine_button.disabled, "Identisches Paar ist kombinierbar")
	_assert_ui("Flinke Stiefel" in main.item_combine_ui.result_label.text,
		"Vorschau nennt das konkrete Ergebnis-Item")
	_assert_ui("garantiert" in main.item_combine_ui.result_label.text,
		"Identisches Paar wird als garantiert ausgewiesen")
	await _capture("06b_forge")
	main.item_combine_ui.visible = false
	get_tree().paused = false

	# Turm-Statistik: gebuendelte Kampfwerte statt Einzelanzeige pro Turm.
	main.tower_stats_ui.show_panel()
	await get_tree().create_timer(0.25, true).timeout
	_assert_ui(main.tower_stats_ui.visible, "Turm-Statistik oeffnet sich")
	await _capture("06c_tower_stats")
	main.tower_stats_ui.visible = false

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
	main.pause_menu._on_quit_pressed()
	await get_tree().create_timer(0.2, true).timeout
	_assert_ui(main.pause_menu.confirm_view.visible, "Spiel beenden verlangt eine Sicherheitsabfrage")
	_assert_ui(main.pause_menu._pending_exit_action == "quit", "Sicherheitsabfrage kennt das Beenden-Ziel")
	_assert_ui("SPIEL BEENDEN" in main.pause_menu.confirm_title_label.text, "Beenden-Dialog hat den passenden Titel")
	await _capture("12_quit_confirmation")
	await _press_escape()
	_assert_ui(main.pause_menu.main_view.visible, "Esc bricht Spiel beenden ab")
	await _press_escape()
	_assert_ui(not main.pause_menu.visible, "Esc setzt das Spiel fort")
	_assert_ui(not get_tree().paused, "Fortsetzen hebt die Pause auf")

	# Entscheidung nach der letzten regulaeren Welle
	main.hud.show_final_wave_choice(func(): pass, func(): pass)
	await get_tree().create_timer(0.35, true).timeout
	_assert_ui(get_tree().paused, "Finale-Entscheidung haelt den Run pausiert")
	await _capture("12b_final_wave_choice")
	var choice_layer: Node = main.hud.get_node_or_null("FinalWaveChoiceLayer")
	if choice_layer:
		choice_layer.free()
	get_tree().paused = false

	var summary := {
		"run_essence": 18,
		"run_xp": 42,
		"kills": 86,
		"max_streak": 17,
		"account_level": 2,
		"essence_total": 31
	}
	main.hud.show_run_summary(summary, true)
	await get_tree().create_timer(0.35, true).timeout
	await _capture("12c_victory_summary")
	var victory_layer: Node = main.hud.get_node_or_null("RunSummaryLayer")
	if victory_layer:
		victory_layer.free()

	main.hud.show_game_over(summary)
	await get_tree().create_timer(0.35, true).timeout
	await _capture("13_run_summary")

	get_tree().paused = false
	print("[UI Capture] Screenshots gespeichert: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	get_tree().quit(1 if failed else 0)


func _find_free_cell(manager: TowerManager, tower_type: String) -> Vector2i:
	# Erst einen gut sichtbaren Bereich waehlen, damit Range und Level im Capture pruefbar bleiben.
	for y in range(2, manager.map_height):
		for x in range(8, manager.map_width):
			var visible_cell := Vector2i(x, y)
			if manager.can_place_at(visible_cell, tower_type):
				return visible_cell
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
