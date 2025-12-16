# ui/element_unlock_ui.gd
# Panel zum Investieren von Element-Kernen in Elemente
extends PanelContainer
class_name ElementUnlockUI

signal element_selected(element: String)
signal panel_closed

var title_label: Label
var cores_label: Label
var elements_container: HBoxContainer
var close_button: Button
var vbox: VBoxContainer

const ELEMENT_COLORS := {
	"water": Color(0.3, 0.6, 1.0),
	"fire": Color(1.0, 0.4, 0.2),
	"earth": Color(0.6, 0.4, 0.2),
	"air": Color(0.8, 0.9, 1.0)
}

const ELEMENT_ICON_PATH := "res://assets/elemental_symbols/%s_element.png"

# Geladene Texturen cachen
var element_textures: Dictionary = {}


func _load_element_textures() -> void:
	for element in TowerData.UNLOCKABLE_ELEMENTS:
		var path := ELEMENT_ICON_PATH % element
		if ResourceLoader.exists(path):
			element_textures[element] = load(path)
		else:
			push_warning("[ElementUnlockUI] Textur nicht gefunden: %s" % path)


func _ready() -> void:
	visible = false
	_load_element_textures()
	_setup_panel()
	_setup_ui()
	_connect_signals()


func _setup_panel() -> void:
	custom_minimum_size = Vector2(480, 260)
	
	# Benutze UITheme für konsistentes Aussehen
	if UITheme:
		UITheme.style_panel(self, "panel_dark")


func _setup_ui() -> void:
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	
	# Titel
	title_label = Label.new()
	title_label.text = "Element-Kerne investieren"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	vbox.add_child(title_label)
	
	# Kerne-Anzeige
	cores_label = Label.new()
	cores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		cores_label.add_theme_font_override("font", UITheme.game_font)
	cores_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cores_label)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Info Text
	var info_label := Label.new()
	info_label.text = "Wähle ein Element zum Freischalten oder Aufwerten:"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		info_label.add_theme_font_override("font", UITheme.game_font)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	vbox.add_child(info_label)
	
	# CenterContainer für die Buttons
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	
	# Elements Container
	elements_container = HBoxContainer.new()
	elements_container.alignment = BoxContainer.ALIGNMENT_CENTER
	elements_container.add_theme_constant_override("separation", 12)
	center.add_child(elements_container)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# Close Button
	close_button = Button.new()
	close_button.text = "Später"
	close_button.custom_minimum_size = Vector2(100, 30)
	close_button.pressed.connect(_on_close_pressed)
	
	if UITheme:
		UITheme.style_button(close_button)
	
	var dark_font := Color(0.1, 0.1, 0.1)
	close_button.add_theme_color_override("font_color", dark_font)
	close_button.add_theme_color_override("font_hover_color", dark_font)
	close_button.add_theme_color_override("font_pressed_color", dark_font)
	
	var btn_container := CenterContainer.new()
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_container.add_child(close_button)
	vbox.add_child(btn_container)


func _connect_signals() -> void:
	GameState.element_cores_changed.connect(_on_cores_changed)
	GameState.element_core_earned.connect(_on_core_earned)
	TowerData.element_unlocked.connect(_on_element_changed)
	TowerData.element_upgraded.connect(_on_element_upgraded)


func _on_cores_changed(_amount: int) -> void:
	_update_cores_display()
	_update_element_buttons()


func _on_core_earned() -> void:
	show_panel()


func _on_element_changed(_element: String) -> void:
	_update_element_buttons()


func _on_element_upgraded(_element: String, _level: int) -> void:
	_update_element_buttons()


func show_panel() -> void:
	Sound.play_click()
	_update_cores_display()
	_create_element_buttons()
	visible = true


func hide_panel() -> void:
	visible = false
	panel_closed.emit()


func _update_cores_display() -> void:
	var cores := GameState.element_cores
	var invested := TowerData.get_total_cores_invested()
	var max_possible := TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL
	
	cores_label.text = "Verfügbar: %d | Investiert: %d/%d" % [cores, invested, max_possible]
	
	if cores > 0:
		cores_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	else:
		cores_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))


func _create_element_buttons() -> void:
	for child in elements_container.get_children():
		child.queue_free()
	
	var all_maxed := TowerData.get_upgradeable_elements().is_empty()
	
	if all_maxed:
		var all_done := Label.new()
		all_done.text = "Alle Elemente auf Maximum!"
		if UITheme and UITheme.game_font:
			all_done.add_theme_font_override("font", UITheme.game_font)
		all_done.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		elements_container.add_child(all_done)
		return
	
	for element in TowerData.UNLOCKABLE_ELEMENTS:
		var btn := _create_element_button(element)
		elements_container.add_child(btn)


