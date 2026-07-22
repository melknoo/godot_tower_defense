# run_schedule.gd
# Einzige Quelle fuer die Wellen-Kadenzen eines Runs: Perk-Auswahl,
# Ability-Upgrades, Element-Kerne, Schmiede und Bosswellen.
#
# Wird bewusst per `const RunSchedule = preload(...)` eingebunden (wie
# autoload/range_grid.gd) statt als Autoload oder class_name — so entfaellt der
# Klassen-Cache-Schritt aus MEMORY.md und es gibt keinen neuen Singleton-Namen.
#
# Wer eine Kadenz aendert, aendert sie hier: main.gd, game_state.gd,
# ability_system.gd und ui/hud.gd fragen alle diese Datei.
extends RefCounted

# --- Kadenzen ---------------------------------------------------------------
const UPGRADE_INTERVAL := 3        # Perk-Auswahl:      3, 6, 9, 12 ...
const ABILITY_FIRST_WAVE := 4      # Ability-Upgrades:  4, 7, 10, 13 ...
const ABILITY_INTERVAL := 3
const ITEM_COMBINE_INTERVAL := 5   # Schmiede:          5, 10, 15 ...
const BOSS_INTERVAL := 5           # Bosswellen:        5, 10, 15 ...

# Regulaeres Ende eines Runs. Danach entscheidet der Spieler zwischen
# Endlos-Modus und Abschluss mit Sieg-Auswertung.
const FINAL_WAVE := 30

# Element-Kerne: frueh zwei feste Wellen, danach im festen Intervall.
const CORE_EARLY_WAVES: Array[int] = [3, 6]
const CORE_INTERVAL := 5
const CORE_INTERVAL_START := 10
const CORE_LAST_WAVE := 100

# --- Farben fuer die Ereignis-Anzeige ---------------------------------------
const COLOR_UPGRADE := Color(0.5, 1.0, 0.5)
const COLOR_ABILITY := Color(0.7, 0.8, 1.0)
const COLOR_CORE := Color(0.55, 0.9, 1.0)
const COLOR_FORGE := Color(1.0, 0.85, 0.5)
const COLOR_BOSS := Color(1.0, 0.45, 0.4)
const COLOR_FINAL := Color(1.0, 0.85, 0.35)


# --- Einzelpruefungen -------------------------------------------------------

static func has_upgrade(wave: int) -> bool:
	if wave < UPGRADE_INTERVAL:
		return false
	return wave % UPGRADE_INTERVAL == 0


static func has_ability_upgrade(wave: int) -> bool:
	if wave < ABILITY_FIRST_WAVE:
		return false
	return (wave - ABILITY_FIRST_WAVE) % ABILITY_INTERVAL == 0


static func has_item_combine(wave: int) -> bool:
	if wave < ITEM_COMBINE_INTERVAL:
		return false
	return wave % ITEM_COMBINE_INTERVAL == 0


static func has_boss(wave: int) -> bool:
	return wave > 0 and wave % BOSS_INTERVAL == 0


static func is_final_wave(wave: int) -> bool:
	return wave == FINAL_WAVE


static func has_element_core(wave: int) -> bool:
	if wave in CORE_EARLY_WAVES:
		return true
	if wave < CORE_INTERVAL_START or wave > CORE_LAST_WAVE:
		return false
	return wave % CORE_INTERVAL == 0


# Vollstaendige Liste der Wellen mit Element-Kern (GameState prueft dagegen).
static func get_core_reward_waves() -> Array[int]:
	var waves: Array[int] = CORE_EARLY_WAVES.duplicate()
	for wave in range(CORE_INTERVAL_START, CORE_LAST_WAVE + 1, CORE_INTERVAL):
		waves.append(wave)
	return waves


# --- Naechste Welle je Ereignis ---------------------------------------------

static func get_next_upgrade_wave(current_wave: int) -> int:
	return _next_multiple(current_wave, UPGRADE_INTERVAL)


static func get_next_ability_upgrade_wave(current_wave: int) -> int:
	if current_wave < ABILITY_FIRST_WAVE:
		return ABILITY_FIRST_WAVE
	var since_first := current_wave - ABILITY_FIRST_WAVE
	return ABILITY_FIRST_WAVE + ((since_first / ABILITY_INTERVAL) + 1) * ABILITY_INTERVAL


static func get_next_item_combine_wave(current_wave: int) -> int:
	return _next_multiple(current_wave, ITEM_COMBINE_INTERVAL)


static func get_next_boss_wave(current_wave: int) -> int:
	return _next_multiple(current_wave, BOSS_INTERVAL)


static func _next_multiple(current_wave: int, interval: int) -> int:
	if current_wave < interval:
		return interval
	return ((current_wave / interval) + 1) * interval


# --- Ereignisse einer Welle -------------------------------------------------

# Liefert alle Ereignisse der uebergebenen Welle als
# [{id, label, icon, color}] in Anzeige-Reihenfolge.
static func get_events(wave: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if is_final_wave(wave):
		events.append({
			"id": "final", "label": "Finale",
			"icon": "star_full", "color": COLOR_FINAL
		})
	if has_boss(wave):
		events.append({
			"id": "boss", "label": "Boss",
			"icon": "warning", "color": COLOR_BOSS
		})
	if has_upgrade(wave):
		events.append({
			"id": "upgrade", "label": "Upgrade",
			"icon": "upgrades", "color": COLOR_UPGRADE
		})
	if has_ability_upgrade(wave):
		events.append({
			"id": "ability", "label": "Ability-Upgrade",
			"icon": "abilities", "color": COLOR_ABILITY
		})
	if has_element_core(wave):
		events.append({
			"id": "core", "label": "Element-Kern",
			"icon": "core", "color": COLOR_CORE
		})
	if has_item_combine(wave):
		events.append({
			"id": "forge", "label": "Schmiede",
			"icon": "inventory", "color": COLOR_FORGE
		})

	return events


# Fahrplan ab `from_wave` (inklusive) ueber `count` Wellen.
# Jeder Eintrag: {wave, events}. Wellen ohne Ereignis bleiben enthalten,
# damit die Anzeige eine durchgehende Zeitleiste zeigen kann.
static func get_upcoming(from_wave: int, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var wave := maxi(1, from_wave)
	for i in range(count):
		result.append({"wave": wave + i, "events": get_events(wave + i)})
	return result
