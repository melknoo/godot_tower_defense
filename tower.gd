extends Node2D
class_name Tower

var tower_type := "archer"
var tower_range := 150.0
var fire_rate := 0.8
var damage := 20
var splash_radius := 0.0

var bullet_scene: PackedScene
var fire_timer := 0.0
var target: Node2D = null
var range_circle: Line2D

# Node für den drehbaren Teil des Turms
var turret: Node2D

func setup(data: Dictionary, type: String) -> void:
	tower_type = type
	tower_range = data["range"]
	fire_rate = data["fire_rate"]
	damage = data["damage"]
	splash_radius = data["splash"]

func _ready() -> void:
	bullet_scene = preload("res://bullet.tscn")
	
	# Turret-Node für Rotation erstellen
	turret = Node2D.new()
	add_child(turret)
	
	# Sprite laden basierend auf Turmtyp
	var sprite := Sprite2D.new()
	var texture_path := "res://assets/tower_" + tower_type + ".png"
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(0.5, 0.5)
		turret.add_child(sprite)
	else:
		# Fallback: Farbiges Polygon
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
			Vector2(0, -25), Vector2(-20, -10)
		])
		match tower_type:
			"archer": poly.color = Color(0.2, 0.7, 0.3)
			"cannon": poly.color = Color(0.7, 0.4, 0.2)
			"sniper": poly.color = Color(0.3, 0.3, 0.8)
		turret.add_child(poly)
	
	# Reichweite-Kreis (dreht sich nicht mit)
	range_circle = Line2D.new()
	for i in range(33):
		var angle := i * TAU / 32
		range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
	range_circle.default_color = Color(1, 1, 1, 0.15)
	range_circle.width = 2
	add_child(range_circle)

func _process(delta: float) -> void:
	fire_timer -= delta
	find_target()
	
	# Turm zum Ziel drehen
	if target:
		var direction := target.position - position
		var target_angle := direction.angle()
		turret.rotation = lerp_angle(turret.rotation, target_angle, 10 * delta)
	
	if target and fire_timer <= 0:
		shoot()
		fire_timer = fire_rate

func find_target() -> void:
	target = null
	var closest_dist := tower_range
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := position.distance_to(enemy.position)
		if dist < closest_dist:
			closest_dist = dist
			target = enemy

func shoot() -> void:
	if not target: return
	
	var bullet := bullet_scene.instantiate()
	bullet.position = position
	bullet.setup(target, damage, splash_radius, tower_type)
	get_parent().add_child(bullet)
