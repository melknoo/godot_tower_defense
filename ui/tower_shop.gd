# ui/tower_shop.gd
# Tower-Auswahl mit Scroll-Funktionalität
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

var selected_type := ""
var tower_buttons: Dictionary = {}
var grid_container: GridContainer
var scroll_left_btn: Button
var scroll_right_btn: Button
var clip_container: Control

var corner_textures: Dictionary = {}

const COLUMNS := 5  # Sichtbare Spalten
const ROWS := 2  # Maximal 2 Zeilen
const VISIBLE_TOWERS := COLUMNS * ROWS  # 10 Tower sichtbar
const BUTTON_WIDTH := 95
const BUTTON_HEIGHT := 65
const H_SPACING := 12  # Etwas mehr Spacing für Selection-Ecken
const V_SPACING := 10
const PADDING := 14  # Mehr Padding für Selection-Ecken

var scroll_offset := 0  # Aktueller Scroll-Index (in Spalten)
var max_scroll := 0


func _ready() -> void:
	_setup_frame()
	_load_corner_textures()
	_load_arrow_textures()
	_create_tower_buttons()
	
	call_deferred("_position_at_bottom_center")
	call_deferred("_move_to_front")  # Nach vorne bringen
	
	GameState.gold_changed.connect(_on_gold_changed)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _move_to_front() -> void:
	# TowerShop an das Ende der Child-Liste verschieben (wird zuletzt gerendert = oben)
	var parent := get_parent()
	if parent:
		parent.move_child(self, -1)


func _setup_frame() -> void:
	var content_width := COLUMNS * (BUTTON_WIDTH + H_SPACING) + 60 + (PADDING * 2)  # +60 für Scroll-Buttons
	var content_height := ROWS * (BUTTON_HEIGHT + V_SPACING) + (PADDING * 2)
	custom_minimum_size = Vector2(content_width, content_height)
	
	# Mouse-Events stoppen, damit sie nicht zum Spielfeld durchgehen
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Hintergrund-Panel
	var style_panel := Panel.new()
	style_panel.name = "FramePanel"
	style_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	style_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Auch hier stoppen
	
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
	
	# Margin Container für Padding
	var margin := MarginContainer.new()
	margin.name = "PaddingMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PADDING)
	margin.add_theme_constant_override("margin_right", PADDING)
	margin.add_theme_constant_override("margin_top", PADDING)
	margin.add_theme_constant_override("margin_bottom", PADDING)
	add_child(margin)
	
	# HBox für Layout: [Left Arrow] [Content] [Right Arrow]
	var hbox := HBoxContainer.new()
	hbox.name = "MainHBox"
	hbox.add_theme_constant_override("separation", 5)
	margin.add_child(hbox)
	
	# Linker Scroll-Button
	scroll_left_btn = Button.new()
	scroll_left_btn.name = "ScrollLeftBtn"
	scroll_left_btn.custom_minimum_size = Vector2(24, 0)
	scroll_left_btn.flat = true
	scroll_left_btn.visible = false
	scroll_left_btn.pressed.connect(_on_scroll_left)
	hbox.add_child(scroll_left_btn)
	
	# Clip-Container für das Grid (versteckt overflow)
	clip_container = Control.new()
	clip_container.name = "ClipContainer"
	clip_container.clip_contents = true
	clip_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(clip_container)
	
	# Grid Container
	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = 100  # Sehr hoch, damit alles in einer "Zeile" von Spalten ist
	grid_container.add_theme_constant_override("h_separation", H_SPACING)
	grid_container.add_theme_constant_override("v_separation", V_SPACING)
	clip_container.add_child(grid_container)
	
	# Rechter Scroll-Button
	scroll_right_btn = Button.new()
	scroll_right_btn.name = "ScrollRightBtn"
	scroll_right_btn.custom_minimum_size = Vector2(24, 0)
	scroll_right_btn.flat = true
	scroll_right_btn.visible = false
	scroll_right_btn.pressed.connect(_on_scroll_right)
	hbox.add_child(scroll_right_btn)


var arrow_left_idle: Texture2D
var arrow_left_pressed: Texture2D
var arrow_right_idle: Texture2D
var arrow_right_pressed: Texture2D


