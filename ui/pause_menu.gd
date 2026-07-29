# Klassisches Pause- und Optionsmenue im vorhandenen Medieval-Asset-Stil.
extends CanvasLayer
class_name PauseMenu

signal main_menu_requested
signal quit_requested

const SETTINGS_PATH := "user://game_settings.cfg"
const MIN_VOLUME_DB := -60.0
const MAX_VOLUME_DB := 0.0

var panel: PanelContainer
var main_view: VBoxContainer
var options_view: VBoxContainer
var confirm_view: VBoxContainer
var confirm_title_label: Label
var confirm_message: Label
var confirm_action_button: Button
var master_slider: HSlider
var sfx_slider: HSlider
var music_slider: HSlider
var master_value_label: Label
var sfx_value_label: Label
var music_value_label: Label
var fullscreen_toggle: CheckButton
var shake_toggle: CheckButton
var _tree_was_paused := false
var _options_only := false
var _pending_exit_action := ""


func _ready() -> void:
	layer = 450
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.018, 0.025, 0.045, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 620)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.style_panel(panel, "carved")
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(root_box)

	main_view = VBoxContainer.new()
	main_view.add_theme_constant_override("separation", 12)
	root_box.add_child(main_view)
	_build_main_view()

	options_view = VBoxContainer.new()
	options_view.add_theme_constant_override("separation", 12)
	options_view.visible = false
	root_box.add_child(options_view)
	_build_options_view()

	confirm_view = VBoxContainer.new()
	confirm_view.add_theme_constant_override("separation", 16)
	confirm_view.visible = false
	root_box.add_child(confirm_view)
	_build_confirm_view()


func _build_main_view() -> void:
	var title := UITheme.create_ribbon_title("SPIEL PAUSIERT", "blue", 360, 22)
	title.custom_minimum_size.y = 58
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_view.add_child(title)

	var hint := Label.new()
	hint.text = "Die Bastion wartet auf deinen Befehl."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(hint, 12, UITheme.COLOR_TEXT_DARK)
	main_view.add_child(hint)

	main_view.add_child(_make_menu_button("FORTSETZEN", "play", _on_resume_pressed))
	main_view.add_child(_make_menu_button("OPTIONEN", "settings", _on_options_pressed))
	main_view.add_child(_make_menu_button("HAUPTMENÜ", "characters", _on_main_menu_pressed))
	main_view.add_child(_make_menu_button("SPIEL BEENDEN", "exit", _on_quit_pressed, true))

	var esc_hint := Label.new()
	esc_hint.text = "Esc · Fortsetzen"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(esc_hint, 10, Color(0.38, 0.32, 0.24))
	main_view.add_child(esc_hint)


func _build_options_view() -> void:
	var title := UITheme.create_ribbon_title("OPTIONEN", "yellow", 340, 22)
	title.custom_minimum_size.y = 58
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	options_view.add_child(title)

	var master_row := _create_slider_row("GESAMTLAUTSTÄRKE")
	master_slider = master_row.slider
	master_value_label = master_row.value_label
	master_slider.value_changed.connect(_on_master_volume_changed)
	options_view.add_child(master_row.root)

	var sfx_row := _create_slider_row("EFFEKTLAUTSTÄRKE")
	sfx_slider = sfx_row.slider
	sfx_value_label = sfx_row.value_label
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	options_view.add_child(sfx_row.root)

	var music_row := _create_slider_row("MUSIKLAUTSTÄRKE")
	music_slider = music_row.slider
	music_value_label = music_row.value_label
	music_slider.value_changed.connect(_on_music_volume_changed)
	options_view.add_child(music_row.root)

	fullscreen_toggle = _create_toggle("VOLLBILD")
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	options_view.add_child(fullscreen_toggle)

	shake_toggle = _create_toggle("BILDSCHIRMWACKELN")
	shake_toggle.toggled.connect(_on_shake_toggled)
	options_view.add_child(shake_toggle)

	var back_button := _make_menu_button("ZURÜCK", "exit", _on_options_back_pressed, true)
	options_view.add_child(back_button)


