# tower.gd
# Tower mit Elemental Engraving, Upgrades und Spezialeffekten
extends Node2D
class_name Tower

var tower_type := "archer"
var tower_range := 150.0
var fire_rate := 1.0
var damage := 20
var splash_radius := 0.0
var level := 0
var attack_type := "projectile"
var engraved_element := ""  # NEU: Graviertes Element

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
var engraving_indicator: Label  # NEU

# Animation
var idle_time := 0.0
var is_shooting := false
var is_attacking := false
var attack_anim_time := 0.0

# Spritesheet Animation
var archer_sprite: Sprite2D
var sword_sprite: Sprite2D
var current_anim_row := 0
var current_anim_frame := 0
var anim_timer := 0.0
var is_playing_shoot_anim := false
var is_playing_attack_anim := false

const ARCHER_FRAME_SIZE := Vector2(192, 192)
const ARCHER_COLUMNS := 8
const ARCHER_ROWS := 7
var archer_anim_speed := 0.08

const SWORD_FRAME_SIZE := Vector2(192, 192)
const SWORD_COLUMNS := 6
const SWORD_ROWS := 8

const ARCHER_DIRECTION_ROWS := {"up": 2, "up_right": 3, "right": 4, "down_right": 5, "down": 6}
const SWORD_DIRECTION_ROWS := {"up": 2, "up_right": 3, "right": 4, "down_right": 5, "down": 6}

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
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
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
			VFX.spawn_upgrade_effect(position, get_effective_element(), new_level)


# NEU: Elemental Engraving
func engrave(element: String) -> bool:
	if not TowerData.can_engrave(tower_type):
		return false
	if not TowerData.is_element_unlocked(element):
		return false
	if not TowerData.can_afford_engraving():
		return false
	
	GameState.gold -= TowerData.get_engraving_cost()
	engraved_element = element
	
	# Spezialeffekt des Elements laden
	_load_engraving_effects()
	
	if is_inside_tree():
		_update_visuals()
		_show_engraving_effect()
	
	Sound.play_element_select()
	return true


func _load_engraving_effects() -> void:
	if engraved_element == "":
		return
	
	# Gravierte Türme bekommen abgeschwächte Elementar-Effekte
	match engraved_element:
		"water":
			special_type = "slow"
			slow_amount = 0.15 + level * 0.05  # Schwächer als echter Wasser-Turm
		"fire":
			special_type = "burn"
			burn_damage = 2 + level * 2
		"earth":
			special_type = "stun"
			stun_chance = 0.05 + level * 0.03
		"air":
			special_type = "chain"
			chain_targets = level  # 0, 1, 2 bei Level 0, 1, 2


func _show_engraving_effect() -> void:
	if VFX:
		VFX.spawn_pixel_burst(position, engraved_element, 16)
		VFX.spawn_pixel_ring(position, engraved_element, 50.0)
		VFX.screen_flash(ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE, 0.15)


func get_effective_element() -> String:
	# Gibt das Element zurück das für Damage-Berechnung verwendet wird
	if engraved_element != "":
		return engraved_element
	if tower_type in TowerData.UNLOCKABLE_ELEMENTS:
		return tower_type
	if TowerData.is_combination(tower_type):
		return tower_type  # Kombis haben eigenes Element
	return ""  # Neutral


func is_engraved() -> bool:
	return engraved_element != ""


func can_be_engraved() -> bool:
	return TowerData.can_engrave(tower_type) and engraved_element == ""


func _load_special_effects() -> void:
	# Wenn graviert, nutze Gravur-Effekte
	if engraved_element != "":
		_load_engraving_effects()
		return
	
	special_type = TowerData.get_stat(tower_type, "special")
	if special_type == null:
		special_type = ""
	match special_type:
		"slow": slow_amount = TowerData.get_stat(tower_type, "slow_amount", level)
		"burn": burn_damage = TowerData.get_stat(tower_type, "burn_damage", level)
		"stun": stun_chance = TowerData.get_stat(tower_type, "stun_chance", level)
		"chain": chain_targets = TowerData.get_stat(tower_type, "chain_targets", level)


func _update_archer_anim_speed() -> void:
	if tower_type == "archer":
		var shoot_frames := 8
		var anim_duration := fire_rate * 0.8
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
	
	# NEU: Engraving Indicator
	engraving_indicator = Label.new()
	engraving_indicator.position = Vector2(-25, -45)
	engraving_indicator.add_theme_font_size_override("font_size", 14)
	engraving_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	engraving_indicator.add_theme_constant_override("outline_size", 2)
	engraving_indicator.visible = false
	add_child(engraving_indicator)


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
	
	# Range Circle mit Element-Farbe wenn graviert
	range_circle.clear_points()
	for i in range(33):
		var angle := i * TAU / 32
		range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
	
	if engraved_element != "":
		var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
		range_circle.default_color = elem_color.lerp(Color.WHITE, 0.7)
		range_circle.default_color.a = 0.2
	
	_update_level_indicator()
	_update_engraving_indicator()


