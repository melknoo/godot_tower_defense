extends SceneTree

const RangeGridHelper = preload("res://autoload/range_grid.gd")
const RunSchedule = preload("res://autoload/run_schedule.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := root.get_node_or_null("ProgressionSystem")
	var game_state := root.get_node_or_null("GameState")
	var tower_data := root.get_node_or_null("TowerData")
	var upgrade_system := root.get_node_or_null("UpgradeSystem")
	var ability_system := root.get_node_or_null("AbilitySystem")
	var item_system := root.get_node_or_null("ItemSystem")
	if not progression or not game_state or not tower_data or not upgrade_system or not ability_system or not item_system:
		push_error("Progression smoke test: Autoloads fehlen")
		quit(1)
		return

	_check_item_rarities(item_system)

	var snapshot := {
		"essence": progression.essence,
		"account_level": progression.account_level,
		"account_xp": progression.account_xp,
		"total_kills": progression.total_kills,
		"best_wave": progression.best_wave,
		"highest_streak": progression.highest_streak,
		"research_levels": progression.research_levels.duplicate(true),
		"recruited_characters": progression.recruited_characters.duplicate(true),
		"run_active": progression.run_active,
		"run_finalized": progression.run_finalized,
		"run_tower_unlocks": progression.run_tower_unlocks.duplicate(true),
		"active_upgrades": upgrade_system.active_upgrades.duplicate(true),
		"selected_character": ability_system.selected_character,
	}

	for research_id in progression.RESEARCH:
		progression.research_levels[research_id] = 0
	game_state.reset()
	_assert_equal(game_state.gold, 60, "Harter Start: Gold")
	_assert_equal(game_state.lives, 10, "Harter Start: Leben")
	_assert_equal(game_state.supply_max, 3, "Harter Start: Supply")
	_assert_equal(1 in game_state._get_core_reward_waves(), false, "Kein Element-Kern in Welle 1")
	_assert_equal(3 in game_state._get_core_reward_waves(), true, "Erster Element-Kern in Welle 3")
	_assert_equal(10 in game_state._get_core_reward_waves(), true, "Element-Kern in Welle 10")

	_check_run_schedule(ability_system)

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
	# "combinations" ist keine Pro-Level-Werteliste (nur eine Liste erlaubter Kombi-Tuerme),
	# daher von der generischen Stufenanzahl-Pruefung ausgenommen.
	var non_level_array_fields := ["combinations"]
	for tower_type in ["sword", "archer", "wizard", "cannon", "trapper", "aura"]:
		var tower_definition: Dictionary = tower_data.get_tower_data(tower_type)
		for field_name in tower_definition:
			var field_value = tower_definition[field_name]
			if not (field_value is Array) or field_name in non_level_array_fields:
				continue
			# Jedes Array-Feld muss MAX_LEVEL+1 Eintraege haben (Index 0..MAX_LEVEL),
			# upgrade_costs nur MAX_LEVEL (kein Kostenaufstieg von der letzten Stufe aus).
			var expected_size: int = tower_data.MAX_LEVEL if field_name == "upgrade_costs" else tower_data.MAX_LEVEL + 1
			_assert_equal(field_value.size(), expected_size, "%s Feld '%s' Stufenanzahl" % [tower_type, field_name])

	# === Charakter-Rekrutierung & Passiven ===
	# Migration v1 -> v2: leeres recruited_characters => Basis-4 frei, Rekrutierbare gesperrt
	progression.recruited_characters = {}
	_assert_equal(ability_system.is_character_unlocked("pyromancer"), true, "Basis-Charakter frei")
	_assert_equal(ability_system.is_character_unlocked("ashweaver"), false, "Aschenweberin anfangs gesperrt")

	# Rekrutierungs-Flow Aschenweberin (500 Kills, kostenlos)
	progression.total_kills = 499
	_assert_equal(progression.can_recruit_character("ashweaver"), false, "499 Kills reichen nicht")
	progression.total_kills = 500
	_assert_equal(progression.can_recruit_character("ashweaver"), true, "500 Kills schalten frei")
	var essence_before: int = progression.essence
	_assert_equal(progression.recruit_character("ashweaver"), true, "Kostenlose Rekrutierung")
	_assert_equal(progression.essence, essence_before, "Kosten 0 lassen Aether unveraendert")
	_assert_equal(ability_system.is_character_unlocked("ashweaver"), true, "Aschenweberin rekrutiert")
	_assert_equal(progression.recruit_character("ashweaver"), false, "Doppel-Rekrutierung schlaegt fehl")

	# Kostenpflichtige Rekrutierung Gezeitenhueter (Beste Welle 10, 90 Aether)
	progression.best_wave = 10
	progression.essence = 89
	_assert_equal(progression.can_recruit_character("tidewarden"), false, "Zu wenig Aether")
	progression.essence = 90
	_assert_equal(progression.recruit_character("tidewarden"), true, "Rekrutierung mit Aether")
	_assert_equal(progression.essence, 0, "Aetherkosten abgezogen")

	# Passiven ueber den zentralen Modifier-Lookup
	ability_system.selected_character = "stormhunter"
	_assert_close(ability_system.get_effective_stat("chain_lightning", "chain_count"), 9.0, "Sturmjaeger +1 Kettensprung")
	_assert_close(ability_system.get_effective_stat("chain_lightning", "chain_range"), 172.5, "Sturmjaeger Sprungreichweite x1.15")
	ability_system.selected_character = "ashweaver"
	_assert_close(ability_system.get_passive_modifier("burn_duration_mult", 1.0), 1.2, "Aschenweberin Brenndauer x1.2")
	ability_system.selected_character = "tidewarden"
	_assert_close(ability_system.get_passive_modifier("slowed_tower_damage_mult", 1.0), 1.08, "Gezeitenhueter Slow-Bonus")
	for research_id in progression.RESEARCH:
		progression.research_levels[research_id] = 0
	ability_system.selected_character = "runewarden"
	_assert_equal(game_state.get_max_lives(), 12, "Runenwaechter +2 Startleben")
	ability_system.selected_character = "pyromancer"
	_assert_equal(game_state.get_max_lives(), 10, "Basis-Charakter ohne Lebensbonus")
	_assert_close(ability_system.get_passive_modifier("burn_duration_mult", 1.0), 1.0, "Kein Passiv-Bonus ohne Passive")

	progression.essence = snapshot.essence
	progression.account_level = snapshot.account_level
	progression.account_xp = snapshot.account_xp
	progression.total_kills = snapshot.total_kills
	progression.best_wave = snapshot.best_wave
	progression.highest_streak = snapshot.highest_streak
	progression.research_levels = snapshot.research_levels
	progression.recruited_characters = snapshot.recruited_characters
	progression.run_active = snapshot.run_active
	progression.run_finalized = snapshot.run_finalized
	progression.run_tower_unlocks = snapshot.run_tower_unlocks
	upgrade_system.active_upgrades = snapshot.active_upgrades
	ability_system.selected_character = snapshot.selected_character
	progression.current_streak = 0
	progression.streak_time_left = 0.0
	# recruit_character() hat waehrend des Tests gespeichert — echten Stand zurueckschreiben
	progression.save_progress()
	progression._save_dirty = false
	if failed:
		push_error("[TEST] Progression smoke test fehlgeschlagen")
		quit(1)
	else:
		print("[TEST] Progression smoke test bestanden")
		quit(0)


# Die Wellen-Kadenzen liegen in autoload/run_schedule.gd. HUD, Fahrplan-Panel und
# die Panel-Logik in main.gd lesen alle daraus - eine Verschiebung hier faellt sonst
# erst im Spiel auf.
func _check_run_schedule(ability_system: Node) -> void:
	var upgrade_waves: Array[int] = []
	var ability_waves: Array[int] = []
	var forge_waves: Array[int] = []
	var boss_waves: Array[int] = []
	for wave in range(1, 16):
		if RunSchedule.has_upgrade(wave):
			upgrade_waves.append(wave)
		if RunSchedule.has_ability_upgrade(wave):
			ability_waves.append(wave)
		if RunSchedule.has_item_combine(wave):
			forge_waves.append(wave)
		if RunSchedule.has_boss(wave):
			boss_waves.append(wave)

	_assert_equal(upgrade_waves, [3, 6, 9, 12, 15], "Perk-Kadenz")
	_assert_equal(ability_waves, [4, 7, 10, 13], "Ability-Upgrade-Kadenz")
	_assert_equal(forge_waves, [5, 10, 15], "Schmiede-Kadenz")
	_assert_equal(boss_waves, [5, 10, 15], "Boss-Kadenz")

	# AbilitySystem delegiert an dieselbe Quelle
	_assert_equal(ability_system.should_show_ability_upgrades(7), true, "AbilitySystem delegiert Kadenz")
	_assert_equal(ability_system.get_next_ability_upgrade_wave(8), 10, "Naechste Ability-Welle")

	# get_events liefert das wichtigste Ereignis zuerst (Boss vor dem Rest)
	var wave_10_events := RunSchedule.get_events(10)
	_assert_equal(wave_10_events.size(), 4, "Welle 10 hat vier Ereignisse")
	_assert_equal(wave_10_events[0]["id"], "boss", "Boss steht in Welle 10 vorn")
	_assert_equal(RunSchedule.get_events(1).is_empty(), true, "Welle 1 ohne Ereignis")
	_assert_equal(RunSchedule.get_upcoming(8, 3).size(), 3, "Fahrplan liefert angeforderte Laenge")

	# Welle 30 ist das regulaere Run-Ende und wird als Finale angekuendigt.
	_assert_equal(RunSchedule.is_final_wave(RunSchedule.FINAL_WAVE), true, "Welle 30 ist Finale")
	_assert_equal(RunSchedule.is_final_wave(29), false, "Welle 29 ist kein Finale")
	_assert_equal(RunSchedule.get_events(30)[0]["id"], "final", "Finale steht in Welle 30 vorn")


# Regressionstest gegen vergessene Raritaets-Tabellen: RARITY_ORDER ist die einzige
# Quelle der Wahrheit, aber RARITIES (item_system.gd) sowie RARITY_NAMES/SELL_PRICES
# (item_inventory_ui.gd) sind separate, von Hand gepflegte Tabellen - eine neue Rarität,
# die dort vergessen wird, faellt sonst nur als stiller Verkaufswert 10 oder ein
# englisches Label auf.
func _check_item_rarities(item_system: Node) -> void:
	# Die Anzeigetabellen liegen in ui/item_inventory_ui.gd. Bewusst per load() plus
	# get_script_constant_map() statt ueber den Klassennamen `ItemInventoryUI`: eine
	# direkte Referenz zieht das UI-Skript schon beim Kompilieren dieses Tests mit
	# herein, und dort sind die Autoloads (ItemSystem) noch nicht registriert - das
	# Laden des Tests scheitert dann mit "Identifier not found: ItemSystem".
	var inventory_script: GDScript = load("res://ui/item_inventory_ui.gd")
	var constants: Dictionary = inventory_script.get_script_constant_map()
	var rarity_names: Dictionary = constants.get("RARITY_NAMES", {})
	var sell_prices: Dictionary = constants.get("SELL_PRICES", {})
	_assert_equal(rarity_names.is_empty(), false, "RARITY_NAMES aus item_inventory_ui.gd gelesen")
	_assert_equal(sell_prices.is_empty(), false, "SELL_PRICES aus item_inventory_ui.gd gelesen")

	for rarity in item_system.RARITY_ORDER:
		_assert_equal(item_system.RARITIES.has(rarity), true, "Raritaet '%s' fehlt in RARITIES" % rarity)
		_assert_equal(rarity_names.has(rarity), true, "Raritaet '%s' fehlt in RARITY_NAMES" % rarity)
		_assert_equal(sell_prices.has(rarity), true, "Raritaet '%s' fehlt in SELL_PRICES" % rarity)
	_assert_equal(item_system.is_max_rarity("legendary"), true, "Legendary ist die hoechste Raritaet")


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		push_error("%s: erwartet %s, erhalten %s" % [label, expected, actual])
		failed = true


func _assert_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		push_error("%s: erwartet %.4f, erhalten %.4f" % [label, expected, actual])
		failed = true
