# ui/item_inventory_ui.gd
# Zeigt gesammelte Items und ermöglicht Drag & Drop auf Türme
extends CanvasLayer
class_name ItemInventoryUI

signal item_selected(item: Dictionary)
signal panel_closed

var panel: PanelContainer
#var title_label: Label
var title_label = IconSystem
var count_label: Label
var grid_container: GridContainer
var close_button: Button
var detail_panel: PanelContainer
var detail_name: Label
var detail_desc: Label
var detail_rarity: Label
var detail_allowed: Label

var selected_item: Dictionary = {}
var is_dragging := false
var drag_preview: Control

const SLOT_SIZE := 48
const GRID_COLUMNS := 5
const RARITY_NAMES := {
	"common": "Gewöhnlich",
	"uncommon": "Ungewöhnlich", 
	"rare": "Selten",
	"epic": "Episch"
}


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()
	
	if ItemSystem:
		ItemSystem.inventory_changed.connect(_refresh_inventory)


func _setup_ui() -> void:
	# Hintergrund
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	
	# Hauptpanel links
	panel = PanelContainer.new()
	panel.position = Vector2(20, 100)
	panel.custom_minimum_size = Vector2(300, 400)
	add_child(panel)
	
	if UITheme:
		UITheme.style_panel(panel, "panel_dark")
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	#title_label = Label.new()
	title_label = title_label.create_rich_label(200, 20)
	#title_label.text = "📦 Inventar"
	title_label.text = "%s Inventar" % IconSystem.bb("inventory", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	header.add_child(title_label)
	
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme and UITheme.game_font:
		count_label.add_theme_font_override("font", UITheme.game_font)
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(count_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Info Text
	var info := Label.new()
	info.text = "Klicke Item → Klicke Turm zum Ausrüsten"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		info.add_theme_font_override("font", UITheme.game_font)
	info.add_theme_font_size_override("font_size", 9)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(info)
	
	# Scroll Container für Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLUMNS
	grid_container.add_theme_constant_override("h_separation", 6)
	grid_container.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid_container)
	
	# Close Button
	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)
	
	close_button = Button.new()
	close_button.text = "Schließen"
	close_button.custom_minimum_size = Vector2(100, 28)
	close_button.pressed.connect(_on_close_pressed)
	btn_center.add_child(close_button)
	
	if UITheme:
		UITheme.style_button(close_button)
	close_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	
	# Detail Panel rechts
	_setup_detail_panel()
	
	# Drag Preview
	drag_preview = Control.new()
	drag_preview.visible = false
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 200
	add_child(drag_preview)


func _setup_detail_panel() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.position = Vector2(340, 100)
	detail_panel.custom_minimum_size = Vector2(200, 150)
	detail_panel.visible = false
	add_child(detail_panel)
	
	if UITheme:
		UITheme.style_panel(detail_panel, "panel_light")
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	detail_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	detail_name = Label.new()
	if UITheme and UITheme.game_font:
		detail_name.add_theme_font_override("font", UITheme.game_font)
	detail_name.add_theme_font_size_override("font_size", 14)
	vbox.add_child(detail_name)
	
	detail_rarity = Label.new()
	if UITheme and UITheme.game_font:
		detail_rarity.add_theme_font_override("font", UITheme.game_font)
	detail_rarity.add_theme_font_size_override("font_size", 10)
	vbox.add_child(detail_rarity)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	detail_desc = Label.new()
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_desc.custom_minimum_size = Vector2(170, 0)
	if UITheme and UITheme.game_font:
		detail_desc.add_theme_font_override("font", UITheme.game_font)
	detail_desc.add_theme_font_size_override("font_size", 11)
	detail_desc.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(detail_desc)
	
	detail_allowed = Label.new()
	detail_allowed.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_allowed.custom_minimum_size = Vector2(170, 0)
	if UITheme and UITheme.game_font:
		detail_allowed.add_theme_font_override("font", UITheme.game_font)
	detail_allowed.add_theme_font_size_override("font_size", 9)
	detail_allowed.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(detail_allowed)


func show_panel() -> void:
	Sound.play_click()
	_refresh_inventory()
	visible = true
	
	panel.modulate.a = 0
	panel.scale = Vector2(0.9, 0.9)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)


func hide_panel() -> void:
	deselect_item()
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): visible = false)
	panel_closed.emit()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _refresh_inventory() -> void:
	# Clear grid
	for child in grid_container.get_children():
		child.queue_free()
	
	if not ItemSystem:
		return
	
	var inventory := ItemSystem.get_inventory()
	count_label.text = "%d / %d" % [inventory.size(), ItemSystem.MAX_INVENTORY]
	
	# Create slots
	for i in range(ItemSystem.MAX_INVENTORY):
		var slot := _create_item_slot(i)
		grid_container.add_child(slot)
		
		if i < inventory.size():
			_fill_slot(slot, inventory[i])


