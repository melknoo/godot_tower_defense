# terrain_data.gd
# Wegzonen: Abschnitte des Pfads mit eigener Beschaffenheit. Jede Zone ist an ein
# Element gekoppelt und folgt EINER Regel, passend zum Elementkreis
# (Wasser > Feuer > Erde > Luft > Wasser):
#   - Angriffe des Zonenelements: x BOOST_MULT ("Resonanz")
#   - Angriffe des Elements, das vom Zonenelement geschlagen wird: x DAMPEN_MULT
#   - dazu ein Tempo-Effekt auf Gegner in der Zone
# So bekommt die Karte Platzierungsentscheidungen: Feuertuerme an die Aschefelder.
class_name TerrainData
extends RefCounted

const BOOST_MULT := 1.25
const DAMPEN_MULT := 0.75

const ZONES := {
	"mud": {
		"name": "Schlamm", "element": "earth", "speed_mult": 0.75,
		"note": "Gegner -25 % Tempo",
	},
	"ford": {
		"name": "Furt", "element": "water", "speed_mult": 0.85,
		"note": "Gegner -15 % Tempo",
	},
	"ash": {
		"name": "Aschefeld", "element": "fire", "speed_mult": 1.0, "burn_duration_mult": 1.5,
		"note": "Brennen hält 50 % länger",
	},
	"windpass": {
		"name": "Windpass", "element": "air", "speed_mult": 1.2,
		"note": "Gegner +20 % Tempo",
	},
}

# Wer schlaegt wen (Spiegel von ElementalSystem.WEAKNESSES, hier statisch fuer Tests)
const BEATS := {"water": "fire", "fire": "earth", "earth": "air", "air": "water"}
const FUSION_PARENTS := {
	"ice": ["water", "air"], "steam": ["water", "fire"],
	"lava": ["fire", "earth"], "nature": ["earth", "air"],
}

# Zuweisung pro Karte
const ZONE_COUNT_MIN := 2
const ZONE_COUNT_MAX := 4
const ZONE_LEN_MIN := 4
const ZONE_LEN_MAX := 7
const EDGE_MARGIN := 3      # erste/letzte Wegfelder bleiben normaler Erdweg
const MIN_GAP := 3          # mindestens so viele Erdweg-Felder zwischen zwei Zonen


static func zone_element(zone: String) -> String:
	return String(ZONES.get(zone, {}).get("element", ""))


static func zone_name(zone: String) -> String:
	return String(ZONES.get(zone, {}).get("name", ""))


static func speed_mult(zone: String) -> float:
	return float(ZONES.get(zone, {}).get("speed_mult", 1.0))


static func burn_duration_mult(zone: String) -> float:
	return float(ZONES.get(zone, {}).get("burn_duration_mult", 1.0))


# Schadensmultiplikator fuer einen Angriff mit attack_element auf einen Gegner in zone.
# Fusionen zaehlen mit ihren Elternelementen; trifft eines die Zone, gewinnt die
# Verstaerkung (wie ElementalSystem: "bester Elternteil").
static func damage_mult(attack_element: String, zone: String) -> float:
	var z_elem := zone_element(zone)
	if z_elem == "" or attack_element == "":
		return 1.0
	var elems: Array = FUSION_PARENTS.get(attack_element, [attack_element])
	if z_elem in elems:
		return BOOST_MULT
	if String(BEATS.get(z_elem, "")) in elems:
		return DAMPEN_MULT
	return 1.0


# Tooltip-Text der Wegzone, mehrzeilig (eine Zeile pro Aussage), z. B.
# "Furt (Wasser)" / "Gegner -15 % Tempo" / "Wasser-Türme ×1,25" / "Feuer-Türme ×0,75"
static func describe(zone: String) -> String:
	var z_elem := zone_element(zone)
	if z_elem == "":
		return ""
	var dampened := String(BEATS.get(z_elem, ""))
	return "%s\n%s\n%s-Türme ×%s\n%s-Türme ×%s" % [
		zone_name(zone), String(ZONES[zone]["note"]),
		_elem_name(z_elem), _fmt(BOOST_MULT), _elem_name(dampened), _fmt(DAMPEN_MULT),
	]


static func _elem_name(elem: String) -> String:
	return {"water": "Wasser", "fire": "Feuer", "earth": "Erde", "air": "Luft"}.get(elem, elem)


static func _fmt(value: float) -> String:
	return ("%.2f" % value).replace(".", ",")


# Verteilt 2-4 Zonen (je 4-7 Felder) auf den Weg. Rueckgabe parallel zu cells,
# "" = normaler Erdweg. Deterministisch fuer dasselbe RNG (Karten-Seed).
static func assign_zones(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[String]:
	var terrain: Array[String] = []
	terrain.resize(cells.size())
	terrain.fill("")
	var usable := cells.size() - 2 * EDGE_MARGIN
	if usable < ZONE_LEN_MIN:
		return terrain

	var types: Array = ZONES.keys()
	# Mischen mit dem uebergebenen RNG (Array.shuffle nutzt den globalen Zufall)
	for i in range(types.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = types[i]
		types[i] = types[j]
		types[j] = tmp

	var wanted := rng.randi_range(ZONE_COUNT_MIN, ZONE_COUNT_MAX)
	# Weg in gleich grosse Abschnitte teilen, je Abschnitt hoechstens eine Zone:
	# verteilt die Zonen ueber die ganze Strecke statt sie zu buendeln.
	var segment := float(usable) / wanted
	var last_end := -MIN_GAP - 1
	var placed := 0
	for z in range(wanted):
		var seg_start := EDGE_MARGIN + int(z * segment)
		var seg_end := EDGE_MARGIN + int((z + 1) * segment)   # exklusiv
		var length := rng.randi_range(ZONE_LEN_MIN, ZONE_LEN_MAX)
		var earliest := maxi(seg_start, last_end + MIN_GAP + 1)
		var latest := mini(seg_end, cells.size() - EDGE_MARGIN) - length
		if latest < earliest:
			length = mini(seg_end, cells.size() - EDGE_MARGIN) - earliest
			latest = earliest
			if length < ZONE_LEN_MIN:
				continue
		var start := rng.randi_range(earliest, latest)
		var zone: String = types[placed % types.size()]
		for i in range(start, start + length):
			terrain[i] = zone
		last_end = start + length - 1
		placed += 1
	return terrain
