# Sammlungs- und Rekrutierungsübersicht für Charaktere (Menüpunkt "Charaktere").
# Gesperrte Karten zeigen Name, Silhouette, Spielstil und Zielfortschritt statt "???",
# damit sie als sichtbare mittelfristige Ziele funktionieren (INCREMENTAL_ROADMAP.md).
extends CanvasLayer
class_name CharacterRosterUI

signal panel_closed

var panel: PanelContainer
var essence_label: Label
var roster_root: VBoxContainer
var _tree_was_paused := false

const COLOR_PANEL := Color("181d2e")
const COLOR_CARD := Color("20273b")
const COLOR_BORDER := Color("394866")
const COLOR_TEXT := Color("edf3ff")
const COLOR_AETHER := Color("75ddff")
const SILHOUETTE := Color(0.05, 0.05, 0.08)

const STAT_LABELS := {
	"total_kills": "Gegner besiegt",
	"best_wave": "Beste Welle",
	"highest_streak": "Höchste Serie"
}


func _ready() -> void:
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	if ProgressionSystem:
		ProgressionSystem.essence_changed.connect(_on_essence_changed)
	_refresh()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.07, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

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

	var title := UITheme.create_ribbon_title("CHARAKTERE", "blue", 410, 23)
	title.custom_minimum_size.y = 58
	for child in title.get_children():
		if child is Label:
			child.offset_top = -4
			child.offset_bottom = -4
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Neue Spielweisen · Freischalten durch Spielziele, Rekrutieren mit Aether"
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
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	close_button.add_theme_constant_override("icon_max_width", 18)
	close_button.expand_icon = true
	close_button.tooltip_text = "Schließen (Esc)"
	close_button.pressed.connect(hide_panel)
	if UITheme:
		UITheme.style_icon_button(close_button, true)
	header.add_child(close_button)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("785d32"))
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	roster_root = VBoxContainer.new()
	roster_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_root.add_theme_constant_override("separation", 16)
	scroll.add_child(roster_root)

	var footer := Label.new()
	footer.text = "Charaktere sind Seitwärtsfortschritt: neue Spielweisen statt roher Macht."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(footer, 11, Color("554731"))
	root.add_child(footer)


func show_panel() -> void:
	_tree_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh()
	visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	panel_closed.emit()


func _refresh() -> void:
	if not ProgressionSystem or not roster_root:
		return
	essence_label.text = "✦  %d AETHER" % ProgressionSystem.essence

	for child in roster_root.get_children():
		child.queue_free()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	roster_root.add_child(grid)

	for char_id in AbilitySystem.CHARACTERS:
		grid.add_child(_create_character_card(char_id, AbilitySystem.CHARACTERS[char_id]))


func _create_character_card(char_id: String, data: Dictionary) -> PanelContainer:
	var unlocked: bool = AbilitySystem.is_character_unlocked(char_id)
	var accent: Color = data.get("color", COLOR_AETHER)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(455, 200)
	if UITheme:
		UITheme.style_panel(card, "carved_small")
	else:
		card.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, accent.darkened(0.35) if unlocked else Color("313746"), 2, 10))
	if not unlocked:
		card.modulate = Color(0.78, 0.76, 0.72, 0.94)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Portrait — gesperrte Charaktere als Silhouette (Form bleibt lesbar)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(58, 58)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_panel.add_theme_stylebox_override("panel", _panel_style(accent.darkened(0.65), accent if unlocked else accent.darkened(0.4), 1, 8))
	row.add_child(icon_panel)
	var icon_texture := _resolve_portrait(data)
	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(42, 42)
		if not unlocked:
			icon.modulate = SILHOUETTE
		icon_panel.add_child(icon)
	else:
		var glyph := Label.new()
		glyph.text = "✦"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_label(glyph, 25, accent if unlocked else SILHOUETTE)
		icon_panel.add_child(glyph)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	var name_label := Label.new()
	name_label.text = String(data.get("name", char_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(name_label, 15, accent if unlocked else UITheme.COLOR_TEXT_DARK)
	name_row.add_child(name_label)
	var status_label := Label.new()
	status_label.text = "Verfügbar" if unlocked else "Gesperrt"
	_style_label(status_label, 11, Color("5a8a5e") if unlocked else Color("8a6a4a"))
	name_row.add_child(status_label)

	var playstyle := Label.new()
	var ability_data: Dictionary = AbilitySystem.ABILITIES.get(String(data.get("starting_ability", "")), {})
	playstyle.text = "%s  ·  Start: %s" % [String(data.get("playstyle", "")), String(ability_data.get("name", "?"))]
	_style_label(playstyle, 11, Color("554b3b"))
	info.add_child(playstyle)

	var passive: Dictionary = data.get("passive", {})
	if not passive.is_empty():
		var passive_label := Label.new()
		passive_label.text = "Passiv: %s" % String(passive.get("description", ""))
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(passive_label, 11, Color("185a78"))
		info.add_child(passive_label)

	if not unlocked:
		_add_unlock_section(info, char_id, card)

	return card


func _add_unlock_section(info: VBoxContainer, char_id: String, card: PanelContainer) -> void:
	var progress: Dictionary = ProgressionSystem.get_character_unlock_progress(char_id)
	if progress.is_empty():
		return

	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", 10)
	info.add_child(goal_row)

	var goal_label := Label.new()
	var stat_name: String = STAT_LABELS.get(String(progress["stat"]), String(progress["stat"]))
	goal_label.text = "%s: %d / %d" % [stat_name, int(progress["current"]), int(progress["target"])]
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(goal_label, 11, UITheme.COLOR_TEXT_DARK)
	goal_row.add_child(goal_label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = float(progress["target"])
	bar.value = minf(float(progress["current"]), bar.max_value)
	bar.show_percentage = false
	info.add_child(bar)

	var recruit_button := Button.new()
	recruit_button.custom_minimum_size.y = 34
	var cost := int(progress["cost"])
	var goal_met: bool = progress["goal_met"]
	if not goal_met:
		recruit_button.text = "ZIEL NOCH NICHT ERREICHT"
		recruit_button.disabled = true
	elif cost <= 0:
		recruit_button.text = "KOSTENLOS REKRUTIEREN"
	else:
		recruit_button.text = "REKRUTIEREN   %d ✦" % cost
		recruit_button.disabled = ProgressionSystem.essence < cost
		if recruit_button.disabled:
			recruit_button.add_theme_color_override("font_disabled_color", Color("b05050"))
	if not recruit_button.disabled:
		recruit_button.pressed.connect(_on_recruit_pressed.bind(char_id, card))
	if UITheme:
		UITheme.style_button(recruit_button)
	info.add_child(recruit_button)


func _on_recruit_pressed(char_id: String, card: Control) -> void:
	if not ProgressionSystem.recruit_character(char_id):
		if Sound: Sound.play_error()
		return
	if Sound: Sound.play_confirm()
	var char_color: Color = AbilitySystem.get_character_data(char_id).get("color", COLOR_AETHER)
	if VFX: VFX.screen_flash(char_color, 0.25)
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.15)
	tween.tween_callback(_refresh)


func _resolve_portrait(data: Dictionary) -> Texture2D:
	if not IconSystem:
		return null
	var texture: Texture2D = IconSystem.get_texture(String(data.get("icon_name", "")))
	if texture == null:
		texture = IconSystem.get_texture(String(data.get("element", "")))
	return texture


func _on_essence_changed(_total: int, _delta: int) -> void:
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


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if UITheme and UITheme.game_font:
		label.add_theme_font_override("font", UITheme.game_font)
