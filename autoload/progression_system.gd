# Persistente Incremental-Progression, die mehrere Runs miteinander verbindet.
extends Node

signal essence_changed(total: int, delta: int)
signal account_progress_changed(level: int, xp: int, xp_required: int)
signal research_changed(research_id: String, new_level: int)
signal run_progress_changed(run_essence: int, run_xp: int)
signal streak_changed(streak: int, multiplier: float, time_left: float)
signal milestone_reached(wave: int, reward: int)
signal auto_wave_changed(enabled: bool)
signal character_recruited(char_id: String)

# Der Dateiname bleibt "_v1" — Umbenennen wuerde bestehende Saves verwaisen.
const SAVE_PATH := "user://incremental_progression_v1.json"
const SAVE_VERSION := 2
const STREAK_WINDOW := 3.0
const MILESTONE_WAVES: Array[int] = [3, 5, 10, 15, 25, 40, 60, 100]

# --- Aether-Balancing ---------------------------------------------------------
# Alle Aether-Quellen liegen hier gebuendelt, damit Nachtunen ohne Formelsuche geht.
# Leitidee: Der fruehe Verlauf bleibt spuerbar belohnend, der spaete Zufluss waechst
# deutlich flacher. Deshalb sind die wellenabhaengigen Anteile gedeckelt und die
# Exponenten liegen nahe an linear.
const ESSENCE_STREAK_STEP := 10          # Jeder n-te Kill einer Serie zahlt Aether aus.
const ESSENCE_STREAK_REWARD := 1         # Feste Auszahlung pro Serien-Meilenstein.
const ESSENCE_BOSS_KILL := 4             # Aether pro erlegtem Boss.
const ESSENCE_WAVE_BASE := 2             # Sockel pro abgeschlossener Welle.
const ESSENCE_WAVE_STEP := 2             # Sockel waechst alle n Wellen um 1 ...
const ESSENCE_WAVE_STEP_CAP := 3         # ... maximal aber um diesen Betrag.
const ESSENCE_WAVE_CYCLE := 5            # Jede n-te Welle zahlt zusaetzlich aus.
const ESSENCE_WAVE_CYCLE_BONUS := 10     # Sockel dieses Zyklusbonus.
const ESSENCE_WAVE_CYCLE_STEP := 5       # Zyklusbonus waechst alle n Wellen um 1 ...
const ESSENCE_WAVE_CYCLE_CAP := 2        # ... maximal aber um diesen Betrag.
const ESSENCE_LEVEL_BASE := 4            # Sockel pro Account-Levelaufstieg.
const ESSENCE_LEVEL_CAP := 6             # Deckel des levelabhaengigen Anteils.
const ESSENCE_MILESTONE_BASE := 8        # Sockel je Wellen-Meilenstein.
const ESSENCE_MILESTONE_EXP := 1.0       # Wellen-Exponent des Meilensteins.
const ESSENCE_RUN_SCALE := 1.8           # Faktor der Run-Abschlusspraemie.
const ESSENCE_RUN_EXP := 1.05            # Wellen-Exponent der Run-Abschlusspraemie.

const TOWER_RESEARCH := {
	"archer": "unlock_archer",
	"wizard": "unlock_wizard",
	"trapper": "unlock_trapper",
	"cannon": "unlock_cannon",
	"aura": "unlock_aura"
}

