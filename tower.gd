# tower.gd
# Tower mit Upgrades, Spezialeffekten und VFX
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
var selection_corners: Node2D
var selection_tween: Tween

# Idle Animation
var idle_time := 0.0
var is_shooting := false

# Corner Textures
static var corner_textures: Dictionary = {}
static var corners_loaded := false


func _ready() -> void:
	bullet_scene = preload("res://bullet.tscn")
	_load_corner_textures()
	_create_visuals()
	_update_visuals()
	
	# Platzierungs-Effekt
	if VFX:
		VFX.spawn_place_effect(position, tower_type)


func _load_corner_textures() -> void:
	if corners_loaded:
		return
	
	var base_path := "res://assets/ui/"
	var corners := ["top_left", "top_right", "bottom_left", "bottom_right"]
	
	for corner in corners:
		var path := base_path + "selection_%s_corner.png" % corner
		if ResourceLoader.exists(path):
			corner_textures[corner] = load(path)
	
	corners_loaded = true


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
		
		# VFX
		if VFX:
			VFX.spawn_upgrade_effect(position, tower_type, new_level)


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
			sprite.scale = Vector2(3, 3)
		
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
		is_shooting = true
		_rotate_towards_target(delta)
		if fire_timer <= 0:
			_shoot()
			fire_timer = fire_rate
	else:
		is_shooting = false
		_do_idle_animation(delta)


func _do_idle_animation(delta: float) -> void:
	idle_time += delta
	
	# Sanftes Auf und Ab wenn kein Ziel
	if sprite:
		sprite.position.y = sin(idle_time * 2.0) * 1.5


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
		return
	
	var direction := target.position - position
	var is_facing_left := direction.x < 0
	
	if sprite:
		sprite.flip_h = is_facing_left
		sprite.position.y = 0  # Reset idle bob
	
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
	
	# VFX Muzzle Flash
	var direction := (target.position - position).normalized()
	if VFX:
		VFX.spawn_muzzle_flash(position + direction * 15, direction, tower_type)
	
	_do_recoil()


func _do_recoil() -> void:
	if not sprite:
		return
	
	# Kurzer Rückstoß
	var original_pos := sprite.position
	var recoil_dir := Vector2(0, 3)  # Nach unten
	
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", original_pos + recoil_dir, 0.05)
	tween.tween_property(sprite, "position", original_pos, 0.1).set_trans(Tween.TRANS_ELASTIC)


func select() -> void:
	if selection_corners:
		return
	
	if corner_textures.size() < 4:
		return
	
	selection_corners = Node2D.new()
	selection_corners.name = "SelectionCorners"
	add_child(selection_corners)
	
	var offset := 38.0
	var scale := Vector2(3, 3)
	
	var tl := Sprite2D.new()
	tl.texture = corner_textures["top_left"]
	tl.scale = scale
	tl.position = Vector2(-offset, -offset)
	selection_corners.add_child(tl)
	
	var tr := Sprite2D.new()
	tr.texture = corner_textures["top_right"]
	tr.scale = scale
	tr.position = Vector2(offset, -offset)
	selection_corners.add_child(tr)
	
	var bl := Sprite2D.new()
	bl.texture = corner_textures["bottom_left"]
	bl.scale = scale
	bl.position = Vector2(-offset, offset)
	selection_corners.add_child(bl)
	
	var br := Sprite2D.new()
	br.texture = corner_textures["bottom_right"]
	br.scale = scale
	br.position = Vector2(offset, offset)
	selection_corners.add_child(br)
	
	_start_float_animation()
	
	if range_circle:
		range_circle.default_color = Color(1, 0.5, 0.5, 0.3)


func deselect() -> void:
	if selection_corners:
		selection_corners.queue_free()
		selection_corners = null
	
	if selection_tween:
		selection_tween.kill()
		selection_tween = null
	
	if range_circle:
		range_circle.default_color = Color(1, 1, 1, 0.15)


func _start_float_animation() -> void:
	if not selection_corners:
		return
	
	if selection_tween:
		selection_tween.kill()
	
	var base_y := 0.0
	var float_amount := 4.0
	var float_duration := 0.8
	
	selection_corners.position.y = base_y
	
	selection_tween = create_tween()
	selection_tween.set_loops()
	selection_tween.tween_property(selection_corners, "position:y", base_y - float_amount, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	selection_tween.tween_property(selection_corners, "position:y", base_y + float_amount, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
