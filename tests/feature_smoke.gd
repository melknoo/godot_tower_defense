extends SceneTree

## Prueft in einer echten Main-Szene die Systeme, die sich nur im laufenden Spiel
## zeigen: Icon-Fallbacks, Turm-Platzhalter, Boss-Auftritt und Fahrplan-Panel.
## Aufruf:
##   godot --headless --path . --script res://tests/feature_smoke.gd

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout

	var item_system := root.get_node_or_null("ItemSystem")
	var icon_system := root.get_node_or_null("IconSystem")

	# --- Icon-Fallbacks ---
	var item: Dictionary = item_system._create_item_instance(
		"ember_lance", item_system.ITEMS["ember_lance"], "epic"
	)
	var fallback_tex: Texture2D = item_system.get_item_texture(item)
	_check(fallback_tex != null, "Item ohne Icon bekommt Kategorie-Fallback")
	# Der Fallback muss eine einzelne Zelle sein - frueher kam das ganze Sammelicon.
	_check(
		fallback_tex != null and fallback_tex.get_size() == Vector2(
			item_system.SHEET_CELL_SIZE, item_system.SHEET_CELL_SIZE
		),
		"Kategorie-Fallback ist eine einzelne 16x16-Zelle"
	)
	var other: Dictionary = item_system._create_item_instance(
		"first_strike", item_system.ITEMS["first_strike"], "epic"
	)
	_check(
		item_system.get_item_texture(other) != fallback_tex,
		"Zwei Items derselben Kategorie teilen sich nicht dasselbe Fallback-Icon"
	)
	var sharp: Dictionary = item_system._create_item_instance(
		"sharp_blade", item_system.ITEMS["sharp_blade"], "rare"
	)
	_check(item_system.get_item_texture(sharp) != null, "Vorhandenes Item-Icon laedt")
	_check(icon_system.get_texture("core_fire") != null, "core_fire faellt auf core zurueck")
	_check(icon_system.get_texture("warning") != null, "warning faellt auf damage zurueck")
	_check(not icon_system.bb("core_ice").begins_with("[?]"), "bb() liefert kein [?] mehr")

	# --- Turm-Platzhalter ---
	var tower_scene: PackedScene = load("res://tower.tscn")
	for tower_type in ["cannon", "wizard", "trapper", "aura"]:
		var tower: Node2D = tower_scene.instantiate()
		main.add_child(tower)
		tower.setup(root.get_node("TowerData").get_legacy_data(tower_type, 0), tower_type)
		await process_frame
		var turret: Node2D = tower.turret
		var child_count: int = turret.get_child_count() if turret else -1
		_check(child_count >= 4,
			"%s bekommt einen Platzhalter mit Sockel+Glyphe (Kinder: %d)" % [tower_type, child_count])
		tower.queue_free()

	# --- Boss-Auftritt ---
	var hud = main.get_node("UI/HUD")
	_check(hud.boss_bar_root != null, "Boss-Leiste existiert")
	_check(not hud.boss_bar_root.visible, "Boss-Leiste startet versteckt")

	var enemy: Node2D = load("res://enemy.tscn").instantiate()
	main.add_child(enemy)
	var boss_path: Array[Vector2] = [Vector2(100, 100), Vector2(400, 100)]
	enemy.setup_extended(boss_path, {
		"type": "boss", "health": 1200, "speed": 45.0,
		"reward": 50, "scale": 1.0, "element": "fire"
	})
	await process_frame
	await process_frame
	_check(hud.boss_bar_root.visible, "Boss-Spawn zeigt die Leiste")
	_check(is_equal_approx(hud.boss_bar.value, 1.0), "Boss-Leiste startet voll")
	enemy.health = 600
	await process_frame
	_check(is_equal_approx(hud.boss_bar.value, 0.5), "Boss-Leiste folgt der HP")
	enemy.free()
	await process_frame
	await process_frame
	_check(not hud.boss_bar_root.visible, "Boss-Leiste verschwindet mit dem Boss")

	# --- Fahrplan ---
	var schedule_ui = main.run_schedule_ui
	_check(schedule_ui != null, "Fahrplan-Panel existiert")
	schedule_ui.show_panel()
	await process_frame
	_check(schedule_ui.visible, "Fahrplan oeffnet sich")
	_check(schedule_ui.rows_container.get_child_count() == schedule_ui.PREVIEW_WAVES,
		"Fahrplan zeigt %d Wellen" % schedule_ui.PREVIEW_WAVES)
	schedule_ui.hide_panel()

	# --- Kettenglied verteilt Spruenge ---
	# Der Bogen hat von Haus aus keine Ketten-Spezialisierung; das Item allein
	# muss chain_targets erhoehen.
	var chain_tower: Node2D = tower_scene.instantiate()
	main.add_child(chain_tower)
	chain_tower.setup(root.get_node("TowerData").get_legacy_data("archer", 0), "archer")
	await process_frame
	_check(chain_tower.chain_targets == 0, "Bogen startet ohne Kettenspruenge")
	var chain_item: Dictionary = item_system._create_item_instance(
		"chain_link", item_system.ITEMS["chain_link"], "rare"
	)
	chain_item["uid"] = "test_chain"
	item_system.collect_item(chain_item)
	item_system.equip_item(chain_tower, "test_chain", 0)
	await process_frame
	_check(chain_tower.chain_targets > 0, "Kettenglied erhoeht die Sprungzahl")
	chain_tower.queue_free()

	# --- Stadt nimmt Farmen auf, ohne Supply zu verlieren ---
	var game_state := root.get_node("GameState")
	var tower_data := root.get_node("TowerData")
	var tower_manager = main.tower_manager
	game_state.reset()
	game_state.gold = 9999
	var farm_positions: Array[Vector2i] = []
	for cell in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		if tower_manager.place_tower(cell, "farm") != null:
			farm_positions.append(cell)
	await process_frame
	_check(farm_positions.size() == 3, "Drei Farmen platziert")

	var supply_before: int = game_state.supply_max
	_check(tower_data.is_tower_available("city"), "Stadt ab Supply-Schwelle verfuegbar")
	var city_pos := Vector2i(6, 2)
	var city: Node2D = tower_manager.place_tower(city_pos, "city")
	await process_frame
	_check(city != null, "Stadt platziert")
	_check(game_state.supply_max == supply_before, "Leere Stadt aendert das Supply nicht")

	var absorbed: int = tower_manager.absorb_farms(city_pos)
	await process_frame
	_check(absorbed == 3, "Stadt nimmt alle drei Farmen auf")
	_check(tower_manager.count_free_farms() == 0, "Keine Farm mehr auf dem Feld")
	_check(game_state.supply_max == supply_before, "Supply bleibt nach dem Aufnehmen gleich")

	tower_manager.sell_tower(city_pos)
	await process_frame
	_check(game_state.supply_max == game_state.STARTING_MAX_SUPPLY + game_state.archive_supply_bonus,
		"Verkauf der Stadt nimmt das gespeicherte Supply mit")

	# --- Items ueberleben den Run nicht ---
	item_system.collect_item(sharp)
	_check(item_system.get_inventory().size() > 0, "Item liegt im Inventar")
	root.get_node("GameState").reset()
	_check(item_system.get_inventory().is_empty(), "Run-Reset leert das Inventar")

	if failed:
		push_error("[TEST] Feature-Check fehlgeschlagen")
		quit(1)
	else:
		print("[TEST] Feature-Check bestanden")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		push_error("  FAIL %s" % label)
		failed = true
