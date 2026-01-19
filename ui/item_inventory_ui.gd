# ui/item_inventory_ui.gd
# Zeigt gesammelte Items und ermöglicht Drag & Drop auf Türme
extends CanvasLayer
class_name ItemInventoryUI

signal item_selected(item: Dictionary)
signal panel_closed

var panel: PanelContainer
var title_label = IconSystem
var count_label: Label
var grid_container: GridContainer
var close_button: Button
var detail_panel: PanelContainer
var detail_name: Label
var detail_desc: Label
var detail_rarity: Label
var detail_allowed: Label
var sell_button: Button

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

const SELL_PRICES := {
	"common": 10,
	"uncommon": 15,
	"rare": 25,
	"epic": 50
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
	
	title_label = title_label.create_rich_label(200, 20)
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
	
	# Detail Panel
	_setup_detail_panel()
	
	# Drag Preview
	drag_preview = Control.new()
	drag_preview.visible = false
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 200
	add_child(drag_preview)


func _setup_detail_panel() -> void:
	detail_panel = PanelContainer.new()
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
	
	# Header mit Close Button
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	detail_name = Label.new()
	detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme and UITheme.game_font:
		detail_name.add_theme_font_override("font", UITheme.game_font)
	detail_name.add_theme_font_size_override("font_size", 14)
	header.add_child(detail_name)
	
	# Close Button rechts im Header
	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.icon = IconSystem.get_texture("close")
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_on_detail_close_pressed)
	close_btn.flat = true
	header.add_child(close_btn)
	
	# Icon-Farbe für Hover-Effekt
	close_btn.add_theme_color_override("icon_normal_color", Color(0.3, 0.3, 0.3))
	close_btn.add_theme_color_override("icon_hover_color", Color(0.8, 0.2, 0.2))
	close_btn.add_theme_color_override("icon_pressed_color", Color(0.6, 0.1, 0.1))
	
	# Transparenter Hintergrund
	var transparent_style := StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	transparent_style.content_margin_left = 3
	transparent_style.content_margin_right = 0
	transparent_style.content_margin_top = 0
	transparent_style.content_margin_bottom = 0
	close_btn.add_theme_stylebox_override("normal", transparent_style)
	close_btn.add_theme_stylebox_override("hover", transparent_style)
	close_btn.add_theme_stylebox_override("pressed", transparent_style)
	close_btn.add_theme_stylebox_override("focus", transparent_style)
	
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
	
	var sell_sep := HSeparator.new()
	sell_sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sell_sep)
	
	# Verkaufen Button
	var sell_center := CenterContainer.new()
	vbox.add_child(sell_center)
	
	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(140, 32)
	sell_button.pressed.connect(_on_sell_pressed)
	sell_center.add_child(sell_button)
	
	if UITheme:
		UITheme.style_button(sell_button)
	
	# Roter Stil für Verkaufen
	var sell_style := StyleBoxFlat.new()
	sell_style.bg_color = Color(0.6, 0.2, 0.2)
	sell_style.border_color = Color(0.8, 0.3, 0.3)
	sell_style.border_width_left = 1
	sell_style.border_width_right = 1
	sell_style.border_width_top = 1
	sell_style.border_width_bottom = 1
	sell_style.corner_radius_top_left = 4
	sell_style.corner_radius_top_right = 4
	sell_style.corner_radius_bottom_left = 4
	sell_style.corner_radius_bottom_right = 4
	sell_button.add_theme_stylebox_override("normal", sell_style)
	
	var sell_hover := sell_style.duplicate()
	sell_hover.bg_color = Color(0.7, 0.25, 0.25)
	sell_button.add_theme_stylebox_override("hover", sell_hover)
	
	var sell_pressed := sell_style.duplicate()
	sell_pressed.bg_color = Color(0.5, 0.15, 0.15)
	sell_button.add_theme_stylebox_override("pressed", sell_pressed)
	
	sell_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
	sell_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	sell_button.visible = false
	
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


func _show_sell_feedback(amount: int) -> void:
	var feedback := Label.new()
	feedback.text = "+%d" % amount
	feedback.add_theme_font_size_override("font_size", 16)
	feedback.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	feedback.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	feedback.add_theme_constant_override("outline_size", 2)
	
	if UITheme and UITheme.game_font:
		feedback.add_theme_font_override("font", UITheme.game_font)
	
	feedback.position = detail_panel.position + Vector2(detail_panel.size.x / 2 - 20, -10)
	add_child(feedback)
	
	var tween := feedback.create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 40, 0.6)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(feedback.queue_free)


func _clear_selection_visuals() -> void:
	for slot in grid_container.get_children():
		if slot.has_meta("style") and slot.has_meta("item"):
			var style: StyleBoxFlat = slot.get_meta("style")
			var item: Dictionary = slot.get_meta("item")
			
			# Border zurücksetzen
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = item.get("color", Color.WHITE).darkened(0.3)
			
			# Hintergrund zurücksetzen
			style.bg_color = Color(0.15, 0.15, 0.18)


func _show_item_detail(item: Dictionary) -> void:
	detail_panel.visible = true
	
	var rarity_color: Color = item.get("color", Color.WHITE)
	var rarity: String = item.get("rarity", "common")
	
	# Common Items dunkler darstellen
	if rarity == "common":
		rarity_color = rarity_color.darkened(0.3)
	
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
	
	if sell_button:
		var sell_price: int = SELL_PRICES.get(rarity, 10)
		sell_button.text = "Verkaufen (%d)" % [sell_price]
		sell_button.icon = IconSystem.get_texture("gold")
		sell_button.visible = true


