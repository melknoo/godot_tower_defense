# main_menu.gd
# Hauptmenü mit Charakterauswahl - Medieval Style
extends Control

signal game_started(character_id: String)

@export var game_scene_path: String = "res://main.tscn"

# UI Referenzen
var main_panel: VBoxContainer
var character_select_panel: PanelContainer
var character_grid: GridContainer
var selected_character: String = ""
var character_buttons: Dictionary = {}
var meta_progression_ui: MetaProgressionUI
var character_roster_ui: CharacterRosterUI
var characters_button: Button
var options_overlay: PauseMenu

# Hintergrund-Textur (optional)
var bg_texture: Texture2D


func _ready() -> void:
	_create_ui()
	meta_progression_ui = MetaProgressionUI.new()
	meta_progression_ui.name = "MetaProgressionUI"
	add_child(meta_progression_ui)
	character_roster_ui = CharacterRosterUI.new()
	character_roster_ui.name = "CharacterRosterUI"
	character_roster_ui.panel_closed.connect(_on_roster_closed)
	add_child(character_roster_ui)
	options_overlay = PauseMenu.new()
	options_overlay.name = "OptionsOverlay"
	add_child(options_overlay)
	_update_character_grid()
	_update_characters_button_badge()
	_show_main_menu()
	if Music:
		Music.play_state("menu")


func _create_ui() -> void:
	# Sicherstellen dass das Control den ganzen Screen füllt
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	# Hintergrund - dunkles Pergament-Feeling
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.085)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_decorate_background(bg)
	
	# Optional: Hintergrund-Textur/Vignette
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0)  # Placeholder für Shader/Textur
	add_child(vignette)
	
	# Zentrierter Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)
	
	var root_container := VBoxContainer.new()
	root_container.add_theme_constant_override("separation", 20)
	center.add_child(root_container)
	
	# === TITEL mit Ribbon ===
	var title_section := VBoxContainer.new()
	title_section.add_theme_constant_override("separation", 8)
	title_section.alignment = BoxContainer.ALIGNMENT_CENTER
	root_container.add_child(title_section)
	
	var title := Label.new()
	title.text = "ARCANE BASTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UI.ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	title.add_theme_constant_override("outline_size", 4)
	title_section.add_child(title)
	
	# Untertitel als Ribbon
	var subtitle_ribbon := Label.new()
	subtitle_ribbon.text = "Aether & Elemente"
	subtitle_ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_ribbon.custom_minimum_size = Vector2(440, 32)
	subtitle_ribbon.custom_minimum_size.y = 52
	subtitle_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_section.add_child(subtitle_ribbon)
	
	# === HAUPTMENÜ PANEL ===
	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 12)
	main_panel.custom_minimum_size = Vector2(320, 0)
	main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	root_container.add_child(main_panel)
	
	_create_menu_button(main_panel, "Neues Spiel", "play", _on_new_game_pressed)
	_create_menu_button(main_panel, "Arkanes Archiv", "star_full", _on_archive_pressed, false, true)
	characters_button = _create_menu_button(main_panel, "Charaktere", "characters", _on_characters_pressed, false, true)
	_create_menu_button(main_panel, "Optionen", "settings", _on_options_pressed, false, true)
	# Im Browser gibt es nichts zu beenden - get_tree().quit() hinterlaesst nur ein
	# totes Canvas. Der Button entfaellt dort komplett.
	if not OS.has_feature("web"):
		_create_menu_button(main_panel, "Beenden", "exit", _on_quit_pressed, true)  # Rot
	
	# === CHARAKTERAUSWAHL PANEL ===
	character_select_panel = PanelContainer.new()
	character_select_panel.visible = false
	# Breit genug fuer drei Karten (3 x 230 + 2 x 12 Abstand). Bei zwei Spalten wurde
	# die Auswahl mit der zusaetzlichen Passiv-Zeile so hoch, dass die Buttons darunter
	# aus dem Bild liefen.
	character_select_panel.custom_minimum_size = Vector2(760, 0)
	root_container.add_child(character_select_panel)
	
	var char_vbox := VBoxContainer.new()
	char_vbox.add_theme_constant_override("separation", 10)
	character_select_panel.add_child(char_vbox)
	
	# Charakter-Titel als Ribbon
	var char_title_ribbon := Label.new()
	char_title_ribbon.text = "Wähle deinen Charakter"
	char_title_ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title_ribbon.custom_minimum_size = Vector2(320, 32)
	char_title_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	char_vbox.add_child(char_title_ribbon)
	
	# Character Grid
	character_grid = GridContainer.new()
	# Drei Spalten: acht Charaktere passen damit in drei Reihen statt vier.
	character_grid.columns = 3
	character_grid.add_theme_constant_override("h_separation", 12)
	character_grid.add_theme_constant_override("v_separation", 8)
	char_vbox.add_child(character_grid)
	
	# Buttons unter Grid
	var char_buttons := HBoxContainer.new()
	char_buttons.add_theme_constant_override("separation", 16)
	char_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	char_vbox.add_child(char_buttons)
	
	var back_btn := _create_styled_button("Zurück", _on_character_back_pressed, true)
	back_btn.custom_minimum_size = Vector2(130, 40)
	char_buttons.add_child(back_btn)
	
	var start_btn := _create_styled_button("Starten", _on_character_start_pressed)
	start_btn.custom_minimum_size = Vector2(130, 40)
	start_btn.name = "StartButton"
	char_buttons.add_child(start_btn)


