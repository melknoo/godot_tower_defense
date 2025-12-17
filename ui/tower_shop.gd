# ui/tower_shop.gd
# Tower-Auswahl mit Scroll-Funktionalität (einzeilig)
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

var selected_type := ""
var tower_buttons: Dictionary = {}
var grid_container: HBoxContainer
var scroll_left_btn: Button
var scroll_right_btn: Button
var clip_container: Control

var corner_textures: Dictionary = {}

const VISIBLE_TOWERS := 6
const BUTTON_WIDTH := 95
const BUTTON_HEIGHT := 85
const H_SPACING := 12
const PADDING := 8

# Archer Spritesheet Konstanten
const ARCHER_FRAME_SIZE := Vector2(192, 192)
const ARCHER_COLUMNS := 8

var scroll_offset := 0
var max_scroll := 0


func _ready() -> void:
	_setup_frame()
	_load_corner_textures()
	_load_arrow_textures()
	_create_tower_buttons()
	
	call_deferred("_position_at_bottom_center")
	call_deferred("_move_to_front")
	
	GameState.gold_changed.connect(_on_gold_changed)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _move_to_front() -> void:
	var parent := get_parent()
	if parent:
		parent.move_child(self, -1)


func _setup_frame() -> void:
	var content_width := VISIBLE_TOWERS * (BUTTON_WIDTH + H_SPACING) + 80 + (PADDING * 2)
	var content_height := 105
	custom_minimum_size = Vector2(content_width, content_height)
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style_panel := Panel.new()
	style_panel.name = "FramePanel"
	style_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	style_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.4, 0.35, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style_panel.add_theme_stylebox_override("panel", style)
	add_child(style_panel)
	
	var margin := MarginContainer.new()
	margin.name = "PaddingMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PADDING)
	margin.add_theme_constant_override("margin_right", PADDING)
	margin.add_theme_constant_override("margin_top", PADDING)
	margin.add_theme_constant_override("margin_bottom", PADDING)
	add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.name = "MainHBox"
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	
	scroll_left_btn = Button.new()
	scroll_left_btn.name = "ScrollLeftBtn"
	scroll_left_btn.custom_minimum_size = Vector2(40, 70)
	scroll_left_btn.flat = true
	scroll_left_btn.visible = false
	scroll_left_btn.focus_mode = Control.FOCUS_NONE
	scroll_left_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll_left_btn.expand_icon = true
	scroll_left_btn.pressed.connect(_on_scroll_left)
	scroll_left_btn.button_down.connect(_on_left_btn_down)
	scroll_left_btn.button_up.connect(_on_left_btn_up)
	_style_arrow_button(scroll_left_btn)
	hbox.add_child(scroll_left_btn)
	
	clip_container = Control.new()
	clip_container.name = "ClipContainer"
	clip_container.clip_contents = true
	clip_container.custom_minimum_size = Vector2(VISIBLE_TOWERS * (BUTTON_WIDTH + H_SPACING), 85)
	clip_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(clip_container)
	
	grid_container = HBoxContainer.new()
	grid_container.name = "GridContainer"
	grid_container.add_theme_constant_override("separation", H_SPACING)
	clip_container.add_child(grid_container)
	
	scroll_right_btn = Button.new()
	scroll_right_btn.name = "ScrollRightBtn"
	scroll_right_btn.custom_minimum_size = Vector2(40, 70)
	scroll_right_btn.flat = true
	scroll_right_btn.visible = false
	scroll_right_btn.focus_mode = Control.FOCUS_NONE
	scroll_right_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll_right_btn.expand_icon = true
	scroll_right_btn.pressed.connect(_on_scroll_right)
	scroll_right_btn.button_down.connect(_on_right_btn_down)
	scroll_right_btn.button_up.connect(_on_right_btn_up)
	_style_arrow_button(scroll_right_btn)
	hbox.add_child(scroll_right_btn)


func _style_arrow_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)


var arrow_left_idle: Texture2D
var arrow_left_pressed: Texture2D
var arrow_right_idle: Texture2D
var arrow_right_pressed: Texture2D


