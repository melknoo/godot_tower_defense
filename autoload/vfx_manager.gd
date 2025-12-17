# vfx_manager.gd
# Autoload für Pixel-Art-freundliche visuelle Effekte
extends Node

const PALETTES := {
	"water": [Color(0.2, 0.4, 0.8), Color(0.3, 0.6, 1.0), Color(0.6, 0.8, 1.0)],
	"fire": [Color(0.8, 0.2, 0.0), Color(1.0, 0.5, 0.1), Color(1.0, 0.9, 0.3)],
	"earth": [Color(0.3, 0.2, 0.1), Color(0.6, 0.4, 0.2), Color(0.8, 0.7, 0.5)],
	"air": [Color(0.7, 0.8, 0.9), Color(0.85, 0.9, 0.95), Color(1.0, 1.0, 1.0)],
	"ice": [Color(0.4, 0.6, 0.8), Color(0.6, 0.85, 0.95), Color(0.9, 0.95, 1.0)],
	"lava": [Color(0.6, 0.1, 0.0), Color(1.0, 0.4, 0.0), Color(1.0, 0.8, 0.2)],
	"nature": [Color(0.1, 0.4, 0.1), Color(0.3, 0.7, 0.2), Color(0.6, 0.9, 0.3)],
	"steam": [Color(0.5, 0.5, 0.6), Color(0.7, 0.7, 0.8), Color(0.9, 0.9, 0.95)],
	"damage": [Color(1.0, 0.2, 0.2), Color(1.0, 0.5, 0.3), Color(1.0, 0.8, 0.6)],
	"gold": [Color(0.7, 0.5, 0.1), Color(1.0, 0.8, 0.2), Color(1.0, 0.95, 0.6)],
	"crit": [Color(1.0, 0.1, 0.1), Color(1.0, 0.4, 0.1), Color(1.0, 1.0, 0.3)],
	"archer": [Color(0.4, 0.7, 0.7), Color(0.55, 0.85, 0.8), Color(0.7, 0.95, 0.9)],
	"sword": [Color(0.6, 0.6, 0.65), Color(0.8, 0.8, 0.85), Color(1.0, 1.0, 1.0)],
}


func _ready() -> void:
	print("[VFX] Manager geladen")


# === MELEE EFFECTS ===

func spawn_cleave_effect(pos: Vector2, radius: float, element: String) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES.get(element, PALETTES["sword"])
	
	# Äußerer Schwung-Ring
	var arc := Line2D.new()
	arc.width = 4
	arc.default_color = colors[2]
	arc.position = pos
	
	var segments := 24
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		var point := Vector2(cos(angle), sin(angle)) * radius
		arc.add_point(point)
	
	parent.add_child(arc)
	
	var tween := arc.create_tween()
	tween.set_parallel(true)
	tween.tween_property(arc, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(arc, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(arc.queue_free)
	
	# Innerer Ring
	var inner_arc := Line2D.new()
	inner_arc.width = 2
	inner_arc.default_color = colors[1]
	inner_arc.position = pos
	
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		var point := Vector2(cos(angle), sin(angle)) * (radius * 0.6)
		inner_arc.add_point(point)
	
	parent.add_child(inner_arc)
	
	var inner_tween := inner_arc.create_tween()
	inner_tween.set_parallel(true)
	inner_tween.tween_property(inner_arc, "scale", Vector2(1.5, 1.5), 0.12)
	inner_tween.tween_property(inner_arc, "modulate:a", 0.0, 0.15)
	inner_tween.chain().tween_callback(inner_arc.queue_free)
	
	# Funken am Rand
	for i in range(8):
		var angle := randf() * TAU
		var spark_pos := pos + Vector2(cos(angle), sin(angle)) * radius
		var spark := _create_pixel(colors[randi() % colors.size()], 3)
		spark.position = spark_pos
		parent.add_child(spark)
		
		var outward := Vector2(cos(angle), sin(angle)) * randf_range(20, 40)
		var spark_tween := spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", spark_pos + outward, 0.2)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.25)
		spark_tween.chain().tween_callback(spark.queue_free)


func spawn_melee_hit_sparks(pos: Vector2, hit_count: int, element: String) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES.get(element, PALETTES["sword"])
	var spark_count := mini(hit_count * 3, 15)
	
	for i in range(spark_count):
		var pixel := _create_pixel(colors[randi() % colors.size()], randi_range(2, 4))
		pixel.position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		parent.add_child(pixel)
		
		var angle := randf() * TAU
		var speed := randf_range(60, 120)
		var target_pos := pixel.position + Vector2(cos(angle), sin(angle)) * speed * 0.3
		
		var tween := pixel.create_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(pixel.queue_free)
	
	# Impact Flash
	var flash := _create_pixel(Color.WHITE, 12)
	flash.position = pos
	flash.modulate.a = 0.7
	parent.add_child(flash)
	
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(0.2, 0.2), 0.1)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(flash.queue_free)


# === PIXEL PARTICLES ===

func spawn_pixels(pos: Vector2, element: String, count: int = 8, spread: float = 30.0) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var colors: Array = PALETTES.get(element, PALETTES["damage"])
	for i in range(count):
		var pixel := _create_pixel(colors[randi() % colors.size()])
		pixel.position = pos
		parent.add_child(pixel)
		var angle := randf() * TAU
		var dist := randf_range(spread * 0.5, spread)
		var target := pos + Vector2(cos(angle), sin(angle)) * dist
		var tween := pixel.create_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "position", target, randf_range(0.2, 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pixel, "modulate:a", 0.0, randf_range(0.3, 0.5)).set_delay(0.1)
		tween.chain().tween_callback(pixel.queue_free)


func spawn_pixel_burst(pos: Vector2, element: String, count: int = 12) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var colors: Array = PALETTES.get(element, PALETTES["damage"])
	for i in range(count):
		var pixel := _create_pixel(colors[randi() % colors.size()], randi_range(3, 5))
		pixel.position = pos
		parent.add_child(pixel)
		var angle := (float(i) / count) * TAU + randf_range(-0.2, 0.2)
		var speed := randf_range(80, 150)
		var gravity := randf_range(200, 400)
		_animate_pixel_physics(pixel, angle, speed, gravity)


func spawn_pixel_ring(pos: Vector2, element: String, radius: float = 40.0) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var colors: Array = PALETTES.get(element, PALETTES["damage"])
	var segments := 16
	for i in range(segments):
		var pixel := _create_pixel(colors[1], 4)
		pixel.position = pos
		pixel.modulate.a = 0.8
		parent.add_child(pixel)
		var angle := (float(i) / segments) * TAU
		var target := pos + Vector2(cos(angle), sin(angle)) * radius
		var tween := pixel.create_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pixel, "modulate:a", 0.0, 0.3).set_delay(0.15)
		tween.chain().tween_callback(pixel.queue_free)


