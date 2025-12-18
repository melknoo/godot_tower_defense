# ui/hud.gd
# Zeigt Gold, Leben, Welle, Element-Kerne, Seed, Start-Button und Fast-Forward
extends Control
class_name HUD

signal start_wave_pressed
signal open_element_panel_pressed

@export var gold_label: Label
@export var lives_label: Label
@export var wave_label: Label
@export var enemies_label: Label
@export var cores_label: Label
@export var cores_button: Button
@export var start_button: Button
@export var wave_preview_label: Label
@export var wave_element_icon: TextureRect  # NEU
@export var wave_element_label: Label  # NEU
@export var seed_label: Label
@export var fast_forward_button: Button

var is_fast_forward := false
const FAST_FORWARD_SPEED := 2.0

var ff_idle_tex: Texture2D
var ff_pressed_tex: Texture2D

# Element-Texturen
var element_textures: Dictionary = {}


func _ready() -> void:
	_load_fast_forward_textures()
	_load_element_textures()
	_setup_hud_size()
	_find_or_create_ui_elements()
	_apply_styles()
	_connect_signals()
	update_all()


func _load_element_textures() -> void:
	var elements := ["water", "fire", "earth", "air"]
	for elem in elements:
		var path := "res://assets/elemental_symbols/%s_element.png" % elem
		if ResourceLoader.exists(path):
			element_textures[elem] = load(path)


func _load_fast_forward_textures() -> void:
	var base_path := "res://assets/ui/"
	if ResourceLoader.exists(base_path + "fast_forward_idle.png"):
		ff_idle_tex = load(base_path + "fast_forward_idle.png")
	if ResourceLoader.exists(base_path + "fast_forward_pressed.png"):
		ff_pressed_tex = load(base_path + "fast_forward_pressed.png")


func _setup_hud_size() -> void:
	var hud_height := 105
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = -hud_height
	offset_bottom = 0
	
	if not has_node("HUDBackground"):
		var bg := Panel.new()
		bg.name = "HUDBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.22, 0.95)
		bg.add_theme_stylebox_override("panel", style)
		add_child(bg)
		move_child(bg, 0)


func _find_or_create_ui_elements() -> void:
	var hud_height := 105
	var bottom_y := hud_height - 22
	var second_row_y := hud_height - 44
	var third_row_y := hud_height - 66
	var viewport_size := get_viewport_rect().size
	
	gold_label = _get_or_create_label("GoldLabel", Vector2(20, third_row_y))
	lives_label = _get_or_create_label("LivesLabel", Vector2(20, second_row_y))
	wave_label = _get_or_create_label("WaveLabel", Vector2(150, third_row_y))
	enemies_label = _get_or_create_label("EnemiesLabel", Vector2(150, second_row_y))
	cores_label = _get_or_create_label("CoresLabel", Vector2(20, bottom_y))
	seed_label = _get_or_create_label("SeedLabel", Vector2(10, -hud_height - 25))
	wave_preview_label = _get_or_create_label("WavePreviewLabel", Vector2(viewport_size.x - 400, hud_height - 85))
	
	# NEU: Wave Element Anzeige (Icon + Label)
	wave_element_icon = _get_or_create_texture_rect("WaveElementIcon", Vector2(viewport_size.x - 400, hud_height - 55), Vector2(24, 24))
	wave_element_label = _get_or_create_label("WaveElementLabel", Vector2(viewport_size.x - 370, hud_height - 52))
	
	cores_button = _get_or_create_button("CoresButton", Vector2(380, third_row_y - 5), Vector2(64, 64))
	start_button = _get_or_create_button("StartWaveButton", Vector2(viewport_size.x - 650, hud_height - 90), Vector2(130, 32))
	fast_forward_button = _get_or_create_button("FastForwardButton", Vector2(viewport_size.x - 450, hud_height - 100), Vector2(48, 48))


func _get_or_create_label(node_name: String, default_pos: Vector2) -> Label:
	var label: Label = get_node_or_null(node_name) as Label
	if not label:
		label = Label.new()
		label.name = node_name
		label.position = default_pos
		add_child(label)
	return label


func _get_or_create_button(node_name: String, default_pos: Vector2, default_size: Vector2) -> Button:
	var btn: Button = get_node_or_null(node_name) as Button
	if not btn:
		btn = Button.new()
		btn.name = node_name
		btn.position = default_pos
		btn.custom_minimum_size = default_size
		add_child(btn)
	return btn


func _get_or_create_texture_rect(node_name: String, default_pos: Vector2, default_size: Vector2) -> TextureRect:
	var tex_rect: TextureRect = get_node_or_null(node_name) as TextureRect
	if not tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = node_name
		tex_rect.position = default_pos
		tex_rect.custom_minimum_size = default_size
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(tex_rect)
	return tex_rect


