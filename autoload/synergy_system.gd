# autoload/synergy_system.gd
# Meisterschafts-/Synergie-System: trackt worin der Spieler investiert (Tags),
# gewichtet die Perk-/Ability-Auswahl dorthin und schaltet Schwellen-Boni (Tiers) frei.
# Rückgrat für den Build-Path. Wird von UpgradeSystem, tower.gd, enemy.gd,
# ability_system.gd und ui/synergy_panel.gd abgefragt.
extends Node

signal mastery_changed(tag: String, points: int, tier: int)
signal tier_unlocked(tag: String, tier: int)

# === TRACKS ===
# Element-Tracks (fire/water/earth/air) + Stil-Tracks (crit/splash/control).
const TAGS: Array[String] = ["fire", "water", "earth", "air", "crit", "splash", "control"]

# Punkte-Schwellen für Tier 1 / 2 / 3
const TIER_THRESHOLDS: Array[int] = [4, 8, 12]

# Punkte pro Quelle (Startwerte zum Tunen)
const POINTS_PER_PERK := 2
const POINTS_PER_CORE := 2
const POINTS_PER_PLACE := 1
const POINTS_PER_ENGRAVE := 1

# === EFFEKT-KONSTANTEN (Startwerte) ===
const ELEMENT_T2_DAMAGE := 0.15          # Element T2: +15% Schaden für dieses Element
const COMBO_CAPSTONE_PER_TIER := 0.10    # Combo: +10% Schaden je min-Tier der Elternelemente

const FIRE_T1_BURN := 0.25               # +25% Brennschaden
const FIRE_T3_BURNING_VULN := 0.15       # brennende Gegner +15% Schaden

const WATER_T1_SLOW := 0.15              # +15% Verlangsamungs-Stärke
const WATER_T3_FREEZE_DURATION := 0.20   # +20% Freeze-Dauer

const EARTH_T1_STUN := 0.10              # +10% Stun-Chance
const EARTH_T3_STUNNED_VULN := 0.20      # gestunnte Gegner +20% Schaden

const AIR_T1_CHAIN := 1                  # +1 Kettenziel

const CRIT_T1_CHANCE := 0.08             # +8% Crit-Chance
const CRIT_T2_DAMAGE := 0.30             # +30% Crit-Schaden

const SPLASH_T1_RADIUS := 0.20           # +20% Splash-Radius
const SPLASH_T2_DAMAGE := 0.15           # +15% Splash-Schaden

const CONTROL_T1_DURATION := 0.15        # +15% Status-Dauer (slow/freeze/stun)
const CONTROL_T2_VULN := 0.12            # kontrollierte Gegner nehmen +12% Turmschaden
const CONTROL_T3_FREEZE_CHANCE := 0.10   # 10% Freeze-Chance bei Treffer auf verlangsamten Gegner

# Anzeige-Metadaten fürs UI
const TRACK_INFO := {
	"fire":    {"name": "Feuer",      "icon": "🔥"},
	"water":   {"name": "Wasser",     "icon": "💧"},
	"earth":   {"name": "Erde",       "icon": "🪨"},
	"air":     {"name": "Luft",       "icon": "💨"},
	"crit":    {"name": "Präzision",  "icon": "🎯"},
	"splash":  {"name": "Explosiv",   "icon": "💥"},
	"control": {"name": "Kontrolle",  "icon": "❄"},
}

# Effekt-Texte pro Tier (für UI)
const TIER_EFFECTS := {
	"fire":    ["+25% Brennschaden", "+15% Schaden für Feuer-Türme", "Brennende Gegner nehmen +15% Schaden"],
	"water":   ["+15% Verlangsamung", "+15% Schaden für Wasser-Türme", "+20% Einfrier-Dauer"],
	"earth":   ["+10% Stun-Chance", "+15% Schaden für Erd-Türme", "Gestunnte Gegner nehmen +20% Schaden"],
	"air":     ["+1 Kettenziel", "+15% Schaden für Luft-Türme", "Ketten verlieren keinen Schaden"],
	"crit":    ["+8% Crit-Chance", "+30% Crit-Schaden", "Crits lösen Brand aus"],
	"splash":  ["+20% Splash-Radius", "+15% Splash-Schaden", "Splash verlangsamt Gegner"],
	"control": ["+15% Status-Dauer", "Kontrollierte Gegner: +12% Turmschaden", "10% Freeze-Chance vs. verlangsamte Gegner"],
}

