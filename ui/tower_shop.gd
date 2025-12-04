# ui/tower_shop.gd
# Tower-Auswahl Buttons mit Vorschau
# An VBoxContainer oder HBoxContainer anbringen
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

var selected_type := ""
var tower_buttons: Dictionary = {}


func _ready() -> void:
	_create_tower_buttons()
	GameState.gold_changed.connect(_on_gold_changed)


func _create_tower_buttons() -> void:
	# Alte Buttons entfernen
	for child in get_children():
		child.queue_free()
	
	# Buttons für alle Basis-Tower erstellen
	var tower_types := TowerData.get_base_tower_types()
	
	for type in tower_types:
		var btn := _create_button(type)
		add_child(btn)
		tower_buttons[type] = btn


func _create_button(type: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 80)
	btn.flat = true
	btn.name = type.capitalize() + "Button"
	
	# Container für Sprite + Kosten
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	# Tower-Sprite (erster Frame)
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % type
	if ResourceLoader.exists(texture_path):
		var full_tex: Texture2D = load(texture_path)
		var atlas := AtlasTexture.new()
		atlas.atlas = full_tex
		atlas.region = Rect2(0, 0, 16, 16)
		tex_rect.texture = atlas
	
	vbox.add_child(tex_rect)
	
	# Kosten-Label
	var cost: int = TowerData.get_stat(type, "cost")
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%dg" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	
	# Styling
	_apply_button_style(btn, false)
	
	# Signal
	btn.pressed.connect(_on_tower_button_pressed.bind(type))
	
	return btn


func _apply_button_style(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	
	if is_selected:
		style.bg_color = Color(0.2, 0.4, 0.2, 0.9)
		style.border_color = Color(0.4, 1.0, 0.4)
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style.border_color = Color(0.4, 0.4, 0.4)
	
	btn.add_theme_stylebox_override("normal", style)
	
	# Hover Style
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	hover_style.border_color = Color(0.6, 0.6, 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)


func _on_tower_button_pressed(type: String) -> void:
	if selected_type == type:
		# Deselektieren bei erneutem Klick
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
	# Buttons aktualisieren basierend auf Leistbarkeit
	for type in tower_buttons:
		var btn: Button = tower_buttons[type]
		_update_button_affordability(btn, type)


func _update_button_affordability(btn: Button, type: String) -> void:
	var cost: int = TowerData.get_stat(type, "cost")
	var can_afford := GameState.can_afford(cost)
	
	# Button-Transparenz
	btn.modulate.a = 1.0 if can_afford else 0.5
	
	# Kosten-Label Farbe
	var cost_label := btn.find_child("CostLabel", true, false) as Label
	if cost_label:
		if can_afford:
			cost_label.remove_theme_color_override("font_color")
		else:
			cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func get_selected_type() -> String:
	return selected_type


func has_selection() -> bool:
	return selected_type != ""
