# Dunkles Forschungsarchiv für die persistente Incremental-Progression.
extends CanvasLayer
class_name MetaProgressionUI

signal panel_closed

var panel: PanelContainer
var essence_label: Label
var level_label: Label
var stats_label: Label
var milestone_label: Label
var research_root: VBoxContainer
var _tree_was_paused := false

const COLOR_BG := Color("10131f")
const COLOR_PANEL := Color("181d2e")
const COLOR_CARD := Color("20273b")
const COLOR_BORDER := Color("394866")
const COLOR_TEXT := Color("edf3ff")
const COLOR_MUTED := Color("9aa8c2")
const COLOR_AETHER := Color("75ddff")
const COLOR_GOLD := Color("f4cf6a")


func _ready() -> void:
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	_connect_signals()
	_refresh()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.07, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# Dezente horizontale Bänder geben Tiefe, ohne fremde Assets einzuführen.
	for i in range(6):
		var band := ColorRect.new()
		band.color = Color(0.15, 0.3, 0.48, 0.025 + i * 0.008)
		band.position = Vector2(0, 90 + i * 155)
		band.size = Vector2(1920, 2)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.add_child(band)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1010, 850)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.style_panel(panel, "carved")
	else:
		panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_BORDER, 3, 14))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := UITheme.create_ribbon_title("ARKANES ARCHIV", "blue", 410, 23)
	title.custom_minimum_size.y = 58
	for child in title.get_children():
		if child is Label:
			child.offset_top = -4
			child.offset_bottom = -4
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Dauerhafte Forschung · Jeder Run nährt den nächsten"
	_style_label(subtitle, 12, UITheme.COLOR_TEXT_DARK)
	title_box.add_child(subtitle)

	var currency_box := PanelContainer.new()
	currency_box.custom_minimum_size = Vector2(230, 58)
	if UITheme:
		UITheme.style_panel(currency_box, "carved_small")
	else:
		currency_box.add_theme_stylebox_override("panel", _panel_style(Color("111a2a"), COLOR_AETHER.darkened(0.25), 2, 10))
	header.add_child(currency_box)
	essence_label = Label.new()
	essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(essence_label, 18, Color("185a78"))
	currency_box.add_child(essence_label)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(46, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.icon = IconSystem.get_texture("close") if IconSystem else null
	if UITheme:
		UITheme.center_button_icon(close_button)
	close_button.add_theme_constant_override("icon_max_width", 18)
	close_button.tooltip_text = "Schließen (Esc)"
	close_button.pressed.connect(hide_panel)
	if UITheme:
		UITheme.style_icon_button(close_button, true)
	else:
		_style_dark_button(close_button, Color("713d58"))
	header.add_child(close_button)

	var progress_panel := PanelContainer.new()
	if UITheme:
		progress_panel.add_theme_stylebox_override("panel", UITheme.create_info_badge_style())
	else:
		progress_panel.add_theme_stylebox_override("panel", _panel_style(Color("121827"), Color("293752"), 1, 10))
	root.add_child(progress_panel)
	var progress_margin := MarginContainer.new()
	progress_margin.add_theme_constant_override("margin_left", 14)
	progress_margin.add_theme_constant_override("margin_right", 14)
	progress_margin.add_theme_constant_override("margin_top", 10)
	progress_margin.add_theme_constant_override("margin_bottom", 10)
	progress_panel.add_child(progress_margin)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 22)
	progress_margin.add_child(progress_row)

	level_label = Label.new()
	level_label.custom_minimum_size.x = 180
	_style_label(level_label, 14, Color("795518"))
	progress_row.add_child(level_label)

	stats_label = Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(stats_label, 12, UITheme.COLOR_TEXT_DARK)
	progress_row.add_child(stats_label)

	milestone_label = Label.new()
	milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	milestone_label.custom_minimum_size.x = 230
	_style_label(milestone_label, 12, Color("185a78"))
	progress_row.add_child(milestone_label)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("785d32"))
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	research_root = VBoxContainer.new()
	research_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_root.add_theme_constant_override("separation", 16)
	scroll.add_child(research_root)

	var footer := Label.new()
	footer.text = "Aether wird sofort gespeichert. Tiefere Runs zahlen überproportional mehr aus."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(footer, 11, Color("554731"))
	root.add_child(footer)


func _connect_signals() -> void:
	if not ProgressionSystem:
		return
	ProgressionSystem.essence_changed.connect(_on_essence_changed)
	ProgressionSystem.account_progress_changed.connect(_on_account_progress_changed)
	ProgressionSystem.research_changed.connect(_on_research_changed)
	ProgressionSystem.milestone_reached.connect(_on_milestone_reached)


func show_panel() -> void:
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	visible = true
	if UITheme:
		UITheme.animate_panel_open(panel)


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	panel_closed.emit()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _refresh() -> void:
	if not ProgressionSystem or not research_root:
		return
	essence_label.text = "✦  %s AETHER" % _format_number(ProgressionSystem.essence)
	level_label.text = "ARCHIV-STUFE %d  ·  %d/%d XP" % [
		ProgressionSystem.account_level,
		ProgressionSystem.account_xp,
		ProgressionSystem.get_xp_required()
	]
	stats_label.text = "Bestwelle %d   ·   %d Runs   ·   %s Kills" % [
		ProgressionSystem.best_wave,
		ProgressionSystem.total_runs,
		_format_number(ProgressionSystem.total_kills)
	]
	var milestone: Dictionary = ProgressionSystem.get_next_milestone()
	if int(milestone.get("wave", 0)) > 0:
		milestone_label.text = "Nächstes Ziel: Welle %d  (+%d ✦)" % [milestone.wave, milestone.reward]
	else:
		milestone_label.text = "Alle Meilensteine gemeistert"
	_rebuild_research_cards()


