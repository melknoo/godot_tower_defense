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
	var label := RichTextLabel.new()
	label.name = "CostLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(60, 20)
	#var label := Label.new()
	label.text = "+%d%s"  % [amount, IconSystem.bb("coin", 16)]
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


func spawn_lightning_strike(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["air"]
	
	# Blitz-Linie mit Zacken
	var lightning := Line2D.new()
	lightning.width = 4
	lightning.default_color = colors[2]
	lightning.position = Vector2.ZERO
	
	_generate_lightning_points(lightning, from_pos, to_pos, 8)
	parent.add_child(lightning)
	
	# Glow-Linie dahinter
	var glow := Line2D.new()
	glow.width = 12
	glow.default_color = Color(colors[1].r, colors[1].g, colors[1].b, 0.4)
	glow.points = lightning.points
	parent.add_child(glow)
	glow.z_index = -1
	
	# Impact-Effekt am Ziel
	spawn_pixel_burst(to_pos, "air", 12)
	spawn_pixel_ring(to_pos, "air", 30.0)
	
	# Flash am Start
	var flash := _create_pixel(Color.WHITE, 16)
	flash.position = from_pos
	parent.add_child(flash)
	
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	flash_tween.tween_callback(flash.queue_free)
	
	# Lightning fadeout
	var tween := lightning.create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.25)
	tween.tween_callback(lightning.queue_free)
	tween.tween_callback(glow.queue_free)


