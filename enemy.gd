# enemy.gd
# Gegner mit Elementar-Typen, Schwächen und VFX
extends Node2D
class_name Enemy

var path: Array[Vector2] = []
var path_index := 0
var health := 100
var max_health := 100
var speed := 80.0
var base_speed := 80.0
var reward := 2
var enemy_type := "normal"
var element := "neutral"  # NEU: Elementar-Typ

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
var element_indicator: Label  # NEU: Element-Anzeige


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
	
	# Element Indicator
	element_indicator = Label.new()
	element_indicator.position = Vector2(-8, -38)
	element_indicator.add_theme_font_size_override("font_size", 12)
	element_indicator.visible = false
	add_child(element_indicator)
	
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
	element = data.get("element", "neutral")  # NEU
	
	position = path[0] if path.size() > 0 else Vector2.ZERO
	
	var enemy_scale: float = data.get("scale", 0.5)
	var base_color: Color = data.get("color", Color.WHITE)
	
	# Farbe basierend auf Element anpassen
	var final_color := _calculate_element_color(base_color)
	original_modulate = final_color
	
	# Nur aktualisieren wenn Visuals bereits existieren
	if sprite:
		sprite.scale = Vector2(enemy_scale, enemy_scale)
		sprite.modulate = final_color
	
	if shadow:
		shadow.scale = Vector2(enemy_scale * 1.5, enemy_scale)
	
	# Element-Indikator aktualisieren (mit Null-Check in der Funktion)
	_update_element_indicator()


func _calculate_element_color(base_color: Color) -> Color:
	if element == "neutral" or element == "":
		return base_color
	
	var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
	# Mische Basis-Farbe mit Element-Farbe
	return base_color.lerp(elem_color, 0.5)


func _update_element_indicator() -> void:
	if not element_indicator:
		return
	
	if element == "neutral" or element == "":
		element_indicator.visible = false
		return
	
	element_indicator.visible = true
	element_indicator.text = ElementalSystem.get_element_symbol(element) if ElementalSystem else element.substr(0, 1).to_upper()
	
	# Outline für bessere Sichtbarkeit
	element_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	element_indicator.add_theme_constant_override("outline_size", 2)


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


# NEU: Damage mit Elementar-Multiplikator
func take_damage(amount: int, trigger_effects: bool = true, attacker_element: String = "") -> void:
	var final_damage := amount
	var multiplier := 1.0
	
	# Elementar-Multiplikator berechnen
	if attacker_element != "" and ElementalSystem:
		multiplier = ElementalSystem.get_damage_multiplier(attacker_element, element)
		final_damage = int(amount * multiplier)
	
	health -= final_damage
	
	if trigger_effects:
		GameState.record_damage(final_damage)
		_do_hit_flash()
		
		# VFX spawnen
		if VFX:
			var is_crit := final_damage > damage_threshold_for_crit()
			var is_effective := multiplier > 1.0
			var is_resisted := multiplier < 1.0
			
			# Spezielle VFX für effektive/resistierte Treffer
			if is_effective:
				VFX.spawn_pixel_burst(position, attacker_element, 10)
				VFX.spawn_damage_number(position, final_damage, true, attacker_element)
			elif is_resisted:
				VFX.spawn_pixels(position, element, 4, 15.0)
				VFX.spawn_damage_number(position, final_damage, false, "")
			else:
				VFX.spawn_hit_effect(position, attacker_element if attacker_element != "" else "damage", is_crit)
				VFX.spawn_damage_number(position, final_damage, is_crit, attacker_element)
	
	if health <= 0:
		_die()


func damage_threshold_for_crit() -> int:
	return int(max_health * 0.5)


func _do_hit_flash() -> void:
	flash_timer = 0.1
	if sprite:
		sprite.modulate = Color.WHITE


func _die() -> void:
	GameState.enemy_died(reward)
	Sound.play_coin()
	
	if VFX:
		VFX.spawn_death_effect(position, enemy_type)
		VFX.spawn_gold_number(position, reward)
		
		# Extra VFX für elementare Gegner
		if element != "neutral" and element != "":
			VFX.spawn_pixel_ring(position, element, 30.0)
		
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
	
	if VFX:
		VFX.spawn_pixels(position, "ice", 4, 15.0)


func apply_burn(damage_per_second: int, duration: float) -> void:
	burn_damage = damage_per_second
	burn_timer = maxf(burn_timer, duration)
	
	_show_status_icon("burn")
	
	if VFX:
		VFX.spawn_pixels(position, "fire", 4, 15.0)


func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)
	wobble_time = 0.0
	
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.5)
	
	if VFX:
		VFX.spawn_pixels(position, "air", 6, 20.0)


func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	
	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0)
		sprite.modulate.a = 0.7
	
	if VFX:
		VFX.spawn_pixel_ring(position, "ice", 25.0)


# === VISUALS ===

func _update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, -22))
	
	# Farbe basierend auf Element und HP
	var bar_color := Color(1 - health_percent, health_percent, 0)
	if element != "neutral" and element != "":
		var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
		bar_color = bar_color.lerp(elem_color, 0.3)
	health_bar.default_color = bar_color


func _show_status_icon(effect_type: String) -> void:
	for child in status_indicator.get_children():
		if child.name == effect_type:
			return
	
	var icon := Label.new()
	icon.name = effect_type
	icon.add_theme_font_size_override("font_size", 10)
	
	match effect_type:
		"burn": icon.text = "🔥"
		"slow": icon.text = "❄"
		"stun": icon.text = "⚡"
	
	status_indicator.add_child(icon)


func get_progress() -> float:
	if path.size() == 0:
		return 0.0
	return float(path_index) / path.size()


func get_remaining_health_percent() -> float:
	return float(health) / max_health


func get_element() -> String:
	return element
