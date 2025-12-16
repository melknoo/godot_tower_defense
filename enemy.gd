# enemy.gd
# Gegner mit verschiedenen Typen, Effekten und VFX
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

# Hit-Flash
var flash_timer := 0.0
var original_modulate := Color.WHITE

# Visuals
var sprite: Sprite2D
var health_bar_bg: Line2D
var health_bar: Line2D
var status_indicator: Node2D
var shadow: Polygon2D


func _ready() -> void:
	add_to_group("enemies")
	_create_visuals()


func _create_visuals() -> void:
	# Schatten
	shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-12, 4), Vector2(12, 4),
		Vector2(10, 8), Vector2(-10, 8)
	])
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.z_index = -1
	add_child(shadow)
	
	# Sprite
	sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/enemy.png"):
		sprite.texture = preload("res://assets/enemy.png")
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	
	# Health Bar Background
	health_bar_bg = Line2D.new()
	health_bar_bg.add_point(Vector2(-15, -22))
	health_bar_bg.add_point(Vector2(15, -22))
	health_bar_bg.default_color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar_bg.width = 6
	add_child(health_bar_bg)
	
	# Health Bar
	health_bar = Line2D.new()
	health_bar.add_point(Vector2(-15, -22))
	health_bar.add_point(Vector2(15, -22))
	health_bar.default_color = Color(0, 1, 0)
	health_bar.width = 4
	add_child(health_bar)
	
	# Status Indicator
	status_indicator = Node2D.new()
	status_indicator.position = Vector2(0, -30)
	add_child(status_indicator)


func setup(path_points: Array[Vector2], hp: int, spd: float) -> void:
	path = path_points
	health = hp
	max_health = hp
	speed = spd
	base_speed = spd
	position = path[0] if path.size() > 0 else Vector2.ZERO


func setup_extended(path_points: Array[Vector2], data: Dictionary) -> void:
	path = path_points
	health = data.get("health", 100)
	max_health = health
	speed = data.get("speed", 80.0)
	base_speed = speed
	reward = data.get("reward", 10)
	enemy_type = data.get("type", "normal")
	
	position = path[0] if path.size() > 0 else Vector2.ZERO
	
	var enemy_scale: float = data.get("scale", 0.5)
	var enemy_color: Color = data.get("color", Color.WHITE)
	
	if sprite:
		sprite.scale = Vector2(enemy_scale, enemy_scale)
		sprite.modulate = enemy_color
		original_modulate = enemy_color
	
	# Schatten anpassen
	if shadow:
		shadow.scale = Vector2(enemy_scale * 1.5, enemy_scale)


func _process(delta: float) -> void:
	# Hit-Flash abklingen
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0 and sprite:
			sprite.modulate = original_modulate
	
	# Gestunned oder eingefroren?
	if stun_timer > 0:
		stun_timer -= delta
		_do_stun_wobble(delta)
		return
	
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			is_frozen = false
			if sprite:
				sprite.modulate = original_modulate
		return
	
	_update_status_effects(delta)
	_move(delta)
	_update_health_bar()
	_do_walk_animation(delta)


var walk_bob := 0.0

func _do_walk_animation(delta: float) -> void:
	walk_bob += delta * 12.0
	if sprite:
		sprite.position.y = sin(walk_bob) * 2


var wobble_time := 0.0

func _do_stun_wobble(delta: float) -> void:
	wobble_time += delta * 20.0
	if sprite:
		sprite.rotation = sin(wobble_time) * 0.2


func _move(delta: float) -> void:
	if path_index >= path.size():
		_reach_end()
		return
	
	var current_speed := base_speed
	if slow_timer > 0:
		current_speed *= (1.0 - slow_amount)
	
	var target_pos := path[path_index]
	var direction := (target_pos - position).normalized()
	position += direction * current_speed * delta
	
	if direction.length() > 0:
		sprite.rotation = direction.angle() + PI/2
	
	if position.distance_to(target_pos) < 5:
		path_index += 1


func _reach_end() -> void:
	GameState.enemy_reached_end()
	
	# Screen Shake wenn Enemy durchkommt
	if VFX:
		VFX.screen_shake(8.0, 0.3)
		VFX.screen_flash(Color(1, 0, 0), 0.15)
	
	queue_free()


func _update_status_effects(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_amount = 0.0
			if sprite:
				sprite.modulate = original_modulate
	
	if burn_timer > 0:
		burn_timer -= delta
		take_damage(int(burn_damage * delta), false, "fire")


func take_damage(amount: int, trigger_effects: bool = true, element: String = "") -> void:
	health -= amount
	
	if trigger_effects:
		GameState.record_damage(amount)
		_do_hit_flash()
		
		# VFX spawnen
		if VFX:
			var is_crit := amount > damage_threshold_for_crit()
			VFX.spawn_hit_effect(position, element if element != "" else "damage", is_crit)
			VFX.spawn_damage_number(position, amount, is_crit, element)
	
	if health <= 0:
		_die()


func damage_threshold_for_crit() -> int:
	# Crit nur bei wirklich hohem Schaden (>40% der max HP in einem Hit)
	return int(max_health * 0.5)


func _do_hit_flash() -> void:
	flash_timer = 0.1
	if sprite:
		sprite.modulate = Color.WHITE


func _die() -> void:
	GameState.enemy_died(reward)
	Sound.play_coin()
	# VFX
	if VFX:
		VFX.spawn_death_effect(position, enemy_type)
		VFX.spawn_gold_number(position, reward)
		
		# Screen Shake bei Boss
		if enemy_type == "boss":
			VFX.screen_shake(12.0, 0.4)
			VFX.screen_flash(Color(1, 0.8, 0.3), 0.2)
	
	queue_free()


# === STATUS EFFEKTE ===

func apply_slow(amount: float, duration: float) -> void:
	if amount > slow_amount:
		slow_amount = amount
	slow_timer = maxf(slow_timer, duration)
	
	if sprite:
		sprite.modulate = original_modulate.lerp(Color(0.5, 0.5, 1.0), 0.5)
	
	# Eis-Partikel
	if VFX:
		VFX.spawn_pixels(position, "ice", 4, 15.0)


func apply_burn(damage_per_second: int, duration: float) -> void:
	burn_damage = damage_per_second
	burn_timer = maxf(burn_timer, duration)
	
	_show_status_icon("burn")
	
	# Feuer-Partikel
	if VFX:
		VFX.spawn_pixels(position, "fire", 4, 15.0)


func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)
	wobble_time = 0.0
	
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.5)
	
	# Blitz-Effekt
	if VFX:
		VFX.spawn_pixels(position, "air", 6, 20.0)


func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	
	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0)
		sprite.modulate.a = 0.7
	
	# Eis-Ring
	if VFX:
		VFX.spawn_pixel_ring(position, "ice", 25.0)


# === VISUALS ===

func _update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, -22))
	health_bar.default_color = Color(1 - health_percent, health_percent, 0)


func _show_status_icon(effect_type: String) -> void:
	for child in status_indicator.get_children():
		if child.name == effect_type:
			return
	
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


func get_progress() -> float:
	if path.size() == 0:
		return 0.0
	return float(path_index) / path.size()


func get_remaining_health_percent() -> float:
	return float(health) / max_health
