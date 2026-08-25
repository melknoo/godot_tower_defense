extends RefCounted
class_name SymbolFont

## Haengt die Symbol-/Emoji-Fallbacks hinter einen Projektfont.
##
## Weder Clarity.ttf noch PixelOperator8 haben Glyphen fuer 🔥 ⚡ ★ → usw. Auf
## Desktop und Android holt Godot die aus System-Fonts (Windows: Segoe UI Emoji).
## Im Browser gibt es diese Schnittstelle nicht - dort erscheinen ohne Fallback
## Tofu-Kaestchen. Die beiden Subsets decken genau die 54 Zeichen ab, die im UI
## vorkommen; gebaut von `tools/build_symbol_font.py`.
##
## Reihenfolge zaehlt: ui_emoji zuerst, damit z. B. ❄ und ⚡ farbig kommen wie auf
## dem Desktop, und nicht als monochrome Outline aus ui_symbols.

const EMOJI_PATH := "res://assets/fonts/ui_emoji.ttf"
const SYMBOLS_PATH := "res://assets/fonts/ui_symbols.ttf"

static var _fallbacks: Array[Font] = []
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for path in [EMOJI_PATH, SYMBOLS_PATH]:
		var font := load(path) as Font
		if font:
			_fallbacks.append(font)
		else:
			push_warning("[SymbolFont] Fallback-Font fehlt: %s" % path)


## Ergaenzt die Fallbacks von `font` (idempotent, mehrfach aufrufbar).
static func install(font: Font) -> void:
	if font == null:
		return
	_load()
	var current := font.fallbacks
	for fb in _fallbacks:
		if not current.has(fb):
			current.append(fb)
	font.fallbacks = current