# Perk-ID → Meisterschafts-Tags. Zentrale Quelle, damit upgrade_system.gd nicht
# angefasst werden muss. Perks ohne Eintrag geben keine Meisterschaftspunkte.
const PERK_TAGS := {
	"fire_spawn_rate": ["fire"],
	"water_spawn_rate": ["water"],
	"earth_spawn_rate": ["earth"],
	"air_spawn_rate": ["air"],
	"fire_damage": ["fire"],
	"water_damage": ["water", "control"],
	"earth_damage": ["earth", "control"],
	"air_damage": ["air"],
	"crit_chance": ["crit"],
	"crit_damage": ["crit"],
	"splash_bonus": ["splash"],
}

# === RUNTIME STATE ===
var mastery_points: Dictionary = {}


func _ready() -> void:
	_init_points()
	print("[SynergySystem] Initialisiert mit %d Tracks" % TAGS.size())


func _init_points() -> void:
	for tag in TAGS:
		mastery_points[tag] = 0


# === PUNKTE VERGEBEN ===

func add_points(tag: String, amount: int) -> void:
	if not tag in TAGS or amount == 0:
		return
	var old_tier := get_tier(tag)
	mastery_points[tag] = maxi(0, int(mastery_points.get(tag, 0)) + amount)
	var new_tier := get_tier(tag)
	mastery_changed.emit(tag, mastery_points[tag], new_tier)
	if new_tier > old_tier:
		tier_unlocked.emit(tag, new_tier)


func add_points_multi(tags: Array, amount: int) -> void:
	for tag in tags:
		add_points(tag, amount)


# Tags eines Perks (leer, wenn der Perk keinen Track speist)
func get_perk_tags(upgrade_id: String) -> Array:
	return PERK_TAGS.get(upgrade_id, [])


# Perk gewählt: vergibt Punkte für alle Tags des Perks
func on_perk_selected(upgrade_id: String) -> void:
	add_points_multi(get_perk_tags(upgrade_id), POINTS_PER_PERK)


# Element-Kern investiert
func on_core_invested(element: String) -> void:
	add_points(element, POINTS_PER_CORE)
	# Wasser/Erde sind Kontroll-Elemente (Slow/Stun)
	if element == "water" or element == "earth":
		add_points("control", 1)


# Element-/Combo-Turm platziert. `element` = Basis-Element oder Combo-Name.
# `is_cc` = wendet Crowd-Control an (slow/freeze/stun/root/confuse).
func on_tower_placed(element: String, is_cc: bool) -> void:
	for base in _resolve_to_bases(element):
		add_points(base, POINTS_PER_PLACE)
	if is_cc:
		add_points("control", POINTS_PER_PLACE)


# Turm graviert
func on_tower_engraved(element: String) -> void:
	add_points(element, POINTS_PER_ENGRAVE)
	if element == "water" or element == "earth":
		add_points("control", 1)


# === ABFRAGEN ===

func get_points(tag: String) -> int:
	return int(mastery_points.get(tag, 0))


func get_tier(tag: String) -> int:
	var pts := get_points(tag)
	var tier := 0
	for i in range(TIER_THRESHOLDS.size()):
		if pts >= TIER_THRESHOLDS[i]:
			tier = i + 1
	return tier


func has_tier(tag: String, tier: int) -> bool:
	return get_tier(tag) >= tier


func get_points_to_next_tier(tag: String) -> int:
	var tier := get_tier(tag)
	if tier >= TIER_THRESHOLDS.size():
		return 0
	return TIER_THRESHOLDS[tier] - get_points(tag)


# Löst Combo-Namen in Basis-Elemente auf; Basis-Elemente bleiben unverändert.
func _resolve_to_bases(element: String) -> Array:
	if ElementalSystem and ElementalSystem.COMBO_ELEMENTS.has(element):
		return ElementalSystem.COMBO_ELEMENTS[element]
	if element in ["fire", "water", "earth", "air"]:
		return [element]
	return []


# === MECHANISCHE GETTER ===