func _build_confirm_view() -> void:
	var title := UITheme.create_ribbon_title("RUN BEENDEN?", "red", 350, 22)
	title.custom_minimum_size.y = 58
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_view.add_child(title)
	for child in title.get_children():
		if child is Label:
			confirm_title_label = child

	var warning_panel := PanelContainer.new()
	warning_panel.custom_minimum_size = Vector2(390, 150)
	UITheme.style_panel(warning_panel, "carved_small")
	confirm_view.add_child(warning_panel)
	confirm_message = Label.new()
	confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(confirm_message, 12, UITheme.COLOR_TEXT_DARK)
	warning_panel.add_child(confirm_message)

	var continue_button := _make_menu_button("WEITERSPIELEN", "play", _on_confirm_cancel_pressed)
	continue_button.name = "ContinueRunButton"
	confirm_view.add_child(continue_button)
	confirm_action_button = _make_menu_button("RUN BEENDEN", "exit", _on_confirm_leave_pressed, true)
	confirm_action_button.name = "ConfirmLeaveButton"
	confirm_view.add_child(confirm_action_button)


func _make_menu_button(text: String, icon_name: String, callback: Callable, red: bool = false) -> Button:
	var button := Button.new()
	button.text = "  " + text
	button.custom_minimum_size = Vector2(390, 70)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 19)
	if UITheme:
		UITheme.style_button(button, red)
	if IconSystem:
		button.icon = IconSystem.get_texture(icon_name)
		if UITheme:
			UITheme.center_button_icon(button)
		else:
			button.expand_icon = true
	button.pressed.connect(callback)
	return button


func _create_slider_row(title_text: String) -> Dictionary:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(390, 82)
	if UITheme:
		UITheme.style_panel(row_panel, "carved_small")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var label := Label.new()
	label.text = title_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(label, 12, UITheme.COLOR_TEXT_DARK)
	header.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(value_label, 12, UITheme.COLOR_TEXT_GOLD.darkened(0.2))
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = MIN_VOLUME_DB
	slider.max_value = MAX_VOLUME_DB
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(350, 22)
	box.add_child(slider)
	return {"root": row_panel, "slider": slider, "value_label": value_label}


