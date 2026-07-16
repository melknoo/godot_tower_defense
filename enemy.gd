# enemy.gd
# Gegner mit Elementar-Typen, animierten Sprites und VFX
extends Node2D
class_name Enemy

var path: Array[Vector2] = []
var path_index := 0
var health := 85
var max_health := 100
var speed := 80.0
var base_speed := 80.0
var reward := 2
var enemy_type := "normal"
var tower_type_multipliers: Dictionary = {}
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
var element_indicator: RichTextLabel

# Animation - Alle Gegner: 4 Frames horizontal
var anim_timer := 0.0
var anim_frame := 3  # Start bei Frame 3, läuft rückwärts
const ANIM_SPEED := 0.15  # Sekunden pro Frame
const FRAME_COUNT := 4

# Sprite-Konstanten
const FRAME_SIZE := Vector2(16, 16)
const ENEMY_SCALE := 3.0

var walk_bob := 0.0
var wobble_time := 0.0

# Shadow FX
var shadow_offset_y := 8.0
var shadow_base_scale := Vector2.ONE
var shadow_bob_t := 0.0
var shadow_stun_t := 0.0

var collision_area: Area2D
var collision_shape: CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_create_collision()
	_create_visuals()


func _create_collision() -> void:
	"""Erstellt die Kollisions-Area für Traps und andere Detektionen"""
	collision_area = Area2D.new()
	collision_area.collision_layer = 2  # Enemy ist auf Layer 2
	collision_area.collision_mask = 0   # Enemies detekten nichts selbst
	add_child(collision_area)
	
	# Circle Shape für Kollision
	var shape := CircleShape2D.new()
	shape.radius = 12.0  # Angepasst an Enemy-Größe
	
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	collision_area.add_child(collision_shape)


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
	element_indicator = _get_or_create_rich_label("element_indicator", Vector2(-8, -50))
	#element_indicator.position = Vector2(-8, -44)
	element_indicator.add_theme_font_size_override("font_size", 12)
	element_indicator.visible = false

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
	path = path_points
	health = data.get("health", 100)
	max_health = health
	speed = data.get("speed", 80.0)
	base_speed = speed
	reward = data.get("reward", 10)
	enemy_type = data.get("type", "normal")
	element = String(data.get("element", "neutral")).to_lower()

	# Schatten-Defaults (einheitlich für alle Gegner)
	shadow_offset_y = 8.0
	shadow_base_scale = Vector2(1.0, 1.0)

	if shadow:
		shadow.position.y = shadow_offset_y
		shadow.scale = shadow_base_scale

	position = path[0] if path.size() > 0 else Vector2.ZERO

	# Sprite laden basierend auf Element
	_setup_sprite()
	_apply_type_visuals()

	# Größe basierend auf Gegner-Typ
	var type_scale: float = data.get("scale", 0.5)
	var final_scale := ENEMY_SCALE * (type_scale / 0.5)

	if sprite:
		sprite.scale = Vector2(final_scale, final_scale)
		original_modulate = sprite.modulate

	if shadow:
		shadow.scale = Vector2(final_scale * 0.8, final_scale * 0.4)
	_setup_tower_type_multipliers()


func _setup_tower_type_multipliers() -> void:
	# Jeder Gegner-Typ definiert Schwächen (>1.0) und Resistenzen (<1.0)
	# Nicht definierte Tower-Typen = 1.0 (neutral)
	match enemy_type:

		"tank":
			# Schwer gepanzert – Pfeile finden Schwachstellen, Schwerter prallen ab
			tower_type_multipliers = {
				"archer":  1.6,   # SCHWACH – Pfeile in Gelenke
				"sword":   0.65,  # STARK   – Rüstung blockt Hiebe
				"wizard":  0.8,   # leicht resistent
				"cannon":  1.0,
				"trapper": 1.0,
			}

		"swift":
			# Schnell und wendig – Schwerter erwischen ihn, Pfeile treffen nicht
			tower_type_multipliers = {
				"archer":  0.8,   # STARK   – zu flink für Pfeile
				"sword":   1.6,   # SCHWACH – Klinge trifft bei Nahkampf
				"wizard":  1.0,
				"cannon":  0.75,  # leicht resistent (zu klein als Ziel)
				"trapper": 1.25,  # Fallen halten ihn besonders gut
			}

		"ethereal":
			# Magisches Wesen – Magie trifft, physisch kaum greifbar
			tower_type_multipliers = {
				"archer":  0.7,   # RESISTENT – Pfeile gehen durch
				"sword":   0.7,   # RESISTENT – Klingen greifen nicht
				"wizard":  1.6,   # SCHWACH   – Magie trifft die Essenz
				"cannon":  0.65,  # RESISTENT – physische Explosion nutzlos
				"trapper": 0.75,
			}

		"brute":
			# Massiver Koloss – Kanone trifft hart, Magie verpufft
			tower_type_multipliers = {
				"archer":  1.0,
				"sword":   1.15,
				"wizard":  0.65,  # RESISTENT – magisch unempfindlich
				"cannon":  1.7,   # SCHWACH   – Explosivschaden ideal
				"trapper": 0.75,
			}

		"burrower":
			# Unterirdisch – Fallen sind tödlich, Fernkämpfer hoffnungslos
			tower_type_multipliers = {
				"archer":  0.75,   # RESISTENT – taucht kurz auf
				"sword":   0.75,   # RESISTENT – zu tief unten
				"wizard":  1.15,
				"cannon":  1.15,
				"trapper": 1.7,   # SCHWACH   – Fallen halten ihn an der Oberfläche
			}

		_:
			# "normal" und unbekannte Typen: alle 1.0
			tower_type_multipliers = {}