func _apply_styles() -> void:
	if enemies_label:
		enemies_label.visible = false
	
	if cores_label:
		cores_label.add_theme_font_size_override("font_size", 11)
		cores_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	
	if seed_label:
		seed_label.add_theme_font_size_override("font_size", 10)
		seed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	
	if wave_preview_label:
		wave_preview_label.add_theme_font_size_override("font_size", 10)
		wave_preview_label.visible = false
	
	if wave_element_icon:
		wave_element_icon.visible = false
	
	if wave_element_label:
		wave_element_label.add_theme_font_size_override("font_size", 11)
		wave_element_label.visible = false
	
	if cores_button:
		cores_button.text = ""
		cores_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cores_button.expand_icon = true
		var icon_path := "res://assets/elemental_symbols/four_elements.png"
		if ResourceLoader.exists(icon_path):
			cores_button.icon = load(icon_path)
	
	if start_button:
		start_button.text = "Nächste Welle"
	
	if fast_forward_button:
		fast_forward_button.text = ""
		fast_forward_button.visible = false
		fast_forward_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fast_forward_button.expand_icon = true
		fast_forward_button.flat = true
		_update_fast_forward_icon()
		_style_fast_forward_button()
	
	if UITheme:
		if start_button:
			UITheme.style_button(start_button)
		if cores_button:
			UITheme.style_button(cores_button)
	
	if start_button:
		_apply_button_font_color(start_button)
	if cores_button:
		_apply_button_font_color(cores_button)


func _style_fast_forward_button() -> void:
	if not fast_forward_button:
		return
	var empty := StyleBoxEmpty.new()
	fast_forward_button.add_theme_stylebox_override("normal", empty)
	fast_forward_button.add_theme_stylebox_override("hover", empty)
	fast_forward_button.add_theme_stylebox_override("pressed", empty)
	fast_forward_button.add_theme_stylebox_override("focus", empty)
	fast_forward_button.add_theme_stylebox_override("disabled", empty)


func _update_fast_forward_icon() -> void:
	if not fast_forward_button:
		return
	if is_fast_forward and ff_pressed_tex:
		fast_forward_button.icon = ff_pressed_tex
	elif ff_idle_tex:
		fast_forward_button.icon = ff_idle_tex


func _apply_button_font_color(btn: Button) -> void:
	if not btn:
		return
	var dark_font := Color(0.1, 0.1, 0.1)
	btn.add_theme_color_override("font_color", dark_font)
	btn.add_theme_color_override("font_hover_color", dark_font)
	btn.add_theme_color_override("font_pressed_color", dark_font)
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))


func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.enemy_count_changed.connect(_on_enemy_count_changed)
	GameState.element_cores_changed.connect(_on_cores_changed)
	GameState.element_core_earned.connect(_on_core_earned)
	
	TowerData.element_unlocked.connect(_on_element_invested)
	TowerData.element_upgraded.connect(_on_element_upgraded)
	
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if cores_button:
		cores_button.pressed.connect(_on_cores_button_pressed)
	if fast_forward_button:
		fast_forward_button.pressed.connect(_on_fast_forward_pressed)


func _on_element_invested(_element: String) -> void:
	_on_cores_changed(GameState.element_cores)


func _on_element_upgraded(_element: String, _level: int) -> void:
	_on_cores_changed(GameState.element_cores)


func update_all() -> void:
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_update_wave_display()
	_on_enemy_count_changed(GameState.enemies_remaining)
	_on_cores_changed(GameState.element_cores)


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	if not lives_label:
		return
	lives_label.text = "Leben: %d" % amount
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lives_label.remove_theme_color_override("font_color")


func _on_cores_changed(amount: int) -> void:
	var invested := TowerData.get_total_cores_invested()
	var max_possible := TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL
	
	if cores_label:
		cores_label.text = "Kerne: %d | %d/%d" % [amount, invested, max_possible]
		if amount > 0:
			cores_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		else:
			cores_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	
	if cores_button:
		cores_button.visible = true
		var has_upgradeable := not TowerData.get_upgradeable_elements().is_empty()
		if amount > 0 and has_upgradeable:
			cores_button.text = "%d" % amount
			_highlight_cores_button(true)
		elif not has_upgradeable:
			cores_button.text = "✓"
			_highlight_cores_button(false)
		else:
			cores_button.text = ""
			_highlight_cores_button(false)


func _on_core_earned() -> void:
	_flash_cores_label()


func _highlight_cores_button(highlight: bool) -> void:
	if not cores_button:
		return
	if highlight:
		cores_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		cores_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))


