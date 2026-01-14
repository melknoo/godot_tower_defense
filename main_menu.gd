# main_menu.gd
# Hauptmenü mit Charakterauswahl
extends Control

signal game_started(character_id: String)

@export var game_scene_path: String = "res://main.tscn"

# UI Referenzen
var main_panel: VBoxContainer
var character_select_panel: PanelContainer
var character_grid: GridContainer
var selected_character: String = ""
var character_buttons: Dictionary = {}

# Styles
var button_normal_style: StyleBoxFlat
var button_hover_style: StyleBoxFlat
var button_selected_style: StyleBoxFlat
var panel_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()
	_create_ui()
	_update_character_grid()
	_show_main_menu()


func _create_styles() -> void:
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.3, 0.3, 0.35)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	
	button_normal_style = StyleBoxFlat.new()
	button_normal_style.bg_color = Color(0.2, 0.2, 0.25)
	button_normal_style.border_color = Color(0.4, 0.4, 0.45)
	button_normal_style.set_border_width_all(2)
	button_normal_style.set_corner_radius_all(6)
	button_normal_style.set_content_margin_all(12)
	
	button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.25, 0.25, 0.3)
	button_hover_style.border_color = Color(0.5, 0.5, 0.6)
	button_hover_style.set_border_width_all(2)
	button_hover_style.set_corner_radius_all(6)
	button_hover_style.set_content_margin_all(12)
	
	button_selected_style = StyleBoxFlat.new()
	button_selected_style.bg_color = Color(0.2, 0.35, 0.5)
	button_selected_style.border_color = Color(0.4, 0.7, 1.0)
	button_selected_style.set_border_width_all(3)
	button_selected_style.set_corner_radius_all(6)
	button_selected_style.set_content_margin_all(12)


func _create_ui() -> void:
	# Hintergrund
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Zentrierter Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var root_container := VBoxContainer.new()
	root_container.add_theme_constant_override("separation", 30)
	center.add_child(root_container)
	
	# Titel
	var title := Label.new()
	title.text = "TOWER DEFENSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	root_container.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Elementare Macht"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	root_container.add_child(subtitle)
	
	# === HAUPTMENÜ PANEL ===
	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 15)
	main_panel.custom_minimum_size = Vector2(300, 0)
	root_container.add_child(main_panel)
	
	_create_menu_button(main_panel, "Neues Spiel", "play", _on_new_game_pressed)
	_create_menu_button(main_panel, "Charaktere", "characters", _on_characters_pressed)
	_create_menu_button(main_panel, "Optionen", "settings", _on_options_pressed)
	_create_menu_button(main_panel, "Beenden", "exit", _on_quit_pressed)
	
	# === CHARAKTERAUSWAHL PANEL ===
	character_select_panel = PanelContainer.new()
	character_select_panel.add_theme_stylebox_override("panel", panel_style)
	character_select_panel.visible = false
	root_container.add_child(character_select_panel)
	
	var char_vbox := VBoxContainer.new()
	char_vbox.add_theme_constant_override("separation", 20)
	character_select_panel.add_child(char_vbox)
	
	var char_title := Label.new()
	char_title.text = "Wähle deinen Charakter"
	char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title.add_theme_font_size_override("font_size", 28)
	char_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	char_vbox.add_child(char_title)
	
	# Character Grid
	character_grid = GridContainer.new()
	character_grid.columns = 2
	character_grid.add_theme_constant_override("h_separation", 15)
	character_grid.add_theme_constant_override("v_separation", 15)
	char_vbox.add_child(character_grid)
	
	# Buttons unter Grid
	var char_buttons := HBoxContainer.new()
	char_buttons.add_theme_constant_override("separation", 20)
	char_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	char_vbox.add_child(char_buttons)
	
	var back_btn := _create_styled_button("Zurück", _on_character_back_pressed)
	back_btn.custom_minimum_size = Vector2(120, 45)
	char_buttons.add_child(back_btn)
	
	var start_btn := _create_styled_button("Starten", _on_character_start_pressed)
	start_btn.custom_minimum_size = Vector2(120, 45)
	start_btn.name = "StartButton"
	char_buttons.add_child(start_btn)


func _create_menu_button(parent: Node, text: String, icon_name: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 55)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_stylebox_override("normal", button_normal_style)
	btn.add_theme_stylebox_override("hover", button_hover_style)
	btn.add_theme_stylebox_override("pressed", button_hover_style)
	btn.pressed.connect(callback)
	
	# Button mit Icon
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	
	# Icon
	var icon_texture: Texture2D = null
	if IconSystem:
		icon_texture = IconSystem.get_texture(icon_name)
	
	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)
	
	parent.add_child(btn)
	return btn


func _create_styled_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", button_normal_style)
	btn.add_theme_stylebox_override("hover", button_hover_style)
	btn.add_theme_stylebox_override("pressed", button_hover_style)
	btn.pressed.connect(callback)
	return btn


func _update_character_grid() -> void:
	for child in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()
	
	if not AbilitySystem:
		return
	
	for char_id in AbilitySystem.CHARACTERS:
		var char_data: Dictionary = AbilitySystem.CHARACTERS[char_id]
		var is_unlocked: bool = AbilitySystem.is_character_unlocked(char_id)
		
		var char_btn := _create_character_button(char_id, char_data, is_unlocked)
		character_grid.add_child(char_btn)
		character_buttons[char_id] = char_btn


