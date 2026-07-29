extends Node
## ui_theme.gd — zentrale UI-Tokens für Arcane Bastion
##
## Registrierung: Project Settings → Globals → Autoload
##   Pfad: res://ui/ui_theme.gd   Name: UI   (Enable ✔)
##
## Regeln, die dieser Code durchsetzt:
##   1. Ein Panel-Material im ganzen Spiel (dunkler Stein + 2 px Messingrahmen).
##   2. corner_radius ist IMMER 0 — Pixel-Art und Rundungen schließen sich aus.
##   3. Gold/Messing ist knapp: nur Fokus, Währung, Legendary, Panel-Rahmen.
##   4. Farbe bedeutet immer etwas (Element, Rarity, Status). Keine Dekorfarbe.

# ═══ Hintergrund-Ebenen ════════════════════════════════════════
const BG_0        := Color("0A0D13")   # Screen-Backdrop, Menühintergrund
const BG_1        := Color("141A24")   # Panel / Overlay — der Standard
const BG_2        := Color("1E2632")   # Sektion, Listenzeile, Panel-Header, Button
const BG_3        := Color("2A3442")   # Vertiefung: Item-Slot, Balken-Track, Input
const SCRIM       := Color("060810B8") # 72 % Abdunkelung unter modalen Overlays

# ═══ Rahmen ════════════════════════════════════════════════════
const BORDER_BRASS := Color("C79A3C")  # Panel-Außenrahmen
const BORDER_SOFT  := Color("3A4658")  # Karten, Slots, Trennlinien
const BORDER_SHADE := Color("0A0D13")  # 1 px Innenschatten = Tiefe ohne Blur
const BORDER_FOCUS := Color("E0B44E")  # Hover / Fokus / Selektion
const BRASS_INNER  := Color("6B5522")  # 1 px Innenlinie im Messingprofil

# ═══ Text ══════════════════════════════════════════════════════
const TEXT_PRIMARY   := Color("EDE6D6")  # 13.4:1 auf BG_1
const TEXT_SECOND    := Color("9EAAB9")  #  6.8:1 auf BG_1
const TEXT_DISABLED  := Color("5A6675")
const TEXT_ON_ACCENT := Color("10141B")  # Text auf gefüllter Messingfläche

# ═══ Semantik ══════════════════════════════════════════════════
const ACCENT       := Color("E0B44E")
const ACCENT_HOVER := Color("F2CB6E")
const ACCENT_PRESS := Color("B98E33")
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
## Nur diese fünf Größen. Untergrenze 16 — bei 1280×720 (Faktor 0.667)
## landet das bei ~11 px und bleibt gerade lesbar.
const FS_DISPLAY := 48   # Spieltitel, Sieg/Niederlage
const FS_TITLE   := 32   # Panel-Header (genau 1× pro Panel)
const FS_SECTION := 24   # Sektionstitel, Buttonlabel, hervorgehobene Werte
const FS_BODY    := 20   # Stats, Beschreibungen, Listen
const FS_MICRO   := 16   # Labels, Hotkeys, Fußnoten

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

## Panel / Overlay: BG_1, 2 px Messing, harter 4-px-Schatten.
func panel() -> StyleBoxFlat:
	var s := _box(BG_1, BORDER_BRASS, BW_PANEL, SP_5)
	s.shadow_color = SHADOW_COLOR
	s.shadow_size = 0
	s.shadow_offset = SHADOW_OFFSET
	return s

## Panel-Header-Leiste: BG_2 mit 1 px Messing-Innenlinie unten.
func panel_header() -> StyleBoxFlat:
	var s := _box(BG_2, BRASS_INNER, 0, SP_4)
	s.border_width_bottom = BW_HAIRLINE
	s.content_margin_left = SP_5
	s.content_margin_right = SP_5
	return s

func section() -> StyleBoxFlat:
	return _box(BG_2, BORDER_SOFT, BW_HAIRLINE, SP_4)

## Listenzeile mit Zebra: Hinterlegung ist BG_2 — HELLER als das Panel,
## niemals dunkler als der eigene Text.
func row(striped: bool) -> StyleBoxFlat:
	return _box(BG_2 if striped else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, SP_3)

func slot() -> StyleBoxFlat:
	return _box(BG_3, BORDER_SOFT, BW_PANEL, SP_1)

func slot_rarity(r: int) -> StyleBoxFlat:
	var s := _box(BG_3, rarity(r), BW_PANEL, SP_1)
	if r == Rarity.LEGENDARY:
		s.shadow_color = BRASS_INNER   # 1 px Innenlinie als Prestige-Marker
		s.shadow_size = 1
		s.shadow_offset = Vector2.ZERO
	return s

func slot_selected() -> StyleBoxFlat:
	return _box(BG_3, ACCENT, BW_SELECTED, SP_1)

