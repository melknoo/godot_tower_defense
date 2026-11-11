extends Node
## ui_theme.gd — zentrale UI-Tokens für Arcane Bastion
##
## Registrierung: Project Settings → Globals → Autoload
##   Pfad: res://ui/ui_theme.gd   Name: UI   (Enable ✔)
##
## Stil: Holz-Theme aus dem Ninja-Adventure-Pack (CC0) - dieselbe Pixel-Sprache wie
## Figuren und Boden: schwarze 1-px-Outline, Pixel-Ecken, warmes Oliv/Braun/Orange.
## Die 9-Patch-Grafiken baut tools/ninja_import/build_assets.py --ui nach
## assets/ui/ninja/ (vorskaliert x NINJA_SCALE). Ein Font: NinjaAdventure (9 px Raster).
##
## Regeln, die dieser Code durchsetzt:
##   1. Panels/Buttons sind StyleBoxTexture aus den Ninja-9-Patches, keine Rundungen.
##   2. Schrift nur in Vielfachen von 9 px (snap_font_size), sonst verwischt das Raster.
##   3. Orange ist knapp: Primär-Button, Fokus, Währung, Rahmen-Panel.
##   4. Farbe bedeutet immer etwas (Element, Rarity, Status). Keine Dekorfarbe.

# ═══ Hintergrund-Ebenen ════════════════════════════════════════
const BG_0        := Color("231F18")   # Screen-Backdrop, Menühintergrund
const BG_1        := Color("46402E")   # Panel / Overlay — der Standard (Pack-Oliv)
const BG_2        := Color("5A5240")   # Sektion, Listenzeile, Panel-Header
const BG_3        := Color("34312C")   # Vertiefung: Item-Slot, Balken-Track, Input
const SCRIM       := Color("131B1BB8") # 72 % Abdunkelung unter modalen Overlays

# ═══ Rahmen ════════════════════════════════════════════════════
const BORDER_BRASS := Color("F06733")  # Rahmen-Akzent (Pack-Orange); Name historisch
const BORDER_SOFT  := Color("131B1B")  # Outline wie in der Pixel-Art
const BORDER_SHADE := Color("131B1B")
const BORDER_FOCUS := Color("FFAD55")  # Hover / Fokus / Selektion
const BRASS_INNER  := Color("9B513C")  # Holzbraun

# ═══ Text ══════════════════════════════════════════════════════
const TEXT_PRIMARY   := Color("F4EAD8")
const TEXT_SECOND    := Color("CBBC9C")
const TEXT_DISABLED  := Color("8A7D63")
const TEXT_ON_ACCENT := Color("131B1B")  # Text auf gefüllter Orangefläche

# ═══ Semantik ══════════════════════════════════════════════════
const ACCENT       := Color("FFAD55")
const ACCENT_HOVER := Color("FFD09E")
const ACCENT_PRESS := Color("F06733")
const SUCCESS      := Color("5FBF7A")
const WARNING      := Color("E8963C")
const DANGER       := Color("E0524B")
const DANGER_HOVER := Color("3A1F1F")   # Füllung bei Hover auf Danger-Button

# ═══ Elementfarben ═════════════════════════════════════════════
## Als Set konstruiert: gleiche Helligkeit/Sättigung (oklch L≈0.74, C≈0.15),
## nur der Hue variiert. Erde und Dampf sind absichtlich entsättigt, damit sie
## nicht mit Messing bzw. Eis kollidieren. Alle ≥ 5.5:1 auf BG_1.
const ELEMENT := {
	"feuer":   Color("FF7A45"),
	"wasser":  Color("3E9BE8"),
	"erde":    Color("B5854F"),
	"luft":    Color("B9B6EE"),
	"eis":     Color("79E1E6"),
	"lava":    Color("E24545"),
	"natur":   Color("67CC63"),
	"dampf":   Color("9BB6C2"),
	"neutral": Color("9EAAB9"),
}

func el(id: String) -> Color:
	return ELEMENT.get(id, ELEMENT["neutral"])

## 18 %-Flächenfüllung — die einzige erlaubte Element-Hintergrundfüllung.
func el_fill(id: String) -> Color:
	var c := el(id)
	c.a = 0.18
	return c

# ═══ Rarity ════════════════════════════════════════════════════
## Aus dem Elementset abgeleitet: Grau = Sekundärtext, Grün = Natur,
## Blau = Wasser, Violett ist der einzige freie Hue, Legendary = Messing.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const RARITY := {
	Rarity.COMMON:    Color("9EAAB9"),
	Rarity.UNCOMMON:  Color("67CC63"),
	Rarity.RARE:      Color("3E9BE8"),
	Rarity.EPIC:      Color("B36BE8"),
	Rarity.LEGENDARY: Color("E0B44E"),
}