func get_selected_item() -> Dictionary:
	return selected_item


func has_selection() -> bool:
	return not selected_item.is_empty()


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func _on_detail_close_pressed() -> void:
	Sound.play_click()
	deselect_item()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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


func _on_sell_pressed() -> void:
	if selected_item.is_empty():
		return
	
	var uid: String = selected_item.get("uid", "")
	if uid == "":
		return
	
	var rarity: String = selected_item.get("rarity", "common")
	var sell_price: int = SELL_PRICES.get(rarity, 10)
	
	if ItemSystem:
		ItemSystem.remove_item(uid)
	
	GameState.gold += sell_price
	Sound.play_sell()
	_show_sell_feedback(sell_price)
	
	selected_item = {}
	detail_panel.visible = false
	_clear_selection_visuals()
	
	print("[ItemInventoryUI] Item verkauft für %d Gold" % sell_price)


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _refresh_inventory() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	if not ItemSystem:
		return
	
	var inventory := ItemSystem.get_inventory()
	count_label.text = "%d / %d" % [inventory.size(), ItemSystem.MAX_INVENTORY]
	
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
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)
	
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
	
	var dot := Label.new()
	dot.text = "●"
	dot.position = Vector2(2, 2)
	dot.add_theme_font_size_override("font_size", 8)
	dot.add_theme_color_override("font_color", rarity_color)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(dot)
	
	slot.gui_input.connect(_on_slot_input.bind(slot))
	slot.mouse_entered.connect(_on_slot_hover.bind(slot, true))
	slot.mouse_exited.connect(_on_slot_hover.bind(slot, false))


func _on_slot_input(event: InputEvent, slot: PanelContainer) -> void:
	if not slot.has_meta("item"):
		return
	
	if event is InputEventMouseButton and event.pressed:
		var item: Dictionary = slot.get_meta("item")
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_item(item, slot)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Rechtsklick: Deselektieren wenn es das ausgewählte Item ist
			if selected_item.get("uid") == item.get("uid"):
				deselect_item()
				Sound.play_click()
				get_viewport().set_input_as_handled()


func _on_slot_hover(slot: PanelContainer, entered: bool) -> void:
	if not slot.has_meta("item"):
		return
	
	var style: StyleBoxFlat = slot.get_meta("style")
	var item: Dictionary = slot.get_meta("item")
	
	# Nicht hovern wenn es das ausgewählte Item ist
	var is_selected: bool = selected_item.get("uid") == item.get("uid")
	
	if entered:
		# Nur Hover-Farbe wenn nicht ausgewählt
		if not is_selected:
			style.bg_color = Color(0.25, 0.25, 0.3)
		# Nur Detail anzeigen wenn nichts ausgewählt ist
		if selected_item.is_empty():
			_show_item_detail(item)
			_position_detail_panel_at_slot(slot)
	else:
		# Nur Farbe zurücksetzen wenn nicht ausgewählt
		if not is_selected:
			style.bg_color = Color(0.15, 0.15, 0.18)
		# Detail-Panel nur schließen wenn kein Item ausgewählt ist
		if selected_item.is_empty():
			detail_panel.visible = false


func _select_item(item: Dictionary, slot: PanelContainer) -> void:
	_clear_selection_visuals()
	
	if selected_item.get("uid") == item.get("uid"):
		selected_item = {}
		detail_panel.visible = false
		return
	
	selected_item = item
	
	var style: StyleBoxFlat = slot.get_meta("style")
	var rarity_color: Color = item.get("color", Color.WHITE)
	
	# Dickerer, hellerer Border
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = rarity_color.lightened(0.3)
	
	# Hellerer Hintergrund
	style.bg_color = Color(0.25, 0.25, 0.3)
	
	_show_item_detail(item)
	
	# Position Detail-Panel neben dem Slot
	_position_detail_panel_at_slot(slot)
	
	item_selected.emit(item)
	Sound.play_click()


func _position_detail_panel_at_slot(slot: PanelContainer) -> void:
	# Warte einen Frame damit die Sizes aktualisiert sind
	await get_tree().process_frame
	
	# Prüfe ob Slot noch existiert (könnte zwischenzeitlich gelöscht worden sein)
	if not is_instance_valid(slot) or not slot.is_inside_tree():
		detail_panel.visible = false
		return
	
	# Globale Position des Slots
	var slot_global_pos := slot.global_position
	var slot_size := slot.size
	
	# Detail-Panel an bottom-right corner des Slots
	var new_x := slot_global_pos.x + slot_size.x - 10  # 10px nach links für leichte Überlappung
	var new_y := slot_global_pos.y + slot_size.y - 10  # 10px nach oben für leichte Überlappung
	
	# Viewport-Größe prüfen für Overflow-Schutz
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = detail_panel.size.x if detail_panel.size.x > 0 else 200.0
	var panel_height: float = detail_panel.size.y if detail_panel.size.y > 0 else 200.0
	
	# Falls Panel rechts rausgeht, links vom Slot anzeigen
	if new_x + panel_width > viewport_size.x - 20:
		new_x = slot_global_pos.x - panel_width + 10
	
	# Falls Panel unten rausgeht, nach oben verschieben
	if new_y + panel_height > viewport_size.y - 20:
		new_y = slot_global_pos.y - panel_height + 10
	
	detail_panel.position = Vector2(new_x, new_y)


func deselect_item() -> void:
	_clear_selection_visuals()
	selected_item = {}
	detail_panel.visible = false
	if sell_button:
		sell_button.visible = false
