# item_drop.gd
# Visuelles Item auf dem Boden das eingesammelt werden kann
extends Node2D
class_name ItemDrop

signal collected(item: Dictionary)

var item_data: Dictionary = {}
var is_collected := false

var sprite: Sprite2D
var glow: Sprite2D
var rarity_ring: Line2D
var label: Label
var pickup_area: Area2D

var bob_time := 0.0
var bob_speed := 3.0
var bob_height := 4.0
var base_y := 0.0

var spawn_tween: Tween
var glow_tween: Tween

const PICKUP_RANGE := 40.0
const DESPAWN_TIME := 30.0  # Sekunden bis Item verschwindet


func _ready() -> void:
	add_to_group("item_drops")
	_create_visuals()
	_start_despawn_timer()


func setup(data: Dictionary) -> void:
	item_data = data
	base_y = position.y
	_update_visuals()
	_play_spawn_animation()


func _create_visuals() -> void:
	# Glow hinter dem Item
	glow = Sprite2D.new()
	glow.z_index = -1
	add_child(glow)
	
	# Rarity Ring
	rarity_ring = Line2D.new()
	rarity_ring.width = 2
	rarity_ring.z_index = -1
	var pts := 17
	for i in range(pts):
		var a := float(i) / (pts - 1) * TAU
		rarity_ring.add_point(Vector2(cos(a), sin(a)) * 14)
	add_child(rarity_ring)
	
	# Item Sprite
	sprite = Sprite2D.new()
	sprite.scale = Vector2(2.5, 2.5)  # 16x16 -> 40x40
	add_child(sprite)
	
	# Item Name Label
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -45)
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	label.visible = false  # Nur bei Hover
	add_child(label)
	
	# Pickup Area
	pickup_area = Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = PICKUP_RANGE
	collision.shape = shape
	pickup_area.add_child(collision)
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 0
	add_child(pickup_area)


func _update_visuals() -> void:
	if item_data.is_empty():
		return
	
	var rarity_color: Color = item_data.get("color", Color.WHITE)
	
	# Sprite aus ItemSystem
	if ItemSystem:
		var tex := ItemSystem.get_item_texture(item_data)
		if tex:
			sprite.texture = tex
	
	# Fallback wenn keine Textur
	if not sprite.texture:
		_create_fallback_sprite()
	
	# Ring-Farbe
	rarity_ring.default_color = rarity_color
	rarity_ring.default_color.a = 0.6
	
	# Glow basierend auf Rarity
	_create_glow(rarity_color)
	
	# Label
	label.text = item_data.get("name", "Item")
	label.add_theme_color_override("font_color", rarity_color)


func _create_fallback_sprite() -> void:
	# Polygon als Fallback
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	var cat: String = item_data.get("category", "")
	match cat:
		"weapon": poly.color = Color(0.8, 0.3, 0.3)
		"accessory": poly.color = Color(0.3, 0.6, 0.8)
		"elemental": poly.color = Color(0.5, 0.3, 0.8)
		"special": poly.color = Color(0.9, 0.7, 0.2)
		_: poly.color = Color(0.6, 0.6, 0.6)
	sprite.add_child(poly)


func _create_glow(color: Color) -> void:
	# Einfacher Glow-Effekt mit Polygon
	var glow_poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var size := 20.0
	for i in range(8):
		var a := float(i) / 8 * TAU
		pts.append(Vector2(cos(a), sin(a)) * size)
	glow_poly.polygon = pts
	glow_poly.color = color
	glow_poly.color.a = 0.3
	glow.add_child(glow_poly)
	
	# Pulsierender Glow
	if glow_tween:
		glow_tween.kill()
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.8).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)


func _play_spawn_animation() -> void:
	# Item "springt" aus dem Boden
	var target_y := base_y
	position.y = base_y + 20
	scale = Vector2(0.3, 0.3)
	modulate.a = 0
	
	spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(self, "position:y", target_y - 15, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
	spawn_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
	spawn_tween.chain().set_parallel(true)
	spawn_tween.tween_property(self, "position:y", target_y, 0.15).set_trans(Tween.TRANS_BOUNCE)
	spawn_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Partikel
	if VFX:
		var color: Color = item_data.get("color", Color.WHITE)
		VFX.spawn_pixels(position, _get_vfx_element(), 8, 25.0)


func _get_vfx_element() -> String:
	var elem: String = item_data.get("element", "")
	if elem != "":
		return elem
	var cat: String = item_data.get("category", "")
	match cat:
		"weapon": return "fire"
		"accessory": return "air"
		"elemental": return item_data.get("element", "water")
		"special": return "gold"
	return "damage"


func _start_despawn_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = DESPAWN_TIME
	timer.one_shot = true
	timer.timeout.connect(_on_despawn)
	add_child(timer)
	timer.start()
	
	# Warnung kurz vor Despawn
	var warn_timer := Timer.new()
	warn_timer.wait_time = DESPAWN_TIME - 5.0
	warn_timer.one_shot = true
	warn_timer.timeout.connect(_start_despawn_warning)
	add_child(warn_timer)
	warn_timer.start()


func _start_despawn_warning() -> void:
	# Blinken vor dem Verschwinden
	var blink := create_tween().set_loops(10)
	blink.tween_property(self, "modulate:a", 0.3, 0.25)
	blink.tween_property(self, "modulate:a", 1.0, 0.25)


func _on_despawn() -> void:
	if is_collected:
		return
	
	# Verschwinden Animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Bobbing Animation
	bob_time += delta * bob_speed
	position.y = base_y + sin(bob_time) * bob_height
	
	# Leichte Rotation
	sprite.rotation = sin(bob_time * 0.7) * 0.1


func _input(event: InputEvent) -> void:
	if is_collected:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		if position.distance_to(mouse_pos) <= PICKUP_RANGE:
			try_collect()


func try_collect() -> bool:
	if is_collected:
		return false
	
	if not ItemSystem:
		return false
	
	if ItemSystem.collect_item(item_data):
		_play_collect_animation()
		return true
	else:
		# Inventar voll
		_show_inventory_full_message()
		return false


func _play_collect_animation() -> void:
	is_collected = true
	
	if glow_tween:
		glow_tween.kill()
	
	Sound.play_coin()
	
	if VFX:
		VFX.spawn_pixel_burst(position, _get_vfx_element(), 12)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
	
	collected.emit(item_data)


func _show_inventory_full_message() -> void:
	Sound.play_error()
	
	var msg := Label.new()
	msg.text = "Inventar voll!"
	msg.position = Vector2(-40, -60)
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	msg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	msg.add_theme_constant_override("outline_size", 2)
	add_child(msg)
	
	var tween := msg.create_tween()
	tween.tween_property(msg, "position:y", msg.position.y - 20, 1.0)
	tween.parallel().tween_property(msg, "modulate:a", 0.0, 1.0)
	tween.tween_callback(msg.queue_free)


# Hover Detection
func _on_mouse_entered() -> void:
	label.visible = true
	
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.1)


func _on_mouse_exited() -> void:
	label.visible = false
	
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(2.5, 2.5), 0.1)


func _mouse_entered():
	_on_mouse_entered()

func _mouse_exited():
	_on_mouse_exited()
