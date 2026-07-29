# ui/item_combine_ui.gd
# Panel alle 5 Wellen: zwei Items derselben Rarität zu einem stärkeren kombinieren
extends CanvasLayer
class_name ItemCombineUI

signal items_combined(result_item: Dictionary)
signal panel_closed

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var grid_container: GridContainer
var preview_slot_a: PanelContainer
var preview_slot_b: PanelContainer
var result_label: Label
var combine_button: Button
var close_button: Button

var selected_a: Dictionary = {}
var selected_b: Dictionary = {}
var current_wave: int = 0

const SLOT_SIZE := 48
const GRID_COLUMNS := 5

# Slot-Farben wie im Inventar, damit beide Panels gleich aussehen
const COLOR_SLOT_BG := ItemInventoryUI.COLOR_SLOT_BG
const COLOR_SLOT_BG_HOVER := ItemInventoryUI.COLOR_SLOT_BG_HOVER
const COLOR_SLOT_BG_DIMMED := ItemInventoryUI.COLOR_SLOT_BG_DIMMED
const COLOR_SLOT_DISABLED := ItemInventoryUI.COLOR_SLOT_INCOMPATIBLE
const SLOT_ALPHA_DISABLED := ItemInventoryUI.SLOT_ALPHA_INCOMPATIBLE
const RARITY_NAMES := ItemInventoryUI.RARITY_NAMES


func _ready() -> void:
	layer = 150  # Wie WaveUpgradeUI: über Inventar und HUD
	visible = false
	# WICHTIG: Muss während Pause funktionieren
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()

	if ItemSystem:
		ItemSystem.inventory_changed.connect(_on_inventory_changed)