func _create_toggle(text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.custom_minimum_size = Vector2(390, 46)
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
	toggle.add_theme_color_override("font_hover_color", UITheme.COLOR_TEXT_DARK)
	toggle.add_theme_color_override("font_pressed_color", UITheme.COLOR_TEXT_DARK)
	toggle.add_theme_color_override("font_hover_pressed_color", UITheme.COLOR_TEXT_DARK)
	if UITheme and UITheme.game_font:
		toggle.add_theme_font_override("font", UITheme.game_font)
	return toggle


func show_pause() -> void:
	if visible:
		return
	_options_only = false
	_tree_was_paused = get_tree().paused
	_show_main_view()
	visible = true
	get_tree().paused = true
	_animate_open()


func show_options_only() -> void:
	_options_only = true
	_tree_was_paused = get_tree().paused
	_show_options_view()
	visible = true
	_animate_open()


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused


func handle_escape() -> void:
	if not visible:
		return
	if confirm_view.visible:
		_on_confirm_cancel_pressed()
	elif options_view.visible:
		_on_options_back_pressed()
	else:
		_on_resume_pressed()


func _animate_open() -> void:
	if UITheme:
		UITheme.animate_panel_open(panel)


func _show_main_view() -> void:
	_pending_exit_action = ""
	main_view.visible = true
	options_view.visible = false
	confirm_view.visible = false


func _show_options_view() -> void:
	main_view.visible = false
	options_view.visible = true
	confirm_view.visible = false


func _show_confirm_view(action: String) -> void:
	_pending_exit_action = action
	if action == "quit":
		confirm_title_label.text = "SPIEL BEENDEN?"
		confirm_message.text = "Wenn du das Spiel jetzt beendest, wird der aktuelle Run abgeschlossen und das Spiel geschlossen.\n\nDein verdientes Aether und dein Archiv-Fortschritt bleiben gespeichert."
		confirm_action_button.text = "  SPIEL BEENDEN"
	else:
		confirm_title_label.text = "RUN BEENDEN?"
		confirm_message.text = "Wenn du jetzt ins Hauptmenü zurückkehrst, wird der aktuelle Run beendet.\n\nDein verdientes Aether und dein Archiv-Fortschritt bleiben gespeichert."
		confirm_action_button.text = "  RUN BEENDEN"
	main_view.visible = false
	options_view.visible = false
	confirm_view.visible = true


func _on_resume_pressed() -> void:
	if Sound: Sound.play_click()
	hide_menu()


func _on_options_pressed() -> void:
	if Sound: Sound.play_click()
	_show_options_view()


func _on_options_back_pressed() -> void:
	if Sound: Sound.play_click()
	if _options_only:
		hide_menu()
	else:
		_show_main_view()


func _on_main_menu_pressed() -> void:
	if Sound: Sound.play_click()
	_show_confirm_view("main_menu")


func _on_confirm_cancel_pressed() -> void:
	if Sound: Sound.play_click()
	_show_main_view()


func _on_confirm_leave_pressed() -> void:
	if Sound: Sound.play_click()
	var action := _pending_exit_action
	hide_menu()
	_pending_exit_action = ""
	if action == "quit":
		_save_settings()
		quit_requested.emit()
	else:
		main_menu_requested.emit()


func _on_quit_pressed() -> void:
	if Sound: Sound.play_click()
	_show_confirm_view("quit")


func _on_master_volume_changed(value: float) -> void:
	if Sound: Sound.set_master_volume(value)
	if Music: Music.set_master_volume(value)
	master_value_label.text = "%d%%" % _db_to_percent(value)
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	if Sound: Sound.set_sfx_volume(value)
	sfx_value_label.text = "%d%%" % _db_to_percent(value)
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	if Music: Music.set_music_volume(value)
	music_value_label.text = "%d%%" % _db_to_percent(value)
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_shake_toggled(enabled: bool) -> void:
	if VFX:
		VFX.screen_shake_enabled = enabled
	_save_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(SETTINGS_PATH) == OK
	var master := float(config.get_value("audio", "master_db", 0.0)) if loaded else 0.0
	var sfx := float(config.get_value("audio", "sfx_db", 0.0)) if loaded else 0.0
	var music := float(config.get_value("audio", "music_db", -6.0)) if loaded else -6.0
	var fullscreen_default := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var fullscreen := bool(config.get_value("video", "fullscreen", fullscreen_default)) if loaded else fullscreen_default
	var shake := bool(config.get_value("video", "screen_shake", true)) if loaded else true

	master_slider.set_value_no_signal(master)
	sfx_slider.set_value_no_signal(sfx)
	music_slider.set_value_no_signal(music)
	fullscreen_toggle.set_pressed_no_signal(fullscreen)
	shake_toggle.set_pressed_no_signal(shake)
	master_value_label.text = "%d%%" % _db_to_percent(master)
	sfx_value_label.text = "%d%%" % _db_to_percent(sfx)
	music_value_label.text = "%d%%" % _db_to_percent(music)
	if Sound:
		Sound.set_master_volume(master)
		Sound.set_sfx_volume(sfx)
	if Music:
		Music.set_master_volume(master)
		Music.set_music_volume(music)
	if VFX:
		VFX.screen_shake_enabled = shake
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _save_settings() -> void:
	if not master_slider or not fullscreen_toggle:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_slider.value)
	config.set_value("audio", "sfx_db", sfx_slider.value)
	config.set_value("audio", "music_db", music_slider.value)
	config.set_value("video", "fullscreen", fullscreen_toggle.button_pressed)
	config.set_value("video", "screen_shake", shake_toggle.button_pressed)
	config.save(SETTINGS_PATH)


func _db_to_percent(value: float) -> int:
	return int(round(remap(value, MIN_VOLUME_DB, MAX_VOLUME_DB, 0.0, 100.0)))


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		handle_escape()
		get_viewport().set_input_as_handled()
