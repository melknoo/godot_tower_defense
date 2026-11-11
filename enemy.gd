# enemy.gd
# Gegner mit Elementar-Typen, animierten Sprites und VFX
extends Node2D
class_name Enemy

var path: Array[Vector2] = []
var path_index := 0
var path_terrain: Array[String] = []   # Wegzone je Pfadfeld (TerrainData), "" = Erdweg

# --- Gegner-Verhalten: jeder Typ verlangt genau eine Antwort ---
const TANK_ARMOR_MIN_SHARE := 0.25    # Ruestung laesst mindestens 25 % jedes Treffers durch
const ETHEREAL_PHYSICAL_MULT := 0.5   # elementlose Treffer (ungravierte Basistuerme)
const BRUTE_CC_MULT := 0.5            # Koloss: Kontrolleffekte halb so lang
const BURROW_SURFACE_TIME := 2.5      # Graeber: so lange oben ...
const BURROW_UNDER_TIME := 1.5        # ... so lange unter der Erde
const DIGGABLE_ZONES := ["", "mud"]   # Erdweg und Schlamm; in Furt/Asche/Windpass bleibt er oben
const BOSS_PHASE_HP := 0.5
const BOSS_PHASE_SPEED_MULT := 1.15
const ELEMENTAL_ATTACKS := ["water", "fire", "earth", "air", "ice", "steam", "lava", "nature"]
var armor := 0
var is_burrowed := false
var burrow_timer := 0.0
var boss_phase := 1
var health := 85
var max_health := 100
var speed := 80.0
var base_speed := 80.0
var reward := 2
var enemy_type := "normal"
var tower_type_multipliers: Dictionary = {}
var element := "neutral"
var _resolved := false
# Letzter Turm, der Schaden verursacht hat (für Kill-Zuordnung, Part G).
# null = nicht zuordenbare Quelle (Ability, Item, Burn-DoT, ...)
var _last_damage_source: Node2D = null

# Status-Effekte
var slow_amount := 0.0
var slow_timer := 0.0
var burn_damage := 0
var burn_timer := 0.0
# Brand tickt in festen Intervallen, nicht pro Frame: `int(burn_damage * delta)` waere
# bei 60 FPS jeden Frame 0 und der Bruchteil ginge verloren (Brand machte nie Schaden).
const BURN_TICK_INTERVAL := 0.5
var burn_tick_timer := 0.0
var stun_timer := 0.0
var is_frozen := false
var freeze_timer := 0.0
var confuse_timer := 0.0

# Dampf-Effekt: konfuse Gegner nehmen mehr Schaden
const CONFUSE_DAMAGE_MULT := 1.25

# Hard-CC Diminishing Returns (geteilt zwischen Freeze & Stun/Root)
var cc_dr_stacks := 0
var cc_dr_reset_timer := 0.0
const CC_DR_FALLOFF := 0.55            # jede weitere Hard-CC-Anwendung ~55% der vorigen Dauer
const CC_DR_RESET := 3.5               # Sekunden ohne neue Hard-CC bis DR zurücksetzt
const CC_MIN_DURATION := 0.25          # darunter: kein Hard-CC, stattdessen Slow-Fallback
const CC_FALLBACK_SLOW := 0.5          # Slow-Stärke des Fallbacks (50%)
const CC_FALLBACK_SLOW_DURATION := 1.5

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