func _create_item_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.name = "Slot_%d" % index
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)
	
	slot.set_meta("style", style)
	slot.set_meta("index", index)
	
	return slot


func _fill_slot(slot: PanelContainer, item: Dictionary) -> void:
	slot.set_meta("item", item)
	
	var style: StyleBoxFlat = slot.get_meta("style")
	var rarity_color: Color = item.get("color", Color.WHITE)
	style.border_color = rarity_color.darkened(0.3)
	
	# Icon Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)
	
	# Item Sprite
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(32, 32)
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if ItemSystem:
		var tex := ItemSystem.get_item_texture(item)
		if tex:
			tex_rect.texture = tex
	
	center.add_child(tex_rect)
	
	# Rarity Dot
	var dot := Label.new()
	dot.text = "●"
	dot.position = Vector2(2, 2)
	dot.add_theme_font_size_override("font_size", 8)
	dot.add_theme_color_override("font_color", rarity_color)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(dot)
	
	# Interaktion
	slot.gui_input.connect(_on_slot_input.bind(slot))
	slot.mouse_entered.connect(_on_slot_hover.bind(slot, true))
	slot.mouse_exited.connect(_on_slot_hover.bind(slot, false))


func _on_slot_input(event: InputEvent, slot: PanelContainer) -> void:
	if not slot.has_meta("item"):
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item: Dictionary = slot.get_meta("item")
			_select_item(item, slot)


func _on_slot_hover(slot: PanelContainer, entered: bool) -> void:
	if not slot.has_meta("item"):
		return
	
	var style: StyleBoxFlat = slot.get_meta("style")
	var item: Dictionary = slot.get_meta("item")
	var rarity_color: Color = item.get("color", Color.WHITE)
	
	if entered:
		style.bg_color = Color(0.25, 0.25, 0.3)
		_show_item_detail(item)
	else:
		style.bg_color = Color(0.15, 0.15, 0.18)
		if selected_item.get("uid") != item.get("uid"):
			detail_panel.visible = false


func _select_item(item: Dictionary, slot: PanelContainer) -> void:
	# Deselect previous
	_clear_selection_visuals()
	
	if selected_item.get("uid") == item.get("uid"):
		# Toggle off
		selected_item = {}
		detail_panel.visible = false
		return
	
	selected_item = item
	
	# Visual feedback
	var style: StyleBoxFlat = slot.get_meta("style")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = item.get("color", Color.WHITE)
	
	_show_item_detail(item)
	item_selected.emit(item)
	Sound.play_click()


func deselect_item() -> void:
	_clear_selection_visuals()
	selected_item = {}
	detail_panel.visible = false


func _clear_selection_visuals() -> void:
	for slot in grid_container.get_children():
		if slot.has_meta("style") and slot.has_meta("item"):
			var style: StyleBoxFlat = slot.get_meta("style")
			var item: Dictionary = slot.get_meta("item")
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = item.get("color", Color.WHITE).darkened(0.3)


func _show_item_detail(item: Dictionary) -> void:
	detail_panel.visible = true
	
	var rarity_color: Color = item.get("color", Color.WHITE)
	var rarity: String = item.get("rarity", "common")
	
	detail_name.text = item.get("name", "Item")
	detail_name.add_theme_color_override("font_color", rarity_color)
	
	detail_rarity.text = RARITY_NAMES.get(rarity, rarity.capitalize())
	detail_rarity.add_theme_color_override("font_color", rarity_color.darkened(0.2))
	
	detail_desc.text = item.get("description", "")
	
	var allowed: Array = item.get("allowed_towers", [])
	if allowed.is_empty():
		detail_allowed.text = "Kann auf alle Türme"
	else:
		var names: Array[String] = []
		for t in allowed:
			names.append(t.capitalize())
		detail_allowed.text = "Nur: " + ", ".join(names)


func get_selected_item() -> Dictionary:
	return selected_item


func has_selection() -> bool:
	return not selected_item.is_empty()


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Klick außerhalb des Panels
		var panel_rect := panel.get_global_rect()
		var detail_rect := detail_panel.get_global_rect() if detail_panel.visible else Rect2()
		var mouse_pos := get_viewport().get_mouse_position()
		
		if not panel_rect.has_point(mouse_pos) and not detail_rect.has_point(mouse_pos):
			hide_panel()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			hide_panel()
			get_viewport().set_input_as_handled()
