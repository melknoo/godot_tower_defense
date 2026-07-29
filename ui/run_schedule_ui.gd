# ui/run_schedule_ui.gd
# Fahrplan: zeigt die kommenden Wellen mit ihren Ereignissen (Boss, Perk,
# Ability-Upgrade, Element-Kern, Schmiede). Die Kadenzen kommen aus
# autoload/run_schedule.gd - dieselbe Quelle, aus der auch die "DANACH"-Zeile
# im HUD und die Panel-Logik in main.gd lesen.
extends CanvasLayer
class_name RunScheduleUI

signal panel_closed

const RunSchedule = preload("res://autoload/run_schedule.gd")

# Wie viele Wellen der Fahrplan im Voraus zeigt.
const PREVIEW_WAVES := 12

var panel: PanelContainer
var subtitle_label: Label
var rows_container: VBoxContainer
var close_button: Button


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()


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
	panel.custom_minimum_size = Vector2(520, 470)
	center.add_child(panel)
	if UITheme:
		UITheme.style_panel(panel, "carved")

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

	var title_label := Label.new()
	title_label.text = "Fahrplan"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
	header.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme and UITheme.game_font:
		subtitle_label.add_theme_font_override("font", UITheme.game_font)
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color("554731"))
	header.add_child(subtitle_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color("785d32"))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 6)
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_container)

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
	if Sound:
		Sound.play_click()
	_refresh()
	visible = true

	if UITheme:
		UITheme.animate_panel_open(panel)


func hide_panel() -> void:
	if UITheme:
		UITheme.animate_panel_close(panel, func(): visible = false)
	panel_closed.emit()


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _refresh() -> void:
	for child in rows_container.get_children():
		child.queue_free()

	# Waehrend einer laufenden Welle ist diese die "aktuelle" Zeile, sonst die naechste.
	var current := GameState.current_wave
	var first_wave: int = current if GameState.wave_active else current + 1
	first_wave = maxi(1, first_wave)
	subtitle_label.text = "Welle %d – %d" % [first_wave, first_wave + PREVIEW_WAVES - 1]

	for entry in RunSchedule.get_upcoming(first_wave, PREVIEW_WAVES):
		rows_container.add_child(_create_row(entry, entry["wave"] == first_wave))


func _create_row(entry: Dictionary, is_current: bool) -> PanelContainer:
	var wave: int = entry["wave"]
	var events: Array = entry["events"]

	var row := PanelContainer.new()
	if UITheme and (is_current or not events.is_empty()):
		row.add_theme_stylebox_override("panel", UITheme.create_info_badge_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var wave_label := Label.new()
	wave_label.text = "WELLE %d" % wave
	wave_label.custom_minimum_size = Vector2(110, 26)
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme and UITheme.game_font:
		wave_label.add_theme_font_override("font", UITheme.game_font)
	wave_label.add_theme_font_size_override("font_size", 13)
	wave_label.add_theme_color_override(
		"font_color", UITheme.COLOR_TEXT_DARK if is_current else Color("554731")
	)
	hbox.add_child(wave_label)

	var events_label := IconSystem.create_rich_label(300, 26)
	events_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_label.add_theme_font_size_override("normal_font_size", 11)
	if events.is_empty():
		events_label.text = "[color=#7d6c4d]nur Gegner[/color]"
	else:
		var parts: Array[String] = []
		for event in events:
			parts.append("%s [color=#%s]%s[/color]" % [
				IconSystem.bb(event["icon"], 14),
				Color(event["color"]).darkened(0.45).to_html(false),
				event["label"]
			])
		events_label.text = "  ·  ".join(parts)
	hbox.add_child(events_label)

	return row


func _on_close_pressed() -> void:
	if Sound:
		Sound.play_click()
	hide_panel()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()