func _load_arrow_textures() -> void:
	var base_path := "res://assets/ui/"
	
	if ResourceLoader.exists(base_path + "arrow_button_right_idle.png"):
		arrow_right_idle = load(base_path + "arrow_button_right_idle.png")
	if ResourceLoader.exists(base_path + "arrow_button_right_pressed.png"):
		arrow_right_pressed = load(base_path + "arrow_button_right_pressed.png")
	
	# Linke Pfeile (separate Assets oder gespiegelte Texturen)
	if ResourceLoader.exists(base_path + "arrow_button_left_idle.png"):
		arrow_left_idle = load(base_path + "arrow_button_left_idle.png")
	elif arrow_right_idle:
		# Gespiegelte Version erstellen
		var img := arrow_right_idle.get_image()
		img.flip_x()
		arrow_left_idle = ImageTexture.create_from_image(img)
	
	if ResourceLoader.exists(base_path + "arrow_button_left_pressed.png"):
		arrow_left_pressed = load(base_path + "arrow_button_left_pressed.png")
	elif arrow_right_pressed:
		var img := arrow_right_pressed.get_image()
		img.flip_x()
		arrow_left_pressed = ImageTexture.create_from_image(img)
	
	# Texturen zu Buttons zuweisen
	if arrow_right_idle:
		scroll_right_btn.icon = arrow_right_idle
	if arrow_left_idle:
		scroll_left_btn.icon = arrow_left_idle


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
	
	# Horizontal zentriert
	position.x = (viewport_size.x - shop_width) / 2
	# Vertikal: Im HUD-Bereich (HUD ist 200px hoch, Shop 10px vom oberen HUD-Rand)
	position.y = viewport_size.y - 200 + 10


func _create_tower_buttons() -> void:
	# Alte Corner-Nodes entfernen
	for child in get_children():
		if child.name.begins_with("Corners_"):
			child.queue_free()
	
	for child in grid_container.get_children():
		child.queue_free()
	tower_buttons.clear()
	
	var available_types := TowerData.get_available_tower_types()
	
	# Grid mit 2 Zeilen erstellen
	var tower_columns: Array[Array] = []
	var col_count := ceili(float(available_types.size()) / ROWS)
	
	for i in range(col_count):
		tower_columns.append([])
	
	for i in range(available_types.size()):
		var col := i / ROWS
		tower_columns[col].append(available_types[i])
	
	# Grid-Columns auf Anzahl der Spalten setzen
	grid_container.columns = col_count
	
	# Erst alle Zeile-1-Tower, dann alle Zeile-2-Tower
	for row in range(ROWS):
		for col in range(col_count):
			if row < tower_columns[col].size():
				var type: String = tower_columns[col][row]
				var btn := _create_button(type)
				grid_container.add_child(btn)
				tower_buttons[type] = btn
			else:
				# Leerer Platzhalter
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
				grid_container.add_child(spacer)
	
	_update_scroll(available_types.size())


func _update_scroll(tower_count: int) -> void:
	var total_columns := ceili(float(tower_count) / ROWS)
	max_scroll = maxi(0, total_columns - COLUMNS)
	
	scroll_offset = mini(scroll_offset, max_scroll)
	
	# Scroll-Buttons anzeigen/verstecken
	scroll_left_btn.visible = max_scroll > 0
	scroll_right_btn.visible = max_scroll > 0
	
	_apply_scroll()


func _apply_scroll() -> void:
	var offset_x := -scroll_offset * (BUTTON_WIDTH + H_SPACING)
	grid_container.position.x = offset_x
	
	# Button-States aktualisieren
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
	btn.add_child(hbox)
	
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(36, 36)
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
	
	# Corners werden zum TowerShop selbst hinzugefügt, nicht zum Button
	# So werden sie nicht vom clip_container abgeschnitten
	var corners_node := Node2D.new()
	corners_node.name = "Corners_" + container.name
	corners_node.visible = false
	corners_node.z_index = 100  # Über allem anderen
	
	# Speichere Referenz im Container für späteres Zugreifen
	container.set_meta("corners_node", corners_node)
	
	# Zum TowerShop root hinzufügen (nicht zum container!)
	add_child(corners_node)
	
	var btn_size := container.custom_minimum_size
	var scl := Vector2(2.5, 2.5)
	var offset := 6.0  # Ecken leicht außerhalb
	
	var tl := Sprite2D.new()
	tl.texture = corner_textures["top_left"]
	tl.scale = scl
	tl.position = Vector2(-offset, -offset)
	tl.centered = false
	corners_node.add_child(tl)
	
	var tr := Sprite2D.new()
	tr.texture = corner_textures["top_right"]
	tr.scale = scl
	var tr_width := tr.texture.get_width() * scl.x
	tr.position = Vector2(btn_size.x - tr_width + offset, -offset)
	tr.centered = false
	corners_node.add_child(tr)
	
	var bl := Sprite2D.new()
	bl.texture = corner_textures["bottom_left"]
	bl.scale = scl
	var bl_height := bl.texture.get_height() * scl.y
	bl.position = Vector2(-offset, btn_size.y - bl_height + offset)
	bl.centered = false
	corners_node.add_child(bl)
	
	var br := Sprite2D.new()
	br.texture = corner_textures["bottom_right"]
	br.scale = scl
	var br_width := br.texture.get_width() * scl.x
	var br_height := br.texture.get_height() * scl.y
	br.position = Vector2(btn_size.x - br_width + offset, btn_size.y - br_height + offset)
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
			if corners_node.visible:
				# Position der Ecken auf die globale Position des Containers setzen
				corners_node.global_position = container.global_position


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
