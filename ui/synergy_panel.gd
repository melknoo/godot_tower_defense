# ui/synergy_panel.gd
# Zeigt die Meisterschafts-Tracks (Build-Path): Punkte, aktuelle Tier und Schwellen-Effekte.
# Hotkey Y. Muster wie ui/upgrade_overview.gd.
extends CanvasLayer
class_name SynergyPanel

signal panel_closed

var panel: PanelContainer
var tracks_container: VBoxContainer

const TRACK_COLORS := {
	"fire": Color(1.0, 0.45, 0.25),
	"water": Color(0.35, 0.65, 1.0),
	"earth": Color(0.7, 0.5, 0.3),
	"air": Color(0.8, 0.9, 1.0),
	"crit": Color(1.0, 0.85, 0.35),
	"splash": Color(1.0, 0.55, 0.3),
	"control": Color(0.55, 0.85, 1.0),
}


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()

	if SynergySystem:
		SynergySystem.mastery_changed.connect(_on_mastery_changed)


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
	panel.custom_minimum_size = Vector2(560, 520)
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

	var title_label := Label.new()
	title_label.text = "Meisterschaft & Synergien"
	if UITheme and UITheme.game_font:
		title_label.add_theme_font_override("font", UITheme.game_font)
	title_label.add_theme_font_size_override("font_size", 20)
	if UITheme:
		title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
	vbox.add_child(title_label)

	var hint := Label.new()
	hint.text = "Investiere in Perks, Elemente & Türme, um Schwellen-Boni freizuschalten."
	if UITheme and UITheme.game_font:
		hint.add_theme_font_override("font", UITheme.game_font)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("554731"))
	vbox.add_child(hint)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color("785d32"))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	tracks_container = VBoxContainer.new()
	tracks_container.add_theme_constant_override("separation", 10)
	tracks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tracks_container)

	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)

	var close_button := Button.new()
	close_button.text = "Schließen"
	close_button.custom_minimum_size = Vector2(120, 32)
	close_button.pressed.connect(_on_close_pressed)
	btn_center.add_child(close_button)

	if UITheme:
		UITheme.style_button(close_button)
	close_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))


func show_panel() -> void:
	Sound.play_click()
	_refresh_tracks()
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


func _refresh_tracks() -> void:
	for child in tracks_container.get_children():
		child.queue_free()

	if not SynergySystem:
		return

	for tag in SynergySystem.TAGS:
		tracks_container.add_child(_create_track_row(tag))


func _create_track_row(tag: String) -> PanelContainer:
	var info: Dictionary = SynergySystem.TRACK_INFO.get(tag, {})
	var color: Color = TRACK_COLORS.get(tag, Color.WHITE)
	var points: int = SynergySystem.get_points(tag)
	var tier: int = SynergySystem.get_tier(tag)
	var effects: Array = SynergySystem.TIER_EFFECTS.get(tag, [])
	var thresholds: Array = SynergySystem.TIER_THRESHOLDS

	var entry := PanelContainer.new()
	if UITheme:
		entry.add_theme_stylebox_override("panel", UITheme.create_info_badge_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	entry.add_child(vbox)

	# Kopfzeile: Icon + Name + Punkte/Tier
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon_label := Label.new()
	icon_label.text = info.get("icon", "")
	icon_label.add_theme_font_size_override("font_size", 20)
	header.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = info.get("name", tag)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color.darkened(0.35))
	header.add_child(name_label)

	var tier_label := Label.new()
	var next_txt := " (max)"
	if tier < thresholds.size():
		next_txt = " → %d" % thresholds[tier]
	tier_label.text = "T%d · %d Pkt%s" % [tier, points, next_txt]
	if UITheme and UITheme.game_font:
		tier_label.add_theme_font_override("font", UITheme.game_font)
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color("554731"))
	header.add_child(tier_label)

	# Effekt-Zeilen (freigeschaltete hervorgehoben)
	for i in range(effects.size()):
		var eff := Label.new()
		var unlocked := tier >= (i + 1)
		eff.text = "%s  T%d: %s" % ["✔" if unlocked else "•", i + 1, effects[i]]
		if UITheme and UITheme.game_font:
			eff.add_theme_font_override("font", UITheme.game_font)
		eff.add_theme_font_size_override("font_size", 10)
		eff.add_theme_color_override("font_color", color.darkened(0.2) if unlocked else Color("8a7a55"))
		vbox.add_child(eff)

	return entry


func _on_mastery_changed(_tag: String, _points: int, _tier: int) -> void:
	if visible:
		_refresh_tracks()


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
