# ui/hud.gd
# Zeigt Gold, Leben, Welle und Start-Button
# An einem Control Node anbringen
extends Control
class_name HUD

signal start_wave_pressed

var gold_label: Label
var lives_label: Label
var wave_label: Label
var enemies_label: Label
var start_button: Button
var wave_preview_label: Label


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	update_all()


func _setup_ui() -> void:
	# Prüfen ob Nodes schon existieren, sonst erstellen
	gold_label = get_node_or_null("GoldLabel")
	if not gold_label:
		gold_label = Label.new()
		gold_label.name = "GoldLabel"
		gold_label.position = Vector2(10, 10)
		add_child(gold_label)
	
	lives_label = get_node_or_null("LivesLabel")
	if not lives_label:
		lives_label = Label.new()
		lives_label.name = "LivesLabel"
		lives_label.position = Vector2(10, 35)
		add_child(lives_label)
	
	wave_label = get_node_or_null("WaveLabel")
	if not wave_label:
		wave_label = Label.new()
		wave_label.name = "WaveLabel"
		wave_label.position = Vector2(10, 60)
		add_child(wave_label)
	
	enemies_label = get_node_or_null("EnemiesLabel")
	if not enemies_label:
		enemies_label = Label.new()
		enemies_label.name = "EnemiesLabel"
		enemies_label.position = Vector2(10, 85)
		enemies_label.visible = false
		add_child(enemies_label)
	
	start_button = get_node_or_null("StartWaveButton")
	if not start_button:
		start_button = Button.new()
		start_button.name = "StartWaveButton"
		start_button.text = "Start Welle"
		start_button.position = Vector2(10, 115)
		add_child(start_button)
	
	wave_preview_label = get_node_or_null("WavePreviewLabel")
	if not wave_preview_label:
		wave_preview_label = Label.new()
		wave_preview_label.name = "WavePreviewLabel"
		wave_preview_label.position = Vector2(10, 150)
		wave_preview_label.add_theme_font_size_override("font_size", 11)
		wave_preview_label.visible = false
		add_child(wave_preview_label)


func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.enemy_count_changed.connect(_on_enemy_count_changed)
	start_button.pressed.connect(_on_start_button_pressed)


func update_all() -> void:
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_update_wave_display()
	_on_enemy_count_changed(GameState.enemies_remaining)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	lives_label.text = "Leben: %d" % amount
	
	# Farbe ändern bei niedrigen Leben
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lives_label.remove_theme_color_override("font_color")


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
		wave_preview_label.text = "Nächste: " + wave_manager.get_wave_info(next_wave)
	else:
		wave_preview_label.text = "Nächste Welle bereit"


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


func show_game_over() -> void:
	start_button.visible = false
	
	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: %d" % GameState.current_wave
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.position = Vector2(250, 200)
	game_over_label.name = "GameOverLabel"
	add_child(game_over_label)
	
	var restart_btn := Button.new()
	restart_btn.text = "Neustart"
	restart_btn.position = Vector2(350, 320)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
