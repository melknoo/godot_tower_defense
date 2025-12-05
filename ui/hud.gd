# ui/hud.gd
# Zeigt Gold, Leben, Welle, Element-Kerne und Start-Button
extends Control
class_name HUD

signal start_wave_pressed
signal open_element_panel_pressed

var gold_label: Label
var lives_label: Label
var wave_label: Label
var enemies_label: Label
var cores_label: Label
var cores_button: Button
var start_button: Button
var wave_preview_label: Label


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	update_all()


func _setup_ui() -> void:
	# Obere Leiste - Ressourcen nebeneinander
	gold_label = _get_or_create_label("GoldLabel", Vector2(20, 970))
	lives_label = _get_or_create_label("LivesLabel", Vector2(200, 970))
	wave_label = _get_or_create_label("WaveLabel", Vector2(380, 970))
	enemies_label = _get_or_create_label("EnemiesLabel", Vector2(560, 970))
	enemies_label.visible = false
	
	# Element-Kerne Anzeige - unten links
	cores_label = _get_or_create_label("CoresLabel", Vector2(20, 1000))
	cores_label.add_theme_font_size_override("font_size", 12)
	cores_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	
	# Element-Panel Button
	cores_button = get_node_or_null("CoresButton")
	if not cores_button:
		cores_button = Button.new()
		cores_button.name = "CoresButton"
		cores_button.text = "Elemente"
		cores_button.position = Vector2(300, 1000)
		cores_button.custom_minimum_size = Vector2(90, 28)
		cores_button.visible = false
		add_child(cores_button)
	
	# Start Button - unten rechts
	start_button = get_node_or_null("StartWaveButton")
	if not start_button:
		start_button = Button.new()
		start_button.name = "StartWaveButton"
		start_button.text = "Welle starten"
		start_button.position = Vector2(1550, 970)
		start_button.custom_minimum_size = Vector2(130, 35)
		add_child(start_button)
	
	# Wave Preview - über dem Start Button
	wave_preview_label = _get_or_create_label("WavePreviewLabel", Vector2(1750, 940))
	wave_preview_label.add_theme_font_size_override("font_size", 11)
	wave_preview_label.visible = false
	
	if UITheme:
		UITheme.style_button(start_button)
		UITheme.style_button(cores_button)
	
	# Dunkle Schriftfarbe für Buttons
	var dark_font := Color(0.1, 0.1, 0.1)
	start_button.add_theme_color_override("font_color", dark_font)
	start_button.add_theme_color_override("font_hover_color", dark_font)
	start_button.add_theme_color_override("font_pressed_color", dark_font)
	cores_button.add_theme_color_override("font_color", dark_font)
	cores_button.add_theme_color_override("font_hover_color", dark_font)
	cores_button.add_theme_color_override("font_pressed_color", dark_font)


func _get_or_create_label(node_name: String, pos: Vector2) -> Label:
	var label := get_node_or_null(node_name) as Label
	if not label:
		label = Label.new()
		label.name = node_name
		label.position = pos
		add_child(label)
	return label


func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.enemy_count_changed.connect(_on_enemy_count_changed)
	GameState.element_cores_changed.connect(_on_cores_changed)
	GameState.element_core_earned.connect(_on_core_earned)
	
	start_button.pressed.connect(_on_start_button_pressed)
	cores_button.pressed.connect(_on_cores_button_pressed)


func update_all() -> void:
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_update_wave_display()
	_on_enemy_count_changed(GameState.enemies_remaining)
	_on_cores_changed(GameState.element_cores)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "Leben: %d" % amount
	
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lives_label.remove_theme_color_override("font_color")


func _on_cores_changed(amount: int) -> void:
	var unlocked := TowerData.get_unlocked_count()
	var total := TowerData.get_total_unlockable()
	
	cores_label.text = "Kerne: %d  Elemente: %d/%d" % [amount, unlocked, total]
	
	# Button nur anzeigen wenn es noch was freizuschalten gibt
	var has_locked := not TowerData.get_locked_elements().is_empty()
	cores_button.visible = has_locked
	
	# Button hervorheben wenn Kerne verfügbar
	if amount > 0 and has_locked:
		cores_button.text = "🔮 (%d)" % amount
		_highlight_cores_button(true)
	else:
		cores_button.text = "🔮"
		_highlight_cores_button(false)


func _on_core_earned() -> void:
	# Visueller Hinweis dass ein Kern verdient wurde
	_flash_cores_label()


func _highlight_cores_button(highlight: bool) -> void:
	if highlight:
		cores_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		cores_button.remove_theme_color_override("font_color")


func _flash_cores_label() -> void:
	var original_color := cores_label.get_theme_color("font_color")
	
	var tween := cores_label.create_tween()
	tween.tween_property(cores_label, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	tween.tween_property(cores_label, "modulate", Color.WHITE, 0.3)


func _on_wave_started(wave: int) -> void:
	_update_wave_display()
	start_button.disabled = true
	start_button.text = "Wave läuft..."
	wave_preview_label.visible = false


func _on_wave_completed(wave: int) -> void:
	start_button.disabled = false
	start_button.text = "Nächste Welle"
	_update_wave_preview(wave + 1)


func _on_enemy_count_changed(count: int) -> void:
	if GameState.wave_active:
		enemies_label.text = "Gegner: %d" % count
		enemies_label.visible = true
	else:
		enemies_label.visible = false


func _update_wave_display() -> void:
	if GameState.current_wave == 0:
		wave_label.text = "Welle: --"
	else:
		wave_label.text = "Welle: %d" % GameState.current_wave


func _update_wave_preview(next_wave: int) -> void:
	wave_preview_label.visible = true
	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if wave_manager:
		var info := wave_manager.get_wave_info(next_wave)
		wave_preview_label.text = "Nächste: " + info
		
		# Hinweis auf Boss-Welle und Element-Kern
		if next_wave % 5 == 0:
			wave_preview_label.text += "\n⚠ Boss-Welle! (+1 Kern)"
			wave_preview_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		elif next_wave == 1:
			wave_preview_label.text += "\n(+1 Kern nach Welle 1)"
			wave_preview_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		else:
			wave_preview_label.remove_theme_color_override("font_color")
	else:
		wave_preview_label.text = "Nächste Welle bereit"


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


func _on_cores_button_pressed() -> void:
	open_element_panel_pressed.emit()


func show_game_over() -> void:
	start_button.visible = false
	cores_button.visible = false
	
	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: %d\nElemente: %d/%d" % [
		GameState.current_wave,
		TowerData.get_unlocked_count(),
		TowerData.get_total_unlockable()
	]
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.position = Vector2(280, 180)
	game_over_label.name = "GameOverLabel"
	add_child(game_over_label)
	
	var restart_btn := Button.new()
	restart_btn.text = "Neustart"
	restart_btn.position = Vector2(350, 320)
	restart_btn.custom_minimum_size = Vector2(100, 35)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)
	
	if UITheme:
		UITheme.style_button(restart_btn)
	
	# Dunkle Schriftfarbe
	restart_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	restart_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1))
	restart_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1))


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
