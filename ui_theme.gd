# autoload/ui_theme.gd
# Medieval-Style UI Theme mit 9-Slice Texturen
extends Node

# === BUTTON TEXTURES (9-Slice) ===
var btn_blue_normal: Texture2D
var btn_blue_pressed: Texture2D
var btn_blue_hover: Texture2D
var btn_blue_disabled: Texture2D

var btn_red_normal: Texture2D
var btn_red_pressed: Texture2D

var btn_hover_9slice: Texture2D
var btn_disable_9slice: Texture2D

# === PANEL TEXTURES ===
var carved_regular: Texture2D
var carved_9slice: Texture2D
var carved_3slice: Texture2D

# === BANNER / RIBBON ===
var banner_horizontal: Texture2D
var banner_vertical: Texture2D
var banner_conn_up: Texture2D
var banner_conn_down: Texture2D
var banner_conn_left: Texture2D
var banner_conn_right: Texture2D

var ribbon_blue: Texture2D
var ribbon_blue_3slice: Texture2D
var ribbon_yellow: Texture2D
var ribbon_yellow_3slice: Texture2D
var ribbon_red: Texture2D
var ribbon_red_3slice: Texture2D

# === CORNER PIECES (für Panel-Rahmen) ===
var corner_pieces: Array[Texture2D] = []

# === FONT ===
var game_font: FontFile

# === MARGINS ===
const BUTTON_9SLICE_MARGIN := 20  # Randbreite der 192x192 Button-Texturen
const PANEL_9SLICE_MARGIN := 20   # Carved Panels sind auch 192x192
const CARVED_MARGIN := 20
const BUTTON_CONTENT_PADDING := 24  # Innenabstand Text zu Rand

# === FARBEN ===
const COLOR_TEXT_DARK := Color(0.15, 0.12, 0.08)
const COLOR_TEXT_LIGHT := Color(0.95, 0.9, 0.8)
const COLOR_TEXT_GOLD := Color(0.85, 0.7, 0.3)
const COLOR_TEXT_DISABLED := Color(0.5, 0.45, 0.4)
const COLOR_TEXT_RED := Color(0.7, 0.2, 0.15)
const COLOR_TEXT_GREEN := Color(0.2, 0.55, 0.2)

# HUD-Hintergrund im Medieval-Stil
const COLOR_HUD_BG := Color(0.12, 0.1, 0.08, 0.95)
const COLOR_PANEL_BORDER := Color(0.45, 0.35, 0.2)


func _ready() -> void:
	_load_button_textures()
	_load_panel_textures()
	_load_banner_textures()
	_load_ribbon_textures()
	_load_corner_pieces()
	_load_font()
	print("[UITheme] Medieval Theme geladen")


func _load_button_textures() -> void:
	var base := "res://assets/ui/buttons/"
	btn_blue_normal = _load_tex(base + "Button_Blue_9Slides.png")
	btn_blue_pressed = _load_tex(base + "Button_Blue_9Slides_Pressed.png")
	btn_blue_hover = _load_tex(base + "Button_Hover_9Slides.png")
	btn_blue_disabled = _load_tex(base + "Button_Disable_9Slides.png")
	
	btn_red_normal = _load_tex(base + "Button_Red_9Slides.png")
	btn_red_pressed = _load_tex(base + "Button_Red_9Slides_Pressed.png")


func _load_panel_textures() -> void:
	var base := "res://assets/ui/panels/"
	carved_regular = _load_tex(base + "Carved_Regular.png")
	carved_9slice = _load_tex(base + "Carved_9Slides.png")
	carved_3slice = _load_tex(base + "Carved_3Slides.png")


func _load_banner_textures() -> void:
	var base := "res://assets/ui/banners/"
	banner_horizontal = _load_tex(base + "Banner_Horizontal.png")
	banner_vertical = _load_tex(base + "Banner_Vertical.png")
	banner_conn_up = _load_tex(base + "Banner_Connection_Up.png")
	banner_conn_down = _load_tex(base + "Banner_Connection_Down.png")
	banner_conn_left = _load_tex(base + "Banner_Connection_Left.png")
	banner_conn_right = _load_tex(base + "Banner_Connection_Right.png")


