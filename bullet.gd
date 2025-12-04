# bullet.gd
# Projektil mit Spezialeffekten
extends Node2D
class_name Bullet

var target: Node2D
var damage := 20
var speed := 400.0
var splash_radius := 0.0
var bullet_type := "water"

# Spezialeffekte
var special_type := ""
var slow_amount := 0.0
var slow_duration := 2.0
var burn_damage := 0
var burn_duration := 3.0
var stun_chance := 0.0
var stun_duration := 0.5
var chain_targets := 0
var chain_range := 100.0
var already_hit: Array[Node2D] = []

# Visuals
var sprite: Sprite2D
var trail: Line2D


func _ready() -> void:
	_create_visuals()


func setup(t: Node2D, dmg: int, splash: float, type: String) -> void:
	target = t
	damage = dmg
	splash_radius = splash
	bullet_type = type
	_set_speed_for_type(type)


func setup_extended(data: Dictionary) -> void:
	target = data.get("target")
	damage = data.get("damage", 20)
	splash_radius = data.get("splash", 0.0)
	bullet_type = data.get("type", "water")
	special_type = data.get("special", "")
	slow_amount = data.get("slow_amount", 0.0)
	burn_damage = data.get("burn_damage", 0)
	stun_chance = data.get("stun_chance", 0.0)
	chain_targets = data.get("chain_targets", 0)
	
	_set_speed_for_type(bullet_type)


func _set_speed_for_type(type: String) -> void:
	match type:
		"water": speed = 300.0
		"fire": speed = 350.0
		"earth": speed = 200.0
		"air": speed = 500.0
		"sniper": speed = 600.0
		"cannon": speed = 250.0
		"ice": speed = 350.0
		"steam": speed = 300.0
		"lava": speed = 200.0
		"nature": speed = 280.0
		_: speed = 400.0


func _create_visuals() -> void:
	var texture_path := "res://assets/elemental_bullets/bullet_%s.png" % bullet_type
	
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		
		# Animiertes Spritesheet?
		if sprite.texture.get_width() > sprite.texture.get_height():
			var frame_count := sprite.texture.get_width() / sprite.texture.get_height()
			sprite.hframes = frame_count
			sprite.vframes = 1
			
			var timer := Timer.new()
			timer.wait_time = 0.1
			timer.autostart = true
			timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % frame_count)
			add_child(timer)
		
		sprite.scale = Vector2(2, 2)
		add_child(sprite)
	else:
		# Fallback Polygon
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-6, -3), Vector2(6, -3),
			Vector2(8, 0), Vector2(6, 3),
			Vector2(-6, 3)
		])
		poly.color = _get_bullet_color()
		add_child(poly)
	
	# Trail Effekt
	_create_trail()


func _create_trail() -> void:
	trail = Line2D.new()
	trail.width = 4
	trail.default_color = _get_bullet_color()
	trail.default_color.a = 0.5
	
	# Gradient für Trail
	var gradient := Gradient.new()
	gradient.set_color(0, _get_bullet_color())
	gradient.set_color(1, Color(_get_bullet_color(), 0))
	trail.gradient = gradient
	
	get_parent().call_deferred("add_child", trail)


func _get_bullet_color() -> Color:
	match bullet_type:
		"water": return Color(0.3, 0.6, 1.0)
		"fire": return Color(1.0, 0.5, 0.2)
		"earth": return Color(0.6, 0.4, 0.2)
		"air": return Color(0.8, 0.9, 1.0)
		"ice": return Color(0.7, 0.9, 1.0)
		"steam": return Color(0.7, 0.7, 0.8)
		"lava": return Color(1.0, 0.3, 0.0)
		"nature": return Color(0.3, 0.8, 0.2)
		_: return Color.WHITE


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		_explode()
		return
	
	# Bewegung zum Ziel
	var direction := (target.position - position).normalized()
	position += direction * speed * delta
	rotation = direction.angle()
	
	# Trail aktualisieren
	_update_trail()
	
	# Treffer prüfen
	if position.distance_to(target.position) < 15:
		_hit_target()


func _update_trail() -> void:
	if not is_instance_valid(trail):
		return
	
	trail.add_point(position)
	
	# Trail auf max 10 Punkte begrenzen
	while trail.get_point_count() > 10:
		trail.remove_point(0)


