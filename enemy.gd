# enemy.gd
# Gegner mit Elementar-Typen, animierten Sprites und VFX
extends Node2D
class_name Enemy

var path: Array[Vector2] = []
var path_index := 0
var health := 100
var max_health := 100
var speed := 80.0
var base_speed := 80.0
var reward := 2
var enemy_type := "normal"
var element := "neutral"
var _resolved := false


# Status-Effekte
var slow_amount := 0.0
var slow_timer := 0.0
var burn_damage := 0
var burn_timer := 0.0
var stun_timer := 0.0
var is_frozen := false
var freeze_timer := 0.0

# Hit-Flash
var flash_timer := 0.0
var original_modulate := Color.WHITE

# Visuals
var sprite: Sprite2D
var health_bar_bg: Line2D
var health_bar: Line2D
var status_indicator: Node2D
var shadow: Polygon2D
var element_indicator: Label

# Animation
var anim_timer := 0.0
var anim_frame := 3  # Start bei Frame 3, läuft rückwärts
const ANIM_SPEED := 0.15  # Sekunden pro Frame
const FRAME_COUNT := 4
var anim_col := 0
var anim_row := 0
const NORMAL_COLS := 3
const NORMAL_ROWS := 4

# Sprite-Konstanten
const FRAME_SIZE := Vector2(16, 16)
const ENEMY_SCALE := 3.0  # Skalierung für bessere Sichtbarkeit

var walk_bob := 0.0
var wobble_time := 0.0
# Shadow FX
var shadow_offset_y := 8.0
var shadow_base_scale := Vector2.ONE
var shadow_bob_t := 0.0
var shadow_stun_t := 0.0



func _ready() -> void:
	print("[Enemy] _ready script=", get_script().resource_path, " name=", name)
	add_to_group("enemies")
	_create_visuals()


func _create_visuals() -> void:
	# Schatten
	shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-12, 0),
		Vector2(12, 0),
		Vector2(10, 4),
		Vector2(-10, 4)
	])
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.z_index = -1
	shadow.position.y = shadow_offset_y
	add_child(shadow)

	# Sprite
	sprite = Sprite2D.new()
	sprite.scale = Vector2(ENEMY_SCALE, ENEMY_SCALE)
	add_child(sprite)

	# Health Bar Background
	health_bar_bg = Line2D.new()
	health_bar_bg.add_point(Vector2(-15, -28))
	health_bar_bg.add_point(Vector2(15, -28))
	health_bar_bg.default_color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar_bg.width = 6
	add_child(health_bar_bg)

	# Health Bar
	health_bar = Line2D.new()
	health_bar.add_point(Vector2(-15, -28))
	health_bar.add_point(Vector2(15, -28))
	health_bar.default_color = Color(0, 1, 0)
	health_bar.width = 4
	add_child(health_bar)

	# Element Indicator
	element_indicator = Label.new()
	element_indicator.position = Vector2(-8, -44)
	element_indicator.add_theme_font_size_override("font_size", 12)
	element_indicator.visible = false
	add_child(element_indicator)

	# Status Indicator
	status_indicator = Node2D.new()
	status_indicator.position = Vector2(0, -36)
	add_child(status_indicator)


func setup(path_points: Array[Vector2], hp: int, spd: float) -> void:
	path = path_points
	health = hp
	max_health = hp
	speed = spd
	base_speed = spd
	position = path[0] if path.size() > 0 else Vector2.ZERO


func setup_extended(path_points: Array[Vector2], data: Dictionary) -> void:
	print("[Enemy] setup_extended script=", get_script().resource_path, " data=", data)
	path = path_points
	health = data.get("health", 100)
	max_health = health
	speed = data.get("speed", 80.0)
	base_speed = speed
	reward = data.get("reward", 10)
	enemy_type = data.get("type", "normal")

	element = String(data.get("element", "neutral")).to_lower()

	# Schatten-Defaults je nach Gegnerart
	if element == "neutral" or element == "":
		shadow_offset_y = 26.0
		shadow_base_scale = Vector2(1.1, 0.6)
	else:
		shadow_offset_y = 8.0
		shadow_base_scale = Vector2(1.0, 1.0)

	if shadow:
		shadow.position.y = shadow_offset_y
		shadow.scale = shadow_base_scale
		
	if shadow and (element == "neutral" or element == ""):
		shadow.scale = Vector2(1.1, 0.6)

	position = path[0] if path.size() > 0 else Vector2.ZERO

	# Sprite laden basierend auf Element
	_setup_sprite()

	# Größe basierend auf Gegner-Typ
	var type_scale: float = data.get("scale", 0.5)
	var final_scale := ENEMY_SCALE * (type_scale / 0.5)  # Normalisiert auf Basis-Scale

	if sprite:
		sprite.scale = Vector2(final_scale, final_scale)
		original_modulate = sprite.modulate

	if shadow:
		shadow.scale = Vector2(final_scale * 0.8, final_scale * 0.4)

	_update_element_indicator()