# Sprite-Konstanten: Welt-Pixelart laeuft einheitlich x4 (16-px-Art = eine 64-px-Zelle).
# Bosse sind groessere Quell-Sprites (~40 px) und laufen deshalb eine Stufe kleiner.
const FRAME_SIZE := Vector2(16, 16)
const ENEMY_SCALE := 4.0
const BOSS_SCALE := 3.0
const BOSS_FRAMES := {"neutral": 5, "fire": 5, "water": 5, "earth": 6, "air": 5}
const ELEMENT_TINT := 0.25   # Element als leichte Toenung + farbiger Schatten
var frame_count := 4

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
	element_indicator.add_theme_font_size_override("font_size", 18)
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
	armor = int(data.get("armor", 0))
	burrow_timer = BURROW_SURFACE_TIME

	# Schatten-Defaults (einheitlich für alle Gegner)
	shadow_offset_y = 8.0
	shadow_base_scale = Vector2(1.0, 1.0)

	if shadow:
		shadow.position.y = shadow_offset_y
		shadow.scale = shadow_base_scale

	position = path[0] if path.size() > 0 else Vector2.ZERO

	# Sprite pro Gegnertyp, Element als Toenung/Schatten. Groesse kommt aus der
	# Silhouette, nicht aus Skalierung - alle Gegner laufen in derselben Pixeldichte.
	_setup_sprite()
	_apply_type_visuals()

	var final_scale := BOSS_SCALE if enemy_type == "boss" else ENEMY_SCALE
	if sprite:
		sprite.scale = Vector2(final_scale, final_scale)
		original_modulate = sprite.modulate
		_place_health_bar()

	if shadow:
		var shadow_w := 4.0 if enemy_type == "boss" else 2.0
		shadow_base_scale = Vector2(shadow_w, shadow_w * 0.6)
		shadow.scale = shadow_base_scale
		if sprite and sprite.texture:
			# Schatten an die Fuesse statt in die Koerpermitte
			shadow_offset_y = float(sprite.texture.get_height()) * sprite.scale.y * 0.5 - 6.0
			shadow.position.y = shadow_offset_y
		if element != "neutral" and element != "" and ElementalSystem:
			var c := ElementalSystem.get_element_color(element)
			shadow.color = Color(c.r, c.g, c.b, 0.45)
	_setup_tower_type_multipliers()

	if enemy_type == "boss":
		_announce_boss()


# Ein Boss ist der wichtigste Moment einer Welle und soll auch so ankommen:
# Banner, Wackeln, roter Blitz - und eine eigene Leiste oben im HUD.
func _announce_boss() -> void:
	if VFX:
		VFX.spawn_status_text(position + Vector2(0, -60), "BOSS", Color(1.0, 0.75, 0.2))
		VFX.spawn_pixel_ring(position, "fire", 90.0)
		VFX.screen_shake(6.0, 0.35)
		VFX.screen_flash(Color(0.9, 0.3, 0.15, 0.28), 0.18)
	if Sound:
		Sound.play_explosion()

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar(self)


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
	if elem == "":
		elem = "neutral"
	var sprite_path := ""

	# Gegner: eigenes Monster pro Typ (4 Lauf-Frames). Boss: eigener Riese pro Element.
	if enemy_type == "boss":
		sprite_path = "res://assets/enemies/boss_%s.png" % elem
		frame_count = BOSS_FRAMES.get(elem, 5)
	else:
		sprite_path = "res://assets/enemies/enemy_%s.png" % enemy_type
		frame_count = 4
	if not ResourceLoader.exists(sprite_path):
		sprite_path = "res://assets/enemies/enemy_normal.png"
		frame_count = 4

	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
		sprite.visible = true
		sprite.hframes = frame_count
		sprite.vframes = 1
		anim_frame = clampi(anim_frame, 0, frame_count - 1)
		sprite.frame = anim_frame
	else:
		push_warning("[Enemy] Sprite nicht gefunden: %s" % sprite_path)
		sprite.texture = null