func _setup_sprite() -> void:
	if not sprite:
		return

	var elem := String(element if element != null else "neutral").to_lower()
	var sprite_path := ""

	# Sprite-Pfad basierend auf Element
	if elem != "" and elem != "neutral":
		sprite_path = "res://assets/enemies/%s_enemy_level_1.png" % elem
	else:
		sprite_path = "res://assets/enemies/normal_enemy_level_1.png"

	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
		sprite.visible = true
		# Alle Gegner: 4 Frames in einer Reihe
		sprite.hframes = 4
		sprite.vframes = 1
		anim_frame = clampi(anim_frame, 0, 3)
		sprite.frame = anim_frame
	else:
		push_warning("[Enemy] Sprite nicht gefunden: %s" % sprite_path)
		sprite.texture = null


func _apply_type_visuals() -> void:
	if not sprite:
		return

	match enemy_type:
		"tank":
			# Blau-grau getönt, etwas größer
			sprite.modulate = Color(0.7, 0.8, 1.1)
			sprite.scale *= 1.3

		"swift":
			# Grünlich, kleiner und flacher
			sprite.modulate = Color(0.7, 1.2, 0.7)
			sprite.scale *= 0.8
			sprite.scale.y *= 0.85  # etwas flacher

		"ethereal":
			# Lila + halbtransparent, leichtes Pulsieren
			sprite.modulate = Color(1.1, 0.6, 1.3, 0.75)
			sprite.scale *= 1.0
			# Pulsier-Tween für den Ghost-Effekt
			var tween := create_tween().set_loops()
			tween.tween_property(sprite, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
			tween.tween_property(sprite, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE)

		"brute":
			# Rot-orange getönt, deutlich größer und breiter
			sprite.modulate = Color(1.3, 0.6, 0.4)
			sprite.scale *= 1.6
			sprite.scale.x *= 1.15  # breiter

		"burrower":
			# Braun-erdfarben, dunkler
			sprite.modulate = Color(0.75, 0.55, 0.3)
			sprite.scale *= 0.9

		"boss":
			# Gold-gelb, groß, pulsierendes Leuchten
			sprite.modulate = Color(1.4, 1.1, 0.3)
			var tween := create_tween().set_loops()
			tween.tween_property(sprite, "modulate:v", 0.85, 0.6)
			tween.tween_property(sprite, "modulate:v", 1.0,  0.6)

		_:
			pass  # "normal" bleibt unverändert

	# original_modulate NACH den Änderungen setzen,
	# damit Hit-Flash korrekt zurückfedert
	original_modulate = sprite.modulate


func _update_element_indicator() -> void:
	if not element_indicator:
		return

	if element == "neutral" or element == "":
		element_indicator.visible = false
		return

	element_indicator.visible = true
	element_indicator.text = ElementalSystem.get_element_bb(element, 18) if ElementalSystem else element.substr(0, 1).to_upper()
	element_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	element_indicator.add_theme_constant_override("outline_size", 2)


func _process(delta: float) -> void:
	if _resolved:
		return
	
	# Hit-Flash abklingen
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

	# Fallback für Sprites ohne Animation
	if sprite.hframes <= 1:
		walk_bob += delta * 12.0
		sprite.position.y = sin(walk_bob) * 2
		return

	# Alle Gegner: 4 Frames, rückwärts animiert
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
	position += direction * current_speed * delta

	# Sprite spiegeln basierend auf Bewegungsrichtung
	if sprite and direction.length() > 0:
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

	var y := shadow_offset_y
	var scale := shadow_base_scale

	# Bobbing beim Laufen (nur wenn nicht stunned/frozen)
	if stun_timer <= 0.0 and not is_frozen:
		shadow_bob_t += delta * 8.0
		var bob := (sin(shadow_bob_t) + 1.0) * 0.5
		scale *= Vector2(1.0 + bob * 0.08, 1.0 - bob * 0.08)

	# Freeze: Schatten kleiner & "näher" am Boden
	if is_frozen:
		scale *= Vector2(0.85, 0.85)
		y += 2.0

	# Stun: leichtes Zittern
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


func take_damage(amount: int, apply_elemental: bool = false, attacker_element: String = "",
		is_crit: bool = false, attacker_tower_type: String = "") -> void:
	if health <= 0:
		return

	var final_damage := amount
	var elemental_mult := 1.0
	var tower_mult := 1.0

	# --- Elementar-Multiplikator ---
	if apply_elemental and attacker_element != "" and element != "" and element != "neutral":
		if ElementalSystem:
			elemental_mult = ElementalSystem.get_damage_multiplier(attacker_element, element)

	# --- Tower-Typ-Multiplikator ---
	if attacker_tower_type != "" and tower_type_multipliers.has(attacker_tower_type):
		tower_mult = tower_type_multipliers[attacker_tower_type]

	# Beide kombinieren (additive wäre zu schwach, multiplikativ kann extrem werden –
	# daher: Elemental voll, Tower-Mult leicht gedämpft wenn beide aktiv)
	var combined_mult: float
	if elemental_mult != 1.0 and tower_mult != 1.0:
		# Beide aktiv: nicht voll multiplizieren, sondern mitteln
		combined_mult = (elemental_mult * tower_mult + elemental_mult + tower_mult) / 3.0
	else:
		combined_mult = elemental_mult * tower_mult

	# Charakter-Passive (Gezeitenhüter): verlangsamte/gefrorene Gegner nehmen mehr Turmschaden
	if attacker_tower_type != "" and (slow_timer > 0.0 or is_frozen) and AbilitySystem:
		combined_mult *= AbilitySystem.get_passive_modifier("slowed_tower_damage_mult", 1.0)

	final_damage = int(amount * combined_mult)

	health -= final_damage
	_update_health_bar()

	if flash_timer <= 0:
		_do_hit_flash()

	# --- VFX mit kombiniertem Ergebnis ---
	if VFX:
		var is_effective := combined_mult > 1.2
		var is_resisted  := combined_mult < 0.8

		if is_effective:
			VFX.spawn_pixel_burst(position, attacker_element if attacker_element != "" else "crit", 10)
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


func _try_drop_item() -> void:
	if not ItemSystem:
		return
	
	var item := ItemSystem.try_drop_item(enemy_type, position, element)
	
	if item.is_empty():
		return
	
	# Item-Drop spawnen
	var drop_scene := preload("res://item_drop.tscn") if ResourceLoader.exists("res://item_drop.tscn") else null
	
	if drop_scene:
		var drop := drop_scene.instantiate()
		drop.position = position
		drop.setup(item)
		get_parent().call_deferred("add_child", drop)
	else:
		# Fallback: Direkt als Node erstellen
		var drop := ItemDrop.new()
		drop.position = position
		get_parent().call_deferred("add_child", drop)
		drop.call_deferred("setup", item)
	
	print("[Enemy] Item gedroppt: %s (%s)" % [item.get("name", "?"), item.get("rarity", "?")])


func _die() -> void:
	if _resolved:
		return
	_resolved = true
	
	# Gold-Bonus durch Upgrades
	var bonus_gold := 0
	if UpgradeSystem:
		bonus_gold = UpgradeSystem.get_enemy_gold_bonus()
	
	var total_reward := reward + bonus_gold
	total_reward = GameState.enemy_died(total_reward, enemy_type)
	Sound.play_coin()
	
	# === NEU: Item Drop ===
	_try_drop_item()
	
	if VFX:
		VFX.spawn_death_effect(position, enemy_type)
		VFX.spawn_gold_number(position, total_reward)

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
	# Charakter-Passive (Aschenweberin): Empfänger-Hook deckt alle Brand-Quellen ab
	if AbilitySystem:
		duration *= AbilitySystem.get_passive_modifier("burn_duration_mult", 1.0)
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

	var bar_color := Color(1 - health_percent, health_percent, 0)
	if element != "neutral" and element != "":
		var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
		bar_color = bar_color.lerp(elem_color, 0.3)
	health_bar.default_color = bar_color

func _get_or_create_rich_label(node_name: String, default_pos: Vector2, min_width: float = 120.0) -> RichTextLabel:
	var label: RichTextLabel = get_node_or_null(node_name) as RichTextLabel
	if not label:
		label = RichTextLabel.new()
		label.name = node_name
		label.position = default_pos
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size = Vector2(min_width, 20)
		add_child(label)
	return label

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
