# tower.gd
# Tower mit Upgrades und Spezialeffekten
extends Node2D
class_name Tower

var tower_type := "water"
var tower_range := 150.0
var fire_rate := 1.0
var damage := 20
var splash_radius := 0.0
var level := 0

# Spezialeffekte
var special_type := ""
var slow_amount := 0.0
var burn_damage := 0
var stun_chance := 0.0
var chain_targets := 0

var bullet_scene: PackedScene
var fire_timer := 0.0
var target: Node2D = null

# Visuals
var range_circle: Line2D
var turret: Node2D
var sprite: Sprite2D
var level_indicator: Node2D


func _ready() -> void:
	bullet_scene = preload("res://bullet.tscn")
	_create_visuals()
	_update_visuals()


func setup(data: Dictionary, type: String) -> void:
	tower_type = type
	tower_range = data.get("range", 150.0)
	fire_rate = data.get("fire_rate", 1.0)
	damage = data.get("damage", 20)
	splash_radius = data.get("splash", 0.0)
	
	_load_special_effects()
	
	if is_inside_tree():
		_update_visuals()


func upgrade(data: Dictionary, new_level: int) -> void:
	level = new_level
	tower_range = data.get("range", tower_range)
	fire_rate = data.get("fire_rate", fire_rate)
	damage = data.get("damage", damage)
	splash_radius = data.get("splash", splash_radius)
	
	_load_special_effects()
	
	if is_inside_tree():
		_update_visuals()
		_show_upgrade_effect()


func _load_special_effects() -> void:
	special_type = TowerData.get_stat(tower_type, "special")
	if special_type == null:
		special_type = ""
	
	match special_type:
		"slow": slow_amount = TowerData.get_stat(tower_type, "slow_amount", level)
		"burn": burn_damage = TowerData.get_stat(tower_type, "burn_damage", level)
		"stun": stun_chance = TowerData.get_stat(tower_type, "stun_chance", level)
		"chain": chain_targets = TowerData.get_stat(tower_type, "chain_targets", level)


func _create_visuals() -> void:
	turret = Node2D.new()
	add_child(turret)
	
	range_circle = Line2D.new()
	range_circle.default_color = Color(1, 1, 1, 0.15)
	range_circle.width = 2
	add_child(range_circle)
	
	level_indicator = Node2D.new()
	level_indicator.position = Vector2(20, -20)
	add_child(level_indicator)


func _get_tower_texture_path() -> String:
	if level == 0:
		return "res://assets/elemental_tower/tower_%s.png" % tower_type
	else:
		var display_level := level + 1
		return "res://assets/elemental_tower/tower_%s_level_%d.png" % [tower_type, display_level]


func _update_visuals() -> void:
	for child in turret.get_children():
		child.queue_free()
	
	var texture_path := _get_tower_texture_path()
	
	if not ResourceLoader.exists(texture_path) and level > 0:
		texture_path = "res://assets/elemental_tower/tower_%s.png" % tower_type
		print("[Tower] Level-Sprite nicht gefunden, nutze Basis: %s" % texture_path)
	
	var data := TowerData.get_tower_data(tower_type)
	var is_animated: bool = data.get("animated", true)
	
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		
		if is_animated:
			sprite.vframes = 4
			sprite.hframes = 1
			sprite.scale = Vector2(3, 3)
			
			var timer := Timer.new()
			timer.name = "AnimTimer"
			timer.wait_time = 0.15
			timer.autostart = true
			timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % 4)
			turret.add_child(timer)
		else:
			sprite.vframes = 1
			sprite.hframes = 1
			sprite.scale = Vector2(1, 1)
		
		turret.add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
			Vector2(0, -25), Vector2(-20, -10)
		])
		var color: Variant = TowerData.get_stat(tower_type, "color")
		poly.color = color if color else Color.WHITE
		turret.add_child(poly)
	
	range_circle.clear_points()
	for i in range(33):
		var angle := i * TAU / 32
		range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
	
	_update_level_indicator()


func _update_level_indicator() -> void:
	for child in level_indicator.get_children():
		child.queue_free()
	
	if level == 0:
		return
	
	for i in range(level):
		var star := Label.new()
		star.text = "★"
		star.position = Vector2(i * 12, 0)
		star.add_theme_font_size_override("font_size", 10)
		star.add_theme_color_override("font_color", Color(1, 0.85, 0))
		level_indicator.add_child(star)


func _show_upgrade_effect() -> void:
	if not sprite:
		return
	
	var flash := Sprite2D.new()
	flash.texture = sprite.texture
	flash.vframes = 4
	flash.scale = Vector2(3.5, 3.5)
	flash.modulate = Color(1, 1, 1, 0.8)
	turret.add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(5, 5), 0.3)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _process(delta: float) -> void:
	fire_timer -= delta
	_find_target()
	
	if target:
		_rotate_towards_target(delta)
		if fire_timer <= 0:
			_shoot()
			fire_timer = fire_rate


func _find_target() -> void:
	target = null
	var best_progress := -1.0
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := position.distance_to(enemy.position)
		if dist > tower_range:
			continue
		
		var progress: float = enemy.get_progress() if enemy.has_method("get_progress") else 0.0
		if progress > best_progress:
			best_progress = progress
			target = enemy


func _rotate_towards_target(delta: float) -> void:
	var data := TowerData.get_tower_data(tower_type)
	if data.get("animated", true) == false:
		return  # Keine Rotation für statische Tower
	
	var direction := target.position - position
	
	# Ziel links oder rechts vom Tower?
	var is_facing_left := direction.x < 0
	
	# Sprite horizontal spiegeln wenn Ziel links ist
	if sprite:
		sprite.flip_h = is_facing_left
	
	# Rotation berechnen - X immer positiv behandeln
	# Dadurch dreht sich der Turret max 90° nach oben/unten
	var adjusted_direction := Vector2(abs(direction.x), direction.y)
	var target_angle := adjusted_direction.angle() + TAU
	
	turret.rotation = lerp_angle(turret.rotation, target_angle, 10 * delta)


func _shoot() -> void:
	if not target:
		return
	
	var bullet := bullet_scene.instantiate()
	bullet.position = position
	
	var bullet_data := {
		"target": target,
		"damage": damage,
		"splash": splash_radius,
		"type": tower_type,
		"level": level,
		"special": special_type,
		"slow_amount": slow_amount,
		"burn_damage": burn_damage,
		"stun_chance": stun_chance,
		"chain_targets": chain_targets
	}
	
	if bullet.has_method("setup_extended"):
		bullet.setup_extended(bullet_data)
	else:
		bullet.setup(target, damage, splash_radius, tower_type)
	
	get_parent().add_child(bullet)
	_spawn_muzzle_flash()


func _spawn_muzzle_flash() -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -15), Vector2(5, 0)])
	flash.color = _get_muzzle_color()
	flash.rotation = turret.rotation - PI/2
	flash.position = Vector2(0, -20).rotated(turret.rotation)
	add_child(flash)
	
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)


func _get_muzzle_color() -> Color:
	match tower_type:
		"water": return Color(0.3, 0.6, 1.0)
		"fire": return Color(1.0, 0.5, 0.2)
		"earth": return Color(0.6, 0.4, 0.2)
		"air": return Color(0.9, 0.95, 1.0)
		"steam": return Color(0.8, 0.8, 0.9)
		"ice": return Color(0.7, 0.9, 1.0)
		"lava": return Color(1.0, 0.3, 0.0)
		"nature": return Color(0.3, 0.8, 0.2)
		_: return Color.WHITE