func _apply_type_visuals() -> void:
	if not sprite:
		return

	# Der Typ steckt im Sprite; hier nur noch die Element-Toenung und zwei Typ-Effekte.
	sprite.modulate = Color.WHITE
	if element != "neutral" and element != "" and ElementalSystem:
		sprite.modulate = Color.WHITE.lerp(ElementalSystem.get_element_color(element), ELEMENT_TINT)

	match enemy_type:
		"ethereal":
			# Halbtransparent mit leichtem Pulsieren (Geist)
			sprite.modulate.a = 0.75
			var tween := create_tween().set_loops()
			tween.tween_property(sprite, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
			tween.tween_property(sprite, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE)

		"boss":
			# Pulsierendes Leuchten
			var tween := create_tween().set_loops()
			tween.tween_property(sprite, "modulate:v", 0.85, 0.6)
			tween.tween_property(sprite, "modulate:v", 1.0,  0.6)

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
			if is_burrowed:
				sprite.modulate.a = 0.25

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
	_update_burrow(delta)
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
			anim_frame = frame_count - 1
		sprite.frame = anim_frame


func _do_stun_wobble(delta: float) -> void:
	wobble_time += delta * 20.0
	if sprite:
		sprite.rotation = sin(wobble_time) * 0.2


# Tuerme zielen nur auf Gegner ueber der Erde (Graeber unten sind unsichtbar fuer sie;
# Fallen, Brand und Flaechen-Faehigkeiten treffen trotzdem).
func is_targetable() -> bool:
	return not is_burrowed and health > 0


# Graeber: wechselt auf grabbarem Boden zwischen oben und unten; in Furt, Asche und
# Windpass muss er auftauchen - dort und mit Fallen ist er zu fassen.
func _update_burrow(delta: float) -> void:
	if enemy_type != "burrower":
		return
	var can_dig := get_current_zone() in DIGGABLE_ZONES
	burrow_timer -= delta
	if is_burrowed and (not can_dig or burrow_timer <= 0.0):
		_set_burrowed(false)
		burrow_timer = BURROW_SURFACE_TIME
	elif not is_burrowed and can_dig and burrow_timer <= 0.0:
		_set_burrowed(true)
		burrow_timer = BURROW_UNDER_TIME


func _set_burrowed(value: bool) -> void:
	is_burrowed = value
	if sprite:
		sprite.modulate.a = 0.25 if value else original_modulate.a
	if health_bar:
		health_bar.visible = not value
		health_bar_bg.visible = not value
	if VFX:
		VFX.spawn_pixels(position, "earth", 6, 18.0)


# Boss bei halber Lebensenergie: wechselt ins Element, das den bisherigen Konter
# schlaegt, und wird schneller. Wer sich auf eine Antwort verlassen hat, muss umdenken.
func _enter_boss_phase_two() -> void:
	boss_phase = 2
	var new_elem := ""
	if ElementalSystem:
		if element == "" or element == "neutral":
			new_elem = ElementalSystem.ELEMENTAL_TYPES[randi() % ElementalSystem.ELEMENTAL_TYPES.size()]
		else:
			new_elem = String(ElementalSystem.get_effective_element(ElementalSystem.get_effective_element(element)))
	if new_elem != "" and new_elem != "neutral":
		element = new_elem
		if sprite:
			sprite.modulate = Color.WHITE.lerp(ElementalSystem.get_element_color(element), ELEMENT_TINT * 2.0)
			original_modulate = sprite.modulate
		if shadow:
			var c := ElementalSystem.get_element_color(element)
			shadow.color = Color(c.r, c.g, c.b, 0.55)
		_update_element_indicator()
	base_speed *= BOSS_PHASE_SPEED_MULT
	if VFX:
		var label := "PHASE 2 · %s" % ElementalSystem.get_element_display_name(element).to_upper() if ElementalSystem else "PHASE 2"
		VFX.spawn_status_text(position + Vector2(0, -80), label, Color(1.0, 0.45, 0.3))
		VFX.spawn_pixel_ring(position, element if element != "" else "fire", 110.0)
		VFX.screen_shake(5.0, 0.3)


# Zone des Pfadfelds, auf dem der Gegner gerade steht. path[i] ist die Mitte von
# Pfadfeld i; zwischen zwei Wegpunkten zaehlt das naehere Feld.
func get_current_zone() -> String:
	if path_terrain.is_empty() or path.is_empty():
		return ""
	var i := clampi(path_index - 1, 0, path.size() - 1)
	if path_index < path.size() and position.distance_squared_to(path[path_index]) < position.distance_squared_to(path[i]):
		i = path_index
	return path_terrain[i] if i < path_terrain.size() else ""


func _move(delta: float) -> void:
	if path_index >= path.size():
		_reach_end()
		return

	var current_speed := base_speed
	if slow_timer > 0:
		current_speed *= (1.0 - slow_amount)
	current_speed *= TerrainData.speed_mult(get_current_zone())

	var target_pos := path[path_index]
	var to_target := target_pos - position
	var direction := to_target.normalized()
	var step := current_speed * delta

	# Sprite spiegeln basierend auf Bewegungsrichtung
	if sprite and direction.length() > 0:
		sprite.flip_h = direction.x > 0

	# Schritt auf die Restdistanz klemmen: bei Fast-Forward und schnellen Gegnern ist ein
	# Frame-Schritt groesser als der 5-px-Fangradius, der Gegner pendelte dann um den Wegpunkt.
	if step >= to_target.length() or to_target.length() < 5:
		position = target_pos
		path_index += 1
	else:
		position += direction * step


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
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer += BURN_TICK_INTERVAL
			# maxi(1, ...) haelt auch kleine Brandwerte wirksam
			take_damage(maxi(1, roundi(burn_damage * BURN_TICK_INTERVAL)), false, "fire", false, "", 1.0, null, true)
		if burn_timer <= 0.0:
			_hide_status_icon("burn")

	if confuse_timer > 0:
		confuse_timer -= delta
		if confuse_timer <= 0 and sprite and slow_timer <= 0 and not is_frozen:
			sprite.modulate = original_modulate

	# Hard-CC Diminishing Returns zurücksetzen, wenn der Gegner lange genug CC-frei war.
	# Läuft nur außerhalb von Freeze/Stun (die returnen in _process vorher).
	if cc_dr_reset_timer > 0.0:
		cc_dr_reset_timer -= delta
		if cc_dr_reset_timer <= 0.0:
			cc_dr_stacks = 0


# Gibt den tatsächlich zugefügten Schaden zurück (nach Multiplikatoren, gekappt auf
# die verbleibenden HP). Bestehende Aufrufer, die den Rückgabewert ignorieren, bleiben gültig.
func take_damage(amount: int, apply_elemental: bool = false, attacker_element: String = "",
		is_crit: bool = false, attacker_tower_type: String = "", bonus_mult: float = 1.0,
		source_tower: Node2D = null, is_dot: bool = false) -> int:
	if health <= 0:
		return 0

	# Letzten Verursacher merken - auch bewusst auf null, damit ein Ability-/Item-Kill
	# nicht fälschlich dem zuletzt treffenden Turm gutgeschrieben wird.
	_last_damage_source = source_tower if is_instance_valid(source_tower) else null

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

	# Meisterschaft: zustandsabhängige Verwundbarkeit (control/fire/earth-Schwellen) für Turmschaden
	if attacker_tower_type != "" and SynergySystem:
		combined_mult *= SynergySystem.get_state_damage_mult(self)

	# Konfuse Gegner (Dampf) sind verwundbarer
	if confuse_timer > 0.0:
		combined_mult *= CONFUSE_DAMAGE_MULT

	# Wegzone: Zonenelement verstaerkt, das von ihm geschlagene Element gedaempft.
	# Gilt fuer jede Quelle mit Element (Tuerme, Brand, Fallen, Abilities).
	combined_mult *= TerrainData.damage_mult(attacker_element, get_current_zone())

	# Aetherisch: elementlose Treffer (ungravierte Basistuerme) gleiten zur Haelfte ab
	if enemy_type == "ethereal" and not (attacker_element in ELEMENTAL_ATTACKS):
		combined_mult *= ETHEREAL_PHYSICAL_MULT

	final_damage = int(amount * combined_mult * bonus_mult)

	# Panzer: fester Abzug pro Treffer. Grosse Einzeltreffer (Kanone, Erde) und Brand
	# (DoT ignoriert Ruestung) lohnen sich, viele kleine Kettentreffer nicht.
	if armor > 0 and not is_dot and final_damage > 0:
		final_damage = maxi(final_damage - armor, ceili(final_damage * TANK_ARMOR_MIN_SHARE))

	# Real ausgeteilter Schaden: nie negativ und nie mehr als die verbleibenden HP
	var dealt := clampi(final_damage, 0, health)

	health -= final_damage
	_update_health_bar()

	if enemy_type == "boss" and boss_phase == 1 and health > 0 and health <= max_health * BOSS_PHASE_HP:
		_enter_boss_phase_two()

	GameState.record_damage(dealt)

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
	else:
		Sound.play_hit()

	return dealt


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

	# Kill dem letzten Verursacher-Turm gutschreiben (durch _resolved genau einmal)
	if is_instance_valid(_last_damage_source) and _last_damage_source.has_method("register_kill"):
		_last_damage_source.register_kill()

	# Gold-Bonus durch Upgrades
	var bonus_gold := 0
	if UpgradeSystem:
		bonus_gold = UpgradeSystem.get_enemy_gold_bonus()
	
	var total_reward := reward + bonus_gold
	total_reward = GameState.enemy_died(total_reward, enemy_type)
	Sound.play_enemy_death()
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

# Koloss: alle Kontrolleffekte wirken halb so lang
func _cc_duration_mult() -> float:
	return BRUTE_CC_MULT if enemy_type == "brute" else 1.0


func apply_slow(amount: float, duration: float) -> void:
	duration *= _cc_duration_mult()
	# Charakter-Passive (Kryomant): Empfaenger-Hook deckt alle Slow-Quellen ab.
	# minf(), damit eine Passive den Gegner nie komplett anhaelt.
	if AbilitySystem:
		amount = minf(amount * AbilitySystem.get_passive_modifier("slow_strength_mult", 1.0), 0.85)
	if amount > slow_amount:
		slow_amount = amount
	slow_timer = maxf(slow_timer, duration)

	if sprite:
		sprite.modulate = original_modulate.lerp(Color(0.5, 0.5, 1.0), 0.5)

	if VFX:
		VFX.spawn_pixels(position, "ice", 4, 15.0)


func apply_burn(damage_per_second: int, duration: float) -> void:
	# Charakter-Passiven (Aschenweberin: Dauer, Pyromant: Schaden) - der Empfaenger-Hook
	# deckt alle Brand-Quellen ab: Tuerme, Fallen, Abilities und Item-Procs.
	if AbilitySystem:
		duration *= AbilitySystem.get_passive_modifier("burn_duration_mult", 1.0)
		damage_per_second = int(round(
			damage_per_second * AbilitySystem.get_passive_modifier("burn_damage_mult", 1.0)
		))
	# Aschefeld: Brand haelt laenger
	duration *= TerrainData.burn_duration_mult(get_current_zone())
	# Frischer Brand startet den Tick-Zyklus neu; ein laufender behaelt seinen Rhythmus
	if burn_timer <= 0.0:
		burn_tick_timer = BURN_TICK_INTERVAL
	burn_damage = damage_per_second
	burn_timer = maxf(burn_timer, duration)

	_show_status_icon("burn")

	if VFX:
		VFX.spawn_pixels(position, "fire", 4, 15.0)


# Reduziert eine Hard-CC-Dauer nach DR-Stacks und aktualisiert den State.
func _diminished_cc_duration(duration: float) -> float:
	var factor: float = pow(CC_DR_FALLOFF, cc_dr_stacks)
	cc_dr_reset_timer = CC_DR_RESET
	cc_dr_stacks += 1
	return duration * factor


func apply_stun(duration: float) -> void:
	var eff := _diminished_cc_duration(duration * _cc_duration_mult())
	if eff < CC_MIN_DURATION:
		# Zu stark reduziert -> Slow-Fallback statt Stun
		apply_slow(CC_FALLBACK_SLOW, CC_FALLBACK_SLOW_DURATION)
		return

	stun_timer = maxf(stun_timer, eff)
	wobble_time = 0.0

	if sprite:
		sprite.modulate = Color(1.0, 1.0, 0.5)

	if VFX:
		VFX.spawn_pixels(position, "air", 6, 20.0)


func apply_confuse(duration: float) -> void:
	confuse_timer = maxf(confuse_timer, duration * _cc_duration_mult())

	if sprite:
		sprite.modulate = original_modulate.lerp(Color(0.9, 0.7, 1.0), 0.5)

	if VFX:
		VFX.spawn_pixels(position, "steam", 5, 18.0)


func apply_freeze(duration: float) -> void:
	var eff := _diminished_cc_duration(duration * _cc_duration_mult())
	if eff < CC_MIN_DURATION:
		# Zu stark reduziert -> Slow-Fallback statt Freeze (Eis bleibt nützlich)
		apply_slow(CC_FALLBACK_SLOW, CC_FALLBACK_SLOW_DURATION)
		return

	is_frozen = true
	# maxf: ein kurzer DR-Freeze darf einen noch laufenden längeren nicht abschneiden
	freeze_timer = maxf(freeze_timer, eff)

	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0)
		sprite.modulate.a = 0.7

	if VFX:
		VFX.spawn_pixel_ring(position, "ice", 25.0)