func _hit_target() -> void:
	if splash_radius > 0:
		_hit_splash()
	else:
		_hit_single(target)
	
	# Chain Lightning
	if chain_targets > 0 and special_type == "chain":
		_do_chain_attack()
	
	_explode()


func _hit_single(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy in already_hit:
		return
	
	already_hit.append(enemy)
	enemy.take_damage(damage)
	_apply_special_effects(enemy)


func _hit_splash() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if position.distance_to(enemy.position) <= splash_radius:
			_hit_single(enemy)
	
	_spawn_splash_effect()


func _apply_special_effects(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	
	match special_type:
		"slow":
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_amount, slow_duration)
		
		"burn":
			if enemy.has_method("apply_burn"):
				enemy.apply_burn(burn_damage, burn_duration)
		
		"stun":
			if randf() < stun_chance:
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(stun_duration)
		
		"freeze":
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(2.0)
		
		"confuse":
			# Steam: Gegner laufen kurz rückwärts
			pass  # Später implementieren
		
		"root":
			# Nature: Gegner werden festgehalten
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(1.5)
		
		"pool":
			# Lava: Hinterlässt brennende Pfütze
			_spawn_lava_pool()


func _do_chain_attack() -> void:
	var current_target := target
	var remaining_chains := chain_targets
	var chain_damage := damage / 2  # Chain macht weniger Schaden
	
	while remaining_chains > 0 and is_instance_valid(current_target):
		var next_target: Node2D = null
		var closest_dist := chain_range
		
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in already_hit:
				continue
			
			var dist := current_target.position.distance_to(enemy.position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = enemy
		
		if next_target:
			# Chain Blitz zeichnen
			_draw_chain_lightning(current_target.position, next_target.position)
			
			already_hit.append(next_target)
			next_target.take_damage(chain_damage)
			_apply_special_effects(next_target)
			
			current_target = next_target
			remaining_chains -= 1
		else:
			break


func _draw_chain_lightning(from: Vector2, to: Vector2) -> void:
	var lightning := Line2D.new()
	lightning.width = 2
	lightning.default_color = Color(0.8, 0.9, 1.0)
	
	# Zickzack-Linie
	var segments := 5
	var direction := (to - from) / segments
	var perpendicular := direction.rotated(PI/2).normalized()
	
	lightning.add_point(from)
	for i in range(1, segments):
		var point := from + direction * i
		point += perpendicular * randf_range(-10, 10)
		lightning.add_point(point)
	lightning.add_point(to)
	
	get_parent().add_child(lightning)
	
	# Verblassen
	var tween := lightning.create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.2)
	tween.tween_callback(lightning.queue_free)


func _spawn_splash_effect() -> void:
	var explosion := Node2D.new()
	explosion.position = position
	
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * splash_radius)
	circle.polygon = points
	circle.color = _get_bullet_color()
	circle.color.a = 0.5
	explosion.add_child(circle)
	
	get_parent().add_child(explosion)
	
	var tween := explosion.create_tween()
	tween.tween_property(circle, "color:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)


func _spawn_lava_pool() -> void:
	var pool := Node2D.new()
	pool.position = position
	
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(16):
		var angle := i * TAU / 16
		var radius := splash_radius * randf_range(0.8, 1.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	circle.color = Color(1.0, 0.3, 0.0, 0.6)
	pool.add_child(circle)
	
	get_parent().add_child(pool)
	
	# Pool-Damage über Zeit
	var pool_timer := Timer.new()
	pool_timer.wait_time = 0.5
	pool_timer.autostart = true
	pool.add_child(pool_timer)
	
	var pool_damage := burn_damage if burn_damage > 0 else 5
	var pool_duration := 3.0
	
	pool_timer.timeout.connect(func():
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if pool.position.distance_to(enemy.position) <= splash_radius:
				enemy.take_damage(pool_damage, false)
	)
	
	# Pool verschwindet nach Zeit
	var tween := pool.create_tween()
	tween.tween_interval(pool_duration)
	tween.tween_property(circle, "color:a", 0.0, 0.5)
	tween.tween_callback(pool.queue_free)


func _explode() -> void:
	# Trail aufräumen
	if is_instance_valid(trail):
		var tween := trail.create_tween()
		tween.tween_property(trail, "modulate:a", 0.0, 0.2)
		tween.tween_callback(trail.queue_free)
	
	queue_free()
