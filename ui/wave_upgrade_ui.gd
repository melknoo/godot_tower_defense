# ui/wave_upgrade_ui.gd
# Zeigt nach jeder Welle 3 Upgrade-Optionen
extends CanvasLayer
class_name WaveUpgradeUI

signal upgrade_chosen(upgrade_id: String)
signal panel_closed

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var cards_container: HBoxContainer
var skip_button: Button

var current_options: Array[String] = []

const CARD_WIDTH := 180
const CARD_HEIGHT := 220
const CATEGORY_COLORS := {
	"element": Color(0.4, 0.6, 1.0),
	"economy": Color(1.0, 0.85, 0.3),
	"supply": Color(0.5, 0.8, 0.4),
	"global": Color(0.9, 0.5, 0.9),
	"special": Color(1.0, 0.5, 0.3),
	"instant": Color(0.3, 1.0, 0.6),
	"tower_type": Color(0.7, 0.7, 0.8)
}


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()


func _setup_ui() -> void:
	# Dunkler Hintergrund
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	# Zentrierter Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Hauptpanel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 380)
	center.add_child(panel)
	
	if UITheme:
		UITheme.style_panel(panel, "panel_dark")
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Titel
	title_label = Label.new()
	title_label.text = "Welle abgeschlossen!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "Wähle ein Upgrade für diesen Run:"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		subtitle_label.add_theme_font_override("font", UITheme.game_font)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle_label)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Cards Container (zentriert)
	var cards_center := CenterContainer.new()
	cards_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards_center)
	
	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 15)
	cards_center.add_child(cards_container)
	
	# Skip Button
	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)
	
	skip_button = Button.new()
	skip_button.text = "Überspringen"
	skip_button.custom_minimum_size = Vector2(120, 32)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_button.visible = false  # Nur bei keinen verfügbaren Upgrades
	btn_center.add_child(skip_button)
	
	if UITheme:
		UITheme.style_button(skip_button)
	
	skip_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func show_upgrades(wave: int) -> void:
	title_label.text = "Welle %d abgeschlossen!" % wave
	
	# Upgrades holen
	current_options = UpgradeSystem.get_random_upgrades(3)
	
	_create_upgrade_cards()
	
	if current_options.is_empty():
		subtitle_label.text = "Alle Upgrades bereits maximiert!"
		skip_button.visible = true
	else:
		subtitle_label.text = "Wähle ein Upgrade für diesen Run:"
		skip_button.visible = false
	
	visible = true
	
	# Animation
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false)
	panel_closed.emit()


func _create_upgrade_cards() -> void:
	# Alte Cards entfernen
	for child in cards_container.get_children():
		child.queue_free()
	
	for upgrade_id in current_options:
		var card := _create_card(upgrade_id)
		cards_container.add_child(card)


func _create_card(upgrade_id: String) -> PanelContainer:
	var data: Dictionary = UpgradeSystem.get_upgrade_data(upgrade_id)
	var current_stacks: int = UpgradeSystem.get_upgrade_stacks(upgrade_id)
	var stat: String = data.get("stat")
	var max_stacks: int = data.get("max_stacks", 1)
	var category: String = data.get("category", "special")
	var cat_color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	
	# Card Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = cat_color.darkened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Icon
	var icon_label := Label.new()
	icon_label.text = data.get("icon", "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = data.get("name", upgrade_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", cat_color)
	vbox.add_child(name_label)
	
	# Description
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.y = 50
	if UITheme and UITheme.game_font:
		desc_label.add_theme_font_override("font", UITheme.game_font)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Stack-Anzeige
	if max_stacks > 1 and not stat == "instant_gold":
		var stack_label := Label.new()
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme and UITheme.game_font:
			stack_label.add_theme_font_override("font", UITheme.game_font)
		stack_label.add_theme_font_size_override("font_size", 10)
		
		var dots := ""
		for i in range(max_stacks):
			if i < current_stacks:
				dots += "●"
			elif i == current_stacks:
				dots += "◐"  # Nächster Stack
			else:
				dots += "○"
		stack_label.text = dots
		stack_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(stack_label)
	
	# Auswahl-Button
	var select_btn := Button.new()
	select_btn.text = "Wählen"
	select_btn.custom_minimum_size = Vector2(0, 28)
	select_btn.pressed.connect(_on_upgrade_selected.bind(upgrade_id))
	vbox.add_child(select_btn)
	
	if UITheme:
		UITheme.style_button(select_btn)
	
	select_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	
	# Hover-Effekt
	card.mouse_entered.connect(func():
		style.border_color = cat_color
		style.bg_color = Color(0.2, 0.2, 0.25)
	)
	card.mouse_exited.connect(func():
		style.border_color = cat_color.darkened(0.3)
		style.bg_color = Color(0.15, 0.15, 0.18)
	)
	
	return card


func _on_upgrade_selected(upgrade_id: String) -> void:
	Sound.play_element_select()
	
	UpgradeSystem.activate_upgrade(upgrade_id)
	
	# VFX
	if VFX:
		var viewport_center := get_viewport().get_visible_rect().size / 2
		VFX.spawn_pixel_burst(viewport_center, "gold", 20)
	
	upgrade_chosen.emit(upgrade_id)
	hide_panel()


func _on_skip_pressed() -> void:
	Sound.play_click()
	upgrade_chosen.emit("")
	hide_panel()