# === VISUALS ===

# Lebensleiste knapp ueber dem Sprite - Bosse sind hoeher als normale Gegner
var health_bar_y := -40.0


func _place_health_bar() -> void:
	if not sprite or not sprite.texture:
		return
	var sprite_h := float(sprite.texture.get_height()) * sprite.scale.y
	health_bar_y = -sprite_h * 0.5 - 4.0
	health_bar_bg.set_point_position(0, Vector2(-15, health_bar_y))
	health_bar_bg.set_point_position(1, Vector2(15, health_bar_y))
	health_bar.set_point_position(0, Vector2(-15, health_bar_y))
	status_indicator.position.y = health_bar_y - 8.0


func _update_health_bar() -> void:
	var health_percent := float(health) / max_health
	health_bar.set_point_position(1, Vector2(-15 + 30 * health_percent, health_bar_y))

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

func _hide_status_icon(effect_type: String) -> void:
	var icon := status_indicator.get_node_or_null(effect_type)
	if icon:
		icon.queue_free()


const STATUS_ICONS := {
	"burn": "res://assets/icons/element_fire.png",
	"slow": "res://assets/icons/element_ice.png",
	"stun": "res://assets/icons/element_lightning.png",
}


func _show_status_icon(effect_type: String) -> void:
	for child in status_indicator.get_children():
		if child.name == effect_type:
			return

	# 16-px-Pixelicons statt Emoji (die kamen aus einer Fallback-Schrift in fremder
	# Pixeldichte). x2, ganzzahlig wie alle UI-Overlays.
	var icon_path: String = STATUS_ICONS.get(effect_type, "")
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return
	var icon := Sprite2D.new()
	icon.name = effect_type
	icon.texture = load(icon_path)
	icon.scale = Vector2(2, 2)
	icon.position.x = status_indicator.get_child_count() * 34.0
	status_indicator.add_child(icon)


func get_progress() -> float:
	if path.size() == 0:
		return 0.0
	return float(path_index) / path.size()


func get_remaining_health_percent() -> float:
	return float(health) / max_health


func get_element() -> String:
	return element