func _setup_sprite() -> void:
	if not sprite:
		return

	var elem := String(element if element != null else "neutral").to_lower()
	var sprite_path := ""
	print("[Enemy] element=", element, " path=", "res://assets/enemies/%s_enemy_level_1.png" % element)

	# Elementare Gegner: 1 Reihe, 4 Frames
	if elem != "" and elem != "neutral":
		sprite_path = "res://assets/enemies/%s_enemy_level_1.png" % elem
	else:
		# NEU: Normale Gegner nutzen jetzt das neue animierte Sheet
		sprite_path = "res://assets/enemies/normal_enemy_level_1.png"

	print("[Enemy] element=", elem, " sprite_path=", sprite_path, " exists=", ResourceLoader.exists(sprite_path))

	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
		sprite.visible = true

		if elem != "" and elem != "neutral":
			# Elementar: 4 Frames in einer Reihe
			sprite.hframes = 4
			sprite.vframes = 1
			anim_frame = clampi(anim_frame, 0, 3)
			sprite.frame = anim_frame
		else:
			# Normal: 3x4 (3 Frames pro Richtung)
			sprite.hframes = 3
			sprite.vframes = 4
			# Start: nach unten, Frame 0
			sprite.frame_coords = Vector2i(0, 0)
	else:
		push_warning("[Enemy] Sprite nicht gefunden: %s" % sprite_path)
		sprite.texture = null


func _calculate_element_color(base_color: Color) -> Color:
	if element == "neutral" or element == "":
		return base_color

	var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
	# Mische Basis-Farbe mit Element-Farbe
	return base_color.lerp(elem_color, 0.5)


func _update_element_indicator() -> void:
	if not element_indicator:
		return

	if element == "neutral" or element == "":
		element_indicator.visible = false
		return

	element_indicator.visible = true
	element_indicator.text = ElementalSystem.get_element_symbol(element) if ElementalSystem else element.substr(0, 1).to_upper()

	# Outline für bessere Sichtbarkeit
	element_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	element_indicator.add_theme_constant_override("outline_size", 2)


func _process(delta: float) -> void:
	# Hit-Flash abklingen
	if _resolved:
		return
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0 and sprite:
			sprite.modulate = original_modulate

	# Gestunned oder eingefroren?
	if stun_timer > 0:
		stun_timer -= delta
		_do_stun_wobble(delta)
		_update_shadow_fx(delta)
		return

	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			is_frozen = false
			if sprite:
				sprite.modulate = original_modulate
		_update_shadow_fx(delta)
		return

	_update_status_effects(delta)
	_move(delta)
	_update_health_bar()
	_update_animation(delta)
	_update_shadow_fx(delta)



func _update_animation(delta: float) -> void:
	if not sprite or sprite.texture == null:
		return

	# Normaler Gegner (3x4 Sheet)
	if element == "neutral" or element == "":
		anim_timer += delta
		if anim_timer >= ANIM_SPEED:
			anim_timer = 0.0
			anim_col = (anim_col + 1) % NORMAL_COLS
			sprite.frame_coords = Vector2i(anim_col, anim_row)
		return

	# Elementare Gegner (4 Frames, 1 Reihe) – dein altes Verhalten
	if sprite.hframes <= 1:
		walk_bob += delta * 12.0
		sprite.position.y = sin(walk_bob) * 2
		return

	anim_timer += delta
	if anim_timer >= ANIM_SPEED:
		anim_timer = 0.0
		anim_frame -= 1
		if anim_frame < 0:
			anim_frame = FRAME_COUNT - 1
		sprite.frame = anim_frame


func _do_stun_wobble(delta: float) -> void:
	wobble_time += delta * 20.0
	if sprite:
		sprite.rotation = sin(wobble_time) * 0.2


func _move(delta: float) -> void:
	if path_index >= path.size():
		_reach_end()
		return

	var current_speed := base_speed
	if slow_timer > 0:
		current_speed *= (1.0 - slow_amount)

	var target_pos := path[path_index]
	var direction := (target_pos - position).normalized()
	# Für normalen Gegner: Reihe anhand Bewegungsrichtung setzen
	if element == "neutral" or element == "":
		if abs(direction.x) > abs(direction.y):
			# Links/Rechts
			anim_row = 2 if direction.x > 0 else 1
		else:
			# Hoch/Runter
			anim_row = 0 if direction.y > 0 else 3
	position += direction * current_speed * delta

	# Sprite spiegeln basierend auf Bewegungsrichtung
	# Sprites schauen standardmäßig nach links, also flip wenn nach rechts
	if sprite and (element != "neutral" and element != "") and direction.length() > 0:
		sprite.flip_h = direction.x > 0

	if position.distance_to(target_pos) < 5:
		path_index += 1


func _reach_end() -> void:
	if _resolved:
		return
	_resolved = true
	GameState.enemy_reached_end()

	if VFX:
		VFX.screen_shake(8.0, 0.3)
		VFX.screen_flash(Color(1, 0, 0), 0.15)

	queue_free()