func _load_arrow_textures() -> void:
	var base_path := "res://assets/ui/"
	var scale_factor := 4.0
	
	if ResourceLoader.exists(base_path + "arrow_button_right_idle.png"):
		arrow_right_idle = load(base_path + "arrow_button_right_idle.png")
	if ResourceLoader.exists(base_path + "arrow_button_right_pressed.png"):
		arrow_right_pressed = load(base_path + "arrow_button_right_pressed.png")
	
	if ResourceLoader.exists(base_path + "arrow_button_left_idle.png"):
		arrow_left_idle = load(base_path + "arrow_button_left_idle.png")
	elif arrow_right_idle:
		var img := arrow_right_idle.get_image()
		img.flip_x()
		arrow_left_idle = ImageTexture.create_from_image(img)
	
	if ResourceLoader.exists(base_path + "arrow_button_left_pressed.png"):
		arrow_left_pressed = load(base_path + "arrow_button_left_pressed.png")
	elif arrow_right_pressed:
		var img := arrow_right_pressed.get_image()
		img.flip_x()
		arrow_left_pressed = ImageTexture.create_from_image(img)
	
	arrow_right_idle = _scale_texture(arrow_right_idle, scale_factor)
	arrow_right_pressed = _scale_texture(arrow_right_pressed, scale_factor)
	arrow_left_idle = _scale_texture(arrow_left_idle, scale_factor)
	arrow_left_pressed = _scale_texture(arrow_left_pressed, scale_factor)
	
	if arrow_right_idle:
		scroll_right_btn.icon = arrow_right_idle
	if arrow_left_idle:
		scroll_left_btn.icon = arrow_left_idle


func _scale_texture(tex: Texture2D, scale: float) -> ImageTexture:
	if tex == null:
		return null
	var img := tex.get_image()
	var new_size := Vector2i(int(img.get_width() * scale), int(img.get_height() * scale))
	img.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _on_left_btn_down() -> void:
	if arrow_left_pressed:
		scroll_left_btn.icon = arrow_left_pressed


func _on_left_btn_up() -> void:
	if arrow_left_idle:
		scroll_left_btn.icon = arrow_left_idle


func _on_right_btn_down() -> void:
	if arrow_right_pressed:
		scroll_right_btn.icon = arrow_right_pressed


func _on_right_btn_up() -> void:
	if arrow_right_idle:
		scroll_right_btn.icon = arrow_right_idle


func _load_corner_textures() -> void:
	var base_path := "res://assets/ui/"
	var corners := ["top_left", "top_right", "bottom_left", "bottom_right"]
	
	for corner in corners:
		var path := base_path + "selection_%s_corner.png" % corner
		if ResourceLoader.exists(path):
			corner_textures[corner] = load(path)


func _position_at_bottom_center() -> void:
	var viewport_size := get_viewport_rect().size
	var shop_width := size.x if size.x > 0 else custom_minimum_size.x
	var shop_height := size.y if size.y > 0 else custom_minimum_size.y
	
	position.x = (viewport_size.x - shop_width) / 2
	position.y = viewport_size.y - shop_height - 5


func _create_tower_buttons() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	tower_buttons.clear()
	
	var available_types := TowerData.get_available_tower_types()
	
	for type in available_types:
		var btn := _create_button(type)
		grid_container.add_child(btn)
		tower_buttons[type] = btn
	
	_update_scroll(available_types.size())


func _update_scroll(tower_count: int) -> void:
	max_scroll = maxi(0, tower_count - VISIBLE_TOWERS)
	scroll_offset = mini(scroll_offset, max_scroll)
	
	scroll_left_btn.visible = max_scroll > 0
	scroll_right_btn.visible = max_scroll > 0
	
	_apply_scroll()


func _apply_scroll() -> void:
	var offset_x := -scroll_offset * (BUTTON_WIDTH + H_SPACING)
	grid_container.position.x = offset_x
	
	scroll_left_btn.disabled = scroll_offset <= 0
	scroll_right_btn.disabled = scroll_offset >= max_scroll
	
	scroll_left_btn.modulate.a = 0.4 if scroll_left_btn.disabled else 1.0
	scroll_right_btn.modulate.a = 0.4 if scroll_right_btn.disabled else 1.0


func _on_scroll_left() -> void:
	if scroll_offset > 0:
		scroll_offset -= 1
		_apply_scroll()
		Sound.play_click()


