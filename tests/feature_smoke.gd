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
	_check(item_system.get_item_texture(item) != null, "Item ohne Icon bekommt Kategorie-Fallback")
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
