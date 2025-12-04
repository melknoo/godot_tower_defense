# ui/hud.gd
# Zeigt Gold, Leben, Welle und Start-Button
# An einem Control/CanvasLayer Node anbringen
extends Control
class_name HUD

signal start_wave_pressed

@onready var gold_label: Label = $GoldLabel
@onready var lives_label: Label = $LivesLabel
@onready var wave_label: Label = $WaveLabel
@onready var enemies_label: Label = $EnemiesLabel
@onready var start_button: Button = $StartWaveButton
@onready var wave_preview_label: Label = $WavePreviewLabel


func _ready() -> void:
	_connect_signals()
	_setup_ui()
	update_all()


func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.enemy_count_changed.connect(_on_enemy_count_changed)
	start_button.pressed.connect(_on_start_button_pressed)


func _setup_ui() -> void:
	# Optional: Labels erstellen falls sie nicht existieren
	if not gold_label:
		gold_label = Label.new()
		gold_label.name = "GoldLabel"
		add_child(gold_label)
	
	if not lives_label:
		lives_label = Label.new()
		lives_label.name = "LivesLabel"
		add_child(lives_label)
	
	if not wave_label:
		wave_label = Label.new()
		wave_label.name = "WaveLabel"
		add_child(wave_label)
	
	if not enemies_label:
		enemies_label = Label.new()
		enemies_label.name = "EnemiesLabel"
		add_child(enemies_label)


func update_all() -> void:
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_update_wave_display()
	_on_enemy_count_changed(GameState.enemies_remaining)


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % amount


func _on_lives_changed(amount: int) -> void:
	if lives_label:
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
	
	if wave_preview_label:
		wave_preview_label.visible = false


func _on_wave_completed(wave: int) -> void:
	start_button.disabled = false
	start_button.text = "Nächste Welle"
	
	_update_wave_preview(wave + 1)


func _on_enemy_count_changed(count: int) -> void:
	if enemies_label:
		if GameState.wave_active:
			enemies_label.text = "Gegner: %d" % count
			enemies_label.visible = true
		else:
			enemies_label.visible = false


func _update_wave_display() -> void:
	if wave_label:
		if GameState.current_wave == 0:
			wave_label.text = "Welle: --"
		else:
			wave_label.text = "Welle: %d" % GameState.current_wave


func _update_wave_preview(next_wave: int) -> void:
	if wave_preview_label:
		wave_preview_label.visible = true
		# WaveManager für Preview nutzen (falls verfügbar)
		var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
		if wave_manager:
			wave_preview_label.text = "Nächste: " + wave_manager.get_wave_info(next_wave)
		else:
			wave_preview_label.text = "Nächste Welle bereit"


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


# Game Over Anzeige
func show_game_over() -> void:
	start_button.visible = false
	
	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: %d" % GameState.current_wave
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.anchors_preset = Control.PRESET_CENTER
	game_over_label.name = "GameOverLabel"
	add_child(game_over_label)
	
	# Restart Button
	var restart_btn := Button.new()
	restart_btn.text = "Neustart"
	restart_btn.position = Vector2(350, 300)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
