# ui/tower_shop.gd
# Tower-Auswahl - zeigt nur freigeschaltete Tower
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

var selected_type := ""
var tower_buttons: Dictionary = {}
var button_container: HBoxContainer


func _ready() -> void:
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 16)  # Erhöht von 8 auf 16
	add_child(button_container)
	
	_create_tower_buttons()
	GameState.gold_changed.connect(_on_gold_changed)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _create_tower_buttons() -> void:
	for child in button_container.get_children():
		child.queue_free()
	tower_buttons.clear()
	
	var available_types := TowerData.get_available_tower_types()
	
	for type in available_types:
		var btn := _create_button(type)
		button_container.add_child(btn)
		tower_buttons[type] = btn


func _on_element_unlocked(_element: String) -> void:
	_create_tower_buttons()


func _create_button(type: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 75)  # Etwas breiter: 90->100
	btn.flat = true
	btn.name = type.capitalize() + "Button"
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)  # Abstand zwischen Icon und Text
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	
	# Tower-Sprite
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(44, 44)  # Etwas größer
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % type
	if ResourceLoader.exists(texture_path):
		var full_tex: Texture2D = load(texture_path)
		var data := TowerData.get_tower_data(type)
		var is_animated: bool = data.get("animated", true)
		
		if is_animated:
			var atlas := AtlasTexture.new()
			atlas.atlas = full_tex
			atlas.region = Rect2(0, 0, 16, 16)
			tex_rect.texture = atlas
		else:
			tex_rect.texture = full_tex
	
	hbox.add_child(tex_rect)
	
	# Info Container
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)
	
	# Name Label
	var data := TowerData.get_tower_data(type)
	var display_name: String = data.get("name", type.capitalize())
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)
	
	# Kosten-Label
	var cost: int = TowerData.get_stat(type, "cost")
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%dg" % cost
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(cost_label)
	
	# Kombinations-Indikator
	if TowerData.is_combination(type):
		var combo_label := Label.new()
		combo_label.name = "ComboLabel"
		combo_label.text = "★ Kombi"
		combo_label.add_theme_font_size_override("font_size", 9)
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(combo_label)
	
	_apply_button_style(btn, false)
	btn.pressed.connect(_on_tower_button_pressed.bind(type))
	
	var desc: String = data.get("description", "")
	btn.tooltip_text = "%s\n%s\nKosten: %d Gold" % [display_name, desc, cost]
	
	return btn


func _apply_button_style(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	if is_selected:
		style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
		style.border_color = Color(0.4, 1.0, 0.4)
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style.border_color = Color(0.4, 0.4, 0.4)
	
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	hover_style.border_color = Color(0.6, 0.6, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)


func _on_tower_button_pressed(type: String) -> void:
	if selected_type == type:
		deselect()
	else:
		select(type)


func select(type: String) -> void:
	selected_type = type
	_update_button_styles()
	tower_selected.emit(type)


func deselect() -> void:
	selected_type = ""
	_update_button_styles()
	tower_deselected.emit()


func _update_button_styles() -> void:
	for type in tower_buttons:
		var btn: Button = tower_buttons[type]
		_apply_button_style(btn, type == selected_type)
		_update_button_affordability(btn, type)


func _on_gold_changed(_amount: int) -> void:
	for type in tower_buttons:
		var btn: Button = tower_buttons[type]
		_update_button_affordability(btn, type)


func _update_button_affordability(btn: Button, type: String) -> void:
	var cost: int = TowerData.get_stat(type, "cost")
	var can_afford := GameState.can_afford(cost)
	
	btn.modulate.a = 1.0 if can_afford else 0.5
	
	var cost_label := btn.find_child("CostLabel", true, false) as Label
	if cost_label:
		if can_afford:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func get_selected_type() -> String:
	return selected_type


func has_selection() -> bool:
	return selected_type != ""