func _create_element_button(element: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 115)
	btn.name = element.capitalize() + "UnlockBtn"
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	
	var vbox_btn := VBoxContainer.new()
	vbox_btn.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_btn.add_theme_constant_override("separation", 3)
	vbox_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox_btn)
	
	# Icon (TextureRect statt Label)
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(40, 40)
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(icon_container)
	
	if element_textures.has(element):
		var icon_sprite := TextureRect.new()
		icon_sprite.texture = element_textures[element]
		icon_sprite.custom_minimum_size = Vector2(32, 32)
		icon_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon_sprite)
	else:
		# Fallback auf Text wenn Textur fehlt
		var icon_label := Label.new()
		icon_label.text = element.substr(0, 1).to_upper()
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 24)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon_label)
	
	# Element Name
	var data := TowerData.get_tower_data(element)
	var name_label := Label.new()
	name_label.text = data.get("name", element.capitalize())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(name_label)
	
	# Level Anzeige (●●○)
	var current_level := TowerData.get_element_level(element)
	var level_label := Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var level_dots := ""
	for i in range(TowerData.MAX_ELEMENT_LEVEL):
		if i < current_level:
			level_dots += "●"
		else:
			level_dots += "○"
	level_label.text = level_dots
	
	if current_level >= TowerData.MAX_ELEMENT_LEVEL:
		level_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.1))
	else:
		level_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	
	vbox_btn.add_child(level_label)
	
	# Status-Text
	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		status_label.add_theme_font_override("font", UITheme.game_font)
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var is_maxed := current_level >= TowerData.MAX_ELEMENT_LEVEL
	var has_cores := GameState.has_element_cores()
	
	if is_maxed:
		status_label.text = "MAX"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.1))
	elif current_level == 0:
		status_label.text = "Freischalten"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.7))
	else:
		status_label.text = "Aufwerten"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	
	vbox_btn.add_child(status_label)
	
	# Styling
	_apply_element_button_style(btn, element, current_level, has_cores)
	
	# Interaktion
	if is_maxed:
		btn.disabled = true
		btn.tooltip_text = "Bereits auf Maximum (Level %d)" % current_level
	elif has_cores:
		btn.pressed.connect(_on_element_button_pressed.bind(element))
		if current_level == 0:
			btn.tooltip_text = "Klicken um %s freizuschalten\n→ Kann Level 1 Tower bauen" % data.get("name", element)
		else:
			btn.tooltip_text = "Klicken um %s aufzuwerten\n→ Kann auf Level %d upgraden" % [data.get("name", element), current_level + 1]
	else:
		btn.disabled = true
		btn.tooltip_text = "Element-Kern benötigt"
	
	return btn


func _apply_element_button_style(btn: Button, element: String, current_level: int, has_cores: bool) -> void:
	var element_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	var is_maxed := current_level >= TowerData.MAX_ELEMENT_LEVEL
	
	# Basis-Style mit UITheme
	if UITheme:
		var base_style := UITheme.create_button_style(false)
		btn.add_theme_stylebox_override("normal", base_style)
		btn.add_theme_stylebox_override("disabled", base_style)
		
		var hover_style := UITheme.create_button_style(true)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
	
	# Modulate basierend auf Status
	if is_maxed:
		btn.modulate = Color(0.9, 0.85, 0.7)  # Goldener Tint
	elif not has_cores:
		btn.modulate = Color(0.6, 0.6, 0.6)  # Ausgegraut
	elif current_level > 0:
		# Leichter Element-Tint für bereits investierte
		btn.modulate = element_color.lerp(Color.WHITE, 0.7)
	else:
		btn.modulate = Color.WHITE


func _update_element_buttons() -> void:
	_create_element_buttons()


func _on_element_button_pressed(element: String) -> void:
	Sound.play_element_select()
	
	var was_new := TowerData.get_element_level(element) == 0
	
	if TowerData.invest_core_in_element(element):
		element_selected.emit(element)
		_show_unlock_effect(element, was_new)
		
		await get_tree().create_timer(0.3).timeout
		_update_element_buttons()
		_update_cores_display()


func _show_unlock_effect(element: String, was_new: bool) -> void:
	# VFX am Panel
	if VFX:
		var center_pos := global_position + size / 2
		VFX.spawn_pixel_burst(center_pos, element, 12 if was_new else 8)


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()