func rarity(r: int) -> Color:
	return RARITY.get(r, RARITY[Rarity.COMMON])

# ═══ Typo-Skala (px @ 1920×1080) ═══════════════════════════════
## Der NinjaAdventure-Font hat ein 9-px-Raster (2048 Einheiten / 9) - nur Vielfache
## von 9 bleiben pixelscharf. Berechnete Größen über snap_font_size().
const FONT_GRID  := 9
const FS_DISPLAY := 45   # Spieltitel, Sieg/Niederlage
const FS_TITLE   := 36   # Panel-Header (genau 1× pro Panel)
const FS_SECTION := 27   # Sektionstitel, Buttonlabel, hervorgehobene Werte
const FS_BODY    := 18   # Stats, Beschreibungen, Listen
const FS_MICRO   := 18   # Labels, Hotkeys, Fußnoten

## Rundet eine Schriftgröße aufs Font-Raster. Untergrenze 18 (2x): 9 px ist die native
## Groesse und auf 1080p kaum lesbar.
func snap_font_size(px: float) -> int:
	return maxi(FONT_GRID * 2, int(round(px / FONT_GRID)) * FONT_GRID)

## Nur MICRO und SECTION dürfen ALL CAPS + letter_spacing 2.
## BODY nie gesperrt, nie zentriert: links Label, rechts Wert.
const TRACKING_WIDE := 2

# ═══ Spacing · 4er-Raster ══════════════════════════════════════
const SP_1 := 4    # Icon↔Text, Chip-Innenabstand
const SP_2 := 8    # Listenzeilen, Gap im Slot-Grid
const SP_3 := 12   # Button-Innenabstand vertikal
const SP_4 := 16   # Sektionsabstand, Karten-Padding
const SP_5 := 24   # Panel-Padding — IMMER 24, keine Ausnahme
const SP_6 := 32   # Blockabstand großer Overlays
const SP_7 := 48   # Screenrand / Safe-Margin, Menü-Rhythmus

# ═══ Geometrie ═════════════════════════════════════════════════
const RADIUS        := 0     # überall, ohne Ausnahme
const BW_PANEL      := 2     # Panel, Button, Karte
const BW_HAIRLINE   := 1     # Trennlinie, Innenschattenlinie
const BW_ELEMENT    := 3     # linke Elementkante
const BW_SELECTED   := 4     # Fokusrahmen bei Selektion
const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW_COLOR  := Color("06081080")   # hart, nie weich (shadow_size = 0)

const BTN_HEIGHT   := 56
const ICON_BTN     := 56    # 56×56; Mindest-Trefferfläche 44 auch bei 1280
const SLOT_SIZE    := 64
const TOPBAR_H     := 64
const BOTTOMBAR_H  := 168
const SCROLLBAR_W  := 8

## Feste Panel-Breiten — nie ad-hoc-Werte
const PANEL_S  := 480
const PANEL_M  := 720
const PANEL_L  := 1040
const PANEL_XL := 1440

## Balkenhöhen
const BAR_H_HP       := 12
const BAR_H_WAVE     := 12
const BAR_H_COOLDOWN := 8
const BAR_H_XP       := 8

# ═══ StyleBox-Fabrik ═══════════════════════════════════════════

