extends Node2D
class_name Enemy

# Keine Signals mehr nötig - GameState wird direkt verwendet

var path: Array[Vector2] = []
var path_index := 0
var health := 100
var max_health := 100
var speed := 80.0
var reward := 10

var health_bar: Line2D


func _ready() -> void:
	add_to_group("enemies")
	
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/enemy.png")
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	
	health_bar = Line2D.new()
	health_bar.add_point(Vector2(-15, -22))
	health_bar.add_point(Vector2(15, -22))
	health_bar.default_color = Color(0, 1, 0)
	health_bar.width = 4
	add_child(health_bar)


func setup(path_points: Array[Vector2], hp: int, spd: float) -> void:
	path = path_points
	health = hp
	max_health = hp
	speed = spd
	position = path[0]

func setup_extended(path_points: Array[Vector2], data: Dictionary) -> void:
	path = path_points
	health = data["health"]
	max_health = health
	speed = data["speed"]
	reward = data["reward"]
	position = path[0]
	# Optional: Farbe/Scale anpassen
	modulate = data.get("color", Color.WHITE)
	scale = Vector2.ONE * data.get("scale", 0.5)


func _process(delta: float) -> void:
	if path_index >= path.size():
		GameState.enemy_reached_end()
		queue_free()
		return
	
	var target_pos := path[path_index]
	var direction := (target_pos - position).normalized()
	position += direction * speed * delta
	
	if position.distance_to(target_pos) < 5:
		path_index += 1
	
	update_health_bar()


func take_damage(amount: int) -> void:
	health -= amount
	GameState.record_damage(amount)
	
	if health <= 0:
		GameState.enemy_died(reward)
		queue_free()


func update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, -22))
	health_bar.default_color = Color(1 - health_percent, health_percent, 0)
