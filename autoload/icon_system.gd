# IconSystem.gd - Autoload für einheitliche Icon-Verwaltung
extends Node

const ICON_PATH := "res://assets/icons/"
const ELEMENTAL_PATH := "res://assets/elemental_symbols/"
const DEFAULT_SIZE := 16

# Icon-Registry: Kurzname -> [Pfad-Präfix, Dateiname]
var icons := {
	# Ressourcen
	"gold": "gold.png",
	"life": "life.png",
	"supply": "supply.png",
	"upgrades": "upgrades.png",
	"inventory": "inventory.png",
	"path": "path.png",
	"warning": "warning.png",
	"play": "play.png",
	"characters": "characters.png",
	"exit": "exit.png",
	"settings": "settings.png",
	
	"ability_lightning": "ability_lightning.png",
	"ability_frost": "ability_frost.png",
	"ability_meteor": "ability_meteor.png",
	"ability_earthquake": "ability_earthquake.png",
	
	# Elemente (in assets/icons)
	"fire": "element_fire.png",
	"ice": "element_ice.png",
	"lightning": "element_lightning.png",
	"earth": "element_earth.png",
	"nature": "element_nature.png",
	"water": "element_water.png",
	"air": "element_air.png",
	"steam": "element_steam.png",
	"lava": "element_lava.png",
	
	# Kerne
	"core": "core.png",
	"core_fire": "core_fire.png",
	"core_ice": "core_ice.png",
	"core_lightning": "core_lightning.png",
	"core_earth": "core_earth.png",
	"core_nature": "core_nature.png",
}

# Icons die im elemental_symbols Ordner liegen
var elemental_icons := {
	"water_elem": "water_element.png",
	"fire_elem": "fire_element.png", 
	"earth_elem": "earth_element.png",
	"air_elem": "air_element.png",
	"four_elements": "four_elements.png",
}

# Cache für geladene Texturen
var _texture_cache := {}


# Gibt den vollständigen Pfad für ein Icon zurück
func get_icon_path(icon_name: String) -> String:
	if icons.has(icon_name):
		return ICON_PATH + icons[icon_name]
	if elemental_icons.has(icon_name):
		return ELEMENTAL_PATH + elemental_icons[icon_name]
	push_warning("IconSystem: Unbekanntes Icon '%s'" % icon_name)
	return ""


# Lädt und cached eine Icon-Textur
func get_texture(icon_name: String) -> Texture2D:
	if _texture_cache.has(icon_name):
		return _texture_cache[icon_name]
	
	var path := get_icon_path(icon_name)
	if path.is_empty():
		return null
	
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_texture_cache[icon_name] = tex
		return tex
	
	push_warning("IconSystem: Icon-Datei nicht gefunden: %s" % path)
	return null


# BBCode für RichTextLabel - fügt Icon inline ein
func bb(icon_name: String, size: int = DEFAULT_SIZE) -> String:
	var path := get_icon_path(icon_name)
	if path.is_empty():
		return "[?]"
	return "[img=%dx%d]%s[/img]" % [size, size, path]


# Erstellt ein TextureRect-Node mit dem Icon
func create_icon_node(icon_name: String, size: int = DEFAULT_SIZE) -> TextureRect:
	var tex := get_texture(icon_name)
	if tex == null:
		return null
	
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# Hilfsfunktion: Text mit Icon davor (für RichTextLabel)
func text_with_icon(icon_name: String, text: String, size: int = DEFAULT_SIZE) -> String:
	return "%s %s" % [bb(icon_name, size), text]


# Hilfsfunktion: Zahl mit Icon (z.B. "🪙 500")
func value_with_icon(icon_name: String, value, size: int = DEFAULT_SIZE) -> String:
	return "%s %s" % [bb(icon_name, size), str(value)]


# Registriert ein neues Icon zur Laufzeit
func register_icon(short_name: String, filename: String) -> void:
	icons[short_name] = filename
	# Cache invalidieren falls bereits geladen
	if _texture_cache.has(short_name):
		_texture_cache.erase(short_name)


# Erstellt ein RichTextLabel mit BBCode-Unterstützung für Icons
func create_rich_label(min_width: float = 120.0, min_height: float = 20.0) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(min_width, min_height)
	return label