# Zustandsabhängiger Multiplikator, angewendet in enemy.take_damage() für Turmschaden.
func get_state_damage_mult(enemy) -> float:
	var mult := 1.0
	if not is_instance_valid(enemy):
		return mult

	var slowed := false
	var frozen := false
	var stunned := false
	var burning := false
	var v = enemy.get("slow_timer")
	if v != null:
		slowed = float(v) > 0.0
	v = enemy.get("is_frozen")
	if v != null:
		frozen = bool(v)
	v = enemy.get("stun_timer")
	if v != null:
		stunned = float(v) > 0.0
	v = enemy.get("burn_timer")
	if v != null:
		burning = float(v) > 0.0

	# control T2: verlangsamte/gefrorene/gestunnte Gegner nehmen mehr Schaden
	if has_tier("control", 2) and (slowed or frozen or stunned):
		mult *= 1.0 + CONTROL_T2_VULN
	# fire T3: brennende Gegner
	if has_tier("fire", 3) and burning:
		mult *= 1.0 + FIRE_T3_BURNING_VULN
	# earth T3: gestunnte Gegner
	if has_tier("earth", 3) and stunned:
		mult *= 1.0 + EARTH_T3_STUNNED_VULN

	return mult


# Element-Schaden-Bonus (Element T2 + Combo-Capstone). `element` kann Basis oder Combo sein.
func get_element_damage_bonus(element: String) -> float:
	var bases := _resolve_to_bases(element)
	if bases.is_empty():
		return 0.0
	var bonus := 0.0
	for b in bases:
		if has_tier(b, 2):
			bonus += ELEMENT_T2_DAMAGE
	# Combo-Capstone: skaliert mit dem schwächeren Elternelement
	if bases.size() == 2:
		bonus += COMBO_CAPSTONE_PER_TIER * mini(get_tier(bases[0]), get_tier(bases[1]))
	return bonus


func get_crit_chance_bonus() -> float:
	return CRIT_T1_CHANCE if has_tier("crit", 1) else 0.0


func get_crit_damage_bonus() -> float:
	return CRIT_T2_DAMAGE if has_tier("crit", 2) else 0.0


func get_splash_radius_bonus() -> float:
	return SPLASH_T1_RADIUS if has_tier("splash", 1) else 0.0


func get_splash_damage_bonus() -> float:
	return SPLASH_T2_DAMAGE if has_tier("splash", 2) else 0.0


func get_chain_bonus() -> int:
	return AIR_T1_CHAIN if has_tier("air", 1) else 0


func get_burn_damage_bonus() -> float:
	return FIRE_T1_BURN if has_tier("fire", 1) else 0.0


func get_slow_strength_bonus() -> float:
	return WATER_T1_SLOW if has_tier("water", 1) else 0.0


func get_stun_chance_bonus() -> float:
	return EARTH_T1_STUN if has_tier("earth", 1) else 0.0


# Multiplikator für Status-Dauer (slow/freeze/stun) — control T1, water T3 (Freeze).
func get_status_duration_mult(status: String) -> float:
	var mult := 1.0
	if has_tier("control", 1):
		mult += CONTROL_T1_DURATION
	if status == "freeze" and has_tier("water", 3):
		mult += WATER_T3_FREEZE_DURATION
	return mult


# --- Verhaltens-Flags (T2/T3) ---

func crit_applies_burn() -> bool:
	return has_tier("crit", 3)


func splash_applies_slow() -> bool:
	return has_tier("splash", 3)


func chains_no_falloff() -> bool:
	return has_tier("air", 3)


# Freeze-Chance beim Treffer auf einen bereits verlangsamten Gegner (control T3)
func get_freeze_on_slowed_chance() -> float:
	return CONTROL_T3_FREEZE_CHANCE if has_tier("control", 3) else 0.0


# === PERK-GEWICHTUNG ===
# Gewicht eines Perks für die gewichtete Auswahl: höher, je mehr Punkte in seinen Tags.
func get_tag_draw_weight(tags: Array) -> float:
	if tags.is_empty():
		return 1.0
	var weight := 1.0
	for tag in tags:
		# Jeder investierte Punkt erhöht das Gewicht leicht
		weight += get_points(tag) * 0.5
	return weight


# === RESET ===

func reset() -> void:
	_init_points()
	for tag in TAGS:
		mastery_changed.emit(tag, 0, 0)
	print("[SynergySystem] Reset für neuen Run")