func _setup_ui() -> void:
	# Dunkler Hintergrund
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	add_child(bg)

	# Zentrierter Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	add_child(center)

	# Hauptpanel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 460)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UI.SP_5)
	margin.add_theme_constant_override("margin_right", UI.SP_5)
	margin.add_theme_constant_override("margin_top", UI.SP_5)
	margin.add_theme_constant_override("margin_bottom", UI.SP_5)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	margin.add_child(vbox)

	# Titel
	title_label = Label.new()
	title_label.text = "Schmiede"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("edf3ff"))
	vbox.add_child(title_label)

	# Untertitel
	subtitle_label = Label.new()
	subtitle_label.text = "Zwei Items gleicher Seltenheit ergeben ein besseres Item"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	vbox.add_child(subtitle_label)

	# Auswahl-Vorschau: [A] + [B] = Ergebnis
	var preview_box := HBoxContainer.new()
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_box.add_theme_constant_override("separation", 10)
	preview_box.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	vbox.add_child(preview_box)

	preview_slot_a = _create_slot_panel()
	preview_box.add_child(preview_slot_a)

	preview_box.add_child(_create_symbol_label("+"))

	preview_slot_b = _create_slot_panel()
	preview_box.add_child(preview_slot_b)

	preview_box.add_child(_create_symbol_label("="))

	result_label = Label.new()
	result_label.text = "?"
	result_label.custom_minimum_size = Vector2(150, 0)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	preview_box.add_child(result_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Inventar-Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	vbox.add_child(scroll)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	scroll.add_child(grid_center)

	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLUMNS
	grid_container.add_theme_constant_override("h_separation", 6)
	grid_container.add_theme_constant_override("v_separation", 6)
	grid_container.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	grid_center.add_child(grid_container)

	# Buttons
	var button_hbox := HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	button_hbox.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	vbox.add_child(button_hbox)

	combine_button = Button.new()
	combine_button.text = "Kombinieren"
	combine_button.custom_minimum_size = Vector2(150, 35)
	combine_button.disabled = true
	combine_button.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	combine_button.pressed.connect(_on_combine_pressed)
	button_hbox.add_child(combine_button)

	close_button = Button.new()
	close_button.text = "Fertig"
	close_button.custom_minimum_size = Vector2(140, 35)
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	close_button.pressed.connect(_on_close_pressed)
	close_button.theme_type_variation = &"SecondaryButton"
	button_hbox.add_child(close_button)

	combine_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _create_symbol_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	return label


# === ANZEIGEN / SCHLIESSEN ===

func show_panel(wave: int = 0) -> void:
	current_wave = wave
	selected_a = {}
	selected_b = {}

	_close_other_panels()
	get_tree().paused = true

	title_label.text = ("Schmiede - nach Welle %d" % wave) if wave > 0 else "Schmiede"
	_refresh_grid()

	visible = true

	# Animation (Panel-Tween läuft weiter, obwohl der Baum pausiert ist)
	if UITheme:
		UITheme.animate_panel_open(panel)

	print("[ItemCombineUI] Panel angezeigt nach Welle %d" % wave)


func hide_panel() -> void:
	selected_a = {}
	selected_b = {}
	if UITheme:
		UITheme.animate_panel_close(panel, func():
			visible = false
			get_tree().paused = false
		)
	panel_closed.emit()


func _close_other_panels() -> void:
	"""Schließt andere UI-Panels die im Weg sein könnten"""
	var item_inventory := get_node_or_null("/root/Main/ItemInventoryUI")
	if item_inventory and item_inventory.has_method("hide_panel") and item_inventory.visible:
		item_inventory.hide_panel()

	var upgrade_overview := get_node_or_null("/root/Main/UpgradeOverviewUI")
	if upgrade_overview and upgrade_overview.has_method("hide_panel") and upgrade_overview.visible:
		upgrade_overview.hide_panel()


# === GRID ===

func _on_inventory_changed() -> void:
	if visible:
		_refresh_grid()


func _refresh_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	if not ItemSystem:
		return

	var inventory := ItemSystem.get_inventory()

	# Auswahl aufräumen, falls die Items nicht mehr im Inventar liegen (z.B. nach dem Kombinieren)
	selected_a = _keep_if_in_inventory(selected_a, inventory)
	selected_b = _keep_if_in_inventory(selected_b, inventory)

	for item in inventory:
		var slot := _create_slot_panel()
		_fill_slot(slot, item)
		grid_container.add_child(slot)

	_update_preview()
	_update_subtitle()


func _keep_if_in_inventory(item: Dictionary, inventory: Array) -> Dictionary:
	if item.is_empty():
		return {}
	var uid: String = item.get("uid", "")
	for it in inventory:
		if it.get("uid", "") == uid:
			return item
	return {}


func _create_slot_panel() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_BG
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

	return slot


func _fill_slot(slot: PanelContainer, item: Dictionary) -> void:
	slot.set_meta("item", item)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
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
	dot.add_theme_font_size_override("font_size", 16)
	dot.add_theme_color_override("font_color", item.get("color", Color.WHITE))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(dot)

	slot.tooltip_text = "%s (%s)" % [
		item.get("name", "Item"),
		RARITY_NAMES.get(item.get("rarity", "common"), "")
	]

	_apply_slot_base_style(slot)

	# Nicht kombinierbare Items sind nicht anklickbar
	if _is_selectable(item):
		slot.gui_input.connect(_on_slot_input.bind(slot))
		slot.mouse_entered.connect(_on_slot_hover.bind(slot, true))
		slot.mouse_exited.connect(_on_slot_hover.bind(slot, false))


# Grundzustand eines Slots: Rarität, Auswahl-Rahmen, oder ausgegraut
func _apply_slot_base_style(slot: PanelContainer) -> void:
	if not slot or not slot.has_meta("style") or not slot.has_meta("item"):
		return

	var style: StyleBoxFlat = slot.get_meta("style")
	var item: Dictionary = slot.get_meta("item")
	var rarity_color: Color = item.get("color", Color.WHITE)

	if _is_selected(item):
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = rarity_color.lightened(0.3)
		style.bg_color = COLOR_SLOT_BG_HOVER
		style.shadow_size = 0
		slot.modulate.a = 1.0
		return

	var selectable := _is_selectable(item)
	var border_width := 2 if selectable else 1
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	if selectable:
		style.border_color = rarity_color.darkened(0.3)
		style.bg_color = COLOR_SLOT_BG
		slot.modulate.a = 1.0
		# Partner derselben Vorlage heben sich ab: sie liefern ein vorhersagbares Ergebnis.
		if ItemSystem and ItemSystem.is_guaranteed_combine(selected_a, item):
			style.border_color = rarity_color.lightened(0.15)
			style.shadow_color = Color(rarity_color, 0.5)
			style.shadow_size = 3
		else:
			style.shadow_size = 0
	else:
		style.border_color = COLOR_SLOT_DISABLED
		style.bg_color = COLOR_SLOT_BG_DIMMED
		style.shadow_size = 0
		slot.modulate.a = SLOT_ALPHA_DISABLED


# Auswählbar: kombinierbar überhaupt, und passend zur bereits getroffenen Auswahl
func _is_selectable(item: Dictionary) -> bool:
	if not ItemSystem:
		return false
	if _is_selected(item):
		return true
	if not ItemSystem.is_item_combinable(item):
		return false
	if not selected_a.is_empty():
		return ItemSystem.can_combine(selected_a, item)
	return true


func _is_selected(item: Dictionary) -> bool:
	var uid: String = item.get("uid", "")
	if uid.is_empty():
		return false
	return selected_a.get("uid", "") == uid or selected_b.get("uid", "") == uid


func _refresh_slot_styles() -> void:
	for slot in grid_container.get_children():
		_apply_slot_base_style(slot as PanelContainer)


func _on_slot_input(event: InputEvent, slot: PanelContainer) -> void:
	if not slot.has_meta("item"):
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	_toggle_selection(slot.get_meta("item"))
	get_viewport().set_input_as_handled()


func _on_slot_hover(slot: PanelContainer, entered: bool) -> void:
	if not slot.has_meta("item") or not slot.has_meta("style"):
		return
	var item: Dictionary = slot.get_meta("item")
	if _is_selected(item):
		return

	if entered:
		var style: StyleBoxFlat = slot.get_meta("style")
		style.bg_color = COLOR_SLOT_BG_HOVER
	else:
		_apply_slot_base_style(slot)


func _toggle_selection(item: Dictionary) -> void:
	var uid: String = item.get("uid", "")

	if selected_a.get("uid", "") == uid:
		# Erstes Item abwählen - zweites rückt nach
		selected_a = selected_b
		selected_b = {}
	elif selected_b.get("uid", "") == uid:
		selected_b = {}
	elif selected_a.is_empty():
		selected_a = item
	elif selected_b.is_empty():
		if not ItemSystem.can_combine(selected_a, item):
			if Sound:
				Sound.play_error()
			return
		selected_b = item
	else:
		# Beide Plätze belegt - neue Auswahl startet neu
		selected_a = item
		selected_b = {}

	if Sound:
		Sound.play_click()

	_refresh_slot_styles()
	_update_preview()


# === VORSCHAU / STATUS ===

func _update_preview() -> void:
	_fill_preview_slot(preview_slot_a, selected_a)
	_fill_preview_slot(preview_slot_b, selected_b)

	var result: Dictionary = ItemSystem.preview_combine(selected_a, selected_b) if ItemSystem else {}
	var ready_to_combine := not result.is_empty()

	combine_button.disabled = not ready_to_combine

	if ready_to_combine:
		# Nur die Ziel-Rarität verraten - Name und Icon bleiben bis nach dem Kombinieren
		# geheim, damit die Überraschung nicht vorweggenommen wird.
		var rarity: String = result.get("rarity", "common")
		result_label.text = "Ergebnis: %s\n?" % RARITY_NAMES.get(rarity, rarity)
		if ItemSystem.is_guaranteed_combine(selected_a, selected_b):
			result_label.text += "\ngarantiert"
		result_label.add_theme_color_override("font_color", result.get("color", UI.TEXT_SECOND))
	elif not selected_a.is_empty():
		result_label.text = "Zweites Item derselben Seltenheit wählen"
		result_label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	else:
		result_label.text = "?"
		result_label.add_theme_color_override("font_color", UI.TEXT_SECOND)


func _fill_preview_slot(slot: PanelContainer, item: Dictionary) -> void:
	# Sofort entfernen (nicht nur queue_free), sonst überlagern sich alte und neue Icons
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

	var style: StyleBoxFlat = slot.get_meta("style")

	if item.is_empty():
		if slot.has_meta("item"):
			slot.remove_meta("item")
		style.bg_color = COLOR_SLOT_BG_DIMMED
		style.border_color = Color(0.3, 0.3, 0.35)
		slot.tooltip_text = ""
		return

	slot.set_meta("item", item)
	style.bg_color = COLOR_SLOT_BG
	style.border_color = item.get("color", Color.WHITE).darkened(0.2)
	slot.tooltip_text = "%s (%s)" % [
		item.get("name", "Item"),
		RARITY_NAMES.get(item.get("rarity", "common"), "")
	]

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
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


func _update_subtitle() -> void:
	if ItemSystem and not ItemSystem.has_combinable_pair():
		subtitle_label.text = "Keine kombinierbaren Items mehr - es braucht zwei gleicher Seltenheit"
		subtitle_label.add_theme_color_override("font_color", Color("c98d6b"))
	else:
		subtitle_label.text = "Zwei Items gleicher Seltenheit ergeben ein besseres Item\nZwei identische Items ergeben garantiert dieselbe Ausrüstung eine Stufe höher\nFrisch geschmiedete Items ruhen bis zur nächsten Schmiede"
		subtitle_label.add_theme_color_override("font_color", UI.TEXT_SECOND)


# === AKTIONEN ===

func _on_combine_pressed() -> void:
	if selected_a.is_empty() or selected_b.is_empty() or not ItemSystem:
		return

	var result := ItemSystem.combine_items(selected_a.get("uid", ""), selected_b.get("uid", ""))
	if result.is_empty():
		if Sound:
			Sound.play_error()
		return

	selected_a = {}
	selected_b = {}

	if Sound:
		Sound.play_upgrade()
	if VFX:
		VFX.screen_flash(result.get("color", Color.WHITE), 0.12)

	_refresh_grid()
	_show_result_feedback(result)
	items_combined.emit(result)


func _show_result_feedback(item: Dictionary) -> void:
	var feedback := Label.new()
	feedback.text = "%s (%s)" % [
		item.get("name", "Item"),
		RARITY_NAMES.get(item.get("rarity", "common"), "")
	]
	feedback.add_theme_font_size_override("font_size", 16)
	feedback.add_theme_color_override("font_color", item.get("color", Color.WHITE))
	feedback.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	feedback.add_theme_constant_override("outline_size", 3)
	feedback.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	feedback.position = panel.global_position + Vector2(panel.size.x * 0.5 - 80, 120)
	add_child(feedback)

	var tween := feedback.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # WICHTIG
	tween.set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 30, 0.8)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tween.chain().tween_callback(feedback.queue_free)


func _on_close_pressed() -> void:
	if Sound:
		Sound.play_click()
	hide_panel()