## Primär-Button: genau EINER pro Panel. Der mit dem Messingrahmen.
func btn_primary(state := "normal") -> StyleBoxFlat:
	var fill := BG_2
	var border := BORDER_BRASS
	match state:
		"hover":    border = ACCENT_HOVER
		"pressed":  fill = ACCENT_PRESS; border = ACCENT_PRESS
		"disabled": fill = BG_1; border = BORDER_SOFT
	var s := _box(fill, border, BW_PANEL, SP_3)
	s.content_margin_left = SP_5
	s.content_margin_right = SP_5
	if state == "pressed":   # Text 2 px nach unten statt Schattenanimation
		s.content_margin_top += 2
		s.content_margin_bottom -= 2
	return s

## Sekundär-Button: nur Umriss, transparente Fläche.
func btn_secondary(state := "normal") -> StyleBoxFlat:
	var border := BORDER_SOFT
	if state == "hover" or state == "pressed":
		border = BORDER_FOCUS
	var s := _box(Color(0, 0, 0, 0), border, BW_PANEL, SP_3)
	s.content_margin_left = SP_5
	s.content_margin_right = SP_5
	if state == "pressed":
		s.bg_color = BG_2
		s.content_margin_top += 2
		s.content_margin_bottom -= 2
	if state == "disabled":
		s.border_color = BG_3
	return s

## Destruktiv (Verkaufen, Beenden): Danger-UMRISS im Ruhezustand,
## gefüllt erst bei pressed.
func btn_danger(state := "normal") -> StyleBoxFlat:
	var s := _box(BG_2, DANGER, BW_PANEL, SP_3)
	match state:
		"hover":    s.bg_color = DANGER_HOVER
		"pressed":  s.bg_color = DANGER
		"disabled": s.bg_color = BG_1; s.border_color = BORDER_SOFT
	s.content_margin_left = SP_5
	s.content_margin_right = SP_5
	return s

func btn_icon(state := "normal") -> StyleBoxFlat:
	var border := BORDER_SOFT
	var fill := BG_2
	match state:
		"hover":    border = ACCENT
		"pressed":  fill = ACCENT; border = ACCENT
		"disabled": fill = BG_1; border = BG_3
	return _box(fill, border, BW_PANEL, SP_1)

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
func shop_card(state := "normal") -> StyleBoxFlat:
	var border := BORDER_SOFT
	var width := BW_HAIRLINE
	match state:
		"hover":
			border = BORDER_FOCUS
		"selected":
			border = ACCENT
			width = BW_SELECTED
	var s := _box(BG_2, border, width, SP_3)
	if state == "disabled":
		s.bg_color = BG_1
		s.border_color = BORDER_SOFT
	return s

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

func tooltip() -> StyleBoxFlat:
	var s := _box(BG_1, BORDER_BRASS, BW_PANEL, SP_4)
	s.shadow_color = SHADOW_COLOR
	s.shadow_size = 0
	s.shadow_offset = SHADOW_OFFSET
	return s

# ═══ Theme-Aufbau ══════════════════════════════════════════════
## Einmal in _ready() der Root-Control aufrufen und zuweisen:
##     get_tree().root.theme = UI.build_theme()
## Alles darunter erbt. Danach KEINE Farb- oder Font-Overrides
## mehr in einzelnen Szenen setzen.

const FONT_REGULAR := "res://ui/fonts/pixel_operator/PixelOperator8.ttf"
const FONT_BOLD    := "res://ui/fonts/pixel_operator/PixelOperator8-Bold.ttf"
const FONT_DISPLAY := "res://ui/fonts/Silkscreen/Silkscreen-Regular.ttf"

func _load_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f: FontFile = load(path)
	# Pixelschriften: kein Filter, keine Mipmaps, sonst matscht das Raster.
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.generate_mipmaps = false
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f

func build_theme() -> Theme:
	var t := Theme.new()
	var font := _load_font(FONT_REGULAR)
	if font:
		t.default_font = font
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
	t.set_color("font_hover_color", "Button", ACCENT_HOVER)
	t.set_color("font_pressed_color", "Button", TEXT_ON_ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_constant("h_separation", "Button", SP_2)   # Icon links, Label rechts —
	t.set_font_size("font_size", "Button", FS_SECTION)  # nie übereinander

	for variant in ["SecondaryButton", "DangerButton"]:
		t.add_type(variant)
		t.set_type_variation(variant, "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "SecondaryButton", btn_secondary(state))
		t.set_stylebox(state, "DangerButton", btn_danger(state))
	t.set_color("font_color", "SecondaryButton", TEXT_SECOND)
	t.set_color("font_color", "DangerButton", DANGER)
	t.set_color("font_pressed_color", "DangerButton", TEXT_ON_ACCENT)

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
	get_tree().root.theme = build_theme()
