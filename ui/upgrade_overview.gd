# ui/upgrade_overview_ui.gd
# Zeigt alle aktiven Upgrades des aktuellen Runs
extends CanvasLayer
class_name UpgradeOverviewUI

signal panel_closed

var panel: PanelContainer
var title_label: Label
var count_label: Label
var scroll_container: ScrollContainer
var upgrades_container: VBoxContainer
var close_button: Button
var no_upgrades_label: Label

const CATEGORY_ORDER := ["element", "tower_type", "global", "economy", "supply", "special", "instant"]
const CATEGORY_NAMES := {
	"element": "Elementar",
	"tower_type": "Tower-Typ",
	"economy": "Wirtschaft",
	"supply": "Supply",
	"global": "Global",
	"special": "Spezial",
	"instant": "Sofort"
}
const CATEGORY_COLORS := {
	"element": Color(0.4, 0.6, 1.0),
	"economy": Color(1.0, 0.85, 0.3),
	"supply": Color(0.5, 0.8, 0.4),
	"global": Color(0.9, 0.5, 0.9),
	"special": Color(1.0, 0.5, 0.3),
	"instant": Color(0.3, 1.0, 0.6),
	"tower_type": Color(0.7, 0.7, 0.8)
}


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()
	
	if UpgradeSystem:
		UpgradeSystem.upgrades_changed.connect(_on_upgrades_changed)


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 450)
	center.add_child(panel)
	
	if UITheme:
		UITheme.style_panel(panel, "panel_dark")
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Aktive Upgrades"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	header.add_child(title_label)
	
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme and UITheme.game_font:
		count_label.add_theme_font_override("font", UITheme.game_font)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(count_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 300)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)
	
	upgrades_container = VBoxContainer.new()
	upgrades_container.add_theme_constant_override("separation", 8)
	upgrades_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(upgrades_container)
	
	no_upgrades_label = Label.new()
	no_upgrades_label.text = "Noch keine Upgrades gewählt.\nSchließe Wellen ab, um Upgrades zu erhalten!"
	no_upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_upgrades_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		no_upgrades_label.add_theme_font_override("font", UITheme.game_font)
	no_upgrades_label.add_theme_font_size_override("font_size", 12)
	no_upgrades_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	no_upgrades_label.visible = false
	upgrades_container.add_child(no_upgrades_label)
	
	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)
	
	close_button = Button.new()
	close_button.text = "Schließen"
	close_button.custom_minimum_size = Vector2(120, 32)
	close_button.pressed.connect(_on_close_pressed)
	btn_center.add_child(close_button)
	
	if UITheme:
		UITheme.style_button(close_button)
	close_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))


func show_panel() -> void:
	Sound.play_click()
	_refresh_upgrades()
	visible = true
	
	panel.modulate.a = 0
	panel.scale = Vector2(0.9, 0.9)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): visible = false)
	panel_closed.emit()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _refresh_upgrades() -> void:
	for child in upgrades_container.get_children():
		if child != no_upgrades_label:
			child.queue_free()
	
	if not UpgradeSystem:
		no_upgrades_label.visible = true
		count_label.text = "0 Upgrades"
		return
	
	var active := UpgradeSystem.get_active_upgrades()
	var total_count := UpgradeSystem.get_active_upgrade_count()
	
	count_label.text = "%d Upgrade%s" % [total_count, "" if total_count == 1 else "s"]
	
	if active.is_empty():
		no_upgrades_label.visible = true
		return
	
	no_upgrades_label.visible = false
	
	var by_category: Dictionary = {}
	for upgrade_id in active:
		var data: Dictionary = UpgradeSystem.get_upgrade_data(upgrade_id)
		var category: String = data.get("category", "special")
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append({"id": upgrade_id, "stacks": active[upgrade_id], "data": data})
	
	for category in CATEGORY_ORDER:
		if not by_category.has(category):
			continue
		var cat_container := _create_category_section(category, by_category[category])
		upgrades_container.add_child(cat_container)


func _create_category_section(category: String, upgrades: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	
	var cat_label := Label.new()
	cat_label.text = CATEGORY_NAMES.get(category, category.capitalize())
	if UITheme and UITheme.game_font:
		cat_label.add_theme_font_override("font", UITheme.game_font)
	cat_label.add_theme_font_size_override("font_size", 12)
	cat_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, Color.WHITE))
	section.add_child(cat_label)
	
	for upgrade_info in upgrades:
		var entry := _create_upgrade_entry(upgrade_info, category)
		section.add_child(entry)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	section.add_child(spacer)
	
	return section


func _create_upgrade_entry(upgrade_info: Dictionary, category: String) -> PanelContainer:
	var data: Dictionary = upgrade_info["data"]
	var stacks: int = upgrade_info["stacks"]
	var max_stacks: int = data.get("max_stacks", 1)
	var cat_color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
	
	var entry := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.border_color = cat_color.darkened(0.4)
	style.border_width_left = 3
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	entry.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	entry.add_child(hbox)
	
	var icon_label := Label.new()
	icon_label.text = data.get("icon", "?")
	icon_label.custom_minimum_size = Vector2(30, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(icon_label)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	var name_label := Label.new()
	name_label.text = data.get("name", upgrade_info["id"])
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	info_vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	if UITheme and UITheme.game_font:
		desc_label.add_theme_font_override("font", UITheme.game_font)
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(desc_label)
	
	if max_stacks > 1:
		var stack_vbox := VBoxContainer.new()
		stack_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(stack_vbox)
		
		var stack_label := Label.new()
		stack_label.text = "%d/%d" % [stacks, max_stacks]
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme and UITheme.game_font:
			stack_label.add_theme_font_override("font", UITheme.game_font)
		stack_label.add_theme_font_size_override("font_size", 11)
		
		if stacks >= max_stacks:
			stack_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			stack_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		
		stack_vbox.add_child(stack_label)
		
		var dots_label := Label.new()
		var dots := ""
		for i in range(max_stacks):
			dots += "●" if i < stacks else "○"
		dots_label.text = dots
		dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dots_label.add_theme_font_size_override("font_size", 8)
		dots_label.add_theme_color_override("font_color", cat_color)
		stack_vbox.add_child(dots_label)
	
	return entry


func _on_upgrades_changed() -> void:
	if visible:
		_refresh_upgrades()


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect := panel.get_global_rect()
		var mouse_pos := get_viewport().get_mouse_position()
		
		if not panel_rect.has_point(mouse_pos):
			hide_panel()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()