func _on_scroll_right() -> void:
	if scroll_offset < max_scroll:
		scroll_offset += 1
		_apply_scroll()
		Sound.play_click()


func _on_element_unlocked(_element: String) -> void:
	_create_tower_buttons()


func _get_tower_icon_texture(type: String) -> Texture2D:
	# Archer: Ersten Frame aus Spritesheet extrahieren
	if type == "archer":
		var spritesheet_path := "res://assets/elemental_tower/archer_spritesheet.png"
		if ResourceLoader.exists(spritesheet_path):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(spritesheet_path)
			# Nur den zentralen Bereich des 192x192 Frames nehmen (Charakter ist ca. 80x80 in der Mitte)
			var margin := 56.0  # (192 - 80) / 2
			atlas.region = Rect2(margin, margin, 80, 80)
			return atlas
	
	# Standard Tower Textur
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % type
	if ResourceLoader.exists(texture_path):
		var full_tex: Texture2D = load(texture_path)
		var data := TowerData.get_tower_data(type)
		var is_animated: bool = data.get("animated", true)
		
		if is_animated:
			# Ersten Frame aus 16x64 Spritesheet
			var atlas := AtlasTexture.new()
			atlas.atlas = full_tex
			atlas.region = Rect2(0, 0, 16, 16)
			return atlas
		else:
			return full_tex
	
	return null


func _create_button(type: String) -> Control:
	var container := Control.new()
	container.name = type.capitalize() + "Container"
	container.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.name = "Button"
	container.add_child(btn)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 5)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	btn.add_child(hbox)
	
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(36, 36)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var icon_texture := _get_tower_icon_texture(type)
	if icon_texture:
		tex_rect.texture = icon_texture
	
	hbox.add_child(tex_rect)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)
	
	var data := TowerData.get_tower_data(type)
	var display_name: String = data.get("name", type.capitalize())
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)
	
	var cost: int = TowerData.get_stat(type, "cost")
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%dg" % cost
	if UITheme and UITheme.game_font:
		cost_label.add_theme_font_override("font", UITheme.game_font)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(cost_label)
	
	if TowerData.is_combination(type):
		var combo_label := Label.new()
		combo_label.name = "ComboLabel"
		combo_label.text = "★"
		if UITheme and UITheme.game_font:
			combo_label.add_theme_font_override("font", UITheme.game_font)
		combo_label.add_theme_font_size_override("font_size", 9)
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
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
	corners_node.name = "CornersNode"
	corners_node.visible = false
	corners_node.z_index = 100
	
	container.set_meta("corners_node", corners_node)
	container.add_child(corners_node)
	
	var btn_width := BUTTON_WIDTH
	var btn_height := BUTTON_HEIGHT
	var scl := Vector2(1.5, 1.5)
	var corner_size := 8.0 * scl.x
	var offset := 8.0
	
	var tl := Sprite2D.new()
	tl.texture = corner_textures["top_left"]
	tl.scale = scl
	tl.position = Vector2(offset, offset)
	tl.centered = false
	corners_node.add_child(tl)
	
	var tr := Sprite2D.new()
	tr.texture = corner_textures["top_right"]
	tr.scale = scl
	tr.position = Vector2(btn_width - corner_size - offset, offset)
	tr.centered = false
	corners_node.add_child(tr)
	
	var bl := Sprite2D.new()
	bl.texture = corner_textures["bottom_left"]
	bl.scale = scl
	bl.position = Vector2(offset, btn_height - corner_size - offset)
	bl.centered = false
	corners_node.add_child(bl)
	
	var br := Sprite2D.new()
	br.texture = corner_textures["bottom_right"]
	br.scale = scl
	br.position = Vector2(btn_width - corner_size - offset, btn_height - corner_size - offset)
	br.centered = false
	corners_node.add_child(br)


func _apply_button_style(btn: Button) -> void:
	var style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)


func _on_tower_button_pressed(type: String) -> void:
	Sound.play_click()
	
	if selected_type == type:
		deselect()
	else:
		select(type)


func select(type: String) -> void:
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
		var corners_node: Node2D = container.get_meta("corners_node", null)
		if corners_node:
			corners_node.visible = (type == selected_type)


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
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func get_selected_type() -> String:
	return selected_type


func has_selection() -> bool:
	return selected_type != ""