# === MUZZLE FLASH ===

func spawn_muzzle_flash(pos: Vector2, direction: Vector2, element: String) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var colors: Array = PALETTES.get(element, PALETTES["fire"])
	var flash := _create_pixel(colors[2], 6)
	flash.position = pos
	parent.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(0.2, 0.2), 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)
	for i in range(4):
		var spark := _create_pixel(colors[randi() % colors.size()], 2)
		spark.position = pos
		parent.add_child(spark)
		var spread := direction.rotated(randf_range(-0.4, 0.4))
		var target := pos + spread * randf_range(15, 30)
		var spark_tween := spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", target, 0.15)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		spark_tween.chain().tween_callback(spark.queue_free)


# === IMPACT EFFECTS ===

func spawn_hit_effect(pos: Vector2, element: String, is_crit: bool = false) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	if is_crit:
		spawn_pixel_burst(pos, "crit", 16)
		spawn_pixel_ring(pos, element, 50.0)
	else:
		spawn_pixels(pos, element, 6, 20.0)
	var flash := _create_pixel(Color.WHITE, 8)
	flash.position = pos
	flash.modulate.a = 0.9
	parent.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(0.1, 0.1), 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(flash.queue_free)


func spawn_death_effect(pos: Vector2, enemy_type: String = "normal") -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var color := _get_enemy_color(enemy_type)
	var count := 12 if enemy_type == "boss" else 8
	for i in range(count):
		var pixel := _create_pixel(color.lerp(Color.WHITE, randf() * 0.3), randi_range(3, 6))
		pixel.position = pos
		parent.add_child(pixel)
		var angle := randf() * TAU
		var speed := randf_range(100, 200)
		var gravity := randf_range(300, 500)
		_animate_pixel_physics(pixel, angle, speed, gravity)
	for i in range(4):
		var soul := _create_pixel(Color(1, 1, 1, 0.6), 3)
		soul.position = pos + Vector2(randf_range(-10, 10), 0)
		parent.add_child(soul)
		var target := soul.position + Vector2(randf_range(-20, 20), -50)
		var tween := soul.create_tween()
		tween.set_parallel(true)
		tween.tween_property(soul, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(soul, "modulate:a", 0.0, 0.8)
		tween.chain().tween_callback(soul.queue_free)


# === TOWER EFFECTS ===

func spawn_place_effect(pos: Vector2, element: String) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	spawn_pixel_ring(pos + Vector2(0, 20), "earth", 35.0)
	spawn_pixels(pos, element, 10, 40.0)
	var colors: Array = PALETTES.get(element, PALETTES["gold"])
	for i in range(6):
		var shimmer := _create_pixel(colors[2], 2)
		shimmer.position = pos + Vector2(randf_range(-20, 20), 20)
		shimmer.modulate.a = 0.7
		parent.add_child(shimmer)
		var target := shimmer.position + Vector2(randf_range(-10, 10), -40)
		var tween := shimmer.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shimmer, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shimmer, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(shimmer.queue_free)


func spawn_upgrade_effect(pos: Vector2, element: String, new_level: int) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	for i in range(new_level + 1):
		await parent.get_tree().create_timer(0.1 * i).timeout
		spawn_pixel_ring(pos, element, 30.0 + i * 15.0)
	spawn_pixel_burst(pos, "gold", 8)


func spawn_sell_effect(pos: Vector2) -> void:
	spawn_pixels(pos, "gold", 12, 40.0)
	spawn_pixel_ring(pos, "gold", 45.0)


# === DAMAGE NUMBERS ===

func spawn_damage_number(pos: Vector2, amount: int, is_crit: bool = false, element: String = "") -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var label := Label.new()
	label.text = str(amount)
	label.position = pos + Vector2(randf_range(-12, 12), -25)
	label.z_index = 100
	if UITheme and UITheme.game_font:
		label.add_theme_font_override("font", UITheme.game_font)
	var size := 18 if is_crit else 13
	label.add_theme_font_size_override("font_size", size)
	var color := Color(1.0, 1.0, 1.0)
	if is_crit:
		color = Color(1.0, 0.9, 0.2)
	elif element != "" and PALETTES.has(element):
		color = PALETTES[element][2]
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	var start_y := label.position.y
	var peak_y := start_y - (35 if is_crit else 22)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", peak_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", start_y + 5, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.15).set_delay(0.3)
	tween.tween_callback(label.queue_free)
	if is_crit:
		label.pivot_offset = Vector2(15, 10)
		label.scale = Vector2(1.6, 1.6)
		var scale_tween := label.create_tween()
		scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)


