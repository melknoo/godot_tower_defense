# enemy.gd
# Gegner mit verschiedenen Typen und Effekten
extends Node2D
class_name Enemy

var path: Array[Vector2] = []
var path_index := 0
var health := 100
var max_health := 100
var speed := 80.0
var base_speed := 80.0
var reward := 10
var enemy_type := "normal"

# Status-Effekte
var slow_amount := 0.0
var slow_timer := 0.0
var burn_damage := 0
var burn_timer := 0.0
var stun_timer := 0.0
var is_frozen := false
var freeze_timer := 0.0

# Visuals
var sprite: Sprite2D
var health_bar: Line2D
var status_indicator: Node2D


func _ready() -> void:
	add_to_group("enemies")
	_create_visuals()


func _create_visuals() -> void:
	# Sprite
	sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/enemy.png"):
		sprite.texture = preload("res://assets/enemy.png")
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	
	# Health Bar
	health_bar = Line2D.new()
	health_bar.add_point(Vector2(-15, -22))
	health_bar.add_point(Vector2(15, -22))
	health_bar.default_color = Color(0, 1, 0)
	health_bar.width = 4
	add_child(health_bar)
	
	# Status Indicator (für Effekte)
	status_indicator = Node2D.new()
	status_indicator.position = Vector2(0, -30)
	add_child(status_indicator)


# Basis-Setup (Kompatibilität)
func setup(path_points: Array[Vector2], hp: int, spd: float) -> void:
	path = path_points
	health = hp
	max_health = hp
	speed = spd
	base_speed = spd
	position = path[0] if path.size() > 0 else Vector2.ZERO


# Erweitertes Setup für WaveManager
func setup_extended(path_points: Array[Vector2], data: Dictionary) -> void:
	path = path_points
	health = data.get("health", 100)
	max_health = health
	speed = data.get("speed", 80.0)
	base_speed = speed
	reward = data.get("reward", 10)
	enemy_type = data.get("type", "normal")
	
	position = path[0] if path.size() > 0 else Vector2.ZERO
	
	# Visuelle Anpassungen je nach Typ
	var enemy_scale: float = data.get("scale", 0.5)
	var enemy_color: Color = data.get("color", Color.WHITE)
	
	if sprite:
		sprite.scale = Vector2(enemy_scale, enemy_scale)
		sprite.modulate = enemy_color


func _process(delta: float) -> void:
	# Gestunned oder eingefroren?
	if stun_timer > 0:
		stun_timer -= delta
		return
	
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			is_frozen = false
			sprite.modulate.a = 1.0
		return
	
	# Status-Effekte updaten
	_update_status_effects(delta)
	
	# Bewegung
	_move(delta)
	
	# UI updaten
	_update_health_bar()


func _move(delta: float) -> void:
	if path_index >= path.size():
		GameState.enemy_reached_end()
		queue_free()
		return
	
	# Aktuelle Geschwindigkeit (mit Slow-Effekt)
	var current_speed := base_speed
	if slow_timer > 0:
		current_speed *= (1.0 - slow_amount)
	
	var target_pos := path[path_index]
	var direction := (target_pos - position).normalized()
	position += direction * current_speed * delta
	
	# Sprite-Rotation zur Bewegungsrichtung
	if direction.length() > 0:
		sprite.rotation = direction.angle() + PI/2
	
	if position.distance_to(target_pos) < 5:
		path_index += 1


func _update_status_effects(delta: float) -> void:
	# Slow
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_amount = 0.0
	
	# Burn
	if burn_timer > 0:
		burn_timer -= delta
		# Schaden pro Sekunde
		take_damage(int(burn_damage * delta), false)


func take_damage(amount: int, trigger_effects: bool = true) -> void:
	health -= amount
	
	if trigger_effects:
		GameState.record_damage(amount)
		_spawn_damage_number(amount)
	
	if health <= 0:
		_die()


func _die() -> void:
	GameState.enemy_died(reward)
	_spawn_death_effect()
	queue_free()


# === STATUS EFFEKTE ===

func apply_slow(amount: float, duration: float) -> void:
	# Stärkerer Slow überschreibt
	if amount > slow_amount:
		slow_amount = amount
	slow_timer = maxf(slow_timer, duration)
	
	# Visuelles Feedback
	sprite.modulate = sprite.modulate.lerp(Color(0.5, 0.5, 1.0), 0.5)


func apply_burn(damage_per_second: int, duration: float) -> void:
	burn_damage = damage_per_second
	burn_timer = maxf(burn_timer, duration)
	
	# Visuelles Feedback
	_show_status_icon("burn")


func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)
	
	# Visuelles Feedback
	sprite.modulate = Color(1.0, 1.0, 0.5)


func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	
	# Visuelles Feedback
	sprite.modulate = Color(0.7, 0.9, 1.0)
	sprite.modulate.a = 0.7


# === VISUALS ===

func _update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, -22))
	health_bar.default_color = Color(1 - health_percent, health_percent, 0)


func _spawn_damage_number(amount: int) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.position = position + Vector2(randf_range(-10, 10), -30)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.z_index = 100
	get_parent().add_child(label)
	
	# Animation
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)


func _spawn_death_effect() -> void:
	var particles := Node2D.new()
	particles.position = position
	get_parent().add_child(particles)
	
	# Einfacher Explosion-Effekt
	for i in range(8):
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3),
			Vector2(3, 3), Vector2(-3, 3)
		])
		particle.color = Color(1.0, 0.5, 0.2)
		particles.add_child(particle)
		
		var angle := i * TAU / 8
		var direction := Vector2(cos(angle), sin(angle))
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", direction * 30, 0.3)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
	
	# Aufräumen
	var cleanup_tween := particles.create_tween()
	cleanup_tween.tween_interval(0.4)
	cleanup_tween.tween_callback(particles.queue_free)


func _show_status_icon(effect_type: String) -> void:
	# Einfache Indikator-Anzeige
	for child in status_indicator.get_children():
		if child.name == effect_type:
			return  # Bereits vorhanden
	
	var icon := Label.new()
	icon.name = effect_type
	icon.add_theme_font_size_override("font_size", 10)
	
	match effect_type:
		"burn":
			icon.text = "🔥"
		"slow":
			icon.text = "❄"
		"stun":
			icon.text = "⚡"
	
	status_indicator.add_child(icon)


# === GETTER ===

func get_progress() -> float:
	# Wie weit ist der Gegner auf dem Pfad (0.0 - 1.0)
	if path.size() == 0:
		return 0.0
	return float(path_index) / path.size()


func get_remaining_health_percent() -> float:
	return float(health) / max_health
