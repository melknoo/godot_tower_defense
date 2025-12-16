# ui/tower_shop.gd
# Tower-Auswahl - zeigt nur freigeschaltete Tower
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

var selected_type := ""
var tower_buttons: Dictionary = {}
var button_container: HBoxContainer

var corner_textures: Dictionary = {}


func _ready() -> void:
	_load_corner_textures()
	
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 32)
	add_child(button_container)
	
	_create_tower_buttons()
	GameState.gold_changed.connect(_on_gold_changed)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _load_corner_textures() -> void:
	var base_path := "res://assets/ui/"
	var corners := ["top_left", "top_right", "bottom_left", "bottom_right"]
	
	for corner in corners:
		var path := base_path + "selection_%s_corner.png" % corner
		if ResourceLoader.exists(path):
			corner_textures[corner] = load(path)


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


func _create_button(type: String) -> Control:
	var container := Control.new()
	container.name = type.capitalize() + "Container"
	container.custom_minimum_size = Vector2(100, 75)
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 75)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.name = "Button"
	container.add_child(btn)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(44, 44)
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
	
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)
	
	var data := TowerData.get_tower_data(type)
	var display_name: String = data.get("name", type.capitalize())
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)
	
	var cost: int = TowerData.get_stat(type, "cost")
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%dg" % cost
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(cost_label)
	
	if TowerData.is_combination(type):
		var combo_label := Label.new()
		combo_label.name = "ComboLabel"
		combo_label.text = "★ Kombi"
		combo_label.add_theme_font_size_override("font_size", 9)
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(combo_label)
	
	_add_corners(container)
	_apply_button_style(btn)
	btn.pressed.connect(_on_tower_button_pressed.bind(type))
	
	var desc: String = data.get("description", "")
	btn.tooltip_text = "%s\n%s\nKosten: %d Gold" % [display_name, desc, cost]
	
	return container


func _add_corners(container: Control) -> void:
	if corner_textures.size() < 4:
		return
	
	var corners_node := Node2D.new()
	corners_node.name = "Corners"
	corners_node.visible = false
	container.add_child(corners_node)
	
	var size := container.custom_minimum_size
	var scale := Vector2(2.5, 2.5)
	var offset_x := -8.0
	var offset_y := -12.0
	
	var tl := Sprite2D.new()
	tl.texture = corner_textures["top_left"]
	tl.scale = scale
	tl.position = Vector2(offset_x, offset_y)
	tl.centered = false
	corners_node.add_child(tl)
	
	var tr := Sprite2D.new()
	tr.texture = corner_textures["top_right"]
	tr.scale = scale
	var tr_width := tr.texture.get_width() * scale.x
	tr.position = Vector2(size.x - tr_width - offset_x, offset_y)
	tr.centered = false
	corners_node.add_child(tr)
	
	var bl := Sprite2D.new()
	bl.texture = corner_textures["bottom_left"]
	bl.scale = scale
	var bl_height := bl.texture.get_height() * scale.y
	bl.position = Vector2(offset_x, size.y - bl_height - offset_y)
	bl.centered = false
	corners_node.add_child(bl)
	
	var br := Sprite2D.new()
	br.texture = corner_textures["bottom_right"]
	br.scale = scale
	var br_width := br.texture.get_width() * scale.x
	var br_height := br.texture.get_height() * scale.y
	br.position = Vector2(size.x - br_width - offset_x, size.y - br_height - offset_y)
	br.centered = false
	corners_node.add_child(br)


func _apply_button_style(btn: Button) -> void:
	var style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)


func _on_tower_button_pressed(type: String) -> void:
	# Click Sound
	Sound.play_click()
	
	if selected_type == type:
		deselect()
	else:
		select(type)


func select(type: String) -> void:
	Sound.play_click()
	selected_type = type
	_update_corner_visibility()
	tower_selected.emit(type)


func deselect() -> void:
	selected_type = ""
	_update_corner_visibility()
	tower_deselected.emit()


func _update_corner_visibility() -> void:
	for type in tower_buttons:
		var container: Control = tower_buttons[type]
		var corners := container.get_node_or_null("Corners")
		if corners:
			corners.visible = (type == selected_type)


func _on_gold_changed(_amount: int) -> void:
	for type in tower_buttons:
		var container: Control = tower_buttons[type]
		var btn := container.get_node("Button") as Button
		_update_button_affordability(btn, container, type)


func _update_button_affordability(btn: Button, container: Control, type: String) -> void:
	var cost: int = TowerData.get_stat(type, "cost")
	var can_afford := GameState.can_afford(cost)
	
	container.modulate.a = 1.0 if can_afford else 0.5
	
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