func _load_ribbon_textures() -> void:
	var base := "res://assets/ui/ribbons/"
	ribbon_blue = _load_tex(base + "Ribbon_Blue_3Slides.png")
	ribbon_yellow = _load_tex(base + "Ribbon_Yellow_3Slides.png")
	ribbon_red = _load_tex(base + "Ribbon_Red_3Slides.png")


func _load_corner_pieces() -> void:
	var base := "res://assets/ui/corners/"
	for i in range(1, 7):
		var tex := _load_tex(base + "%02d.png" % i)
		if tex:
			corner_pieces.append(tex)


func _load_font() -> void:
	game_font = load("res://assets/fonts/Clarity.ttf")


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("[UITheme] Textur nicht gefunden: " + path)
	return null


# =============================================
# BUTTON STYLES
# =============================================

func create_button_style_idle() -> StyleBoxTexture:
	return _make_button_9slice(btn_blue_normal)

func create_button_style_pressed() -> StyleBoxTexture:
	return _make_button_9slice(btn_blue_pressed)

func create_button_style_hover() -> StyleBoxTexture:
	return _make_button_9slice(btn_blue_hover)

func create_button_style_disabled() -> StyleBoxTexture:
	return _make_button_9slice(btn_blue_disabled)

func create_button_style_red() -> StyleBoxTexture:
	return _make_9slice(btn_red_normal, BUTTON_9SLICE_MARGIN)

func create_button_style_red_pressed() -> StyleBoxTexture:
	return _make_9slice(btn_red_pressed, BUTTON_9SLICE_MARGIN)

# Legacy-Kompatibilität
func create_button_style(dark: bool = false) -> StyleBoxTexture:
	if dark:
		return create_button_style_red()
	return create_button_style_idle()


func style_button(btn: Button, red: bool = false) -> void:
	if red:
		btn.add_theme_stylebox_override("normal", create_button_style_red())
		btn.add_theme_stylebox_override("pressed", create_button_style_red_pressed())
	else:
		btn.add_theme_stylebox_override("normal", create_button_style_idle())
		btn.add_theme_stylebox_override("pressed", create_button_style_pressed())
	
	btn.add_theme_stylebox_override("hover", create_button_style_hover())
	btn.add_theme_stylebox_override("disabled", create_button_style_disabled())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	if game_font:
		btn.add_theme_font_override("font", game_font)
	
	# Dunkle Schrift auf den hellen Button-Texturen
	btn.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_DARK)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)


## Für Icon-only Buttons (Inventar, Kerne, Upgrades) - minimale Margins
func style_icon_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_9slice(btn_blue_normal, BUTTON_9SLICE_MARGIN, 4))
	btn.add_theme_stylebox_override("pressed", _make_9slice(btn_blue_pressed, BUTTON_9SLICE_MARGIN, 4))
	btn.add_theme_stylebox_override("hover", _make_9slice(btn_blue_hover, BUTTON_9SLICE_MARGIN, 4))
	btn.add_theme_stylebox_override("disabled", _make_9slice(btn_blue_disabled, BUTTON_9SLICE_MARGIN, 4))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Für Buttons die helle Schrift brauchen (z.B. "Nächste Welle" auf dunklem Hintergrund)
func style_button_light_text(btn: Button) -> void:
	style_button(btn)
	btn.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_LIGHT)
	btn.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	btn.add_theme_constant_override("outline_size", 2)


func style_button_colors(btn: Button, normal: Color = COLOR_TEXT_DARK, disabled: Color = COLOR_TEXT_DISABLED) -> void:
	btn.add_theme_color_override("font_color", normal)
	btn.add_theme_color_override("font_hover_color", normal)
	btn.add_theme_color_override("font_pressed_color", normal)
	btn.add_theme_color_override("font_disabled_color", disabled)


# =============================================
# PANEL STYLES
# =============================================

func create_panel_style(panel_type: String = "carved") -> StyleBoxTexture:
	var tex: Texture2D
	match panel_type:
		"carved", "panel_light":
			tex = carved_9slice
		"carved_small":
			tex = carved_3slice
		"carved_regular":
			tex = carved_regular
		_:
			tex = carved_9slice
	return _make_9slice(tex, CARVED_MARGIN, CARVED_MARGIN + 4)