func _box(fill: Color, border: Color, w: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(w)
	s.border_color = border
	s.set_corner_radius_all(RADIUS)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = false
	return s

# ─── Ninja-9-Patches (assets/ui/ninja, x NINJA_SCALE vorskaliert) ───
const NINJA_DIR := "res://assets/ui/ninja/"
const NINJA_SCALE := 3
var _tex_cache := {}

func _ninja_tex(tex_name: String) -> Texture2D:
	if not _tex_cache.has(tex_name):
		var path := NINJA_DIR + tex_name + ".png"
		_tex_cache[tex_name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[tex_name]

## margins = Quellrand in Pack-Pixeln [links, oben, rechts, unten].
func _nine(tex_name: String, margins: Array, pad_h: int, pad_v: int, tint := Color.WHITE) -> StyleBox:
	var tex := _ninja_tex(tex_name)
	if tex == null:   # Assets fehlen (z. B. vor dem ersten --ui-Lauf): flacher Ersatz
		return _box(BG_1, BORDER_SOFT, BW_PANEL, pad_h)
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margins[0] * NINJA_SCALE
	s.texture_margin_top = margins[1] * NINJA_SCALE
	s.texture_margin_right = margins[2] * NINJA_SCALE
	s.texture_margin_bottom = margins[3] * NINJA_SCALE
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.modulate_color = tint
	return s

const M_BOX := [3, 3, 3, 3]      # panel/section/tooltip/cell/focus: 2-px-Ecke + Outline
const M_FRAMED := [5, 5, 5, 5]   # Holzrahmen mit Innenkante
const M_BUTTON := [3, 2, 3, 2]   # 16x8-Buttons

## Panel / Overlay: Pack-Oliv mit schwarzer Pixel-Outline.
func panel() -> StyleBox:
	return _nine("panel", M_BOX, SP_5, SP_5)

## Rahmen-Panel für modale Overlays (Pause, Upgrades, Archiv): Holzrahmen.
func panel_framed() -> StyleBox:
	return _nine("panel_framed", M_FRAMED, SP_6, SP_6)

## Panel-Header-Leiste: BG_2 mit 1 px Messing-Innenlinie unten.
func panel_header() -> StyleBoxFlat:
	var s := _box(BG_2, BRASS_INNER, 0, SP_4)
	s.border_width_bottom = BW_HAIRLINE
	s.content_margin_left = SP_5
	s.content_margin_right = SP_5
	return s

func section() -> StyleBox:
	return _nine("section", M_BOX, SP_4, SP_4)

## Listenzeile mit Zebra: Hinterlegung ist BG_2 — HELLER als das Panel,
## niemals dunkler als der eigene Text.
func row(striped: bool) -> StyleBoxFlat:
	return _box(BG_2 if striped else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, SP_3)

func slot() -> StyleBox:
	return _nine("cell", M_BOX, SP_1, SP_1)

func slot_rarity(r: int) -> StyleBoxFlat:
	var s := _box(BG_3, rarity(r), BW_PANEL, SP_1)
	if r == Rarity.LEGENDARY:
		s.shadow_color = BRASS_INNER   # 1 px Innenlinie als Prestige-Marker
		s.shadow_size = 1
		s.shadow_offset = Vector2.ZERO
	return s

func slot_selected() -> StyleBox:
	return _nine("focus", M_BOX, SP_1, SP_1)

## Primär-Button: genau EINER pro Panel. Der orange Pack-Button.
func btn_primary(state := "normal") -> StyleBox:
	var s := _nine("button_" + state, M_BUTTON, SP_5, SP_2)
	if state == "pressed":   # der Pack-Button sinkt 1 Pack-Pixel ein - Text mitnehmen
		s.content_margin_top += NINJA_SCALE
		s.content_margin_bottom -= NINJA_SCALE
	return s

## Sekundär-Button: dunkle Holzfläche, Hover hellt auf.
func btn_secondary(state := "normal") -> StyleBox:
	var tint := Color.WHITE
	match state:
		"hover":    tint = Color(1.35, 1.3, 1.2)
		"pressed":  tint = Color(0.8, 0.8, 0.8)
		"disabled": tint = Color(1, 1, 1, 0.55)
	var s := _nine("section", M_BOX, SP_5, SP_2, tint)
	if state == "pressed":
		s.content_margin_top += NINJA_SCALE
		s.content_margin_bottom -= NINJA_SCALE
	return s

## Destruktiv (Verkaufen, Beenden): rot getönter Pack-Button.
func btn_danger(state := "normal") -> StyleBox:
	var tint := Color(1.0, 0.55, 0.55)
	if state == "disabled":
		tint = Color(1, 1, 1, 0.55)
	var s := _nine("button_" + state, M_BUTTON, SP_5, SP_2, tint)
	if state == "pressed":
		s.content_margin_top += NINJA_SCALE
		s.content_margin_bottom -= NINJA_SCALE
	return s

## Reine Icon-Buttons: kleine Innenabstände, Fokusrahmen bei Hover/Pressed.
func btn_icon(state := "normal") -> StyleBox:
	match state:
		"hover", "pressed":
			return _nine("focus", M_BOX, SP_1, SP_1)
		"disabled":
			return _nine("section", M_BOX, SP_1, SP_1, Color(1, 1, 1, 0.55))
	return _nine("section", M_BOX, SP_1, SP_1)

## Karte mit linker Elementkante (Turmkarte, Synergiezeile, Panel-Header).
func element_card(id: String, selected := false) -> StyleBoxFlat:
	var s := _box(BG_2, BORDER_FOCUS if selected else BORDER_SOFT,
			BW_SELECTED if selected else BW_PANEL, SP_4)
	s.border_width_left = BW_ELEMENT
	if selected:
		s.bg_color = el_fill(id).blend(BG_2)
	return s

## Shop-Karte (Bottombar-Turmreihe): fixe Box, nie textabhängig (Phase3b_ShopRow_Konzept.md).
## states: "normal", "hover", "selected", "disabled".
func shop_card(state := "normal") -> StyleBox:
	# pad=0: der Innenabstand kommt aus der expliziten MarginContainer in shop_card.gd,
	# nicht aus der StyleBox — sonst verdoppelt sich das Padding.
	match state:
		"hover":
			return _nine("section", M_BOX, 0, 0, Color(1.35, 1.3, 1.2))
		"selected":
			return _nine("focus", M_BOX, 0, 0)
		"disabled":
			return _nine("section", M_BOX, 0, 0, Color(1, 1, 1, 0.6))
	return _nine("section", M_BOX, 0, 0)

## Fortschrittsbalken. track = true → Hintergrund, false → Füllung.
func bar(track: bool, tint := ACCENT) -> StyleBoxFlat:
	if track:
		return _box(BG_3, BORDER_SHADE, BW_HAIRLINE, 0)
	return _box(tint, tint, 0, 0)

## HP-Farbe: harter Wechsel, kein Verlauf.
func hp_color(ratio: float) -> Color:
	if ratio < 0.25:
		return DANGER
	if ratio < 0.5:
		return WARNING
	return SUCCESS

func tooltip() -> StyleBox:
	return _nine("tooltip", M_BOX, SP_4, SP_3)

# ═══ Theme-Aufbau ══════════════════════════════════════════════
## Einmal in _ready() der Root-Control aufrufen und zuweisen:
##     get_tree().root.theme = UI.build_theme()
## Alles darunter erbt. Danach KEINE Farb- oder Font-Overrides
## mehr in einzelnen Szenen setzen.

## NinjaAdventure (Pack-Font) fuer alles. Ihm fehlen u. a. ß · × → – … € - die kommen
## aus PixelOperator8, Emoji/Symbole danach aus den SymbolFont-Subsets.
const FONT_REGULAR  := "res://assets/fonts/ninja_normal.ttf"
const FONT_FALLBACK := "res://ui/fonts/pixel_operator/PixelOperator8.ttf"

## Das Leerzeichen des Pack-Fonts ist nur 1 Font-Pixel breit - deutsche Saetze lesen
## sich dann wie ein Wort. Zusaetzlicher Wortabstand in Bildschirmpixeln.
const FONT_WORD_SPACING := 6

var _font_cache: Font = null

func _prepare_pixel_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f: FontFile = load(path)
	# Pixelschriften: kein Filter, keine Mipmaps, sonst matscht das Raster.
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.generate_mipmaps = false
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	# Immer in Nenngroesse rastern: bei Fenstern != 1920x1080 (2560er-Monitor, itch-
	# Embed 1280x720) wuerde Godot sonst z. B. bei 24 px rastern - das 9-px-Raster
	# zerfaellt, duenne Striche (i, l) verschwinden. So skaliert die Leinwand die
	# fertigen Pixel (nearest) wie bei der Welt-Grafik.
	f.oversampling = 1.0
	return f

## Der eine UI-Font inkl. Fallback-Kette und Wortabstand (auch fuer VFX-Zahlen).
func ui_font() -> Font:
	if _font_cache:
		return _font_cache
	var f := _prepare_pixel_font(FONT_REGULAR)
	if f == null:
		f = _prepare_pixel_font(FONT_FALLBACK)
		if f == null:
			return null
	else:
		var fallback := _prepare_pixel_font(FONT_FALLBACK)
		if fallback and not f.fallbacks.has(fallback):
			var fbs := f.fallbacks
			fbs.append(fallback)
			f.fallbacks = fbs
	# Symbole/Emoji aus den Subsets, sonst Tofu im Browser.
	SymbolFont.install(f)
	var spaced := FontVariation.new()
	spaced.base_font = f
	spaced.spacing_space = FONT_WORD_SPACING
	_font_cache = spaced
	return spaced

func build_theme() -> Theme:
	var t := Theme.new()
	var font := ui_font()
	if font:
		t.default_font = font
		# RichTextLabel [b]/[i] fielen ohne eigenen Eintrag auf den glatten Engine-Font
		# zurueck. Der Pack-Font hat keinen Bold-Schnitt - Hervorhebung ueber Farbe.
		for slot in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			t.set_font(slot, "RichTextLabel", font)
			t.set_font_size(slot + "_size", "RichTextLabel", FS_BODY)
	t.default_font_size = FS_BODY

	# Panel
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())

	# Button — Primär ist der Default; Sekundär/Danger per Theme-Variation.
	t.set_stylebox("normal", "Button", btn_primary())
	t.set_stylebox("hover", "Button", btn_primary("hover"))
	t.set_stylebox("pressed", "Button", btn_primary("pressed"))
	t.set_stylebox("disabled", "Button", btn_primary("disabled"))
	t.set_stylebox("focus", "Button", btn_primary("hover"))
	t.set_color("font_color", "Button", TEXT_PRIMARY)
	# Primär = oranger Pack-Button: heller Text mit schwarzer Pixel-Outline; Hover ist
	# der hellste Button-Zustand, dort dunkler Text.
	t.set_color("font_hover_color", "Button", TEXT_ON_ACCENT)
	t.set_color("font_pressed_color", "Button", TEXT_PRIMARY)
	t.set_color("font_outline_color", "Button", BORDER_SOFT)
	t.set_constant("outline_size", "Button", NINJA_SCALE)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_constant("h_separation", "Button", SP_2)   # Icon links, Label rechts —
	t.set_font_size("font_size", "Button", FS_SECTION)  # nie übereinander

	for variant in ["SecondaryButton", "DangerButton"]:
		t.add_type(variant)
		t.set_type_variation(variant, "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "SecondaryButton", btn_secondary(state))
		t.set_stylebox(state, "DangerButton", btn_danger(state))
	# Reine Icon-Buttons (Gravur, Aura-Buff, Schliessen-X): die Button-Stile mit SP_5
	# Seitenabstand liessen bei 40-48 px Breite keinen Platz fuers Icon.
	t.add_type("IconButton")
	t.set_type_variation("IconButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "IconButton", btn_icon(state))
	t.add_type("IconDangerButton")
	t.set_type_variation("IconDangerButton", "DangerButton")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var icon_box := btn_danger(state)
		icon_box.content_margin_left = SP_2
		icon_box.content_margin_right = SP_2
		icon_box.content_margin_top = SP_2
		icon_box.content_margin_bottom = SP_2
		t.set_stylebox(state, "IconDangerButton", icon_box)
	t.set_color("font_color", "SecondaryButton", TEXT_SECOND)
	t.set_color("font_hover_color", "SecondaryButton", ACCENT)
	t.set_color("font_color", "DangerButton", TEXT_PRIMARY)
	t.set_color("font_hover_color", "DangerButton", TEXT_PRIMARY)
	t.set_color("font_pressed_color", "DangerButton", TEXT_PRIMARY)

	# Label
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_font_size("font_size", "Label", FS_BODY)

	# ProgressBar
	t.set_stylebox("background", "ProgressBar", bar(true))
	t.set_stylebox("fill", "ProgressBar", bar(false))

	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", tooltip())
	t.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)
	t.set_font_size("font_size", "TooltipLabel", FS_BODY)

	# Scrollbar — Godot-Default-Grau ersetzen
	var track := _box(BG_1, Color(0, 0, 0, 0), 0, 0)
	var grab := _box(BORDER_SOFT, Color(0, 0, 0, 0), 0, 0)
	var grab_hl := _box(ACCENT, Color(0, 0, 0, 0), 0, 0)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, track)
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, grab_hl)
		t.set_stylebox("grabber_pressed", cls, grab_hl)

	# Separator
	var sep := _box(Color("232C38"), Color(0, 0, 0, 0), 0, 0)
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("separator", "VSeparator", sep)
	t.set_constant("separation", "HSeparator", BW_HAIRLINE)

	return t

func _ready() -> void:
	var theme := build_theme()
	get_tree().root.theme = theme
	# Das Root-Theme erreicht keine Controls unter einem CanvasLayer (das ganze HUD,
	# alle Overlays) - die fielen auf Godots Standard-Theme zurueck. Deshalb das
	# System-Theme komplett (Styles, Farben, Font, Groessen) ins Standard-Theme mergen.
	ThemeDB.get_default_theme().merge_with(build_theme())
	# Letzte Instanz fuer Controls ohne jeden Theme-Font: derselbe Pixel-Font samt
	# Fallback-Kette (Symbole/Emoji, sonst Tofu im Browser).
	var font := ui_font()
	if font:
		ThemeDB.fallback_font = font
	else:
		SymbolFont.install(ThemeDB.fallback_font)
