# IconSystem.gd - Autoload für einheitliche Icon-Verwaltung
extends Node

const ICON_PATH := "res://assets/icons/"
const ELEMENTAL_PATH := "res://assets/elemental_symbols/"
const DEFAULT_SIZE := 16

# Icon-Registry: Kurzname -> [Pfad-Präfix, Dateiname]
var icons := {
	# Ressourcen
	"gold": "gold.png",
	"coin": "coin.png",
	"close": "close.png",
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
	"abilities": "abilities.png",
	"star_full": "star_full.png",
	"star_empty": "star_empty.png",
	"damage": "damage.png",
	"range": "range.png",
	"fire_rate": "fire_rate.png",
	"cooldown": "fire_rate.png",
	
	"ability_lightning": "ability_lightning.png",
	"ability_frost": "ability_frost.png",
	"ability_meteor": "ability_meteor.png",
	"ability_earthquake": "ability_earthquake.png",
	"ability_chain_lightning": "ability_chain_lightning.png",
	"ability_fissure": "ability_fissure.png",
	"ability_ice_wall": "ability_ice_wall.png",
	"ability_inferno": "ability_inferno.png",
	"ability_meteor_shower": "ability_meteor_shower.png",
	"ability_sandstorm": "ability_sandstorm.png",
	"ability_tsunami": "ability_tsunami.png",
	
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

# Ersatz fuer registrierte Icons, deren Datei noch fehlt (siehe ASSETS_TODO.md).
# Ohne Ersatz liefert bb() nur "[?]" und create_icon_node() gar nichts.
const FALLBACKS := {
	"warning": "damage",
	"core_fire": "core",
	"core_ice": "core",
	"core_lightning": "core",
	"core_earth": "core",
	"core_nature": "core",
}

# --- Prozedurale Charakter-Portraits ------------------------------------------
# Alle `char_*`-Icons ohne Asset werden aus der Charakter-ID heraus gezeichnet:
# gleiche Bildsprache, aber auf einen Blick unterscheidbar. Rein deterministisch,
# damit ein Charakter ueber Sitzungen hinweg dasselbe Portrait behaelt.
const CHAR_ICON_PREFIX := "char_"
const PORTRAIT_SIZE := 32
# Kopfbedeckungen; die Auswahl haengt an der Charakter-ID, nicht am Element -
# zwei Feuer-Charaktere sehen dadurch verschieden aus.
const PORTRAIT_HEADGEAR := ["hood", "helmet", "crown", "horns"]

# Cache für geladene Texturen
var _texture_cache := {}
# Cache für aufgeloeste Pfade - bb() laeuft bei jedem HUD-Update durch,
# die Existenzpruefung soll nicht pro Aufruf ins Dateisystem gehen.
var _path_cache := {}


# Gibt den vollständigen Pfad für ein Icon zurück.
# Existiert die Datei nicht, wird auf ein registriertes Ersatz-Icon ausgewichen.
func get_icon_path(icon_name: String) -> String:
	if _path_cache.has(icon_name):
		return _path_cache[icon_name]
	var resolved := _resolve_icon_path(icon_name)
	_path_cache[icon_name] = resolved
	return resolved


func _resolve_icon_path(icon_name: String) -> String:
	var path := _raw_icon_path(icon_name)
	if not path.is_empty() and ResourceLoader.exists(path):
		return path

	if FALLBACKS.has(icon_name):
		var fallback_path := _raw_icon_path(FALLBACKS[icon_name])
		if ResourceLoader.exists(fallback_path):
			return fallback_path

	if path.is_empty():
		push_warning("IconSystem: Unbekanntes Icon '%s'" % icon_name)
	else:
		push_warning("IconSystem: Icon-Datei nicht gefunden: %s" % path)
	return ""


func _raw_icon_path(icon_name: String) -> String:
	if icons.has(icon_name):
		return ICON_PATH + icons[icon_name]
	if elemental_icons.has(icon_name):
		return ELEMENTAL_PATH + elemental_icons[icon_name]
	return ""


# Lädt und cached eine Icon-Textur
func get_texture(icon_name: String) -> Texture2D:
	if _texture_cache.has(icon_name):
		return _texture_cache[icon_name]

	# Charakter-Portraits existieren noch nicht als Assets (siehe ASSETS_TODO.md). Statt
	# alle Charaktere eines Elements gleich aussehen zu lassen, wird hier ein
	# unverwechselbares Portrait erzeugt. Eine echte Datei gewinnt immer: sobald
	# assets/icons/<name>.png existiert und registriert ist, greift der Zweig unten.
	if icon_name.begins_with(CHAR_ICON_PREFIX) and _raw_icon_path(icon_name).is_empty():
		var generated := _generate_character_portrait(icon_name)
		_texture_cache[icon_name] = generated
		return generated

	var path := get_icon_path(icon_name)
	if path.is_empty():
		return null

	var tex := load(path) as Texture2D
	_texture_cache[icon_name] = tex
	return tex


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
	_texture_cache.erase(short_name)
	_path_cache.erase(short_name)


# Erstellt ein RichTextLabel mit BBCode-Unterstützung für Icons
func create_rich_label(min_width: float = 120.0, min_height: float = 20.0) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(min_width, min_height)
	return label


# === PROZEDURALE CHARAKTER-PORTRAITS =========================================

# Zeichnet ein 32x32-Portrait: Rahmen, Schultern, Kopf und eine von vier
# Kopfbedeckungen. Farben kommen aus der Charakter-Definition, die Kopfbedeckung aus
# der ID - dadurch unterscheiden sich auch zwei Charaktere desselben Elements.
func _generate_character_portrait(icon_name: String) -> Texture2D:
	var char_id := icon_name.trim_prefix(CHAR_ICON_PREFIX)
	var base := Color(0.55, 0.55, 0.6)
	if AbilitySystem and AbilitySystem.CHARACTERS.has(char_id):
		base = AbilitySystem.CHARACTERS[char_id].get("color", base)

	var accent := base.lightened(0.35)
	var shadow := base.darkened(0.55)
	var skin := Color(0.93, 0.82, 0.7)
	var gear: String = PORTRAIT_HEADGEAR[_headgear_index(char_id)]

	var image := Image.create(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# Wappen-Hintergrund mit abgeschraegten Ecken
	for y in range(2, 30):
		for x in range(2, 30):
			var inset := 0
			if y < 5:
				inset = 5 - y
			elif y > 26:
				inset = y - 26
			if x < 2 + inset or x > 29 - inset:
				continue
			var edge := x <= 3 + inset or x >= 28 - inset or y <= 3 or y >= 28
			image.set_pixel(x, y, shadow if edge else base.darkened(0.25))

	# Schultern
	for y in range(21, 28):
		var half := 4 + (y - 21)
		for x in range(16 - half, 16 + half):
			if x < 4 or x > 27:
				continue
			image.set_pixel(x, y, base)

	# Kopf
	_fill_disc(image, Vector2(15.5, 15.0), 5.6, skin)

	# Kopfbedeckung
	match gear:
		"hood":
			_fill_arc_top(image, Vector2(15.5, 15.0), 7.2, accent)
		"helmet":
			for y in range(8, 13):
				for x in range(9, 23):
					if Vector2(x, y).distance_to(Vector2(15.5, 15.0)) <= 7.0:
						image.set_pixel(x, y, accent)
			for y in range(13, 19):   # Nasenschutz
				image.set_pixel(15, y, accent)
				image.set_pixel(16, y, accent)
		"crown":
			for spike_x in [11, 15, 20]:
				for y in range(6, 11):
					image.set_pixel(spike_x, y, accent)
					image.set_pixel(spike_x + 1, y, accent)
			for x in range(10, 22):
				image.set_pixel(x, 10, accent)
				image.set_pixel(x, 11, accent)
		"horns":
			for i in range(5):
				image.set_pixel(9 - i / 2, 13 - i, accent)
				image.set_pixel(10 - i / 2, 13 - i, accent)
				image.set_pixel(22 + i / 2, 13 - i, accent)
				image.set_pixel(23 + i / 2, 13 - i, accent)
			_fill_arc_top(image, Vector2(15.5, 15.0), 6.6, accent)

	# Elementarer Akzentpunkt unten rechts
	for y in range(24, 28):
		for x in range(23, 27):
			image.set_pixel(x, y, accent)

	return ImageTexture.create_from_image(image)


# Kopfbedeckung anhand der Position in CHARACTERS, nicht per Hash: ein Hash kollidierte
# ausgerechnet bei Pyromant und Aschenweberin, also dem Paar, das sich wegen gleicher
# Elementfarbe am dringendsten unterscheiden muss. Der Versatz `+ index / 4` sorgt dafuer,
# dass der zweite Viererblock gegenueber dem ersten verschoben ist - die beiden
# Charaktere eines Elements liegen genau vier Plaetze auseinander.
func _headgear_index(char_id: String) -> int:
	var count := PORTRAIT_HEADGEAR.size()
	if AbilitySystem:
		var index: int = AbilitySystem.CHARACTERS.keys().find(char_id)
		if index >= 0:
			return (index + index / count) % count
	return _stable_index(char_id, count)


# Deterministischer Index aus einer ID - `String.hash()` waere versionsabhaengig.
func _stable_index(text: String, modulo: int) -> int:
	var sum := 0
	for i in range(text.length()):
		sum += text.unicode_at(i) * (i + 1)
	return sum % maxi(1, modulo)


func _fill_disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(PORTRAIT_SIZE):
		for x in range(PORTRAIT_SIZE):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)


# Nur die obere Haelfte eines Kreises - fuer Kapuzen und Helmschalen.
func _fill_arc_top(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(PORTRAIT_SIZE):
		if float(y) > center.y:
			continue
		for x in range(PORTRAIT_SIZE):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