const RESEARCH := {
	"starting_funds": {
		"name": "Gefuellte Kriegskasse",
		"description": "+25 Startgold pro Rang.",
		"icon": "gold", "max_level": 8, "base_cost": 12, "cost_growth": 1.55,
		"tier": 1, "color": Color("e6b85c")
	},
	"fortification": {
		"name": "Runenwall",
		"description": "+2 Startleben pro Rang.",
		"icon": "life", "max_level": 6, "base_cost": 14, "cost_growth": 1.62,
		"tier": 1, "color": Color("e36b62")
	},
	"logistics": {
		"name": "Arkanes Lager",
		"description": "+1 Start-Supply pro Rang.",
		"icon": "supply", "max_level": 6, "base_cost": 16, "cost_growth": 1.65,
		"tier": 1, "color": Color("75c77b")
	},
	"unlock_archer": {
		"name": "Bogenschuetzen-Gilde",
		"description": "Schaltet den Bogen-Turm ab dem naechsten Run frei.",
		"icon": "range", "max_level": 1, "base_cost": 24, "cost_growth": 1.0,
		"tier": 1, "color": Color("7bd6c4")
	},
	"unlock_wizard": {
		"name": "Arkanes Kolleg",
		"description": "Schaltet den Zauberer ab dem naechsten Run frei.",
		"icon": "upgrades", "max_level": 1, "base_cost": 32, "cost_growth": 1.0,
		"tier": 1, "requires_invested": 2, "color": Color("b784f2")
	},
	"metallurgy": {
		"name": "Sternenmetall",
		"description": "+4% Schaden fuer alle Tuerme pro Rang.",
		"icon": "damage", "max_level": 10, "base_cost": 30, "cost_growth": 1.58,
		"tier": 2, "requires_invested": 3, "color": Color("d879e8")
	},
	"compound_interest": {
		"name": "Ewiger Zins",
		"description": "+1% Zinsrate und +10 Zinslimit pro Rang.",
		"icon": "gold", "max_level": 6, "base_cost": 34, "cost_growth": 1.68,
		"tier": 2, "requires_invested": 3, "color": Color("f0d36c")
	},
	"scavenging": {
		"name": "Essenz-Sieb",
		"description": "+10% Aether aus allen Quellen pro Rang.",
		"icon": "star_full", "max_level": 8, "base_cost": 32, "cost_growth": 1.62,
		"tier": 2, "requires_invested": 3, "color": Color("76d5ef")
	},
	"automation": {
		"name": "Uhrwerk-Befehl",
		"description": "Schaltet den automatischen Wellenstart frei.",
		"icon": "play", "max_level": 1, "base_cost": 70, "cost_growth": 1.0,
		"tier": 2, "requires_invested": 5, "color": Color("8fd4ff")
	},
	"unlock_trapper": {
		"name": "Pfadjaeger-Zunft",
		"description": "Schaltet den Fallensteller ab dem naechsten Run frei.",
		"icon": "path", "max_level": 1, "base_cost": 42, "cost_growth": 1.0,
		"tier": 2, "requires_invested": 4, "color": Color("82bd72")
	},
	"unlock_cannon": {
		"name": "Belagerungswerkstatt",
		"description": "Schaltet die Kanone ab dem naechsten Run frei.",
		"icon": "damage", "max_level": 1, "base_cost": 65, "cost_growth": 1.0,
		"tier": 2, "requires_invested": 7, "color": Color("e58b58")
	},
	"command": {
		"name": "Kommandanten-Siegel",
		"description": "+6 Gold Wellenbonus pro Rang.",
		"icon": "upgrades", "max_level": 8, "base_cost": 85, "cost_growth": 1.7,
		"tier": 3, "requires_invested": 10, "color": Color("e99754")
	},
	"chrono": {
		"name": "Chrono-Runen",
		"description": "+0,5 maximales Spieltempo pro Rang.",
		"icon": "fire_rate", "max_level": 3, "base_cost": 100, "cost_growth": 2.0,
		"tier": 3, "requires_invested": 10, "color": Color("a7a1ff")
	},
	"resonance": {
		"name": "Kernresonanz",
		"description": "Bosswellen geben +1 zusaetzlichen Element-Kern.",
		"icon": "core", "max_level": 1, "base_cost": 180, "cost_growth": 1.0,
		"tier": 3, "requires_invested": 14, "color": Color("ec84ff")
	},
	"unlock_aura": {
		"name": "Resonanz-Obelisk",
		"description": "Schaltet den Aura-Turm ab dem naechsten Run frei.",
		"icon": "star_full", "max_level": 1, "base_cost": 110, "cost_growth": 1.0,
		"tier": 3, "requires_invested": 10, "color": Color("f2d276")
	}
}

var essence := 0
var account_level := 1
var account_xp := 0
var best_wave := 0
var total_runs := 0
var total_kills := 0
var lifetime_essence := 0
var highest_streak := 0
var research_levels: Dictionary = {}
var claimed_milestones: Dictionary = {}
var auto_wave_enabled := false
var recruited_characters: Dictionary = {}

var run_essence := 0
var run_xp := 0
var run_kills := 0
var run_max_streak := 0
var current_streak := 0
var streak_time_left := 0.0
var run_active := false
var run_finalized := false
var run_tower_unlocks: Dictionary = {}

var _save_dirty := false
var _save_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_research()
	_load_progress()
	account_progress_changed.emit(account_level, account_xp, get_xp_required())
	essence_changed.emit(essence, 0)