func _update_engraving_indicator() -> void:
	if engraved_element == "":
		engraving_indicator.visible = false
		return
	
	engraving_indicator.visible = true
	engraving_indicator.text = ElementalSystem.get_element_symbol(engraved_element) if ElementalSystem else engraved_element.substr(0, 1).to_upper()
	
	var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
	engraving_indicator.add_theme_color_override("font_color", elem_color)
	
	# Sprite leicht einfärben
	var current_sprite: Sprite2D = archer_sprite if archer_sprite else (sword_sprite if sword_sprite else sprite)
	if current_sprite:
		current_sprite.modulate = Color.WHITE.lerp(elem_color, 0.25)


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
		return "res://assets/elemental_tower/tower_%s_level_%d.png" % [tower_type, level + 1]


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
	
	if archer_sprite:
		_update_archer_animation(delta)
	elif sword_sprite:
		_update_sword_animation(delta)
	
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
	if anim_timer >= archer_anim_speed:
		anim_timer = 0.0
		current_anim_frame += 1
		if current_anim_frame >= 6:
			if is_playing_attack_anim:
				is_playing_attack_anim = false
				_execute_melee_damage()
				current_anim_row = 0
				current_anim_frame = 0
			else:
				current_anim_frame = 0
		_update_sword_frame()


func _update_archer_frame() -> void:
	if archer_sprite:
		archer_sprite.frame = current_anim_row * ARCHER_COLUMNS + current_anim_frame


func _update_sword_frame() -> void:
	if sword_sprite:
		sword_sprite.frame = current_anim_row * SWORD_COLUMNS + current_anim_frame


func _start_archer_shoot_animation() -> void:
	if not target or not archer_sprite:
		return
	is_playing_shoot_anim = true
	current_anim_frame = 0
	anim_timer = 0.0
	var direction := (target.position - position).normalized()
	var angle := direction.angle()
	archer_sprite.flip_h = direction.x < 0
	if direction.x < 0:
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
	sword_sprite.flip_h = direction.x < 0
	if direction.x < 0:
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
	turret.rotation = sin(progress * PI) * 0.5
	sprite.scale = Vector2(3, 3) * (1.0 + sin(progress * PI) * 0.15)


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
	if sprite:
		sprite.flip_h = direction.x < 0
		sprite.position.y = 0
	var adjusted := Vector2(abs(direction.x), direction.y)
	turret.rotation = lerp_angle(turret.rotation, adjusted.angle() + TAU, 10 * delta)


func _melee_attack() -> void:
	is_attacking = true
	attack_anim_time = 0.0
	_execute_melee_damage()


func _execute_melee_damage() -> void:
	var hit_enemies: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if position.distance_to(enemy.position) <= tower_range:
			hit_enemies.append(enemy)
	
	var elem := get_effective_element()
	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, true, elem)
		_apply_melee_effects(enemy)
	
	if VFX:
		VFX.spawn_cleave_effect(position, tower_range, elem if elem != "" else "sword")
		if hit_enemies.size() > 0:
			VFX.spawn_melee_hit_sparks(position, hit_enemies.size(), elem if elem != "" else "sword")
		if hit_enemies.size() >= 3:
			VFX.screen_shake(2.0, 0.08)
	
	Sound.play_shoot("sword", level)


func _apply_melee_effects(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	match special_type:
		"stun":
			if randf() < stun_chance and enemy.has_method("apply_stun"):
				enemy.apply_stun(0.5)
		"slow":
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_amount, 2.0)


func _shoot() -> void:
	if not target:
		return
	var bullet := bullet_scene.instantiate()
	bullet.position = position
	
	var elem := get_effective_element()
	var bullet_data := {
		"target": target, "damage": damage, "splash": splash_radius,
		"type": elem if elem != "" else tower_type,
		"level": level, "special": special_type,
		"slow_amount": slow_amount, "burn_damage": burn_damage,
		"stun_chance": stun_chance, "chain_targets": chain_targets
	}
	
	if bullet.has_method("setup_extended"):
		bullet.setup_extended(bullet_data)
	else:
		bullet.setup(target, damage, splash_radius, tower_type)
	get_parent().add_child(bullet)
	
	var direction := (target.position - position).normalized()
	if VFX and tower_type != "archer":
		VFX.spawn_muzzle_flash(position + direction * 15, direction, elem if elem != "" else tower_type)
	
	var sound_elem := "base" if tower_type == "archer" and engraved_element == "" else (engraved_element if engraved_element != "" else tower_type)
	Sound.play_shoot(sound_elem, level)
	
	if not archer_sprite:
		_do_recoil()


func _do_recoil() -> void:
	var current_sprite: Sprite2D = archer_sprite if archer_sprite else sprite
	if not current_sprite:
		return
	var original_pos := current_sprite.position
	var tween := current_sprite.create_tween()
	tween.tween_property(current_sprite, "position", original_pos + Vector2(0, 3), 0.05)
	tween.tween_property(current_sprite, "position", original_pos, 0.1).set_trans(Tween.TRANS_ELASTIC)


func select() -> void:
	if selection_corners or corner_textures.size() < 4:
		return
	selection_corners = Node2D.new()
	selection_corners.name = "SelectionCorners"
	add_child(selection_corners)
	var offset := 38.0
	var scl := Vector2(3, 3)
	for corner_data in [["top_left", Vector2(-offset, -offset)], ["top_right", Vector2(offset, -offset)],
						["bottom_left", Vector2(-offset, offset)], ["bottom_right", Vector2(offset, offset)]]:
		var s := Sprite2D.new()
		s.texture = corner_textures[corner_data[0]]
		s.scale = scl
		s.position = corner_data[1]
		selection_corners.add_child(s)
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
		if engraved_element != "":
			var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
			range_circle.default_color = elem_color.lerp(Color.WHITE, 0.7)
			range_circle.default_color.a = 0.2
		else:
			range_circle.default_color = Color(1, 1, 1, 0.15)


func _start_float_animation() -> void:
	if not selection_corners:
		return
	if selection_tween:
		selection_tween.kill()
	selection_tween = create_tween().set_loops()
	selection_tween.tween_property(selection_corners, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	selection_tween.tween_property(selection_corners, "position:y", 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
