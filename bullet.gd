# bullet.gd
# Projektil mit Spezialeffekten, Arrow-Sprite und VFX
extends Node2D
class_name Bullet

var target: Node2D
var damage := 20
var speed := 400.0
var splash_radius := 0.0
var bullet_type := "water"
var bullet_level := 0

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
var trail_timer: Timer

# Arrow spezifisch
const ARROW_FRAME_SIZE := Vector2(64, 64)


func _ready() -> void:
	_create_visuals()
	if bullet_type != "archer":
		_start_trail()


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
	bullet_level = data.get("level", 0)
	special_type = data.get("special", "")
	slow_amount = data.get("slow_amount", 0.0)
	burn_damage = data.get("burn_damage", 0)
	stun_chance = data.get("stun_chance", 0.0)
	chain_targets = data.get("chain_targets", 0)
	
	_set_speed_for_type(bullet_type)


func _set_speed_for_type(type: String) -> void:
	match type:
		"archer": speed = 450.0  # Schneller Pfeil
		"water": speed = 300.0
		"fire": speed = 150.0
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
	if bullet_type == "archer":
		_create_arrow_sprite()
	else:
		_create_standard_bullet()


func _create_arrow_sprite() -> void:
	var arrow_path := "res://assets/elemental_bullets/arrow.png"
	
	if ResourceLoader.exists(arrow_path):
		sprite = Sprite2D.new()
		sprite.texture = load(arrow_path)
		
		# Nur ersten Frame nutzen (64x64 von 64x128)
		sprite.vframes = 2
		sprite.hframes = 1
		sprite.frame = 0
		
		# Skalierung
		var desired_size := 32.0
		var scale_factor := desired_size / ARROW_FRAME_SIZE.x
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		add_child(sprite)
	else:
		# Fallback: Einfacher Pfeil als Polygon
		_create_arrow_polygon()


func _create_arrow_polygon() -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-12, -2), Vector2(8, -2),
		Vector2(8, -5), Vector2(15, 0),
		Vector2(8, 5), Vector2(8, 2),
		Vector2(-12, 2)
	])
	poly.color = Color(0.6, 0.5, 0.3)
	add_child(poly)


func _create_standard_bullet() -> void:
	var texture_path := _get_bullet_texture_path()
	
	if not ResourceLoader.exists(texture_path) and bullet_level > 0:
		texture_path = "res://assets/elemental_bullets/bullet_%s.png" % bullet_type
	
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		
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
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-6, -3), Vector2(6, -3),
			Vector2(8, 0), Vector2(6, 3), Vector2(-6, 3)
		])
		poly.color = _get_bullet_color()
		add_child(poly)


func _get_bullet_texture_path() -> String:
	if bullet_level == 0:
		return "res://assets/elemental_bullets/bullet_%s.png" % bullet_type
	else:
		var display_level := bullet_level + 1
		return "res://assets/elemental_bullets/bullet_%s_level_%d.png" % [bullet_type, display_level]


func _start_trail() -> void:
	if VFX:
		trail_timer = VFX.create_pixel_trail(self, bullet_type, 0.03)


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
		"archer": return Color(0.6, 0.5, 0.3)
		_: return Color.WHITE


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		_explode()
		return
	
	var direction := (target.position - position).normalized()
	position += direction * speed * delta
	
	# Rotation: Pfeil zeigt in Flugrichtung
	rotation = direction.angle()
	
	if position.distance_to(target.position) < 15:
		_hit_target()


func _hit_target() -> void:
	if splash_radius > 0:
		_hit_splash()
	else:
		_hit_single(target)
	
	if chain_targets > 0 and special_type == "chain":
		_do_chain_attack()
	
	_explode()


func _hit_single(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy in already_hit:
		return
	
	already_hit.append(enemy)
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, true, bullet_type)
	
	_apply_special_effects(enemy)


func _hit_splash() -> void:
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if position.distance_to(enemy.position) <= splash_radius:
			_hit_single(enemy)
			hit_count += 1
	
	if VFX:
		VFX.spawn_pixel_ring(position, bullet_type, splash_radius)
		if hit_count > 3:
			VFX.screen_shake(3.0, 0.1)


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
			if randf() < stun_chance and enemy.has_method("apply_stun"):
				enemy.apply_stun(stun_duration)
		"freeze":
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(2.0)
		"root":
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(1.5)
		"pool":
			_spawn_lava_pool()


func _do_chain_attack() -> void:
	var current := target
	var remaining := chain_targets
	var chain_dmg := damage / 2
	
	while remaining > 0 and is_instance_valid(current):
		var next: Node2D = null
		var closest := chain_range
		
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in already_hit:
				continue
			var d := current.position.distance_to(e.position)
			if d < closest:
				closest = d
				next = e
		
		if next:
			_draw_chain_lightning(current.position, next.position)
			already_hit.append(next)
			if next.has_method("take_damage"):
				next.take_damage(chain_dmg, true, "air")
			_apply_special_effects(next)
			current = next
			remaining -= 1
		else:
			break


func _draw_chain_lightning(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2
	line.default_color = Color(0.8, 0.9, 1.0)
	
	var seg := 5
	var dir := (to - from) / seg
	var perp := dir.rotated(PI/2).normalized()
	
	line.add_point(from)
	for i in range(1, seg):
		line.add_point(from + dir * i + perp * randf_range(-10, 10))
	line.add_point(to)
	
	get_parent().add_child(line)
	
	if VFX:
		VFX.spawn_pixels(to, "air", 4, 15.0)
	
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)


func _spawn_lava_pool() -> void:
	var pool := Node2D.new()
	pool.position = position
	
	var circ := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := i * TAU / 16
		pts.append(Vector2(cos(a), sin(a)) * splash_radius * randf_range(0.8, 1.0))
	circ.polygon = pts
	circ.color = Color(1.0, 0.3, 0.0, 0.6)
	pool.add_child(circ)
	
	get_parent().add_child(pool)
	
	var tmr := Timer.new()
	tmr.wait_time = 0.5
	tmr.autostart = true
	pool.add_child(tmr)
	
	var pool_dmg := burn_damage if burn_damage > 0 else 5
	tmr.timeout.connect(func():
		for e in get_tree().get_nodes_in_group("enemies"):
			if pool.position.distance_to(e.position) <= splash_radius:
				if e.has_method("take_damage"):
					e.take_damage(pool_dmg, false, "lava")
		
		if VFX and randf() > 0.5:
			VFX.spawn_pixels(pool.position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "lava", 2, 10.0)
	)
	
	var tw := pool.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(circ, "color:a", 0.0, 0.5)
	tw.tween_callback(pool.queue_free)


func _explode() -> void:
	# Archer hat subtileren Impact
	if VFX:
		if bullet_type == "archer":
			VFX.spawn_pixels(position, "archer", 3, 10.0)
		else:
			VFX.spawn_pixels(position, bullet_type, 4, 15.0)
	
	if trail_timer:
		trail_timer.queue_free()
	
	queue_free()
