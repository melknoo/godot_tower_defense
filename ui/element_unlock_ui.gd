# ui/element_unlock_ui.gd
# Panel zum Freischalten von Elementen mit Element-Kernen
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

const ELEMENT_ICONS := {
	"water": "💧",
	"fire": "🔥",
	"earth": "🪨",
	"air": "💨"
}


func _ready() -> void:
	visible = false
	_setup_panel()
	_setup_ui()
	_connect_signals()


func _setup_panel() -> void:
	custom_minimum_size = Vector2(400, 240)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.4, 0.3, 0.6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)


func _setup_ui() -> void:
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)
	
	# Titel
	title_label = Label.new()
	title_label.text = "Element freischalten"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	# Kerne-Anzeige
	cores_label = Label.new()
	cores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cores_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cores_label)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Info Text
	var info_label := Label.new()
	info_label.text = "Wähle ein Element zum Freischalten:"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)
	
	# CenterContainer für die Buttons
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	
	# Elements Container
	elements_container = HBoxContainer.new()
	elements_container.alignment = BoxContainer.ALIGNMENT_CENTER
	elements_container.add_theme_constant_override("separation", 15)
	center.add_child(elements_container)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Close Button
	close_button = Button.new()
	close_button.text = "Später"
	close_button.custom_minimum_size = Vector2(100, 30)
	close_button.pressed.connect(_on_close_pressed)
	
	var dark_font := Color(0.1, 0.1, 0.1)
	close_button.add_theme_color_override("font_color", dark_font)
	close_button.add_theme_color_override("font_hover_color", dark_font)
	close_button.add_theme_color_override("font_pressed_color", dark_font)
	
	var btn_container := CenterContainer.new()
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_container.add_child(close_button)
	vbox.add_child(btn_container)
	
	if UITheme:
		UITheme.style_button(close_button)


func _connect_signals() -> void:
	GameState.element_cores_changed.connect(_on_cores_changed)
	GameState.element_core_earned.connect(_on_core_earned)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _on_cores_changed(_amount: int) -> void:
	_update_cores_display()
	_update_element_buttons()


func _on_core_earned() -> void:
	show_panel()


func _on_element_unlocked(_element: String) -> void:
	_update_element_buttons()
	
	if TowerData.get_locked_elements().is_empty():
		hide_panel()


func show_panel() -> void:
	_update_cores_display()
	_create_element_buttons()
	visible = true


func hide_panel() -> void:
	visible = false
	panel_closed.emit()


func _update_cores_display() -> void:
	var cores := GameState.element_cores
	var unlocked := TowerData.get_unlocked_count()
	var total := TowerData.get_total_unlockable()
	
	cores_label.text = "Element-Kerne: %d | Freigeschaltet: %d/%d" % [cores, unlocked, total]
	
	if cores > 0:
		cores_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		cores_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _create_element_buttons() -> void:
	for child in elements_container.get_children():
		child.queue_free()
	
	var locked_elements := TowerData.get_locked_elements()
	
	if locked_elements.is_empty():
		var all_unlocked := Label.new()
		all_unlocked.text = "Alle Elemente freigeschaltet!"
		all_unlocked.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		elements_container.add_child(all_unlocked)
		return
	
	for element in TowerData.UNLOCKABLE_ELEMENTS:
		var btn := _create_element_button(element)
		elements_container.add_child(btn)


func _create_element_button(element: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(75, 85)
	btn.name = element.capitalize() + "UnlockBtn"
	
	# MarginContainer für inneren Abstand
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)
	
	var vbox_btn := VBoxContainer.new()
	vbox_btn.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_btn.add_theme_constant_override("separation", 5)
	vbox_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox_btn)
	
	# Icon
	var icon_label := Label.new()
	icon_label.text = ELEMENT_ICONS.get(element, "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(icon_label)
	
	# Element Name
	var data := TowerData.get_tower_data(element)
	var name_label := Label.new()
	name_label.text = data.get("name", element.capitalize())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_btn.add_child(name_label)
	
	# Styling basierend auf Status
	var is_unlocked := TowerData.is_element_unlocked(element)
	var has_cores := GameState.has_element_cores()
	
	_apply_element_button_style(btn, element, is_unlocked, has_cores)
	
	if is_unlocked:
		btn.disabled = true
		btn.tooltip_text = "Bereits freigeschaltet"
	elif has_cores:
		btn.pressed.connect(_on_element_button_pressed.bind(element))
		btn.tooltip_text = "Klicken zum Freischalten"
	else:
		btn.disabled = true
		btn.tooltip_text = "Element-Kern benötigt"
	
	return btn


func _apply_element_button_style(btn: Button, element: String, is_unlocked: bool, has_cores: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	
	var element_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	
	if is_unlocked:
		style.bg_color = element_color.darkened(0.5)
		style.border_color = element_color
		btn.modulate.a = 0.6
	elif has_cores:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
		style.border_color = element_color
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_color = Color(0.3, 0.3, 0.3)
		btn.modulate.a = 0.5
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = element_color.darkened(0.3)
	hover_style.border_color = element_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)


func _update_element_buttons() -> void:
	_create_element_buttons()


func _on_element_button_pressed(element: String) -> void:
	if TowerData.unlock_element(element):
		element_selected.emit(element)
		_show_unlock_effect(element)
		
		await get_tree().create_timer(0.3).timeout
		_update_element_buttons()
		_update_cores_display()


func _show_unlock_effect(element: String) -> void:
	var flash := ColorRect.new()
	flash.color = ELEMENT_COLORS.get(element, Color.WHITE)
	flash.color.a = 0.5
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _on_close_pressed() -> void:
	hide_panel()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()
