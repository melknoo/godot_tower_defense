# tower.gd
# Tower mit Upgrades, Spezialeffekten, Melee-Attacken und animierten Spritesheets
extends Node2D
class_name Tower

var tower_type := "archer"
var tower_range := 150.0
var fire_rate := 1.0
var damage := 20
var splash_radius := 0.0
var level := 0
var attack_type := "projectile"

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

# Animation
var idle_time := 0.0
var is_shooting := false
var is_attacking := false
var attack_anim_time := 0.0

# Archer Spritesheet Animation
var archer_sprite: Sprite2D
var sword_sprite: Sprite2D
var current_anim_row := 0
var current_anim_frame := 0
var anim_timer := 0.0
var is_playing_shoot_anim := false
var is_playing_attack_anim := false
var shoot_anim_callback: Callable

const ARCHER_FRAME_SIZE := Vector2(192, 192)
const ARCHER_COLUMNS := 8
const ARCHER_ROWS := 7
var archer_anim_speed := 0.08  # Sekunden pro Frame, wird dynamisch angepasst

const SWORD_FRAME_SIZE := Vector2(192, 192)
const SWORD_COLUMNS := 6
const SWORD_ROWS := 8

# Schuss-Richtungen: Winkel -> Reihe (0-indexed)
# Reihe 2 (idx 2): Oben, Reihe 3: Oben-Rechts, Reihe 4: Rechts, Reihe 5: Unten-Rechts, Reihe 6: Unten
const ARCHER_DIRECTION_ROWS := {
	"up": 2,
	"up_right": 3,
	"right": 4,
	"down_right": 5,
	"down": 6
}

const SWORD_DIRECTION_ROWS := {
	"up": 2,
	"up_right": 3,
	"right": 4,
	"down_right": 5,
	"down": 6
}

# Corner Textures
static var corner_textures: Dictionary = {}
static var corners_loaded := false


func _ready() -> void:
	bullet_scene = preload("res://bullet.tscn")
	_load_corner_textures()
	_create_visuals()
	_update_visuals()
	Sound.play_place()
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
	attack_type = data.get("attack_type", "projectile")
	_load_special_effects()
	_update_archer_anim_speed()
	if is_inside_tree():
		_update_visuals()


func upgrade(data: Dictionary, new_level: int) -> void:
	level = new_level
	tower_range = data.get("range", tower_range)
	fire_rate = data.get("fire_rate", fire_rate)
	damage = data.get("damage", damage)
	splash_radius = data.get("splash", splash_radius)
	attack_type = data.get("attack_type", attack_type)
	_load_special_effects()
	_update_archer_anim_speed()
	if is_inside_tree():
		_update_visuals()
		_show_upgrade_effect()
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


func _update_archer_anim_speed() -> void:
	# Archer Animation Speed basierend auf fire_rate anpassen
	# 8 Frames Schuss-Animation soll in ~80% der fire_rate Zeit abgespielt werden
	if tower_type == "archer":
		var shoot_frames := 8
		var anim_duration := fire_rate * 0.8  # Animation dauert 80% der Cooldown-Zeit
		archer_anim_speed = anim_duration / shoot_frames


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


func _update_visuals() -> void:
	for child in turret.get_children():
		child.queue_free()
	archer_sprite = null
	sword_sprite = null
	sprite = null
	
	if tower_type == "archer":
		_setup_archer_sprite()
	elif tower_type == "sword":
		_setup_sword_sprite()
	else:
		_setup_standard_sprite()
	
	# Range Circle
	range_circle.clear_points()
	for i in range(33):
		var angle := i * TAU / 32
		range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
	_update_level_indicator()


func _setup_archer_sprite() -> void:
	var spritesheet_path := "res://assets/elemental_tower/archer_spritesheet.png"
	if not ResourceLoader.exists(spritesheet_path):
		_setup_standard_sprite()
		return
	
	archer_sprite = Sprite2D.new()
	archer_sprite.texture = load(spritesheet_path)
	archer_sprite.hframes = ARCHER_COLUMNS
	archer_sprite.vframes = ARCHER_ROWS
	archer_sprite.frame = 0
	
	var desired_size := 128.0
	var scale_factor := desired_size / ARCHER_FRAME_SIZE.x
	archer_sprite.scale = Vector2(scale_factor, scale_factor)
	
	turret.add_child(archer_sprite)
	
	current_anim_row = 0
	current_anim_frame = 0