func _update_shadow_fx(delta: float) -> void:
	if not shadow:
		return

	# Basis
	var y := shadow_offset_y
	var scale := shadow_base_scale

	# Bobbing beim Laufen (nur wenn nicht stunned/frozen)
	if stun_timer <= 0.0 and not is_frozen:
		shadow_bob_t += delta * 8.0
		var bob := (sin(shadow_bob_t) + 1.0) * 0.5  # 0..1
		# leicht "atmen": minimal größer/kleiner
		scale *= Vector2(1.0 + bob * 0.08, 1.0 - bob * 0.08)

	# Freeze: Schatten kleiner & "näher" am Boden
	if is_frozen:
		scale *= Vector2(0.85, 0.85)
		y += 2.0

	# Stun: leichtes Zittern (Position + Mini-Scale wobble)
	if stun_timer > 0.0:
		shadow_stun_t += delta * 45.0
		y += sin(shadow_stun_t) * 0.8
		scale *= Vector2(1.0 + sin(shadow_stun_t * 0.7) * 0.03, 1.0)

	shadow.position.y = y
	shadow.scale = scale

func _update_status_effects(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_amount = 0.0
			if sprite:
				sprite.modulate = original_modulate

	if burn_timer > 0:
		burn_timer -= delta
		take_damage(int(burn_damage * delta), false, "fire")


# NEU: Damage mit Elementar-Multiplikator
func take_damage(amount: int, trigger_effects: bool = true, attacker_element: String = "") -> void:
	if _resolved:
		return
	var final_damage := amount
	var multiplier := 1.0

	# Elementar-Multiplikator berechnen
	if attacker_element != "" and ElementalSystem:
		multiplier = ElementalSystem.get_damage_multiplier(attacker_element, element)
		final_damage = int(amount * multiplier)

	health -= final_damage

	if trigger_effects:
		GameState.record_damage(final_damage)
		_do_hit_flash()

		# VFX spawnen
		if VFX:
			var is_crit := final_damage > damage_threshold_for_crit()
			var is_effective := multiplier > 1.0
			var is_resisted := multiplier < 1.0

			# Spezielle VFX für effektive/resistierte Treffer
			if is_effective:
				VFX.spawn_pixel_burst(position, attacker_element, 10)
				VFX.spawn_damage_number(position, final_damage, true, attacker_element)
			elif is_resisted:
				VFX.spawn_pixels(position, element, 4, 15.0)
				VFX.spawn_damage_number(position, final_damage, false, "")
			else:
				VFX.spawn_hit_effect(position, attacker_element if attacker_element != "" else "damage", is_crit)
				VFX.spawn_damage_number(position, final_damage, is_crit, attacker_element)

	if health <= 0:
		_die()


func damage_threshold_for_crit() -> int:
	return int(max_health * 0.5)


func _do_hit_flash() -> void:
	flash_timer = 0.1
	if sprite:
		sprite.modulate = Color.WHITE


func _die() -> void:
	if _resolved:
		return
	_resolved = true
	GameState.enemy_died(reward)
	Sound.play_coin()

	if VFX:
		VFX.spawn_death_effect(position, enemy_type)
		VFX.spawn_gold_number(position, reward)

		# Extra VFX für elementare Gegner
		if element != "neutral" and element != "":
			VFX.spawn_pixel_ring(position, element, 30.0)

		if enemy_type == "boss":
			VFX.screen_shake(12.0, 0.4)
			VFX.screen_flash(Color(1, 0.8, 0.3), 0.2)

	queue_free()


# === STATUS EFFEKTE ===

func apply_slow(amount: float, duration: float) -> void:
	if amount > slow_amount:
		slow_amount = amount
	slow_timer = maxf(slow_timer, duration)

	if sprite:
		sprite.modulate = original_modulate.lerp(Color(0.5, 0.5, 1.0), 0.5)

	if VFX:
		VFX.spawn_pixels(position, "ice", 4, 15.0)


func apply_burn(damage_per_second: int, duration: float) -> void:
	burn_damage = damage_per_second
	burn_timer = maxf(burn_timer, duration)

	_show_status_icon("burn")

	if VFX:
		VFX.spawn_pixels(position, "fire", 4, 15.0)


func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)
	wobble_time = 0.0

	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.5)

	if VFX:
		VFX.spawn_pixels(position, "air", 6, 20.0)


func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration

	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0)
		sprite.modulate.a = 0.7

	if VFX:
		VFX.spawn_pixel_ring(position, "ice", 25.0)


# === VISUALS ===

func _update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, -28))

	# Farbe basierend auf Element und HP
	var bar_color := Color(1 - health_percent, health_percent, 0)
	if element != "neutral" and element != "":
		var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
		bar_color = bar_color.lerp(elem_color, 0.3)
	health_bar.default_color = bar_color


func _show_status_icon(effect_type: String) -> void:
	for child in status_indicator.get_children():
		if child.name == effect_type:
			return

	var icon := Label.new()
	icon.name = effect_type
	icon.add_theme_font_size_override("font_size", 10)

	match effect_type:
		"burn": icon.text = "🔥"
		"slow": icon.text = "❄"
		"stun": icon.text = "⚡"

	status_indicator.add_child(icon)


func get_progress() -> float:
	if path.size() == 0:
		return 0.0
	return float(path_index) / path.size()


func get_remaining_health_percent() -> float:
	return float(health) / max_health


func get_element() -> String:
	return element