func _rebuild_research_cards() -> void:
	for child in research_root.get_children():
		child.queue_free()

	for tier in range(1, 4):
		var tier_label := Label.new()
		var requirement := 0 if tier == 1 else (3 if tier == 2 else 10)
		tier_label.text = "STUFE %d%s" % [tier, "  ·  ab %d investierten Rängen" % requirement if requirement > 0 else ""]
		_style_label(tier_label, 14, Color("795518") if tier == 1 else Color("185a78"))
		research_root.add_child(tier_label)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 12)
		research_root.add_child(grid)

		for research_id in ProgressionSystem.get_research_ids():
			var data: Dictionary = ProgressionSystem.get_research_data(research_id)
			if int(data.get("tier", 1)) == tier:
				grid.add_child(_create_research_card(research_id, data))


func _create_research_card(research_id: String, data: Dictionary) -> PanelContainer:
	var level := ProgressionSystem.get_research_level(research_id)
	var max_level := int(data.get("max_level", 1))
	var unlocked := ProgressionSystem.is_research_unlocked(research_id)
	var accent: Color = data.get("color", COLOR_AETHER)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(455, 148)
	if UITheme:
		UITheme.style_panel(card, "carved_small")
	else:
		card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD if unlocked else Color("171b26"), accent.darkened(0.35) if unlocked else Color("313746"), 2, 10))
	if not unlocked:
		card.modulate = Color(0.68, 0.66, 0.61, 0.86)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(58, 58)
	icon_panel.add_theme_stylebox_override("panel", _panel_style(accent.darkened(0.65), accent, 1, 8))
	row.add_child(icon_panel)
	var icon_texture := IconSystem.get_texture(String(data.get("icon", "upgrades"))) if IconSystem else null
	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(42, 42)
		icon_panel.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.text = "✦"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_label(glyph, 25, accent)
		icon_panel.add_child(glyph)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	var name_label := Label.new()
	name_label.text = String(data.get("name", research_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(name_label, 15, UITheme.COLOR_TEXT_DARK)
	name_row.add_child(name_label)
	var rank_label := Label.new()
	_style_label(rank_label, 12, accent.darkened(0.38))
	rank_label.text = "%d/%d" % [level, max_level]
	name_row.add_child(rank_label)

	var description := Label.new()
	description.text = String(data.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 38
	_style_label(description, 11, Color("554b3b"))
	info.add_child(description)

	var buy_button := Button.new()
	buy_button.custom_minimum_size.y = 36
	var cost := ProgressionSystem.get_research_cost(research_id)
	if not unlocked:
		var required := int(data.get("requires_invested", 0))
		buy_button.text = "GESPERRT  ·  %d/%d RÄNGE" % [ProgressionSystem.get_total_research_levels(), required]
		buy_button.disabled = true
	elif level >= max_level:
		buy_button.text = "MAXIMIERT"
		buy_button.disabled = true
	else:
		buy_button.text = "ERFORSCHEN   %d ✦" % cost
		buy_button.disabled = ProgressionSystem.essence < cost
		buy_button.pressed.connect(_on_purchase_pressed.bind(research_id, card))
	if UITheme:
		UITheme.style_button(buy_button)
	else:
		_style_dark_button(buy_button, accent.darkened(0.45))
	info.add_child(buy_button)
	return card


func _on_purchase_pressed(research_id: String, card: Control) -> void:
	if not ProgressionSystem.purchase_research(research_id):
		if Sound: Sound.play_error()
		return
	if Sound: Sound.play_upgrade()
	var accent: Color = ProgressionSystem.get_research_data(research_id).get("color", COLOR_AETHER)
	if VFX: VFX.screen_flash(Color(accent.r, accent.g, accent.b, 0.2), 0.12)
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(card, "modulate", Color(1.35, 1.35, 1.55), 0.10)
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(card, "modulate", Color.WHITE, 0.18)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.15)
	tween.chain().tween_callback(_refresh)


func _on_essence_changed(_total: int, _delta: int) -> void:
	if visible: _refresh()


func _on_account_progress_changed(_level: int, _xp: int, _required: int) -> void:
	if visible: _refresh()


func _on_research_changed(_research_id: String, _level: int) -> void:
	if visible: _refresh()


func _on_milestone_reached(_wave: int, _reward: int) -> void:
	if visible: _refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel and not panel.get_global_rect().has_point(event.global_position):
			hide_panel()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()


func _panel_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _style_dark_button(button: Button, accent: Color) -> void:
	var normal := _panel_style(accent, accent.lightened(0.16), 1, 6)
	var hover := _panel_style(accent.lightened(0.12), accent.lightened(0.3), 2, 6)
	var pressed := _panel_style(accent.darkened(0.12), accent, 1, 6)
	var disabled := _panel_style(Color("262b38"), Color("343b4c"), 1, 6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("697286"))
	button.add_theme_font_size_override("font_size", 12)
	if UITheme and UITheme.game_font:
		button.add_theme_font_override("font", UITheme.game_font)


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if UITheme and UITheme.game_font:
		label.add_theme_font_override("font", UITheme.game_font)


func _format_number(value: int) -> String:
	if value >= 1_000_000:
		return "%.2fM" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1fK" % (float(value) / 1_000.0)
	return str(value)