func _process(delta: float) -> void:
	if current_streak > 0 and streak_time_left > 0.0 and not get_tree().paused:
		streak_time_left = maxf(0.0, streak_time_left - delta)
		if streak_time_left <= 0.0:
			current_streak = 0
			streak_changed.emit(0, 1.0, 0.0)
		else:
			streak_changed.emit(current_streak, get_streak_multiplier(), streak_time_left)

	if _save_dirty:
		_save_cooldown -= delta
		if _save_cooldown <= 0.0:
			save_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()


func _initialize_research() -> void:
	for research_id in RESEARCH:
		if not research_levels.has(research_id):
			research_levels[research_id] = 0


func begin_run() -> void:
	run_essence = 0
	run_xp = 0
	run_kills = 0
	run_max_streak = 0
	current_streak = 0
	streak_time_left = 0.0
	run_active = true
	run_finalized = false
	run_tower_unlocks.clear()
	for tower_type in TOWER_RESEARCH:
		run_tower_unlocks[tower_type] = get_research_level(TOWER_RESEARCH[tower_type]) > 0
	run_progress_changed.emit(run_essence, run_xp)
	streak_changed.emit(0, 1.0, 0.0)


func register_kill(enemy_type: String, base_gold: int) -> Dictionary:
	if not run_active:
		begin_run()

	current_streak += 1
	streak_time_left = STREAK_WINDOW
	run_kills += 1
	total_kills += 1
	run_max_streak = maxi(run_max_streak, current_streak)
	highest_streak = maxi(highest_streak, current_streak)

	var multiplier := get_streak_multiplier()
	var bonus_gold := maxi(0, int(round(float(base_gold) * (multiplier - 1.0))))
	var essence_gain := 0
	# Feste Auszahlung pro Serien-Meilenstein: Lange Wellen sollen den Zufluss
	# nicht zusaetzlich ueber die Seriellaenge hochskalieren.
	if current_streak % ESSENCE_STREAK_STEP == 0:
		essence_gain = ESSENCE_STREAK_REWARD
	if enemy_type == "boss":
		essence_gain += ESSENCE_BOSS_KILL
	if essence_gain > 0:
		_award_essence(essence_gain)

	_add_account_xp(1)
	run_progress_changed.emit(run_essence, run_xp)
	streak_changed.emit(current_streak, multiplier, streak_time_left)
	_mark_save_dirty()
	return {"gold_bonus": bonus_gold, "essence": essence_gain, "multiplier": multiplier}


func register_wave_completed(wave: int) -> Dictionary:
	var base_essence := ESSENCE_WAVE_BASE + mini(wave / ESSENCE_WAVE_STEP, ESSENCE_WAVE_STEP_CAP)
	if wave % ESSENCE_WAVE_CYCLE == 0:
		base_essence += ESSENCE_WAVE_CYCLE_BONUS + mini(wave / ESSENCE_WAVE_CYCLE_STEP, ESSENCE_WAVE_CYCLE_CAP)
	var gained_essence := _award_essence(base_essence)
	var gained_xp := 10 + wave * 3
	_add_account_xp(gained_xp)

	if wave > best_wave:
		best_wave = wave
		_check_milestones()

	current_streak = 0
	streak_time_left = 0.0
	streak_changed.emit(0, 1.0, 0.0)
	run_progress_changed.emit(run_essence, run_xp)
	save_progress()
	return {"essence": gained_essence, "xp": gained_xp}


func finish_run(wave: int) -> Dictionary:
	if run_finalized:
		return get_run_summary()
	run_finalized = true
	run_active = false
	total_runs += 1
	best_wave = maxi(best_wave, wave)

	var completion_base := int(round(pow(float(maxi(1, wave)), ESSENCE_RUN_EXP) * ESSENCE_RUN_SCALE))
	var completion_essence := _award_essence(completion_base)
	var completion_xp := 25 + wave * 5
	_add_account_xp(completion_xp)
	_check_milestones()
	save_progress()

	var summary := get_run_summary()
	summary["completion_essence"] = completion_essence
	summary["completion_xp"] = completion_xp
	return summary


func get_run_summary() -> Dictionary:
	return {
		"wave": best_wave if not run_active else GameState.current_wave,
		"run_essence": run_essence,
		"run_xp": run_xp,
		"kills": run_kills,
		"max_streak": run_max_streak,
		"account_level": account_level,
		"essence_total": essence
	}


func get_streak_multiplier() -> float:
	if current_streak < 2:
		return 1.0
	return minf(2.5, 1.0 + floorf(float(current_streak) / 6.0) * 0.1)