func _setup_sword_sprite() -> void:
	var spritesheet_path := "res://assets/elemental_tower/sword_spritesheet.png"
	if not ResourceLoader.exists(spritesheet_path):
		_setup_standard_sprite()
		return
	
	sword_sprite = Sprite2D.new()
	sword_sprite.texture = load(spritesheet_path)
	sword_sprite.hframes = SWORD_COLUMNS
	sword_sprite.vframes = SWORD_ROWS
	sword_sprite.frame = 0
	
	var desired_size := 128.0
	var scale_factor := desired_size / SWORD_FRAME_SIZE.x
	sword_sprite.scale = Vector2(scale_factor, scale_factor)
	
	turret.add_child(sword_sprite)
	
	current_anim_row = 0
	current_anim_frame = 0


func _setup_standard_sprite() -> void:
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


func _get_tower_texture_path() -> String:
	if level == 0:
		return "res://assets/elemental_tower/tower_%s.png" % tower_type
	else:
		var display_level := level + 1
		return "res://assets/elemental_tower/tower_%s_level_%d.png" % [tower_type, display_level]


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
	var current_sprite: Sprite2D = archer_sprite if archer_sprite else sprite
	if not current_sprite:
		return
	var flash := Sprite2D.new()
	flash.texture = current_sprite.texture
	flash.hframes = current_sprite.hframes
	flash.vframes = current_sprite.vframes
	flash.frame = current_sprite.frame
	flash.scale = current_sprite.scale * 1.2
	flash.modulate = Color(1, 1, 1, 0.8)
	turret.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", current_sprite.scale * 1.5, 0.3)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)


func _process(delta: float) -> void:
	fire_timer -= delta
	
	# Spritesheet Animation Update
	if archer_sprite:
		_update_archer_animation(delta)
	elif sword_sprite:
		_update_sword_animation(delta)
	
	# Alte Melee Animation (für nicht-spritesheet Tower)
	if is_attacking and not sword_sprite:
		attack_anim_time += delta
		_do_melee_animation(delta)
		if attack_anim_time > 0.3:
			is_attacking = false
			attack_anim_time = 0.0
		return
	
	_find_target()
	
	if target:
		is_shooting = true
		if attack_type != "melee" and not archer_sprite:
			_rotate_towards_target(delta)
		if fire_timer <= 0 and not is_playing_shoot_anim and not is_playing_attack_anim:
			if attack_type == "melee":
				if sword_sprite:
					_start_sword_attack_animation()
				else:
					_melee_attack()
				fire_timer = fire_rate
			elif archer_sprite:
				_start_archer_shoot_animation()
				fire_timer = fire_rate
			else:
				_shoot()
				fire_timer = fire_rate
	else:
		is_shooting = false
		if not archer_sprite and not sword_sprite:
			_do_idle_animation(delta)


func _update_archer_animation(delta: float) -> void:
	anim_timer += delta
	
	if anim_timer >= archer_anim_speed:
		anim_timer = 0.0
		current_anim_frame += 1
		
		var max_frames := 6 if current_anim_row == 0 else 8
		
		if current_anim_frame >= max_frames:
			if is_playing_shoot_anim:
				is_playing_shoot_anim = false
				_shoot()
				current_anim_row = 0
				current_anim_frame = 0
			else:
				current_anim_frame = 0
		
		_update_archer_frame()


func _update_sword_animation(delta: float) -> void:
	anim_timer += delta
	
	var anim_speed := archer_anim_speed  # Nutzt gleiche Speed-Berechnung
	
	if anim_timer >= anim_speed:
		anim_timer = 0.0
		current_anim_frame += 1
		
		var max_frames := 6  # Alle Reihen haben 6 Frames
		
		if current_anim_frame >= max_frames:
			if is_playing_attack_anim:
				is_playing_attack_anim = false
				_execute_melee_damage()
				current_anim_row = 0
				current_anim_frame = 0
			else:
				current_anim_frame = 0
		
		_update_sword_frame()


func _update_archer_frame() -> void:
	if not archer_sprite:
		return
	var frame_index := current_anim_row * ARCHER_COLUMNS + current_anim_frame
	archer_sprite.frame = frame_index


func _update_sword_frame() -> void:
	if not sword_sprite:
		return
	var frame_index := current_anim_row * SWORD_COLUMNS + current_anim_frame
	sword_sprite.frame = frame_index


func _start_archer_shoot_animation() -> void:
	if not target or not archer_sprite:
		return
	
	is_playing_shoot_anim = true
	current_anim_frame = 0
	anim_timer = 0.0
	
	var direction := (target.position - position).normalized()
	var angle := direction.angle()
	
	var is_left := direction.x < 0
	archer_sprite.flip_h = is_left
	
	if is_left:
		angle = PI - angle
	
	if angle < -PI/3:
		current_anim_row = ARCHER_DIRECTION_ROWS["up"]
	elif angle < -PI/6:
		current_anim_row = ARCHER_DIRECTION_ROWS["up_right"]
	elif angle < PI/6:
		current_anim_row = ARCHER_DIRECTION_ROWS["right"]
	elif angle < PI/3:
		current_anim_row = ARCHER_DIRECTION_ROWS["down_right"]
	else:
		current_anim_row = ARCHER_DIRECTION_ROWS["down"]
	
	_update_archer_frame()