func spawn_gold_number(pos: Vector2, amount: int) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	var label := Label.new()
	label.text = "+%d" % amount
	label.position = pos + Vector2(-15, -30)
	label.z_index = 100
	if UITheme and UITheme.game_font:
		label.add_theme_font_override("font", UITheme.game_font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.25, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	var start_y := label.position.y
	var peak_y := start_y - 35
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", peak_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", start_y - 20, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)
	label.pivot_offset = Vector2(20, 10)
	label.scale = Vector2(1.3, 1.3)
	var scale_tween := label.create_tween()
	scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)


# === SCREEN EFFECTS ===

func screen_shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	var camera := _get_camera()
	if not camera:
		return
	var original_offset := camera.offset
	var shake_tween := camera.create_tween()
	var steps := int(duration / 0.02)
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera, "offset", original_offset + offset, 0.02)
	shake_tween.tween_property(camera, "offset", original_offset, 0.02)


func screen_flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	var canvas := _get_canvas_layer()
	if not canvas:
		return
	var flash := ColorRect.new()
	flash.color = color
	flash.color.a = 0.3
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)


# === TRAIL EFFECTS ===

func create_pixel_trail(node: Node2D, element: String, interval: float = 0.05) -> Timer:
	var timer := Timer.new()
	timer.wait_time = interval
	timer.autostart = true
	node.add_child(timer)
	var colors: Array = PALETTES.get(element, PALETTES["damage"])
	timer.timeout.connect(func():
		if not is_instance_valid(node):
			timer.queue_free()
			return
		var parent := _get_vfx_parent()
		if not parent:
			return
		var pixel := _create_pixel(colors[randi() % colors.size()], 2)
		pixel.position = node.global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		pixel.modulate.a = 0.6
		parent.add_child(pixel)
		var tween := pixel.create_tween()
		tween.tween_property(pixel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(pixel.queue_free)
	)
	return timer


# === HELPERS ===

func _create_pixel(color: Color, size: int = 4) -> Polygon2D:
	var pixel := Polygon2D.new()
	var half := size / 2.0
	pixel.polygon = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)
	])
	pixel.color = color
	return pixel


func _animate_pixel_physics(pixel: Polygon2D, angle: float, speed: float, gravity: float) -> void:
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	var lifetime := randf_range(0.4, 0.7)
	var elapsed := 0.0
	var tween := pixel.create_tween()
	tween.set_loops(int(lifetime / 0.016))
	tween.tween_callback(func():
		elapsed += 0.016
		velocity.y += gravity * 0.016
		pixel.position += velocity * 0.016
		pixel.modulate.a = 1.0 - (elapsed / lifetime)
	).set_delay(0.016)
	tween.chain().tween_callback(pixel.queue_free)


func _get_enemy_color(enemy_type: String) -> Color:
	match enemy_type:
		"normal": return Color(0.8, 0.3, 0.3)
		"fast": return Color(0.3, 0.8, 0.3)
		"tank": return Color(0.4, 0.4, 0.8)
		"boss": return Color(0.8, 0.3, 0.8)
		_: return Color(0.8, 0.3, 0.3)


func _get_vfx_parent() -> Node:
	var main := get_tree().current_scene
	if main:
		var vfx_layer := main.get_node_or_null("VFXLayer")
		if vfx_layer:
			return vfx_layer
		return main
	return null


func _get_camera() -> Camera2D:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_camera_2d()
	return null


func _get_canvas_layer() -> CanvasLayer:
	var main := get_tree().current_scene
	if main:
		var ui := main.get_node_or_null("UI")
		if ui and ui is CanvasLayer:
			return ui
	return null