func _flash_cores_label() -> void:
	if not cores_label:
		return
	var tween := cores_label.create_tween()
	tween.tween_property(cores_label, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	tween.tween_property(cores_label, "modulate", Color.WHITE, 0.3)


func _on_wave_started(wave: int) -> void:
	_update_wave_display()
	if start_button:
		start_button.disabled = true
		start_button.text = "Wave läuft..."
	if wave_preview_label:
		wave_preview_label.visible = false
	if wave_element_icon:
		wave_element_icon.visible = false
	if wave_element_label:
		wave_element_label.visible = false
	if fast_forward_button:
		fast_forward_button.visible = true
	_set_fast_forward(false)


func _on_wave_completed(wave: int) -> void:
	if start_button:
		start_button.disabled = false
		start_button.text = "Nächste Welle"
	_update_wave_preview(wave + 1)
	if fast_forward_button:
		fast_forward_button.visible = false
	_set_fast_forward(false)


func _on_enemy_count_changed(count: int) -> void:
	if not enemies_label:
		return
	if GameState.wave_active:
		enemies_label.text = "Gegner: %d" % count
		enemies_label.visible = true
	else:
		enemies_label.visible = false


func _update_wave_display() -> void:
	if not wave_label:
		return
	if GameState.current_wave == 0:
		wave_label.text = "Welle: --"
	else:
		wave_label.text = "Welle: %d" % GameState.current_wave


func _update_wave_preview(next_wave: int) -> void:
	if not wave_preview_label:
		return
	
	wave_preview_label.visible = true
	
	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if not wave_manager:
		wave_preview_label.text = "Nächste Welle bereit"
		return
	
	var info := wave_manager.get_wave_info(next_wave)
	var preview := wave_manager.get_wave_preview(next_wave)
	var wave_elem: String = preview.get("wave_element", "neutral")
	
	# Gegner-Info Text
	wave_preview_label.text = "Nächste Welle: " + info
	
	if next_wave % 5 == 0:
		wave_preview_label.text += "\n⚠ Boss-Welle! (+1 Kern)"
		wave_preview_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	elif next_wave == 1:
		wave_preview_label.text += "\n(+1 Kern nach Welle 1)"
		wave_preview_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	else:
		wave_preview_label.remove_theme_color_override("font_color")
	
	# Element-Anzeige mit Icon
	_update_wave_element_display(wave_elem)


func _update_wave_element_display(wave_elem: String) -> void:
	if not wave_element_icon or not wave_element_label:
		return
	
	wave_element_icon.visible = true
	wave_element_label.visible = true
	
	if wave_elem == "neutral":
		wave_element_icon.texture = null
		wave_element_icon.visible = false
		wave_element_label.text = "○ Neutrale Gegner"
		wave_element_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	elif wave_elem == "mixed":
		wave_element_icon.texture = null
		wave_element_icon.visible = false
		wave_element_label.text = "🌀 Gemischte Elemente"
		wave_element_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	else:
		# Element-Icon anzeigen
		if element_textures.has(wave_elem):
			wave_element_icon.texture = element_textures[wave_elem]
			wave_element_icon.visible = true
		else:
			wave_element_icon.visible = false
		
		# Element-Name und Schwäche-Info
		var elem_name := wave_elem.capitalize()
		var effective_elem := ""
		if ElementalSystem:
			effective_elem = ElementalSystem.get_effective_element(wave_elem)
		
		if effective_elem != "" and effective_elem != "neutral" and element_textures.has(effective_elem):
			wave_element_label.text = "%s-Gegner (schwach gegen %s)" % [elem_name, effective_elem.capitalize()]
		else:
			wave_element_label.text = "%s-Gegner" % elem_name
		
		# Farbe passend zum Element
		var elem_color := Color.WHITE
		if ElementalSystem:
			elem_color = ElementalSystem.get_element_color(wave_elem)
		wave_element_label.add_theme_color_override("font_color", elem_color)


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


func _on_cores_button_pressed() -> void:
	open_element_panel_pressed.emit()


func _on_fast_forward_pressed() -> void:
	Sound.play_click()
	_set_fast_forward(not is_fast_forward)


func _set_fast_forward(enabled: bool) -> void:
	is_fast_forward = enabled
	_update_fast_forward_icon()
	Engine.time_scale = FAST_FORWARD_SPEED if enabled else 1.0


func show_game_over() -> void:
	_set_fast_forward(false)
	
	if start_button:
		start_button.visible = false
	if cores_button:
		cores_button.visible = false
	if fast_forward_button:
		fast_forward_button.visible = false
	
	var main := get_node_or_null("/root/Main")
	var seed_text := ""
	if main and main.has_method("get_current_seed"):
		seed_text = "\nSeed: %d" % main.get_current_seed()
	
	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: %d\nKerne investiert: %d/%d%s" % [
		GameState.current_wave,
		TowerData.get_total_cores_invested(),
		TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL,
		seed_text
	]
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.position = Vector2(280, 100)
	game_over_label.name = "GameOverLabel"
	add_child(game_over_label)
	
	var restart_btn := Button.new()
	restart_btn.text = "Neustart"
	restart_btn.position = Vector2(350, 240)
	restart_btn.custom_minimum_size = Vector2(100, 35)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)
	
	if UITheme:
		UITheme.style_button(restart_btn)
	_apply_button_font_color(restart_btn)


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
