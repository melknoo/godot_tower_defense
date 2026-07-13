extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := root.get_node_or_null("ProgressionSystem")
	var game_state := root.get_node_or_null("GameState")
	var tower_data := root.get_node_or_null("TowerData")
	if not progression or not game_state or not tower_data:
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
		"run_tower_unlocks": progression.run_tower_unlocks.duplicate(true)
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

	progression.essence = snapshot.essence
	progression.account_level = snapshot.account_level
	progression.account_xp = snapshot.account_xp
	progression.total_kills = snapshot.total_kills
	progression.highest_streak = snapshot.highest_streak
	progression.research_levels = snapshot.research_levels
	progression.run_active = snapshot.run_active
	progression.run_finalized = snapshot.run_finalized
	progression.run_tower_unlocks = snapshot.run_tower_unlocks
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
