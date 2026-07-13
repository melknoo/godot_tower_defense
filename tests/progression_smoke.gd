extends SceneTree

const RangeGridHelper = preload("res://autoload/range_grid.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := root.get_node_or_null("ProgressionSystem")
	var game_state := root.get_node_or_null("GameState")
	var tower_data := root.get_node_or_null("TowerData")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	if not progression or not game_state or not tower_data or not upgrade_system:
		push_error("Progression smoke test: Autoloads fehlen")
		quit(1)
		return

	var snapshot := {
		"essence": progression.essence,
		"account_level": progression.account_level,
		"account_xp": progression.account_xp,
		"total_kills": progression.total_kills,
		"highest_streak": progression.highest_streak,
		"research_levels": progression.research_levels.duplicate(true),
		"run_active": progression.run_active,
		"run_finalized": progression.run_finalized,
		"run_tower_unlocks": progression.run_tower_unlocks.duplicate(true),
		"active_upgrades": upgrade_system.active_upgrades.duplicate(true),
	}

	for research_id in progression.RESEARCH:
		progression.research_levels[research_id] = 0
	game_state.reset()
	_assert_equal(game_state.gold, 60, "Harter Start: Gold")
	_assert_equal(game_state.lives, 10, "Harter Start: Leben")
	_assert_equal(game_state.supply_max, 3, "Harter Start: Supply")
	_assert_equal(1 in game_state._get_core_reward_waves(), false, "Kein Element-Kern in Welle 1")
	_assert_equal(5 in game_state._get_core_reward_waves(), true, "Erster Element-Kern in Welle 5")

	progression.research_levels["starting_funds"] = 2
	progression.research_levels["fortification"] = 1
	progression.research_levels["logistics"] = 3
	progression.research_levels["metallurgy"] = 2
	progression.research_levels["compound_interest"] = 2

	game_state.reset()
	_assert_equal(game_state.gold, 110, "Startgold-Forschung")
	_assert_equal(game_state.lives, 12, "Leben-Forschung")
	_assert_equal(game_state.supply_max, 6, "Supply-Forschung")
	_assert_equal(game_state.get_effective_supply_max(), 6, "Effektives Archiv-Supply")
	var tower_manager_script := load("res://tower_manager.gd")
	var supply_manager = tower_manager_script.new()
	supply_manager.refresh_farm_supply_bonuses()
	_assert_equal(game_state.supply_max, 6, "Farm-Neuberechnung behaelt Archiv-Supply")
	supply_manager.free()
	upgrade_system.active_upgrades["supply_max"] = 2
	_assert_equal(game_state.get_effective_supply_max(), 10, "Run-Supply wird effektiv addiert")
	_assert_equal(game_state.get_supply_info().get("archive_bonus"), 3, "Supply-Aufschluesselung Archiv")
	_assert_equal(game_state.get_supply_info().get("run_bonus"), 4, "Supply-Aufschluesselung Run")
	_assert_close(progression.get_global_damage_bonus(), 0.08, "Schadensforschung")
	_assert_close(game_state.get_interest_rate(), 0.12, "Meta-Zinsrate")
	_assert_equal(game_state.get_max_interest(), 70, "Meta-Zinslimit")

	progression.begin_run()
	_assert_equal(tower_data.get_available_tower_types(), ["sword", "farm"], "Starttuerme")
	progression.research_levels["unlock_archer"] = 1
	_assert_equal(progression.is_tower_unlocked("archer"), false, "Unlock gilt erst im naechsten Run")
	progression.begin_run()
	_assert_equal(progression.is_tower_unlocked("archer"), true, "Permanenter Turm-Unlock")
	_assert_equal("archer" in tower_data.get_available_tower_types(), true, "Bogen im Shop")
	var result := {}
	for i in range(6):
		result = progression.register_kill("normal", 10)
	_assert_equal(progression.current_streak, 6, "Kill-Serie")
	_assert_close(float(result.get("multiplier", 0.0)), 1.1, "Serienmultiplikator")
	_assert_equal(int(result.get("gold_bonus", -1)), 1, "Serien-Goldbonus")
	_assert_equal(progression.get_research_cost("automation"), 70, "Forschungskosten")
	_assert_equal(progression.get_research_cost("unlock_archer"), -1, "Maximierter Turm-Unlock")
	_assert_equal(RangeGridHelper.get_cell_radius(80.0), 1, "Range-Raster: Nahkampf")
	_assert_equal(RangeGridHelper.contains_point(Vector2.ZERO, Vector2(96, 96), 80.0), true, "Range-Raster: Rand enthalten")
	_assert_equal(RangeGridHelper.contains_point(Vector2.ZERO, Vector2(97, 0), 80.0), false, "Range-Raster: ausserhalb")
	_assert_equal(tower_data.get_stat("sword", "damage", 2), 38, "Schwert Level 3 geglaettet")
	var enemy_script := load("res://enemy.gd")
	var swift_enemy = enemy_script.new()
	swift_enemy.enemy_type = "swift"
	swift_enemy._setup_tower_type_multipliers()
	var swift_health_wave_2 := 45 + 10 * 2
	var sword_level_2_hit := int(tower_data.get_stat("sword", "damage", 1) * swift_enemy.tower_type_multipliers["sword"])
	var sword_level_3_hit := int(tower_data.get_stat("sword", "damage", 2) * swift_enemy.tower_type_multipliers["sword"])
	_assert_equal(sword_level_2_hit < swift_health_wave_2, true, "Schwert Level 2 one-shottet Flinke nicht")
	_assert_equal(sword_level_3_hit < swift_health_wave_2, true, "Schwert Level 3 one-shottet Flinke nicht")
	swift_enemy.free()
	for tower_type in ["sword", "archer", "wizard", "cannon", "trapper", "aura"]:
		var tower_definition: Dictionary = tower_data.get_tower_data(tower_type)
		_assert_equal(tower_definition.get("damage", []).size(), tower_data.MAX_LEVEL + 1, "%s Schadensstufen" % tower_type)
		_assert_equal(tower_definition.get("range", []).size(), tower_data.MAX_LEVEL + 1, "%s Reichweitenstufen" % tower_type)
		_assert_equal(tower_definition.get("upgrade_costs", []).size(), tower_data.MAX_LEVEL, "%s Upgradekosten" % tower_type)

	progression.essence = snapshot.essence
	progression.account_level = snapshot.account_level
	progression.account_xp = snapshot.account_xp
	progression.total_kills = snapshot.total_kills
	progression.highest_streak = snapshot.highest_streak
	progression.research_levels = snapshot.research_levels
	progression.run_active = snapshot.run_active
	progression.run_finalized = snapshot.run_finalized
	progression.run_tower_unlocks = snapshot.run_tower_unlocks
	upgrade_system.active_upgrades = snapshot.active_upgrades
	progression.current_streak = 0
	progression.streak_time_left = 0.0
	progression._save_dirty = false
	if failed:
		push_error("[TEST] Progression smoke test fehlgeschlagen")
		quit(1)
	else:
		print("[TEST] Progression smoke test bestanden")
		quit(0)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("%s: erwartet %s, erhalten %s" % [label, expected, actual])
		failed = true


func _assert_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		push_error("%s: erwartet %.4f, erhalten %.4f" % [label, expected, actual])
		failed = true
