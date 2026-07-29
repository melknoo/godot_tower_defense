# ui/tower_shop.gd
# Tower-Auswahl mit Scroll-Funktionalität (einzeilig)
extends Container
class_name TowerShop

signal tower_selected(tower_type: String)
signal tower_deselected

const ShopCardScene := preload("res://ui/shop/shop_card.tscn")

var selected_type := ""
var tower_buttons: Dictionary = {}
var grid_container: HBoxContainer
var scroll_left_btn: Button
var scroll_right_btn: Button
var clip_container: Control

const VISIBLE_TOWERS := 5
const PADDING := 8

# Aus ShopCard.preferred_size() abgeleitet — keine eigene Kartengrößen-Quelle hier.
var BUTTON_WIDTH: int
var BUTTON_HEIGHT: int
var H_SPACING: int

var scroll_offset := 0
var max_scroll := 0


func _ready() -> void:
	var card_size := ShopCard.preferred_size()
	BUTTON_WIDTH = int(card_size.x)
	BUTTON_HEIGHT = int(card_size.y)
	H_SPACING = UI.SP_2

	_setup_frame()
	_load_arrow_textures()
	_create_tower_buttons()
	
	call_deferred("_position_at_bottom_center")
	call_deferred("_move_to_front")
	
	GameState.gold_changed.connect(_on_gold_changed)
	# Die Stadt schaltet sich ueber das Supply-Maximum frei - der Shop muss das mitbekommen.
	GameState.supply_changed.connect(_on_supply_changed)
	TowerData.element_unlocked.connect(_on_element_unlocked)


func _move_to_front() -> void:
	var parent := get_parent()
	if parent:
		parent.move_child(self, -1)


func _setup_frame() -> void:
	var content_width := VISIBLE_TOWERS * (BUTTON_WIDTH + H_SPACING) + 80 + (PADDING * 2)
	var content_height := BUTTON_HEIGHT + PADDING * 2
	custom_minimum_size = Vector2(content_width, content_height)
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_shop_gui_input)

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
	if UITheme:
		UITheme.center_button_icon(scroll_left_btn)
	scroll_left_btn.pressed.connect(_on_scroll_left)
	scroll_left_btn.button_down.connect(_on_left_btn_down)
	scroll_left_btn.button_up.connect(_on_left_btn_up)
	_style_arrow_button(scroll_left_btn)
	hbox.add_child(scroll_left_btn)
	
	clip_container = Control.new()
	clip_container.name = "ClipContainer"
	clip_container.clip_contents = true
	clip_container.custom_minimum_size = Vector2(VISIBLE_TOWERS * (BUTTON_WIDTH + H_SPACING), BUTTON_HEIGHT)
	clip_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_container.mouse_filter = Control.MOUSE_FILTER_STOP
	clip_container.gui_input.connect(_on_shop_gui_input)
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
	if UITheme:
		UITheme.center_button_icon(scroll_right_btn)
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



func _position_at_bottom_center() -> void:
	var viewport_size := get_viewport_rect().size
	var shop_width := size.x if size.x > 0 else custom_minimum_size.x
	var shop_height := size.y if size.y > 0 else custom_minimum_size.y
	
	position.x = (viewport_size.x - shop_width) / 2 - 100
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


# Mausrad scrollt die Turmliste horizontal (Rad hoch = nach links).
func _on_shop_gui_input(event: InputEvent) -> void:
	if max_scroll <= 0:
		return

	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_on_scroll_left()
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_on_scroll_right()
		accept_event()


func _on_element_unlocked(_element: String) -> void:
	_create_tower_buttons()


var _city_was_available := false

func _on_supply_changed(_used: int, _max_supply: int) -> void:
	# Nur neu aufbauen, wenn sich die Verfuegbarkeit wirklich geaendert hat -
	# supply_changed feuert bei jeder Platzierung.
	var available := TowerData.is_tower_available("city")
	if available == _city_was_available:
		return
	_city_was_available = available
	_create_tower_buttons()


func _build_tower_data(type: String) -> Dictionary:
	var data := TowerData.get_tower_data(type)
	var cost: int = TowerData.get_tower_cost(type)
	return {
		"id": type,
		"name": data.get("name", type.capitalize()),
		"description": data.get("description", ""),
		"cost": cost,
		"texture": TowerData.get_tower_icon_texture(type),
		"affordable": GameState.can_afford(cost),
	}


func _create_button(type: String) -> Control:
	var card: ShopCard = ShopCardScene.instantiate()
	var data := _build_tower_data(type)
	card.setup(data)
	card.tooltip_text = "%s\n%s\n%d gold" % [data["name"], data["description"], data["cost"]]
	card.pressed.connect(_on_tower_button_pressed)
	card.set_selected(type == selected_type)
	return card


func _on_tower_button_pressed(type: String) -> void:
	Sound.play_click()

	if selected_type == type:
		deselect()
	else:
		select(type)


func select(type: String) -> void:
	selected_type = type
	_update_selection_visuals()
	tower_selected.emit(type)


func deselect() -> void:
	selected_type = ""
	_update_selection_visuals()
	tower_deselected.emit()


func _update_selection_visuals() -> void:
	for type in tower_buttons:
		var card: ShopCard = tower_buttons[type]
		card.set_selected(type == selected_type)


func _on_gold_changed(_amount: int) -> void:
	for type in tower_buttons:
		var card: ShopCard = tower_buttons[type]
		card.setup(_build_tower_data(type))
		card.set_selected(type == selected_type)


func get_selected_type() -> String:
	return selected_type


func has_selection() -> bool:
	return selected_type != ""