func spawn_lightning_chain(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["air"]
	
	# Dünnerer Chain-Blitz
	var chain := Line2D.new()
	chain.width = 2
	chain.default_color = colors[1]
	
	_generate_lightning_points(chain, from_pos, to_pos, 5)
	parent.add_child(chain)
	
	# Kleiner Impact
	spawn_pixels(to_pos, "air", 4, 15.0)
	
	var tween := chain.create_tween()
	tween.tween_property(chain, "modulate:a", 0.0, 0.15)
	tween.tween_callback(chain.queue_free)


func _generate_lightning_points(line: Line2D, from: Vector2, to: Vector2, segments: int) -> void:
	var direction := (to - from).normalized()
	var distance := from.distance_to(to)
	var perpendicular := direction.rotated(PI / 2)
	
	line.add_point(from)
	
	for i in range(1, segments):
		var t := float(i) / segments
		var base_pos := from.lerp(to, t)
		var offset: Vector2 = perpendicular * randf_range(-12, 12) * (1.0 - abs(t - 0.5) * 2)
		line.add_point(base_pos + offset)
	
	line.add_point(to)


# === FROST NOVA ===

func spawn_frost_nova(pos: Vector2, radius: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["ice"]
	
	# Expandierender Eisring
	var ring := Line2D.new()
	ring.width = 6
	ring.default_color = colors[1]
	ring.position = pos
	
	var segments := 32
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		ring.add_point(Vector2(cos(angle), sin(angle)) * 10)
	
	parent.add_child(ring)
	
	# Ring expandieren
	var tween := ring.create_tween()
	tween.tween_method(func(scale_val: float):
		ring.clear_points()
		for i in range(segments + 1):
			var angle := (float(i) / segments) * TAU
			ring.add_point(Vector2(cos(angle), sin(angle)) * scale_val)
	, 10.0, radius, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)
	
	# Innerer Flash
	var flash := _create_pixel(colors[2], 20)
	flash.position = pos
	flash.modulate.a = 0.8
	parent.add_child(flash)
	
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(radius / 10, radius / 10), 0.2)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	flash_tween.tween_callback(flash.queue_free)
	
	# Eispartikel
	for i in range(16):
		var angle := randf() * TAU
		var dist := randf_range(0, radius)
		var particle_pos := pos + Vector2(cos(angle), sin(angle)) * dist
		
		var ice := _create_pixel(colors[randi() % colors.size()], randi_range(3, 6))
		ice.position = particle_pos
		ice.rotation = randf() * TAU
		parent.add_child(ice)
		
		var ice_tween := ice.create_tween()
		ice_tween.tween_property(ice, "modulate:a", 0.0, randf_range(0.5, 1.0))
		ice_tween.tween_callback(ice.queue_free)
	
	# Screen flash
	screen_flash(Color(0.7, 0.9, 1.0), 0.1)


# === METEOR ===

func spawn_meteor_warning(pos: Vector2, radius: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	# Warnkreis am Boden
	var warning := Line2D.new()
	warning.width = 2
	warning.default_color = Color(1.0, 0.3, 0.1, 0.6)
	warning.position = pos
	
	var segments := 24
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		warning.add_point(Vector2(cos(angle), sin(angle)) * radius)
	
	parent.add_child(warning)
	
	# Pulsieren
	var tween := warning.create_tween().set_loops(3)
	tween.tween_property(warning, "modulate:a", 1.0, 0.15)
	tween.tween_property(warning, "modulate:a", 0.3, 0.15)
	tween.chain().tween_callback(warning.queue_free)
	
	# Ziel-Markierung
	var cross_h := Line2D.new()
	cross_h.width = 2
	cross_h.default_color = Color(1.0, 0.5, 0.2, 0.5)
	cross_h.add_point(Vector2(-radius * 0.3, 0))
	cross_h.add_point(Vector2(radius * 0.3, 0))
	cross_h.position = pos
	parent.add_child(cross_h)
	
	var cross_v := Line2D.new()
	cross_v.width = 2
	cross_v.default_color = Color(1.0, 0.5, 0.2, 0.5)
	cross_v.add_point(Vector2(0, -radius * 0.3))
	cross_v.add_point(Vector2(0, radius * 0.3))
	cross_v.position = pos
	parent.add_child(cross_v)
	
	# Fadeout nach delay
	await parent.get_tree().create_timer(0.7).timeout
	if is_instance_valid(cross_h):
		cross_h.queue_free()
	if is_instance_valid(cross_v):
		cross_v.queue_free()


func spawn_meteor_impact(pos: Vector2, radius: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["fire"]
	var lava_colors: Array = PALETTES["lava"]
	
	# Großer Impact-Flash
	var flash := _create_pixel(Color(1.0, 0.9, 0.5), 30)
	flash.position = pos
	parent.add_child(flash)
	
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(radius / 15, radius / 15), 0.1)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	flash_tween.tween_callback(flash.queue_free)
	
	# Feuer-Explosion
	spawn_pixel_burst(pos, "fire", 24)
	spawn_pixel_burst(pos, "lava", 16)
	
	# Expandierender Feuerring
	spawn_pixel_ring(pos, "fire", radius)
	spawn_pixel_ring(pos, "lava", radius * 0.7)
	
	# Debris-Partikel mit Gravitation
	for i in range(12):
		var debris := _create_pixel(lava_colors[randi() % lava_colors.size()], randi_range(4, 8))
		debris.position = pos
		parent.add_child(debris)
		
		var angle := randf() * TAU
		var speed := randf_range(150, 300)
		var gravity := randf_range(400, 600)
		_animate_pixel_physics(debris, angle, speed, gravity)
	
	# Rauch
	for i in range(8):
		var smoke := _create_pixel(Color(0.3, 0.3, 0.3, 0.6), randi_range(8, 16))
		smoke.position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		parent.add_child(smoke)
		
		var smoke_tween := smoke.create_tween()
		smoke_tween.set_parallel(true)
		smoke_tween.tween_property(smoke, "position:y", smoke.position.y - 60, 1.0)
		smoke_tween.tween_property(smoke, "modulate:a", 0.0, 1.0)
		smoke_tween.tween_property(smoke, "scale", Vector2(2, 2), 1.0)
		smoke_tween.chain().tween_callback(smoke.queue_free)
	
	screen_flash(Color(1.0, 0.6, 0.2), 0.15)


func spawn_small_meteor(pos: Vector2, radius: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	# Kleinere Version des Meteor-Impacts
	var flash := _create_pixel(Color(1.0, 0.7, 0.3), 12)
	flash.position = pos
	parent.add_child(flash)
	
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(radius / 20, radius / 20), 0.08)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)
	
	spawn_pixel_burst(pos, "fire", 8)
	spawn_pixel_ring(pos, "fire", radius * 0.8)


# === EARTHQUAKE ===

func spawn_earthquake_effect() -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var viewport := get_viewport()
	if not viewport:
		return
	
	var screen_size := viewport.get_visible_rect().size
	var colors: Array = PALETTES["earth"]
	
	# Mehrere Shockwave-Ringe vom Zentrum
	var center := screen_size / 2
	
	for wave in range(3):
		await parent.get_tree().create_timer(0.1 * wave).timeout
		
		var ring := Line2D.new()
		ring.width = 4 - wave
		ring.default_color = Color(colors[1].r, colors[1].g, colors[1].b, 0.6)
		ring.position = center
		
		var segments := 32
		for i in range(segments + 1):
			var angle := (float(i) / segments) * TAU
			ring.add_point(Vector2(cos(angle), sin(angle)) * 20)
		
		parent.add_child(ring)
		
		var max_radius: float = screen_size.x * 0.6
		var tween := ring.create_tween()
		tween.tween_method(func(r: float):
			ring.clear_points()
			for i in range(segments + 1):
				var angle := (float(i) / segments) * TAU
				ring.add_point(Vector2(cos(angle), sin(angle)) * r)
		, 20.0, max_radius, 0.5)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
		tween.tween_callback(ring.queue_free)
	
	# Staubpartikel überall
	for i in range(30):
		var dust_pos := Vector2(randf() * screen_size.x, randf() * screen_size.y)
		var dust := _create_pixel(colors[randi() % colors.size()], randi_range(2, 5))
		dust.position = dust_pos
		dust.modulate.a = 0.7
		parent.add_child(dust)
		
		var dust_tween := dust.create_tween()
		dust_tween.set_parallel(true)
		dust_tween.tween_property(dust, "position:y", dust_pos.y - randf_range(20, 50), 0.5)
		dust_tween.tween_property(dust, "modulate:a", 0.0, 0.6)
		dust_tween.chain().tween_callback(dust.queue_free)
	
	# Boden-Risse (kurze Linien)
	for i in range(8):
		var crack_pos := Vector2(randf() * screen_size.x, randf() * screen_size.y)
		var crack := Line2D.new()
		crack.width = 2
		crack.default_color = Color(0.2, 0.15, 0.1)
		crack.position = crack_pos
		
		var crack_length := randf_range(30, 80)
		var crack_angle := randf() * PI
		crack.add_point(Vector2.ZERO)
		crack.add_point(Vector2(cos(crack_angle), sin(crack_angle)) * crack_length)
		
		parent.add_child(crack)
		
		var crack_tween := crack.create_tween()
		crack_tween.tween_property(crack, "modulate:a", 0.0, 1.5)
		crack_tween.tween_callback(crack.queue_free)


# === INFERNO FIELD ===

func spawn_inferno_field(pos: Vector2, radius: float, duration: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["fire"]
	
	# Container für das Feuerfeld
	var field := Node2D.new()
	field.position = pos
	parent.add_child(field)
	
	# Basis-Kreis (Bodenmarkierung)
	var base_circle := Line2D.new()
	base_circle.width = 3
	base_circle.default_color = Color(1.0, 0.3, 0.0, 0.5)
	
	var segments := 24
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		base_circle.add_point(Vector2(cos(angle), sin(angle)) * radius)
	
	field.add_child(base_circle)
	
	# Flammen-Partikel spawnen über die Dauer
	var spawn_timer := Timer.new()
	spawn_timer.wait_time = 0.1
	spawn_timer.autostart = true
	field.add_child(spawn_timer)
	
	spawn_timer.timeout.connect(func():
		if not is_instance_valid(field):
			return
		
		# 3-5 Flammen pro Tick
		for _i in range(randi_range(3, 5)):
			var angle := randf() * TAU
			var dist := randf() * radius
			var flame_pos := Vector2(cos(angle), sin(angle)) * dist
			
			var flame := _create_pixel(colors[randi() % colors.size()], randi_range(4, 8))
			flame.position = flame_pos
			field.add_child(flame)
			
			var flame_tween := flame.create_tween()
			flame_tween.set_parallel(true)
			flame_tween.tween_property(flame, "position:y", flame_pos.y - randf_range(20, 40), 0.4)
			flame_tween.tween_property(flame, "modulate:a", 0.0, 0.4)
			flame_tween.tween_property(flame, "scale", Vector2(0.5, 1.5), 0.4)
			flame_tween.chain().tween_callback(flame.queue_free)
	)
	
	# Field nach duration entfernen
	await parent.get_tree().create_timer(duration).timeout
	if is_instance_valid(field):
		var fade := field.create_tween()
		fade.tween_property(field, "modulate:a", 0.0, 0.3)
		fade.tween_callback(field.queue_free)


# === TSUNAMI ===

func spawn_tsunami_wave(pos: Vector2, width: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["water"]
	var viewport := get_viewport()
	var screen_width: float = viewport.get_visible_rect().size.x if viewport else 1920
	
	# Wellen-Linie die über den Screen fegt
	var wave := Line2D.new()
	wave.width = 8
	wave.default_color = colors[1]
	wave.position = Vector2(-50, pos.y)
	
	# Wellenform
	var wave_points := 20
	for i in range(wave_points + 1):
		var t := float(i) / wave_points
		var y_offset := sin(t * PI * 4) * 15
		wave.add_point(Vector2(0, -width/2 + t * width + y_offset))
	
	parent.add_child(wave)
	
	# Glow dahinter
	var glow := Line2D.new()
	glow.width = 20
	glow.default_color = Color(colors[0].r, colors[0].g, colors[0].b, 0.3)
	glow.points = wave.points
	glow.position = wave.position
	parent.add_child(glow)
	glow.z_index = -1
	
	# Welle bewegen
	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "position:x", screen_width + 50, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(glow, "position:x", screen_width + 50, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(wave.queue_free)
	tween.chain().tween_callback(glow.queue_free)
	
	# Wasserspritzer entlang des Weges
	for i in range(10):
		await parent.get_tree().create_timer(0.07).timeout
		var spray_x: float = (float(i) / 10) * screen_width
		spawn_pixel_burst(Vector2(spray_x, pos.y), "water", 6)


# === SANDSTORM ===

func spawn_sandstorm(pos: Vector2, radius: float, duration: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["air"]
	var earth_colors: Array = PALETTES["earth"]
	
	# Container
	var storm := Node2D.new()
	storm.position = pos
	parent.add_child(storm)
	
	# Basis-Kreis
	var base := Line2D.new()
	base.width = 2
	base.default_color = Color(0.8, 0.7, 0.5, 0.4)
	
	var segments := 24
	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		base.add_point(Vector2(cos(angle), sin(angle)) * radius)
	
	storm.add_child(base)
	
	# Wirbelnde Partikel
	var spawn_timer := Timer.new()
	spawn_timer.wait_time = 0.05
	spawn_timer.autostart = true
	storm.add_child(spawn_timer)
	
	spawn_timer.timeout.connect(func():
		if not is_instance_valid(storm):
			return
		
		for _i in range(4):
			var angle := randf() * TAU
			var dist := randf() * radius
			var sand_pos := Vector2(cos(angle), sin(angle)) * dist
			
			var all_colors: Array = colors + earth_colors
			var sand := _create_pixel(all_colors[randi() % all_colors.size()], randi_range(2, 4))
			sand.position = sand_pos
			sand.modulate.a = 0.7
			storm.add_child(sand)
			
			# Wirbelnde Bewegung
			var end_angle := angle + randf_range(1.5, 3.0)
			var end_pos := Vector2(cos(end_angle), sin(end_angle)) * dist * 0.8
			
			var sand_tween := sand.create_tween()
			sand_tween.set_parallel(true)
			sand_tween.tween_property(sand, "position", end_pos, 0.5).set_trans(Tween.TRANS_SINE)
			sand_tween.tween_property(sand, "modulate:a", 0.0, 0.5)
			sand_tween.chain().tween_callback(sand.queue_free)
	)
	
	# Nach duration entfernen
	await parent.get_tree().create_timer(duration).timeout
	if is_instance_valid(storm):
		var fade := storm.create_tween()
		fade.tween_property(storm, "modulate:a", 0.0, 0.3)
		fade.tween_callback(storm.queue_free)


# === ICE WALL ===

func spawn_ice_wall(pos: Vector2, duration: float, _health: int) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["ice"]
	
	# Eiswand-Rechteck
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(-30, -40), Vector2(30, -40),
		Vector2(30, 10), Vector2(-30, 10)
	])
	wall.color = Color(colors[1].r, colors[1].g, colors[1].b, 0.7)
	wall.position = pos
	parent.add_child(wall)
	
	# Glänzender Rand
	var outline := Line2D.new()
	outline.width = 2
	outline.default_color = colors[2]
	outline.add_point(Vector2(-30, -40))
	outline.add_point(Vector2(30, -40))
	outline.add_point(Vector2(30, 10))
	outline.add_point(Vector2(-30, 10))
	outline.add_point(Vector2(-30, -40))
	outline.position = pos
	parent.add_child(outline)
	
	# Spawn-Effekt
	spawn_pixel_burst(pos, "ice", 12)
	screen_flash(Color(0.8, 0.9, 1.0), 0.1)
	
	# Eispartikel während Dauer
	var particle_timer := Timer.new()
	particle_timer.wait_time = 0.3
	particle_timer.autostart = true
	wall.add_child(particle_timer)
	
	particle_timer.timeout.connect(func():
		if not is_instance_valid(wall):
			return
		var ice := _create_pixel(colors[randi() % colors.size()], 3)
		ice.position = pos + Vector2(randf_range(-25, 25), randf_range(-35, 5))
		parent.add_child(ice)
		
		var ice_tween := ice.create_tween()
		ice_tween.tween_property(ice, "modulate:a", 0.0, 0.5)
		ice_tween.tween_callback(ice.queue_free)
	)
	
	# Nach duration zerstören
	await parent.get_tree().create_timer(duration).timeout
	if is_instance_valid(wall):
		spawn_pixel_burst(pos, "ice", 16)
		wall.queue_free()
		outline.queue_free()


# === FISSURE ===

func spawn_fissure(pos: Vector2, length: float, width: float, duration: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["earth"]
	
	# Hauptriss
	var fissure := Polygon2D.new()
	fissure.polygon = PackedVector2Array([
		Vector2(-length/2, -width/2), Vector2(length/2, -width/2),
		Vector2(length/2, width/2), Vector2(-length/2, width/2)
	])
	fissure.color = Color(0.15, 0.1, 0.05)
	fissure.position = pos
	parent.add_child(fissure)
	
	# Glühende Ränder
	var glow_top := Line2D.new()
	glow_top.width = 3
	glow_top.default_color = Color(0.8, 0.4, 0.1, 0.6)
	glow_top.add_point(Vector2(-length/2, -width/2))
	glow_top.add_point(Vector2(length/2, -width/2))
	glow_top.position = pos
	parent.add_child(glow_top)
	
	var glow_bottom := Line2D.new()
	glow_bottom.width = 3
	glow_bottom.default_color = Color(0.8, 0.4, 0.1, 0.6)
	glow_bottom.add_point(Vector2(-length/2, width/2))
	glow_bottom.add_point(Vector2(length/2, width/2))
	glow_bottom.position = pos
	parent.add_child(glow_bottom)
	
	# Spawn-Effekt
	spawn_pixel_burst(pos, "earth", 10)
	screen_shake(5.0, 0.2)
	
	# Partikel über Dauer
	var particle_timer := Timer.new()
	particle_timer.wait_time = 0.2
	particle_timer.autostart = true
	fissure.add_child(particle_timer)
	
	particle_timer.timeout.connect(func():
		if not is_instance_valid(fissure):
			return
		for _i in range(2):
			var rock := _create_pixel(colors[randi() % colors.size()], randi_range(2, 4))
			rock.position = pos + Vector2(randf_range(-length/2, length/2), randf_range(-width/2, width/2))
			parent.add_child(rock)
			
			var rock_tween := rock.create_tween()
			rock_tween.set_parallel(true)
			rock_tween.tween_property(rock, "position:y", rock.position.y - 20, 0.3)
			rock_tween.tween_property(rock, "modulate:a", 0.0, 0.3)
			rock_tween.chain().tween_callback(rock.queue_free)
	)
	
	# Nach duration schließen
	await parent.get_tree().create_timer(duration).timeout
	if is_instance_valid(fissure):
		var close_tween := fissure.create_tween()
		close_tween.tween_property(fissure, "scale:y", 0.0, 0.3)
		close_tween.parallel().tween_property(glow_top, "modulate:a", 0.0, 0.3)
		close_tween.parallel().tween_property(glow_bottom, "modulate:a", 0.0, 0.3)
		close_tween.tween_callback(fissure.queue_free)
		close_tween.tween_callback(glow_top.queue_free)
		close_tween.tween_callback(glow_bottom.queue_free)


# === STONE SKIN ===

func spawn_stone_skin_effect(duration: float) -> void:
	var parent := _get_vfx_parent()
	if not parent:
		return
	
	var colors: Array = PALETTES["earth"]
	
	# Für jeden Tower einen Stein-Effekt
	var towers := parent.get_tree().get_nodes_in_group("towers")
	
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		
		# Stein-Aura um Tower
		var aura := Line2D.new()
		aura.width = 3
		aura.default_color = Color(colors[1].r, colors[1].g, colors[1].b, 0.6)
		aura.position = tower.position
		
		var segments := 16
		var aura_radius := 40.0
		for i in range(segments + 1):
			var angle := (float(i) / segments) * TAU
			aura.add_point(Vector2(cos(angle), sin(angle)) * aura_radius)
		
		parent.add_child(aura)
		
		# Pulsieren während Dauer
		var pulse_tween := aura.create_tween().set_loops(int(duration / 0.8))
		pulse_tween.tween_property(aura, "modulate:a", 0.8, 0.4)
		pulse_tween.tween_property(aura, "modulate:a", 0.3, 0.4)
		
		# Nach duration entfernen
		var remove_timer := parent.get_tree().create_timer(duration)
		remove_timer.timeout.connect(func():
			if is_instance_valid(aura):
				var fade := aura.create_tween()
				fade.tween_property(aura, "modulate:a", 0.0, 0.3)
				fade.tween_callback(aura.queue_free)
		)
	
	# Global flash
	screen_flash(Color(0.6, 0.5, 0.3), 0.15)
	spawn_pixel_burst(get_viewport().get_visible_rect().size / 2, "earth", 20)
