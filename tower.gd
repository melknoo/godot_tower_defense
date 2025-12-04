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
	
	# Nur updaten wenn bereits ready
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
		"slow":
			slow_amount = TowerData.get_stat(tower_type, "slow_amount", level)
		"burn":
			burn_damage = TowerData.get_stat(tower_type, "burn_damage", level)
		"stun":
			stun_chance = TowerData.get_stat(tower_type, "stun_chance", level)
		"chain":
			chain_targets = TowerData.get_stat(tower_type, "chain_targets", level)


func _create_visuals() -> void:
	# Turret Container
	turret = Node2D.new()
	add_child(turret)
	
	# Range Circle
	range_circle = Line2D.new()
	range_circle.default_color = Color(1, 1, 1, 0.15)
	range_circle.width = 2
	add_child(range_circle)
	
	# Level Indicator
	level_indicator = Node2D.new()
	level_indicator.position = Vector2(20, -20)
	add_child(level_indicator)


func _update_visuals() -> void:
	# Sprite laden/aktualisieren
	for child in turret.get_children():
		child.queue_free()
	
	var texture_path := "res://assets/elemental_tower/tower_%s.png" % tower_type
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.vframes = 4
		sprite.hframes = 1
		sprite.scale = Vector2(3, 3)
		turret.add_child(sprite)
		
		# Animation Timer
		var timer := Timer.new()
		timer.name = "AnimTimer"
		timer.wait_time = 0.15
		timer.autostart = true
		timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % 4)
		turret.add_child(timer)
	else:
		# Fallback Polygon
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
			Vector2(0, -25), Vector2(-20, -10)
		])
		var color: Variant = TowerData.get_stat(tower_type, "color")
		poly.color = color if color else Color.WHITE
		turret.add_child(poly)
	
	# Range Circle aktualisieren
	range_circle.clear_points()
	for i in range(33):
		var angle := i * TAU / 32
		range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
	
	# Level Indicator aktualisieren
	_update_level_indicator()


func _update_level_indicator() -> void:
	for child in level_indicator.get_children():
		child.queue_free()
	
	if level == 0:
		return
	
	# Sterne für Level anzeigen
	for i in range(level):
		var star := Label.new()
		star.text = "★"
		star.position = Vector2(i * 12, 0)
		star.add_theme_font_size_override("font_size", 10)
		star.add_theme_color_override("font_color", Color(1, 0.85, 0))
		level_indicator.add_child(star)


func _show_upgrade_effect() -> void:
	# Visueller Effekt beim Upgrade
	var flash := Sprite2D.new()
	flash.texture = sprite.texture if sprite else null
	flash.vframes = 4 if sprite else 1
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
		
		# Priorität: Gegner der am weitesten auf dem Pfad ist
		var progress: float = enemy.get_progress() if enemy.has_method("get_progress") else 0.0
		if progress > best_progress:
			best_progress = progress
			target = enemy


func _rotate_towards_target(delta: float) -> void:
	var direction := target.position - position
	var target_angle := direction.angle() + PI
	turret.rotation = lerp_angle(turret.rotation, target_angle, 10 * delta)


func _shoot() -> void:
	if not target:
		return
	
	# Bullet erstellen
	var bullet := bullet_scene.instantiate()
	bullet.position = position
	
	# Bullet Setup mit allen Effekt-Daten
	var bullet_data := {
		"target": target,
		"damage": damage,
		"splash": splash_radius,
		"type": tower_type,
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
	
	# Schuss-Effekt
	_spawn_muzzle_flash()


func _spawn_muzzle_flash() -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(0, -15), Vector2(5, 0)
	])
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
