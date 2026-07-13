# ui/element_unlock_ui.gd
# Panel zum Investieren von Element-Kernen in Elemente
extends CanvasLayer
class_name ElementUnlockUI

signal element_selected(element: String)
signal panel_closed

var panel: PanelContainer
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
	layer = 100
	visible = false
	_load_element_textures()
	_setup_ui()
	_connect_signals()


func _setup_ui() -> void:
	# Hintergrund zum Klick-Abfangen
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	
	# Hauptpanel zentriert
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # WICHTIG: Events durchlassen!
	add_child(center)
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 260)
	center.add_child(panel)
	
	# Benutze UITheme für konsistentes Aussehen
	if UITheme:
		UITheme.style_panel(panel, "carved")
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Titel
	title_label = Label.new()
	title_label.text = "Element-Kerne investieren"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
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
	sep.add_theme_color_override("separator", Color("785d32"))
	vbox.add_child(sep)
	
	# Info Text
	var info_label := Label.new()
	info_label.text = "Wähle ein Element zum Freischalten oder Aufwerten:"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		info_label.add_theme_font_override("font", UITheme.game_font)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color("554731"))
	vbox.add_child(info_label)
	
	# CenterContainer für die Buttons
	var center_btn := CenterContainer.new()
	center_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center_btn)
	
	# Elements Container
	elements_container = HBoxContainer.new()
	elements_container.alignment = BoxContainer.ALIGNMENT_CENTER
	elements_container.add_theme_constant_override("separation", 12)
	center_btn.add_child(elements_container)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# Close Button
	close_button = Button.new()
	close_button.text = "Schließen"
	close_button.custom_minimum_size = Vector2(100, 30)
	close_button.pressed.connect(_on_close_pressed)
	
	if UITheme:
		UITheme.style_button(close_button)
		UITheme.style_button_colors(close_button)
	
	var btn_container := CenterContainer.new()
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_container.add_child(close_button)
	vbox.add_child(btn_container)


func _connect_signals() -> void:
	GameState.element_cores_changed.connect(_on_cores_changed)
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
	
	panel.modulate.a = 0
	panel.scale = Vector2(0.9, 0.9)
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): visible = false)
	panel_closed.emit()


func _update_cores_display() -> void:
	var cores := GameState.element_cores
	var invested := TowerData.get_total_cores_invested()
	var max_possible := TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL
	
	cores_label.text = "Verfügbar: %d | Investiert: %d/%d" % [cores, invested, max_possible]
	
	if cores > 0:
		cores_label.add_theme_color_override("font_color", Color("185a78"))
	else:
		cores_label.add_theme_color_override("font_color", Color("695c48"))


func _create_element_buttons() -> void:
	for child in elements_container.get_children():
		child.queue_free()
	
	var all_maxed := TowerData.get_upgradeable_elements().is_empty()
	
	if all_maxed:
		var all_done := Label.new()
		all_done.text = "Alle Elemente auf Maximum!"
		all_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme and UITheme.game_font:
			all_done.add_theme_font_override("font", UITheme.game_font)
		all_done.add_theme_color_override("font_color", Color("78d58b"))
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
	
	# Name
	var name_label := Label.new()
	name_label.text = element.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("201b17"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(name_label)
	
	# Level-Anzeige
	var current_level := TowerData.get_element_level(element)
	var level_text := "Lvl %d/%d" % [current_level, TowerData.MAX_ELEMENT_LEVEL]
	if current_level == 0:
		level_text = "Gesperrt"
	
	var level_label := Label.new()
	level_label.text = level_text
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		level_label.add_theme_font_override("font", UITheme.game_font)
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.add_theme_color_override("font_color", Color("3d4654"))
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(level_label)
	
	# Kosten-Anzeige
	var cost := 1
	var cost_label := Label.new()
	cost_label.text = "Kosten: %d" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		cost_label.add_theme_font_override("font", UITheme.game_font)
	cost_label.add_theme_font_size_override("font_size", 8)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(cost_label)
	
	# Button-Status
	var has_cores := GameState.element_cores >= cost
	btn.disabled = not has_cores or current_level >= TowerData.MAX_ELEMENT_LEVEL
	btn.pressed.connect(_on_element_button_pressed.bind(element))
	
	# Styling
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
		cost_label.text = "MAX"
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	elif not has_cores:
		btn.modulate = Color(0.6, 0.6, 0.6)  # Ausgegraut
		cost_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))
	elif current_level > 0:
		# Leichter Element-Tint für bereits investierte
		btn.modulate = element_color.lerp(Color.WHITE, 0.84)
		cost_label.add_theme_color_override("font_color", Color("235b2e"))
	else:
		btn.modulate = Color.WHITE
		cost_label.add_theme_color_override("font_color", Color("235b2e"))
	
	return btn


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
		var center_pos := panel.global_position + panel.size / 2
		VFX.spawn_pixel_burst(center_pos, element, 12 if was_new else 8)


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Klick außerhalb des Panels
		var panel_rect := panel.get_global_rect()
		var mouse_pos := get_viewport().get_mouse_position()
		
		if not panel_rect.has_point(mouse_pos):
			hide_panel()
			get_viewport().set_input_as_handled()  # Event als handled markieren!


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()