func _create_character_button(char_id: String, data: Dictionary, unlocked: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 160)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18) if unlocked else Color(0.1, 0.1, 0.1)
	var char_color: Color = data.get("color", Color.WHITE)
	style.border_color = char_color if unlocked else Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Name
	var name_label := Label.new()
	var char_name: String = data.get("name", char_id)
	name_label.text = char_name if unlocked else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", char_color if unlocked else Color(0.4, 0.4, 0.4))
	vbox.add_child(name_label)
	
	# Element Icon Container (zentriert)
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(icon_container)
	
	var element: String = data.get("element", "")
	if unlocked and not element.is_empty():
		var icon_texture: Texture2D = null
		if IconSystem:
			icon_texture = IconSystem.get_texture(element)
		
		if icon_texture:
			var icon := TextureRect.new()
			icon.texture = icon_texture
			icon.custom_minimum_size = Vector2(32, 32)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_container.add_child(icon)
		else:
			var fallback := Label.new()
			fallback.text = element.substr(0, 1).to_upper()
			fallback.add_theme_font_size_override("font_size", 28)
			fallback.add_theme_color_override("font_color", char_color)
			icon_container.add_child(fallback)
	else:
		var lock_label := Label.new()
		lock_label.text = "?"
		lock_label.add_theme_font_size_override("font_size", 28)
		lock_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		icon_container.add_child(lock_label)
	
	# Start-Ability
	var ability_label := Label.new()
	if unlocked:
		var ability_id: String = data.get("starting_ability", "")
		var ability_data: Dictionary = AbilitySystem.ABILITIES.get(ability_id, {})
		var ability_name: String = ability_data.get("name", ability_id)
		ability_label.text = ability_name
	else:
		ability_label.text = "Gesperrt"
	ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_label.add_theme_font_size_override("font_size", 14)
	ability_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if unlocked else Color(0.4, 0.4, 0.4))
	vbox.add_child(ability_label)
	
	# Beschreibung
	var desc_label := Label.new()
	var description: String = data.get("description", "")
	desc_label.text = description if unlocked else ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	# Click Handler
	if unlocked:
		var click_handler := Button.new()
		click_handler.flat = true
		click_handler.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_handler.pressed.connect(_on_character_clicked.bind(char_id))
		panel.add_child(click_handler)
	
	panel.set_meta("char_id", char_id)
	panel.set_meta("unlocked", unlocked)
	
	return panel


func _update_character_selection() -> void:
	for char_id in character_buttons:
		var panel: PanelContainer = character_buttons[char_id]
		var is_selected: bool = char_id == selected_character
		var is_unlocked: bool = panel.get_meta("unlocked", false)
		
		if not is_unlocked:
			continue
		
		var style := StyleBoxFlat.new()
		var char_data: Dictionary = AbilitySystem.CHARACTERS.get(char_id, {})
		var char_color: Color = char_data.get("color", Color.WHITE)
		
		if is_selected:
			style.border_color = Color(1.0, 0.9, 0.4)
			style.set_border_width_all(3)
			style.bg_color = Color(0.2, 0.2, 0.15)
		else:
			style.border_color = char_color
			style.set_border_width_all(2)
			style.bg_color = Color(0.15, 0.15, 0.18)
		
		style.set_corner_radius_all(8)
		style.set_content_margin_all(15)
		panel.add_theme_stylebox_override("panel", style)
	
	# Start Button aktivieren/deaktivieren
	var start_btn: Button = character_select_panel.find_child("StartButton", true, false)
	if start_btn:
		start_btn.disabled = selected_character.is_empty()


# === NAVIGATION ===

func _show_main_menu() -> void:
	main_panel.visible = true
	character_select_panel.visible = false


func _show_character_select() -> void:
	main_panel.visible = false
	character_select_panel.visible = true
	selected_character = ""
	_update_character_selection()


# === BUTTON CALLBACKS ===

func _on_new_game_pressed() -> void:
	if Sound:
		Sound.play_click()
	_show_character_select()


func _on_characters_pressed() -> void:
	if Sound:
		Sound.play_click()
	# TODO: Charaktere-Übersicht mit Freischaltungen
	print("[MainMenu] Charaktere-Übersicht (noch nicht implementiert)")


func _on_options_pressed() -> void:
	if Sound:
		Sound.play_click()
	# TODO: Optionen-Menü
	print("[MainMenu] Optionen (noch nicht implementiert)")


func _on_quit_pressed() -> void:
	if Sound:
		Sound.play_click()
	get_tree().quit()


func _on_character_clicked(char_id: String) -> void:
	if Sound:
		Sound.play_click()
	selected_character = char_id
	_update_character_selection()


func _on_character_back_pressed() -> void:
	if Sound:
		Sound.play_click()
	_show_main_menu()


func _on_character_start_pressed() -> void:
	if selected_character.is_empty():
		if Sound:
			Sound.play_error()
		return
	
	if Sound:
		Sound.play_confirm()
	
	# Charakter im AbilitySystem setzen
	if AbilitySystem:
		AbilitySystem.select_character(selected_character)
	
	game_started.emit(selected_character)
	_start_game()


func _start_game() -> void:
	var err := get_tree().change_scene_to_file(game_scene_path)
	if err != OK:
		push_error("[MainMenu] Fehler beim Laden der Spielszene: %s" % err)


# === INPUT ===

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if character_select_panel.visible:
				_on_character_back_pressed()
