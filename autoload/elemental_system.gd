# elemental_system.gd
# Autoload für Elementar-Interaktionen und Damage-Modifikatoren
extends Node

# Elemente
const ELEMENTS := ["neutral", "water", "fire", "earth", "air"]
const ELEMENTAL_TYPES := ["water", "fire", "earth", "air"]

# Schwächen-System: Key ist schwach gegen Value (nimmt mehr Schaden)
# Wasser > Feuer > Natur/Erde > Luft > Wasser (Kreis)
const WEAKNESSES := {
	"fire": "water",      # Feuer ist schwach gegen Wasser
	"water": "air",       # Wasser ist schwach gegen Luft  
	"air": "earth",       # Luft ist schwach gegen Erde
	"earth": "fire",      # Erde ist schwach gegen Feuer
}

# Resistenzen (umgekehrte Schwächen)
const RESISTANCES := {
	"water": "fire",      # Wasser resistent gegen Feuer
	"fire": "earth",      # Feuer resistent gegen Erde
	"earth": "air",       # Erde resistent gegen Luft
	"air": "water",       # Luft resistent gegen Wasser
}

# Damage Multiplikatoren
const WEAKNESS_MULTIPLIER := 1.5      # 50% mehr Schaden bei Schwäche
const RESISTANCE_MULTIPLIER := 0.6    # 40% weniger Schaden bei Resistenz
const NEUTRAL_MULTIPLIER := 1.0

# Kombinations-Elemente und ihre Basis-Elemente
const COMBO_ELEMENTS := {
	"ice": ["water", "air"],
	"steam": ["water", "fire"],
	"lava": ["fire", "earth"],
	"nature": ["earth", "air"]
}


func _ready() -> void:
	print("[ElementalSystem] Initialisiert")


# Berechnet Damage-Multiplikator basierend auf Angreifer- und Verteidiger-Element
func get_damage_multiplier(attacker_element: String, defender_element: String) -> float:
	# Neutral hat keine Vor-/Nachteile
	if attacker_element == "neutral" or attacker_element == "" or defender_element == "neutral" or defender_element == "":
		return NEUTRAL_MULTIPLIER
	
	# Kombinations-Elemente auflösen
	var attack_elements := _resolve_element(attacker_element)
	
	var best_multiplier := NEUTRAL_MULTIPLIER
	
	for atk_elem in attack_elements:
		# Prüfe ob Verteidiger schwach gegen Angreifer ist
		if WEAKNESSES.get(defender_element) == atk_elem:
			best_multiplier = maxf(best_multiplier, WEAKNESS_MULTIPLIER)
		# Prüfe ob Verteidiger resistent gegen Angreifer ist
		elif RESISTANCES.get(defender_element) == atk_elem:
			best_multiplier = minf(best_multiplier, RESISTANCE_MULTIPLIER)
	
	return best_multiplier


# Löst Kombinations-Elemente in Basis-Elemente auf
func _resolve_element(element: String) -> Array[String]:
	if COMBO_ELEMENTS.has(element):
		var result: Array[String] = []
		for e in COMBO_ELEMENTS[element]:
			result.append(e)
		return result
	return [element] as Array[String]


# Gibt das effektivste Element gegen ein Verteidiger-Element zurück
func get_effective_element(defender_element: String) -> String:
	if defender_element == "neutral" or defender_element == "":
		return "neutral"
	return WEAKNESSES.get(defender_element, "neutral")


# Prüft ob ein Element effektiv gegen ein anderes ist
func is_effective(attacker_element: String, defender_element: String) -> bool:
	return get_damage_multiplier(attacker_element, defender_element) > NEUTRAL_MULTIPLIER


# Prüft ob ein Element resistent gegen ein anderes ist
func is_resistant(attacker_element: String, defender_element: String) -> bool:
	return get_damage_multiplier(attacker_element, defender_element) < NEUTRAL_MULTIPLIER


# Gibt Farbton für Element zurück
func get_element_color(element: String) -> Color:
	match element:
		"water": return Color(0.3, 0.6, 1.0)
		"fire": return Color(1.0, 0.4, 0.2)
		"earth": return Color(0.6, 0.4, 0.2)
		"air": return Color(0.8, 0.9, 1.0)
		"ice": return Color(0.7, 0.9, 1.0)
		"steam": return Color(0.7, 0.7, 0.8)
		"lava": return Color(1.0, 0.3, 0.0)
		"nature": return Color(0.3, 0.8, 0.2)
		_: return Color.WHITE


# Gibt Element-Symbol zurück
func get_element_symbol(element: String) -> String:
	match element:
		"water": return "💧"
		"fire": return "🔥"
		"earth": return "🪨"
		"air": return "💨"
		"ice": return "❄"
		"steam": return "♨"
		"lava": return "🌋"
		"nature": return "🌿"
		_: return ""


# Generiert zufälliges Element für Gegner basierend auf Wave
func generate_enemy_element(wave: int) -> String:
	# Frühe Wellen: Mehr neutrale Gegner
	var neutral_chance := maxf(0.2, 0.8 - wave * 0.05)
	
	if randf() < neutral_chance:
		return "neutral"
	
	# Zufälliges Element wählen
	return ELEMENTAL_TYPES[randi() % ELEMENTAL_TYPES.size()]


# Gibt Info-Text für Elementar-Interaktion zurück
func get_interaction_text(attacker: String, defender: String) -> String:
	var mult := get_damage_multiplier(attacker, defender)
	if mult > NEUTRAL_MULTIPLIER:
		return "Effektiv! (x%.1f)" % mult
	elif mult < NEUTRAL_MULTIPLIER:
		return "Resistent (x%.1f)" % mult
	return ""
	
# Gibt BBCode für RichTextLabels zurück
func get_element_bb(element: String, size: int = 16) -> String:
	if IconSystem:
		return IconSystem.bb(element, size)
	return get_element_symbol(element)  # Fallback auf Emoji


# Gibt die Textur direkt zurück (für TextureRect, Button.icon, etc.)
func get_element_texture(element: String) -> Texture2D:
	if IconSystem:
		return IconSystem.get_texture(element)
	return null
