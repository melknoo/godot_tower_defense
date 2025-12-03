extends Node2D
class_name Bullet

var target: Node2D
var damage := 20
var speed := 400.0
var splash_radius := 0.0
var bullet_type := "archer"

func _ready() -> void:
	var texture_path := "res://assets/elemental_bullets/bullet_" + bullet_type + ".png"
	
	if ResourceLoader.exists(texture_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		
		# Prüfen ob animiert (horizontal)
		if sprite.texture.get_width() > sprite.texture.get_height():
			# Horizontales Spritesheet (z.B. water bullet)
			var frame_count := sprite.texture.get_width() / sprite.texture.get_height()
			sprite.hframes = frame_count
			sprite.vframes = 1
			sprite.scale = Vector2(2, 2)
			add_child(sprite)
			
			# Animation Timer
			var timer := Timer.new()
			timer.wait_time = 0.1
			timer.autostart = true
			timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % frame_count)
			add_child(timer)
		else:
			# Einzelnes Bild
			sprite.scale = Vector2(2, 2)
			add_child(sprite)
	else:
		# Fallback: Farbiges Polygon
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4),
			Vector2(4, 4), Vector2(-4, 4)
		])
		match bullet_type:
			"archer": poly.color = Color(0.5, 1, 0.5)
			"cannon": poly.color = Color(1, 0.5, 0.2)
			"sniper": poly.color = Color(0.5, 0.5, 1)
			"water": poly.color = Color(0.3, 0.6, 1.0)
			"fire": poly.color = Color(0.3, 0.6, 1.0)
			"air": poly.color = Color(0.3, 0.6, 1.0)
			"earth": poly.color = Color(0.3, 0.6, 1.0)
		add_child(poly)

func setup(t: Node2D, dmg: int, splash: float, type: String) -> void:
	target = t
	damage = dmg
	splash_radius = splash
	bullet_type = type
	
	match type:
		"sniper": speed = 600.0
		"cannon": speed = 300.0
		"water": speed = 150.0
		"fire": speed = 150.0
		"air": speed = 150.0
		"earth": speed = 150.0

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	
	var direction := (target.position - position).normalized()
	position += direction * speed * delta
	rotation = direction.angle()+PI
	
	if position.distance_to(target.position) < 15:
		hit_target()

func hit_target() -> void:
	if splash_radius > 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if position.distance_to(enemy.position) <= splash_radius:
				enemy.take_damage(damage)
		spawn_explosion()
	else:
		if is_instance_valid(target):
			target.take_damage(damage)
	queue_free()

func spawn_explosion() -> void:
	var explosion := Node2D.new()
	explosion.position = position
	
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(32):
		var angle := i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * splash_radius)
	circle.polygon = points
	circle.color = Color(1, 0.5, 0, 0.5)
	explosion.add_child(circle)
	
	get_parent().add_child(explosion)
	
	var tween := explosion.create_tween()
	tween.tween_property(circle, "color", Color(1, 0.5, 0, 0), 0.3)
	tween.tween_callback(explosion.queue_free)