func _award_essence(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var amount := maxi(1, int(round(float(base_amount) * get_essence_multiplier())))
	essence += amount
	lifetime_essence += amount
	run_essence += amount
	essence_changed.emit(essence, amount)
	run_progress_changed.emit(run_essence, run_xp)
	_mark_save_dirty()
	return amount


func _add_account_xp(amount: int) -> void:
	if amount <= 0:
		return
	account_xp += amount
	run_xp += amount
	var leveled_up := false
	while account_xp >= get_xp_required():
		account_xp -= get_xp_required()
		account_level += 1
		leveled_up = true
		# Jeder Levelaufstieg ist selbst eine kleine Incremental-Auszahlung.
		# Der levelabhaengige Anteil ist gedeckelt, damit hohe Accounts nicht dauerhaft
		# immer groessere Brocken ausschuetten.
		var level_reward := ESSENCE_LEVEL_BASE + mini(account_level, ESSENCE_LEVEL_CAP)
		essence += level_reward
		lifetime_essence += level_reward
		run_essence += level_reward
		essence_changed.emit(essence, level_reward)
	if leveled_up:
		_mark_save_dirty()
	account_progress_changed.emit(account_level, account_xp, get_xp_required())


func get_xp_required(level: int = account_level) -> int:
	return 60 + level * 30 + level * level * 5


func _check_milestones() -> void:
	for wave in MILESTONE_WAVES:
		var key := str(wave)
		if best_wave >= wave and not claimed_milestones.get(key, false):
			claimed_milestones[key] = true
			var actual_reward := _award_essence(get_milestone_reward(wave))
			milestone_reached.emit(wave, actual_reward)


func get_milestone_reward(wave: int) -> int:
	return ESSENCE_MILESTONE_BASE + int(pow(float(wave), ESSENCE_MILESTONE_EXP))


func get_next_milestone() -> Dictionary:
	for wave in MILESTONE_WAVES:
		if best_wave < wave:
			return {"wave": wave, "reward": get_milestone_reward(wave)}
	return {"wave": 0, "reward": 0}


func get_research_ids() -> Array[String]:
	var result: Array[String] = []
	for research_id in RESEARCH:
		result.append(research_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		var tier_a: int = RESEARCH[a].get("tier", 1)
		var tier_b: int = RESEARCH[b].get("tier", 1)
		if tier_a == tier_b:
			return a < b
		return tier_a < tier_b
	)
	return result


func get_research_data(research_id: String) -> Dictionary:
	return RESEARCH.get(research_id, {})


func get_research_level(research_id: String) -> int:
	return int(research_levels.get(research_id, 0))


func get_total_research_levels() -> int:
	var total := 0
	for value in research_levels.values():
		total += int(value)
	return total


func is_research_unlocked(research_id: String) -> bool:
	var data: Dictionary = RESEARCH.get(research_id, {})
	if data.is_empty():
		return false
	return get_total_research_levels() >= int(data.get("requires_invested", 0))


func get_research_cost(research_id: String) -> int:
	var data: Dictionary = RESEARCH.get(research_id, {})
	if data.is_empty():
		return -1
	var level := get_research_level(research_id)
	if level >= int(data.get("max_level", 1)):
		return -1
	return int(round(float(data.get("base_cost", 10)) * pow(float(data.get("cost_growth", 1.5)), level)))


func purchase_research(research_id: String) -> bool:
	if not is_research_unlocked(research_id):
		return false
	var cost := get_research_cost(research_id)
	if cost < 0 or essence < cost:
		return false
	essence -= cost
	research_levels[research_id] = get_research_level(research_id) + 1
	essence_changed.emit(essence, -cost)
	research_changed.emit(research_id, research_levels[research_id])
	if research_id == "automation" and get_research_level("automation") <= 0:
		set_auto_wave_enabled(false)
	save_progress()
	return true


# --- Charakter-Rekrutierung ---------------------------------------------------
# ProgressionSystem besitzt Rekrutierungs-Status und Transaktion (Aether + Stats);
# die Charakter-Definitionen bleiben in AbilitySystem.CHARACTERS.

func is_character_recruited(char_id: String) -> bool:
	return bool(recruited_characters.get(char_id, false))


func get_character_unlock_progress(char_id: String) -> Dictionary:
	var char_data: Dictionary = AbilitySystem.get_character_data(char_id)
	var unlock: Dictionary = char_data.get("unlock", {})
	if unlock.is_empty():
		return {}
	var stat: String = unlock.get("stat", "")
	var current := int(get(stat)) if stat in self else 0
	var target := int(unlock.get("target", 0))
	return {
		"stat": stat,
		"current": current,
		"target": target,
		"cost": int(unlock.get("cost", 0)),
		"goal_met": current >= target
	}


func can_recruit_character(char_id: String) -> bool:
	if is_character_recruited(char_id):
		return false
	var progress := get_character_unlock_progress(char_id)
	if progress.is_empty():
		return false
	return progress["goal_met"] and essence >= int(progress["cost"])


func recruit_character(char_id: String) -> bool:
	if not can_recruit_character(char_id):
		return false
	var cost := int(get_character_unlock_progress(char_id)["cost"])
	if cost > 0:
		essence -= cost
		essence_changed.emit(essence, -cost)
	recruited_characters[char_id] = true
	character_recruited.emit(char_id)
	save_progress()
	return true


func has_recruitable_character() -> bool:
	for char_id in AbilitySystem.CHARACTERS:
		if can_recruit_character(char_id):
			return true
	return false


func set_auto_wave_enabled(enabled: bool) -> void:
	auto_wave_enabled = enabled and is_automation_unlocked()
	auto_wave_changed.emit(auto_wave_enabled)
	_mark_save_dirty()


func is_automation_unlocked() -> bool:
	return get_research_level("automation") > 0


func is_tower_unlocked(tower_type: String) -> bool:
	if tower_type in ["sword", "farm"]:
		return true
	if not TOWER_RESEARCH.has(tower_type):
		return false
	if run_active:
		return bool(run_tower_unlocks.get(tower_type, false))
	return get_research_level(TOWER_RESEARCH[tower_type]) > 0


# --- Permanente Effekt-Getter -------------------------------------------------
func get_starting_gold_bonus() -> int:
	return get_research_level("starting_funds") * 25


func get_starting_lives_bonus() -> int:
	return get_research_level("fortification") * 2


func get_starting_supply_bonus() -> int:
	return get_research_level("logistics")


func get_global_damage_bonus() -> float:
	return get_research_level("metallurgy") * 0.04


func get_interest_rate_bonus() -> float:
	return get_research_level("compound_interest") * 0.01


func get_max_interest_bonus() -> int:
	return get_research_level("compound_interest") * 10


func get_flat_wave_bonus() -> int:
	return get_research_level("command") * 6


func get_essence_multiplier() -> float:
	return 1.0 + get_research_level("scavenging") * 0.10


func get_max_time_scale() -> float:
	return 2.5 + get_research_level("chrono") * 0.5


func get_boss_core_bonus() -> int:
	return 1 if get_research_level("resonance") > 0 else 0


func _mark_save_dirty() -> void:
	_save_dirty = true
	_save_cooldown = 1.5


func save_progress() -> void:
	var data := {
		"version": SAVE_VERSION,
		"essence": essence,
		"account_level": account_level,
		"account_xp": account_xp,
		"best_wave": best_wave,
		"total_runs": total_runs,
		"total_kills": total_kills,
		"lifetime_essence": lifetime_essence,
		"highest_streak": highest_streak,
		"research_levels": research_levels,
		"claimed_milestones": claimed_milestones,
		"auto_wave_enabled": auto_wave_enabled,
		"recruited_characters": recruited_characters
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[ProgressionSystem] Fortschritt konnte nicht gespeichert werden.")
		return
	file.store_string(JSON.stringify(data))
	_save_dirty = false
	_save_cooldown = 0.0


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("[ProgressionSystem] Savegame ist ungueltig; Standardwerte werden verwendet.")
		return
	var data: Dictionary = parsed
	essence = maxi(0, int(data.get("essence", 0)))
	account_level = maxi(1, int(data.get("account_level", 1)))
	account_xp = maxi(0, int(data.get("account_xp", 0)))
	best_wave = maxi(0, int(data.get("best_wave", 0)))
	total_runs = maxi(0, int(data.get("total_runs", 0)))
	total_kills = maxi(0, int(data.get("total_kills", 0)))
	lifetime_essence = maxi(0, int(data.get("lifetime_essence", 0)))
	highest_streak = maxi(0, int(data.get("highest_streak", 0)))
	research_levels = data.get("research_levels", {}).duplicate()
	claimed_milestones = data.get("claimed_milestones", {}).duplicate()
	auto_wave_enabled = bool(data.get("auto_wave_enabled", false))
	# Migration v1 -> v2: fehlender Schluessel ergibt ein leeres Dict — Basis-Charaktere
	# stehen nie in diesem Dict, Rekrutierbare starten gesperrt.
	recruited_characters = data.get("recruited_characters", {}).duplicate()
	_initialize_research()
	if not is_automation_unlocked():
		auto_wave_enabled = false
