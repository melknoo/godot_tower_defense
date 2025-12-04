# autoload/ui_theme.gd
extends Node

var ui_atlas: Texture2D
var button_light_tex: Texture2D
var button_dark_tex: Texture2D
var game_font: FontFile

const REGIONS := {
	# Panels
	"panel_light": Rect2(8, 168, 86, 79),
	"panel_medium": Rect2(102, 168, 56, 79),
	"panel_dark": Rect2(164, 167, 46, 79),
}

# NinePatch Margins
const PANEL_MARGINS := 12
const BUTTON_MARGINS := 8


func _ready() -> void:
	ui_atlas = load("res://assets/ui/ui_sheet.png")
	button_light_tex = load("res://assets/ui/button_light.png")
	button_dark_tex = load("res://assets/ui/button_dark.png")
	game_font = load("res://assets/fonts/Clarity.ttf")  
	print("[UITheme] Geladen")


func get_texture(region_name: String) -> AtlasTexture:
	if not REGIONS.has(region_name):
		push_error("Unknown UI region: " + region_name)
		return null
	
	var tex := AtlasTexture.new()
	tex.atlas = ui_atlas
	tex.region = REGIONS[region_name]
	return tex


func create_panel_style(panel_type: String = "panel_light") -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = get_texture(panel_type)
	
	style.texture_margin_left = PANEL_MARGINS
	style.texture_margin_right = PANEL_MARGINS
	style.texture_margin_top = PANEL_MARGINS
	style.texture_margin_bottom = PANEL_MARGINS
	
	style.content_margin_left = PANEL_MARGINS + 6
	style.content_margin_right = PANEL_MARGINS + 6
	style.content_margin_top = PANEL_MARGINS + 6
	style.content_margin_bottom = PANEL_MARGINS + 6
	
	return style


func create_button_style(dark: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = button_dark_tex if dark else button_light_tex
	
	style.texture_margin_left = BUTTON_MARGINS
	style.texture_margin_right = BUTTON_MARGINS
	style.texture_margin_top = BUTTON_MARGINS
	style.texture_margin_bottom = BUTTON_MARGINS
	
	style.content_margin_left = BUTTON_MARGINS + 4
	style.content_margin_right = BUTTON_MARGINS + 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	return style


func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", create_button_style(false))
	btn.add_theme_stylebox_override("hover", create_button_style(true))
	btn.add_theme_stylebox_override("pressed", create_button_style(true))
	btn.add_theme_font_override("font", game_font)


func style_panel(panel: PanelContainer, panel_type: String = "panel_light") -> void:
	panel.add_theme_stylebox_override("panel", create_panel_style(panel_type))


func style_label(label: Label, size: int = 14) -> void:
	label.add_theme_font_override("font", game_font)
	label.add_theme_font_size_override("font_size", size)