func _decorate_background(background: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in range(34):
		var mote := ColorRect.new()
		var size_value := rng.randi_range(1, 3)
		mote.size = Vector2(size_value, size_value)
		mote.position = Vector2(rng.randi_range(45, 1875), rng.randi_range(35, 1045))
		mote.color = Color(0.35, 0.72, 1.0, rng.randf_range(0.06, 0.2))
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(mote)

	var elements := ["water", "fire", "earth", "air"]
	var positions := [Vector2(150, 130), Vector2(1670, 130), Vector2(150, 810), Vector2(1670, 810)]
	for i in range(elements.size()):
		var texture := IconSystem.get_texture(elements[i]) if IconSystem else null
		if not texture:
			continue
		var symbol := TextureRect.new()
		symbol.texture = texture
		symbol.position = positions[i]
		symbol.size = Vector2(100, 100)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.modulate = Color(0.45, 0.7, 1.0, 0.08)
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(symbol)


func _create_menu_button(parent: Node, text: String, icon_name: String, callback: Callable, red: bool = false, secondary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = " " + text
	btn.custom_minimum_size = Vector2(300, 80)
	btn.clip_text = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	if red:
		btn.theme_type_variation = &"DangerButton"
	elif secondary:
		btn.theme_type_variation = &"SecondaryButton"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 24)

	# Icon direkt auf dem Button
	var icon_texture: Texture2D = null
	if IconSystem:
		icon_texture = IconSystem.get_texture(icon_name)
	if icon_texture:
		btn.icon = icon_texture
		btn.expand_icon = true
	
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _create_styled_button(text: String, callback: Callable, red: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	
	if red:
		btn.theme_type_variation = &"DangerButton"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)

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
	# Hoeher als frueher (170): die Karte zeigt jetzt zusaetzlich die Passive. Nicht
	# weiter erhoehen ohne die Gesamthoehe zu pruefen - bei drei Reihen stoesst die
	# Auswahl sonst unten aus dem Bild (die Buttons darunter verschwinden zuerst).
	panel.custom_minimum_size = Vector2(230, 196)
	
	if not unlocked:
		panel.modulate = Color(0.5, 0.5, 0.5, 0.8)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# Name
	var char_color: Color = data.get("color", Color.WHITE)
	var char_name: String = data.get("name", char_id)
	
	var name_label := Label.new()
	name_label.text = char_name if unlocked else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", char_color if unlocked else UI.TEXT_DISABLED)
	
	if unlocked:
		name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		name_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_label)
	
	# Trennlinie
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)
	
	# Element Icon Container
	var icon_container := CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(icon_container)
	
	var element: String = data.get("element", "")
	if unlocked and not element.is_empty():
		var icon_texture: Texture2D = null
		if IconSystem:
			# Erst das Charakter-Portrait (IconSystem erzeugt es prozedural, solange kein
			# Asset existiert), sonst das Element-Icon. Vorher sahen alle Charaktere eines
			# Elements identisch aus.
			var portrait_name: String = data.get("icon_name", "")
			if not portrait_name.is_empty():
				icon_texture = IconSystem.get_texture(portrait_name)
			if icon_texture == null:
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
			fallback.add_theme_font_size_override("font_size", 32)
			fallback.add_theme_color_override("font_color", char_color)
			icon_container.add_child(fallback)
	else:
		var lock_label := Label.new()
		lock_label.text = "?"
		lock_label.add_theme_font_size_override("font_size", 32)
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
	ability_label.add_theme_font_size_override("font_size", 16)
	ability_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY if unlocked else UI.TEXT_DISABLED)
	vbox.add_child(ability_label)

	# Passive: jeder Charakter hat eine, und sie ist der zweite Teil seiner Identitaet
	# neben der Start-Ability. Frueher stand sie nur im Roster, nicht in der Auswahl.
	var passive_label := Label.new()
	var passive_data: Dictionary = data.get("passive", {})
	var passive_text: String = passive_data.get("description", "")
	passive_label.text = ("Passiv: " + passive_text) if (unlocked and not passive_text.is_empty()) else ""
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	passive_label.add_theme_font_size_override("font_size", 16)
	passive_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY if unlocked else UI.TEXT_DISABLED)
	vbox.add_child(passive_label)

	# Beschreibung
	var desc_label := Label.new()
	var description: String = data.get("description", "")
	desc_label.text = description if unlocked else ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	vbox.add_child(desc_label)
	
	# Click Handler
	if unlocked:
		var click_handler := Button.new()
		click_handler.flat = true
		click_handler.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_handler.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
		
		if is_selected:
			# Gold-Rahmen für selektierten Charakter
			panel.modulate = Color(1.1, 1.05, 0.9)
			# Leichter Scale-Effekt
			var tween := create_tween()
			tween.tween_property(panel, "scale", Vector2(1.03, 1.03), 0.15).set_ease(Tween.EASE_OUT)
			panel.pivot_offset = panel.size / 2
		else:
			panel.modulate = Color.WHITE
			var tween := create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.1)
	
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
	if character_roster_ui:
		character_roster_ui.show_panel()


func _on_roster_closed() -> void:
	# Frisch Rekrutierte sofort in der Neues-Spiel-Auswahl anzeigen
	_update_character_grid()
	_update_characters_button_badge()


func _update_characters_button_badge() -> void:
	if not characters_button or not ProgressionSystem:
		return
	var badge := " Charaktere · NEU!" if ProgressionSystem.has_recruitable_character() else " Charaktere"
	characters_button.text = badge


func _on_archive_pressed() -> void:
	if Sound:
		Sound.play_click()
	if meta_progression_ui:
		meta_progression_ui.show_panel()


func _on_options_pressed() -> void:
	if Sound:
		Sound.play_click()
	if options_overlay:
		options_overlay.show_options_only()


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
	
	if AbilitySystem:
		AbilitySystem.select_character(selected_character)
	
	game_started.emit(selected_character)
	_start_game()


func _start_game() -> void:
	GameState.reset()
	if ProgressionSystem:
		ProgressionSystem.begin_run()
	var err := get_tree().change_scene_to_file(game_scene_path)
	if err != OK:
		push_error("[MainMenu] Fehler beim Laden der Spielszene: %s" % err)


# === INPUT ===

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if character_select_panel.visible:
				_on_character_back_pressed()