func _start_sword_attack_animation() -> void:
	if not target or not sword_sprite:
		return
	
	is_playing_attack_anim = true
	current_anim_frame = 0
	anim_timer = 0.0
	
	var direction := (target.position - position).normalized()
	var angle := direction.angle()
	
	var is_left := direction.x < 0
	sword_sprite.flip_h = is_left
	
	if is_left:
		angle = PI - angle
	
	if angle < -PI/3:
		current_anim_row = SWORD_DIRECTION_ROWS["up"]
	elif angle < -PI/6:
		current_anim_row = SWORD_DIRECTION_ROWS["up_right"]
	elif angle < PI/6:
		current_anim_row = SWORD_DIRECTION_ROWS["right"]
	elif angle < PI/3:
		current_anim_row = SWORD_DIRECTION_ROWS["down_right"]
	else:
		current_anim_row = SWORD_DIRECTION_ROWS["down"]
	
	_update_sword_frame()


func _do_idle_animation(delta: float) -> void:
	idle_time += delta
	if sprite:
		sprite.position.y = sin(idle_time * 2.0) * 1.5


func _do_melee_animation(delta: float) -> void:
	if not sprite:
		return
	var progress := attack_anim_time / 0.3
	var swing_angle := sin(progress * PI) * 0.5
	turret.rotation = swing_angle
	var scale_punch := 1.0 + sin(progress * PI) * 0.15
	sprite.scale = Vector2(3, 3) * scale_punch


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
		sprite.position.y = 0
	var adjusted_direction := Vector2(abs(direction.x), direction.y)
	var target_angle := adjusted_direction.angle() + PI
	turret.rotation = lerp_angle(turret.rotation, target_angle, 10 * delta)


func _melee_attack() -> void:
	is_attacking = true
	attack_anim_time = 0.0
	_execute_melee_damage()


func _execute_melee_damage() -> void:
	var hit_count := 0
	var hit_enemies: Array[Node2D] = []
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := position.distance_to(enemy.position)
		if dist <= tower_range:
			hit_enemies.append(enemy)
			hit_count += 1
	
	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, true, tower_type)
		_apply_melee_effects(enemy)
	
	if VFX:
		VFX.spawn_cleave_effect(position, tower_range, tower_type)
		if hit_count > 0:
			VFX.spawn_melee_hit_sparks(position, hit_count, tower_type)
		if hit_count >= 3:
			VFX.screen_shake(2.0, 0.08)
	
	Sound.play_shoot("sword", level)


func _apply_melee_effects(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	match special_type:
		"cleave":
			pass
		"stun":
			if randf() < stun_chance and enemy.has_method("apply_stun"):
				enemy.apply_stun(0.5)


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
	
	var direction := (target.position - position).normalized()
	if VFX and tower_type != "archer":
		VFX.spawn_muzzle_flash(position + direction * 15, direction, tower_type)
	
	var sound_element := "base" if tower_type == "archer" else tower_type
	Sound.play_shoot(sound_element, level)
	
	if not archer_sprite:
		_do_recoil()


func _do_recoil() -> void:
	var current_sprite: Sprite2D = archer_sprite if archer_sprite else sprite
	if not current_sprite:
		return
	var original_pos := current_sprite.position
	var recoil_dir := Vector2(0, 3)
	var tween := current_sprite.create_tween()
	tween.tween_property(current_sprite, "position", original_pos + recoil_dir, 0.05)
	tween.tween_property(current_sprite, "position", original_pos, 0.1).set_trans(Tween.TRANS_ELASTIC)


func select() -> void:
	if selection_corners:
		return
	if corner_textures.size() < 4:
		return
	selection_corners = Node2D.new()
	selection_corners.name = "SelectionCorners"
	add_child(selection_corners)
	var offset := 38.0
	var scl := Vector2(3, 3)
	var tl := Sprite2D.new()
	tl.texture = corner_textures["top_left"]
	tl.scale = scl
	tl.position = Vector2(-offset, -offset)
	selection_corners.add_child(tl)
	var tr := Sprite2D.new()
	tr.texture = corner_textures["top_right"]
	tr.scale = scl
	tr.position = Vector2(offset, -offset)
	selection_corners.add_child(tr)
	var bl := Sprite2D.new()
	bl.texture = corner_textures["bottom_left"]
	bl.scale = scl
	bl.position = Vector2(-offset, offset)
	selection_corners.add_child(bl)
	var br := Sprite2D.new()
	br.texture = corner_textures["bottom_right"]
	br.scale = scl
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