func create_hud_panel_style() -> StyleBoxTexture:
	# Spezieller HUD-Hintergrund mit Carved-Textur
	var style := _make_9slice(carved_9slice, PANEL_9SLICE_MARGIN, PANEL_9SLICE_MARGIN + 4)
	return style


func style_panel(panel: PanelContainer, panel_type: String = "carved") -> void:
	panel.add_theme_stylebox_override("panel", create_panel_style(panel_type))


# =============================================
# RIBBON / BANNER TITLE BARS
# =============================================

## Erstellt ein kleines Info-Banner (z.B. für Gold-Anzeige im HUD)
func create_info_badge_style() -> StyleBoxTexture:
	return _make_9slice(carved_9slice, CARVED_MARGIN, 6)


## Erstellt ein Ribbon-Label als Titel für ein Panel
## Gibt ein TextureRect + Label Konstrukt zurück
func create_ribbon_title(text: String, color: String = "blue", width: float = 200.0, font_size: int = 14) -> Control:

	var container := Control.new()
	container.custom_minimum_size = Vector2(width, 32)
	
	var ribbon_tex: Texture2D
	match color:
		"blue": ribbon_tex = ribbon_blue
		"yellow": ribbon_tex = ribbon_yellow
		"red": ribbon_tex = ribbon_red
		_: ribbon_tex = ribbon_blue
	
	if ribbon_tex:
		var ribbon := NinePatchRect.new()
		ribbon.texture = ribbon_tex
		ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
		# 3-Slice horizontal: links/rechts patchen
		ribbon.patch_margin_left = 12
		ribbon.patch_margin_right = 12
		ribbon.patch_margin_top = 0
		ribbon.patch_margin_bottom = 0
		container.add_child(ribbon)
	
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if game_font:
		label.add_theme_font_override("font", game_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	label.add_theme_constant_override("outline_size", 2)
	container.add_child(label)
	
	return container


# =============================================
# LABEL STYLES
# =============================================

func style_label(label: Label, size: int = 14, color: Color = COLOR_TEXT_DARK) -> void:
	if game_font:
		label.add_theme_font_override("font", game_font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)


func style_rich_label(label: RichTextLabel, size: int = 14) -> void:
	if game_font:
		label.add_theme_font_override("normal_font", game_font)
	label.add_theme_font_size_override("normal_font_size", size)


# =============================================
# TOOLTIP STYLE
# =============================================

func create_tooltip_style() -> StyleBoxTexture:
	var style := _make_9slice(carved_9slice, CARVED_MARGIN, CARVED_MARGIN + 6)
	return style


# =============================================
# HELPER: 9-Slice StyleBox erstellen
# =============================================

func _make_9slice(tex: Texture2D, tex_margin: int = 6, content_margin: int = -1) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if tex:
		style.texture = tex
	
	style.texture_margin_left = tex_margin
	style.texture_margin_right = tex_margin
	style.texture_margin_top = tex_margin
	style.texture_margin_bottom = tex_margin
	
	var cm := content_margin if content_margin >= 0 else tex_margin + 4
	style.content_margin_left = cm
	style.content_margin_right = cm
	style.content_margin_top = cm
	style.content_margin_bottom = cm
	
	return style


## Buttons haben oft asymmetrische Ränder (Schatten unten dicker)
## content_margin_top kleiner damit Text visuell zentriert wirkt
func _make_button_9slice(tex: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if tex:
		style.texture = tex
	
	style.texture_margin_left = BUTTON_9SLICE_MARGIN
	style.texture_margin_right = BUTTON_9SLICE_MARGIN
	style.texture_margin_top = BUTTON_9SLICE_MARGIN
	style.texture_margin_bottom = BUTTON_9SLICE_MARGIN
	
	style.content_margin_left = BUTTON_CONTENT_PADDING
	style.content_margin_right = BUTTON_CONTENT_PADDING
	style.content_margin_top = BUTTON_CONTENT_PADDING - 8  # Weniger oben = Text rutscht hoch
	style.content_margin_bottom = BUTTON_CONTENT_PADDING + 8  # Mehr unten = kompensiert Schatten
	
	return style
