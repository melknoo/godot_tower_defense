# tower.gd
# Tower mit Elemental Engraving, Upgrades, Spezialeffekten und Blocked-Status
extends Node2D
class_name Tower

var tower_type := "archer"
var tower_range := 150.0
var fire_rate := 1.0
var damage := 20
var splash_radius := 0.0
var level := 0
var attack_type := "projectile"
var engraved_element := ""
var min_range := 0.0
var min_range_circle: Line2D = null

# Trapper-spezifisch
var active_traps: Array[Node2D] = []
var max_traps := 2
var trap_duration := 15.0

# Aura-spezifisch
var aura_range := 0.0
var buff_strength := 0.0
var affected_towers: Array[Node2D] = []
var aura_visual: Line2D = null
var aura_buff_type := ""

# Spezialeffekte
var special_type := ""
var slow_amount := 0.0
var burn_damage := 0
var stun_chance := 0.0
var chain_targets := 0
var base_crit_chance := 0.0

var bullet_scene: PackedScene
var fire_timer := 0.0
var target: Node2D = null

# Blocked Status (Turm steht auf Pfad)
var is_blocked := false
var blocked_overlay: ColorRect
var blocked_pulse_tween: Tween

# Visuals
var range_circle: Line2D
var turret: Node2D
var sprite: Sprite2D
var level_indicator: Node2D
var selection_corners: Node2D
var selection_tween: Tween
var engraving_indicator: RichTextLabel

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

# Equipment
var equipped_items: Array = [{}, {}]  # 2 Slots
var item_indicators: Array[Node2D] = []

# Item-modifizierte Stats (separat von Basis-Stats)
var base_damage := 20
var base_range := 150.0
var base_fire_rate := 1.0
var base_splash := 0.0

const ISOLATION_RADIUS := 350.0

func _get_stat_value(data: Dictionary, key: String, default_val):
	"""Helper um Werte aus Arrays oder direkte Werte zu extrahieren"""
	var val = data.get(key, default_val)
	if val is Array and val.size() > 0:
		return val[0]
	return val if val != null else default_val

func is_isolated() -> bool:
	if not is_inside_tree():
		return false
	
	var towers := get_tree().get_nodes_in_group("towers")
	for other in towers:
		if other == self:
			continue
		var dist := position.distance_to(other.position)
		if dist <= ISOLATION_RADIUS:
			return false
	
	return true



func _ready() -> void:
	add_to_group("towers")
	bullet_scene = preload("res://bullet.tscn")
	_load_corner_textures()
	_create_visuals()
	_update_visuals()
	Sound.play_place()
	if VFX:
		VFX.spawn_place_effect(position, tower_type)
	call_deferred("_recalculate_after_ready")

func _load_corner_textures() -> void:
	if corners_loaded:
		return
	var base_path := "res://assets/ui/"
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		var path := base_path + "selection_%s_corner.png" % corner
		if ResourceLoader.exists(path):
			corner_textures[corner] = load(path)
	corners_loaded = true

func _recalculate_after_ready() -> void:
	if base_damage > 0:  # Nur wenn Tower schon setup wurde
		_apply_upgrade_bonuses()
		_apply_item_bonuses()
		_update_isolation_visual()
		print("[Tower %s] Stats nach _ready recalculated - isolated=%s, damage=%d" % [tower_type, is_isolated(), damage])

func _apply_upgrade_bonuses() -> void:
	if not UpgradeSystem:
		return
	
	var elem := get_effective_element()
	var isolated := is_isolated()
	
	# Damage Multiplikator
	var damage_mult := UpgradeSystem.get_damage_multiplier(tower_type, elem)
	if isolated:
		damage_mult *= UpgradeSystem.get_isolated_damage_multiplier()
	
	# NEU: Aura-Buffs von anderen Türmen
	var aura_buffs := _collect_aura_buffs()
	if aura_buffs.has("damage_mult"):
		damage_mult *= (1.0 + aura_buffs["damage_mult"])
	
	damage = int(float(base_damage) * damage_mult)
	
	# Range Multiplikator
	var range_mult := UpgradeSystem.get_range_multiplier(tower_type)
	if isolated:
		range_mult *= UpgradeSystem.get_isolated_range_multiplier()
	
	if aura_buffs.has("range_mult"):
		range_mult *= (1.0 + aura_buffs["range_mult"])
	
	tower_range = base_range * range_mult
	
	# Fire Rate Multiplikator
	var fire_rate_mult := UpgradeSystem.get_fire_rate_multiplier(tower_type)
	
	if aura_buffs.has("fire_rate_mult"):
		fire_rate_mult += aura_buffs["fire_rate_mult"]
	
	fire_rate = base_fire_rate / (1.0 + fire_rate_mult - 1.0)
	
	# Splash
	if base_splash > 0:
		var splash_mult := UpgradeSystem.get_splash_multiplier()
		splash_radius = base_splash * splash_mult
	
	# Element-spezifische Boni
	if elem != "":
		slow_amount += UpgradeSystem.get_slow_bonus(elem)
		stun_chance += UpgradeSystem.get_stun_bonus(elem)
		chain_targets += UpgradeSystem.get_chain_bonus(elem)
	
	# NEU: Crit von Aura
	if aura_buffs.has("crit_chance"):
		base_crit_chance += aura_buffs["crit_chance"]


func _collect_aura_buffs() -> Dictionary:
	"""Sammelt alle Aura-Buffs die diesen Turm betreffen"""
	var combined_buffs := {}
	
	# ✅ Check ob Tower schon im Tree ist
	if not is_inside_tree():
		return combined_buffs
	
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if tower.attack_type != "none" or tower.special_type != "aura":
			continue
		
		var dist := position.distance_to(tower.position)
		if dist > tower.aura_range:
			continue
		
		# Sammle Buffs von diesem Aura-Turm
		var buffs: Dictionary = tower.get_aura_buffs() if tower.has_method("get_aura_buffs") else {}
		
		for key in buffs:
			if not combined_buffs.has(key):
				combined_buffs[key] = 0.0
			combined_buffs[key] += buffs[key]
	
	return combined_buffs


func _update_isolation_visual() -> void:
	if not is_inside_tree():
		return
	
	# Suche bestehenden Indicator
	var indicator := get_node_or_null("IsolationIndicator")
	
	var currently_isolated := is_isolated()
	var has_perk := UpgradeSystem and UpgradeSystem.get_upgrade_stacks("isolated_damage") > 0
	
	if currently_isolated and has_perk:
		if not indicator:
			indicator = Node2D.new()
			indicator.name = "IsolationIndicator"
			add_child(indicator)
			
			# Leuchtender Ring mit korrektem ISOLATION_RADIUS
			var circle := Line2D.new()
			circle.width = 2
			circle.default_color = Color(0.3, 0.8, 1.0, 0.6)
			# Radius-Kreis mit mehr Punkten für glatten Kreis
			var num_points := 48
			for i in range(num_points + 1):
				var angle := i * TAU / num_points
				circle.add_point(Vector2(cos(angle), sin(angle)) * ISOLATION_RADIUS)
			indicator.add_child(circle)
			
			# Pulsiere
			var tween := create_tween()
			tween.set_loops()
			tween.tween_property(circle, "default_color:a", 0.2, 1.0)
			tween.tween_property(circle, "default_color:a", 0.6, 1.0)
	elif indicator:
		indicator.queue_free()


func setup(data: Dictionary, type: String) -> void:
	tower_type = type
	
	base_range = _get_stat_value(data, "range", 150.0)
	base_fire_rate = _get_stat_value(data, "fire_rate", 1.0)
	base_damage = _get_stat_value(data, "damage", 20)
	base_splash = _get_stat_value(data, "splash", 0.0)
	
	# NEU: Base Crit-Chance basierend auf Tower-Typ
	if tower_type == "archer":
		base_crit_chance = 0.2
	elif tower_type == "sword":
		base_crit_chance = 0.15
	else:
		base_crit_chance = 0.0
	
	# Aktuelle Werte setzen
	tower_range = base_range
	fire_rate = base_fire_rate
	damage = base_damage
	splash_radius = base_splash
	
	attack_type = data.get("attack_type", "projectile")
	
	# NEU: Spezielle Stats für neue Türme
	if data.has("min_range"):
		var min_r = data.get("min_range", 0.0)
		min_range = min_r[0] if min_r is Array else min_r
	
	if data.has("max_traps"):
		var mt = data.get("max_traps", 2)
		max_traps = mt[0] if mt is Array else mt
	
	if data.has("trap_duration"):
		var td = data.get("trap_duration", 15.0)
		trap_duration = td[0] if td is Array else td
	
	if data.has("buff_strength"):
		var bs = data.get("buff_strength", 0.15)
		buff_strength = bs[0] if bs is Array else bs
		aura_range = tower_range  # Aura nutzt tower_range
	
	if data.has("slow_amount"):
		var sa = data.get("slow_amount", 0.0)
		slow_amount = sa[0] if sa is Array else sa
	
	_load_special_effects()
	_apply_upgrade_bonuses()
	_apply_item_bonuses()
	_update_archer_anim_speed()
	_update_isolation_visual()
	
	if is_inside_tree():
		_update_visuals()
		_update_item_indicators()


func _apply_item_bonuses() -> void:
	if not ItemSystem:
		return
	
	var elem := get_effective_element()
	
	# Damage
	var damage_bonus := ItemSystem.get_tower_item_bonus_percent(self, "damage")
	damage = int(float(damage) * (1.0 + damage_bonus))
	
	# Range
	var range_bonus := ItemSystem.get_tower_item_bonus_percent(self, "range")
	tower_range *= (1.0 + range_bonus)
	
	# Fire Rate (höher = schneller)
	var fire_rate_bonus := ItemSystem.get_tower_item_bonus_percent(self, "fire_rate")
	fire_rate /= (1.0 + fire_rate_bonus)
	
	# Splash
	if splash_radius > 0:
		var splash_bonus := ItemSystem.get_tower_item_bonus_percent(self, "splash")
		splash_radius *= (1.0 + splash_bonus)
	
	# Crit Chance
	var item_crit_damage := ItemSystem.get_tower_item_bonus_percent(self, "crit_damage")
	# Wird in _shoot() verwendet
	
	# Element-spezifische Boni
	var slow_bonus := ItemSystem.get_tower_item_bonus_percent(self, "slow_bonus")
	slow_amount += slow_bonus
	
	var burn_bonus := ItemSystem.get_tower_item_bonus_percent(self, "burn_bonus")
	burn_damage = int(float(burn_damage) * (1.0 + burn_bonus)) if burn_damage > 0 else 0
	
	var stun_bonus := ItemSystem.get_tower_item_bonus_percent(self, "stun_bonus")
	stun_chance += stun_bonus
	
	var chain_bonus := ItemSystem.get_tower_item_bonus(self, "chain_bonus")
	chain_targets += int(chain_bonus)


func recalculate_stats() -> void:
	var data := TowerData.get_legacy_data(tower_type, level)
	base_damage = _get_stat_value(data, "damage", 20)
	base_range = _get_stat_value(data, "range", 150.0)
	base_fire_rate = _get_stat_value(data, "fire_rate", 1.0)
	base_splash = _get_stat_value(data, "splash", 0.0)
	
	# Zurück zu Basis-Werten
	tower_range = base_range
	fire_rate = base_fire_rate
	damage = base_damage
	splash_radius = base_splash
	
	# Spezialeffekte neu laden
	_load_special_effects()

	# Alle Boni anwenden
	_apply_upgrade_bonuses()
	_apply_item_bonuses()
	
	# ✅ NEU: Isolation-Visual aktualisieren
	_update_isolation_visual()
	
	# Visuals aktualisieren
	if is_inside_tree():
		_update_visuals()
		_update_item_indicators()
	
	# ✅ Debug-Output
	if UpgradeSystem and (UpgradeSystem.get_upgrade_stacks("isolated_damage") > 0 or UpgradeSystem.get_upgrade_stacks("isolated_range") > 0):
		print("[Tower %s] Isolation-Check: isolated=%s, damage=%d, range=%.0f" % [tower_type, is_isolated(), damage, tower_range])


# === NEUE FUNKTION: Item-Indikatoren anzeigen ===
func _update_item_indicators() -> void:
	# Alte entfernen
	for indicator in item_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	item_indicators.clear()
	
	if not ItemSystem:
		return
	
	var items := ItemSystem.get_tower_equipped_items(self)
	var slot_x := -20
	
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if item.is_empty():
			continue
		
		var indicator := Node2D.new()
		indicator.position = Vector2(slot_x + i * 20, 25)
		add_child(indicator)
		item_indicators.append(indicator)
		
		# Mini-Icon
		var icon := Sprite2D.new()
		var tex := ItemSystem.get_item_texture(item)
		if tex:
			icon.texture = tex
			icon.scale = Vector2(1.5, 1.5)
		else:
			# Fallback: Farbiger Punkt
			var dot := Polygon2D.new()
			dot.polygon = PackedVector2Array([
				Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
			])
			dot.color = item.get("color", Color.WHITE)
			indicator.add_child(dot)
			continue
		
		indicator.add_child(icon)
		
		# Rarity-Rahmen
		var frame := Line2D.new()
		frame.width = 1
		frame.default_color = item.get("color", Color.WHITE)
		frame.add_point(Vector2(-6, -6))
		frame.add_point(Vector2(6, -6))
		frame.add_point(Vector2(6, 6))
		frame.add_point(Vector2(-6, 6))
		frame.add_point(Vector2(-6, -6))
		indicator.add_child(frame)


func upgrade(data: Dictionary, new_level: int) -> void:
	level = new_level
	
	base_range = _get_stat_value(data, "range", 150.0)
	base_fire_rate = _get_stat_value(data, "fire_rate", 1.0)
	base_damage = _get_stat_value(data, "damage", 20)
	base_splash = _get_stat_value(data, "splash", 0.0)
	
	# Aktuelle Werte auf Basis setzen
	tower_range = base_range
	fire_rate = base_fire_rate
	damage = base_damage
	splash_radius = base_splash
	attack_type = data.get("attack_type", attack_type)
	
	if data.has("buff_strength"):
		var bs = data.get("buff_strength", 0.15)
		buff_strength = bs[level] if (bs is Array and level < bs.size()) else (bs[0] if bs is Array else bs)
		aura_range = tower_range  # Aura nutzt tower_range
		print("[Tower Aura] Level %d: buff_strength=%.2f, aura_range=%.0f" % [level, buff_strength, aura_range])
	
	_load_special_effects()
	_apply_upgrade_bonuses()
	_apply_item_bonuses()  # ← DAS FEHLTE!
	
	_update_archer_anim_speed()
	if is_inside_tree():
		_update_visuals()
		_update_item_indicators()  # ← Auch Item-Anzeige aktualisieren
		_show_upgrade_effect()
		if VFX:
			VFX.spawn_upgrade_effect(position, get_effective_element(), new_level)


func engrave(element: String) -> bool:
	if not TowerData.can_engrave(tower_type):
		return false
	if not TowerData.is_element_unlocked(element):
		return false
	if not TowerData.can_afford_engraving():
		return false
	
	GameState.gold -= TowerData.get_engraving_cost()
	engraved_element = element
	_load_engraving_effects()
	
	if is_inside_tree():
		_update_visuals()
		_show_engraving_effect()
	
	Sound.play_element_select()
	return true


# === BLOCKED STATUS ===

func set_blocked(blocked: bool) -> void:
	if is_blocked == blocked:
		return
	
	is_blocked = blocked
	
	if is_blocked:
		_show_blocked_overlay()
	else:
		_hide_blocked_overlay()


func _show_blocked_overlay() -> void:
	if blocked_overlay:
		return
	
	# Rotes Overlay über dem Turm
	blocked_overlay = ColorRect.new()
	blocked_overlay.color = Color(1.0, 0.2, 0.2, 0.4)
	blocked_overlay.size = Vector2(64, 64)
	blocked_overlay.position = Vector2(-32, -32)
	blocked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blocked_overlay)
	
	# Pulsierender Effekt
	_start_blocked_pulse()


func _hide_blocked_overlay() -> void:
	if blocked_pulse_tween:
		blocked_pulse_tween.kill()
		blocked_pulse_tween = null
	
	if blocked_overlay:
		blocked_overlay.queue_free()
		blocked_overlay = null


func _start_blocked_pulse() -> void:
	if not blocked_overlay:
		return
	
	if blocked_pulse_tween:
		blocked_pulse_tween.kill()
	
	blocked_pulse_tween = create_tween().set_loops()
	blocked_pulse_tween.tween_property(blocked_overlay, "color:a", 0.6, 0.5)
	blocked_pulse_tween.tween_property(blocked_overlay, "color:a", 0.25, 0.5)


func _load_engraving_effects() -> void:
	if engraved_element == "":
		return
	if special_type == "aura":
		print("[Tower Aura] Engraved mit %s - behalte special_type='aura'" % engraved_element)
		return
	match engraved_element:
		"water":
			special_type = "slow"
			slow_amount = 0.15 + level * 0.05
		"fire":
			special_type = "burn"
			burn_damage = 2 + level * 2
		"earth":
			special_type = "stun"
			stun_chance = 0.05 + level * 0.03
		"air":
			special_type = "chain"
			chain_targets = level


func _show_engraving_effect() -> void:
	if VFX:
		VFX.spawn_pixel_burst(position, engraved_element, 16)
		VFX.spawn_pixel_ring(position, engraved_element, 50.0)
		VFX.screen_flash(ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE, 0.15)


func get_effective_element() -> String:
	if engraved_element != "":
		return engraved_element
	if tower_type in TowerData.UNLOCKABLE_ELEMENTS:
		return tower_type
	if TowerData.is_combination(tower_type):
		return tower_type
	return ""


func is_engraved() -> bool:
	return engraved_element != ""


func can_be_engraved() -> bool:
	return TowerData.can_engrave(tower_type) and engraved_element == ""


func can_select_aura_buff() -> bool:
	"""Aura-Türme können ihren Buff-Typ wählen wenn noch nicht gesetzt"""
	return tower_type == "aura" and aura_buff_type == ""


func select_aura_buff(buff_type: String) -> bool:
	"""Setzt den Buff-Typ des Aura-Turms (permanent!)"""
	if not can_select_aura_buff():
		return false
	
	if buff_type not in ["damage", "range", "fire_rate"]:
		return false
	
	aura_buff_type = buff_type
	
	# Visuals aktualisieren
	if is_inside_tree():
		_update_visuals()
		_show_aura_selection_effect()
	
	# Alle betroffenen Türme neu berechnen
	_update_aura_buffs()
	
	Sound.play_element_select()
	print("[Tower Aura] Buff-Typ gewählt: %s (Stärke: %.2f)" % [aura_buff_type, buff_strength])
	return true


func _show_aura_selection_effect() -> void:
	"""Visueller Effekt wenn Buff-Typ gewählt wird"""
	if not VFX:
		return
	
	var effect_color := _get_aura_buff_color()
	VFX.spawn_pixel_burst(position, "air", 16)  # Nutze "air" als Basis
	VFX.spawn_pixel_ring(position, "air", 60.0)
	VFX.screen_flash(effect_color, 0.15)


func _get_aura_buff_color() -> Color:
	"""Gibt Farbe basierend auf Buff-Typ zurück"""
	match aura_buff_type:
		"damage":
			return Color(1.0, 0.3, 0.3)  # Rot
		"range":
			return Color(0.3, 0.5, 1.0)  # Blau
		"fire_rate":
			return Color(0.3, 1.0, 0.4)  # Grün
		_:
			return Color(1.0, 0.9, 0.4)  # Gold (default)


func _load_special_effects() -> void:
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
	
	engraving_indicator = _get_or_create_rich_label("engraving_indicator", Vector2(-25, -45))
	engraving_indicator.add_theme_font_size_override("font_size", 14)
	engraving_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	engraving_indicator.add_theme_constant_override("outline_size", 2)
	engraving_indicator.visible = false


func _update_visuals() -> void:
	print("[Tower %s] _update_visuals() START" % tower_type)
	
	print("[Tower %s] Clearing turret children..." % tower_type)
	if turret.get_child_count() > 0:
		print("[Tower %s] Clearing turret children..." % tower_type)
		for child in turret.get_children():
			turret.remove_child(child)
			child.queue_free()
	
	print("[Tower %s] Resetting sprite vars..." % tower_type)
	archer_sprite = null
	sword_sprite = null
	sprite = null
	
	print("[Tower %s] Checking tower_type, value is: '%s'" % [tower_type, tower_type])
	
	# ✅ SPRITE SETUP - nur eine Funktion wird aufgerufen
	if tower_type == "archer":
		print("[Tower] -> Branch: archer")
		_setup_archer_sprite()
	elif tower_type == "sword":
		print("[Tower] -> Branch: sword")
		_setup_sword_sprite()
	elif tower_type == "farm":
		print("[Tower] -> Branch: farm")
		_setup_farm_sprite()
	else:
		print("[Tower] -> Branch: else (calling _setup_standard_sprite)")
		_setup_standard_sprite()
	
	print("[Tower %s] After sprite setup, children count: %d" % [tower_type, turret.get_child_count()])
	
	# ✅ MIN-RANGE CIRCLE - separat, NACH dem Sprite-Setup
	if tower_type == "cannon" and min_range > 0:
		print("[Tower cannon] Setting up min_range_circle")
		if not min_range_circle:
			min_range_circle = Line2D.new()
			min_range_circle.default_color = Color(1, 0.3, 0.3, 0.25)
			min_range_circle.width = 2
			min_range_circle.z_index = -1
			add_child(min_range_circle)
		
		min_range_circle.clear_points()
		for i in range(33):
			var angle := i * TAU / 32
			min_range_circle.add_point(Vector2(cos(angle), sin(angle)) * min_range)
	elif min_range_circle:
		min_range_circle.queue_free()
		min_range_circle = null
	
	# Range Circle
	range_circle.clear_points()
	if attack_type != "none" and tower_range > 0:
		for i in range(33):
			var angle := i * TAU / 32
			range_circle.add_point(Vector2(cos(angle), sin(angle)) * tower_range)
		
		if engraved_element != "":
			var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
			range_circle.default_color = elem_color.lerp(Color.WHITE, 0.7)
			range_circle.default_color.a = 0.2
	elif attack_type == "none" and special_type == "aura":
		if not aura_visual:
			aura_visual = Line2D.new()
			aura_visual.width = 3
			aura_visual.z_index = -1
			add_child(aura_visual)
		
		var aura_color := _get_aura_buff_color()
		aura_visual.default_color = aura_color
		aura_visual.default_color.a = 0.25
		
		aura_visual.clear_points()
		for i in range(33):
			var angle := i * TAU / 32
			aura_visual.add_point(Vector2(cos(angle), sin(angle)) * aura_range)
		
		var tween := create_tween().set_loops()
		tween.tween_property(aura_visual, "default_color:a", 0.1, 1.2)
		tween.tween_property(aura_visual, "default_color:a", 0.4, 1.2)
	else:
		range_circle.visible = false
	
	_update_level_indicator()
	_update_isolation_visual()
	_update_engraving_indicator()
	
	print("[Tower %s] _update_visuals() END" % tower_type)


func _setup_farm_sprite() -> void:
	var texture_path := "res://assets/elemental_tower/farm.png"
	
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(2.0, 2.0)
		sprite.offset.y = -8
		turret.add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-20, 20), Vector2(20, 20), Vector2(20, 0),
			Vector2(25, 0), Vector2(0, -25), Vector2(-25, 0),
			Vector2(-20, 0)
		])
		poly.color = Color(0.5, 0.7, 0.3)
		turret.add_child(poly)
		
		var door := Polygon2D.new()
		door.polygon = PackedVector2Array([
			Vector2(-6, 20), Vector2(6, 20), Vector2(6, 5), Vector2(-6, 5)
		])
		door.color = Color(0.4, 0.3, 0.2)
		turret.add_child(door)


func _update_engraving_indicator() -> void:
	if engraved_element == "":
		engraving_indicator.visible = false
		return
	
	engraving_indicator.visible = true
	engraving_indicator.text = ElementalSystem.get_element_bb(engraved_element) if ElementalSystem else engraved_element.substr(0, 1).to_upper()
	
	var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
	engraving_indicator.add_theme_color_override("font_color", elem_color)
	
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
	print("[Tower %s] _setup_standard_sprite() START" % tower_type)
	var texture_path := _get_tower_texture_path()
	if not ResourceLoader.exists(texture_path) and level > 0:
		texture_path = "res://assets/elemental_tower/tower_%s.png" % tower_type
	var data := TowerData.get_tower_data(tower_type)
	var is_animated: bool = data.get("animated", true)
	
	if ResourceLoader.exists(texture_path):
		print("!!! RESOURCELOADER EXISTS!!!")
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
		print("[Tower %s] -> Creating polygon" % tower_type)
		var poly := Polygon2D.new()
		
		match tower_type:
			"wizard":
				poly.polygon = PackedVector2Array([
					Vector2(-15, 20), Vector2(15, 20), Vector2(15, 0),
					Vector2(8, 0), Vector2(0, -28), Vector2(-8, 0), Vector2(-15, 0)
				])
			
			"cannon":
				print("[Tower] -> cannon polygon")
				# Einfache L-Form (Kanonen-Körper + Rohr)
				poly.polygon = PackedVector2Array([
					# Basis/Körper
					Vector2(-18, 18), Vector2(18, 18),
					Vector2(18, -2), Vector2(8, -2),
					# Rohr
					Vector2(8, -10), Vector2(-30, -10),
					Vector2(-30, -2), Vector2(-18, -2),
					# Zurück
					Vector2(-18, 0)
				])
				poly.color = Color(0.5, 0.5, 0.55)  # Helleres Grau - besser sichtbar!
				print("[Tower] -> cannon color set to: %s" % poly.color)
			
			"trapper":
				poly.polygon = PackedVector2Array([
					Vector2(-20, 20), Vector2(20, 20), Vector2(20, 5),
					Vector2(12, 5), Vector2(12, -5), Vector2(-12, -5),
					Vector2(-12, 5), Vector2(-20, 5)
				])
			
			"aura":
				poly.polygon = PackedVector2Array([
					Vector2(0, -25), Vector2(12, -8), Vector2(18, 8),
					Vector2(0, 20), Vector2(-18, 8), Vector2(-12, -8)
				])
			
			_:
				print("[Tower] -> default polygon")
				poly.polygon = PackedVector2Array([
					Vector2(-20, 20), Vector2(20, 20), Vector2(20, -10),
					Vector2(0, -25), Vector2(-20, -10)
				])
		
		# ✅ NUR Farbe setzen wenn noch nicht gesetzt (für cannon)
		if poly.color == Color.WHITE:
			var color: Variant = data.get("color")
			poly.color = color if color else Color.WHITE
			print("[Tower %s] -> color from data: %s" % [tower_type, poly.color])
		
		print("[Tower %s] -> Adding poly to turret, children before: %d" % [tower_type, turret.get_child_count()])
		turret.add_child(poly)
		print("[Tower %s] -> turret children after: %d" % [tower_type, turret.get_child_count()])
		
		print("[Tower %s] === VISIBILITY CHECKS ===" % tower_type)
		print("  turret.visible: %s" % turret.visible)
		print("  turret.position: %s" % turret.position)
		print("  turret.modulate: %s" % turret.modulate)
		print("  turret.z_index: %d" % turret.z_index)
		print("  poly.visible: %s" % poly.visible)
		print("  poly.color: %s" % poly.color)
		print("  poly.modulate: %s" % poly.modulate)
		print("  poly.z_index: %d" % poly.z_index)
		print("  poly.position: %s" % poly.position)
		print("  poly.polygon points: %d" % poly.polygon.size())
		print("=========================")
		
		sprite = null
	print("[Tower %s] _setup_standard_sprite() END" % tower_type)



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
	if attack_type == "none":
		# Aura-Update (kontinuierlich)
		if special_type == "aura":
			_update_aura_buffs()
		_do_idle_animation(delta)
		return
	
	fire_timer -= delta
	
	if archer_sprite:
		_update_archer_animation(delta)
	elif sword_sprite:
		_update_sword_animation(delta)
		
	if tower_type == "trapper" or attack_type == "trap":
		if GameState.wave_active and fire_timer <= 0:
			_place_trap()
			fire_timer = fire_rate
			print("[Tower Trapper] Falle platziert, nächste in %.1fs" % fire_rate)
		_do_idle_animation(delta)
		return
	
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
			match attack_type:
				"melee":
					if sword_sprite:
						_start_sword_attack_animation()
					else:
						_melee_attack()
					fire_timer = fire_rate
				
				"cannon":  # NEU
					_cannon_shoot()
					fire_timer = fire_rate
				
				"trap":  # NEU
					_place_trap()
					fire_timer = fire_rate
				
				_:  # Normal projectile
					if archer_sprite:
						_start_archer_shoot_animation()
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
		
		# Reichweiten-Check
		if dist > tower_range:
			continue
		
		# NEU: Mindestreichweite für Kanone
		if tower_type == "cannon" and dist < min_range:
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

	var crit_chance := base_crit_chance
	if UpgradeSystem:
		crit_chance += UpgradeSystem.get_crit_chance()
	if ItemSystem:
		crit_chance += ItemSystem.get_tower_item_bonus_percent(self, "crit_chance")

	var is_crit := randf() < crit_chance
	var melee_damage := damage

	if is_crit:
		var crit_mult: float = UpgradeSystem.get_crit_multiplier() if UpgradeSystem and UpgradeSystem.has_method("get_crit_multiplier") else 1.5
		melee_damage = int(float(damage) * crit_mult)
		if VFX:
			VFX.spawn_pixels(position, "crit", 6, 20.0)

	var kills := 0

	for enemy in hit_enemies:
		var was_alive: bool = true
		var h: Variant = enemy.get("health")
		if typeof(h) == TYPE_INT or typeof(h) == TYPE_FLOAT:
			was_alive = h > 0

		if enemy.has_method("take_damage"):
			# NEU: tower_type als 5. Parameter
			enemy.take_damage(melee_damage, true, elem, is_crit, tower_type)
		_apply_melee_effects(enemy)

		if was_alive and (not is_instance_valid(enemy) or enemy.health <= 0):
			kills += 1

	# Life-Steal & Gold-Bonus (unverändert)
	if kills > 0 and ItemSystem:
		var life_steal := int(ItemSystem.get_tower_item_bonus(self, "life_steal"))
		if life_steal > 0:
			GameState.lives = mini(GameState.lives + life_steal * kills, GameState.get_max_lives())
			if VFX:
				VFX.spawn_pixels(position, "nature", 4, 15.0)

	if kills > 0 and ItemSystem:
		var gold_bonus := int(ItemSystem.get_tower_item_bonus(self, "gold_bonus"))
		if gold_bonus > 0:
			GameState.gold += gold_bonus * kills
			if VFX:
				VFX.spawn_gold_number(position, gold_bonus * kills)

	if VFX:
		VFX.spawn_cleave_effect(position, tower_range, elem if elem != "" else "sword")
		if hit_enemies.size() > 0:
			VFX.spawn_melee_hit_sparks(position, hit_enemies.size(), elem if elem != "" else "sword")
		if hit_enemies.size() >= 3:
			VFX.screen_shake(2.0, 0.08)

	Sound.play_shoot("sword", level)


func get_equipped_items() -> Array:
	return equipped_items


func get_equipment_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= equipped_items.size():
		return {}
	return equipped_items[slot]


func has_empty_equipment_slot() -> bool:
	for item in equipped_items:
		if item.is_empty():
			return true
	return false


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
	
	# Crit berechnen
	var is_crit := false
	var final_damage := damage
	var crit_chance := base_crit_chance  # NEU: Starte mit Base Crit
	
	if UpgradeSystem:
		crit_chance += UpgradeSystem.get_crit_chance()
	if ItemSystem:
		crit_chance += ItemSystem.get_tower_item_bonus_percent(self, "crit_chance")
	
	if randf() < crit_chance:
		is_crit = true
		
		# Crit-Multiplikator berechnen
		var crit_mult: float = 1.5  # Base
		
		# Upgrade-System Bonus
		if UpgradeSystem and UpgradeSystem.has_method("get_crit_multiplier"):
			crit_mult = UpgradeSystem.get_crit_multiplier()
		
		# NEU: Item Bonus addieren
		if ItemSystem:
			var item_crit_dmg := ItemSystem.get_tower_item_bonus_percent(self, "crit_damage")
			crit_mult += item_crit_dmg
		
		final_damage = int(float(damage) * crit_mult)
		
		if VFX:
			VFX.spawn_pixels(position, "crit", 4, 15.0)
	
	# Multishot Item-Effekt
	var multishot := 0
	if ItemSystem:
		multishot = int(ItemSystem.get_tower_item_bonus(self, "multishot"))
	
	# Haupt-Projektil
	_fire_bullet(bullet, elem, final_damage, is_crit)
	
	# Extra Projektile durch Multishot
	for i in range(multishot):
		var extra := bullet_scene.instantiate()
		extra.position = position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		_fire_bullet(extra, elem, int(final_damage * 0.7), false)
	
	var direction := (target.position - position).normalized()
	if VFX and tower_type != "archer":
		VFX.spawn_muzzle_flash(position + direction * 15, direction, elem if elem != "" else tower_type)
	
	var sound_elem := "base" if tower_type == "archer" and engraved_element == "" else (engraved_element if engraved_element != "" else tower_type)
	Sound.play_shoot(sound_elem, level)
	
	if not archer_sprite:
		_do_recoil()


func _fire_bullet(bullet: Node2D, elem: String, dmg: int, is_crit: bool) -> void:
	var bullet_data := {
		"target":            target,
		"damage":            dmg,
		"splash":            splash_radius,
		"type":              elem if elem != "" else tower_type,
		"level":             level,
		"special":           special_type,
		"slow_amount":       slow_amount,
		"burn_damage":       burn_damage,
		"stun_chance":       stun_chance,
		"chain_targets":     chain_targets,
		"is_crit":           is_crit,
		"source_tower_type": tower_type,   # NEU
	}
	if bullet.has_method("setup_extended"):
		bullet.setup_extended(bullet_data)
	else:
		bullet.setup(target, dmg, splash_radius, tower_type)
	get_parent().add_child(bullet)


func _do_recoil() -> void:
	var current_sprite: Sprite2D = archer_sprite if archer_sprite else sprite
	if not current_sprite:
		return
	var original_pos := current_sprite.position
	var tween := current_sprite.create_tween()
	tween.tween_property(current_sprite, "position", original_pos + Vector2(0, 3), 0.05)
	tween.tween_property(current_sprite, "position", original_pos, 0.1).set_trans(Tween.TRANS_ELASTIC)


func _cannon_shoot() -> void:
	"""Kanonen-Schuss mit großem Rückstoß und Screen Shake"""
	if not target:
		return
	
	var bullet := bullet_scene.instantiate()
	bullet.position = position
	
	var elem := get_effective_element()
	
	# Crit-Berechnung
	var is_crit := false
	var final_damage := damage
	var crit_chance := base_crit_chance
	
	if UpgradeSystem:
		crit_chance += UpgradeSystem.get_crit_chance()
	if ItemSystem:
		crit_chance += ItemSystem.get_tower_item_bonus_percent(self, "crit_chance")
	
	if randf() < crit_chance:
		is_crit = true
		var crit_mult := UpgradeSystem.get_crit_multiplier() if UpgradeSystem else 1.5
		if ItemSystem:
			crit_mult += ItemSystem.get_tower_item_bonus_percent(self, "crit_damage")
		final_damage = int(float(damage) * crit_mult)
		if VFX:
			VFX.spawn_pixels(position, "crit", 6, 25.0)
	
	var bullet_data := {
		"target": target,
		"damage": final_damage,
		"splash": splash_radius,
		"type": elem if elem != "" else "cannon",
		"level": level,
		"special": "explosive",  # Kanone hat immer Explosion
		"is_crit": is_crit,
		"is_cannon": true,  # Marker für größere Explosion-VFX
		"source_tower_type": "cannon"
	}
	
	if bullet.has_method("setup_extended"):
		bullet.setup_extended(bullet_data)
	else:
		bullet.setup(target, final_damage, splash_radius, "cannon")
	
	get_parent().add_child(bullet)
	
	# Großer Mündungsblitz
	var direction := (target.position - position).normalized()
	if VFX:
		VFX.spawn_muzzle_flash(position + direction * 25, direction, elem if elem != "" else "cannon")
		VFX.spawn_smoke_puff(position - direction * 20, 4)
		VFX.screen_shake(3.0, 0.12)
	
	Sound.play_shoot("cannon", level)
	_do_cannon_recoil()


func _do_cannon_recoil() -> void:
	"""Starker Rückstoß-Effekt für Kanone"""
	if not sprite:
		return
	
	var original_pos := sprite.position
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", original_pos + Vector2(0, 10), 0.08)
	tween.tween_property(sprite, "position", original_pos, 0.25).set_trans(Tween.TRANS_ELASTIC)


func _place_trap() -> void:
	"""Platziert eine Falle in Reichweite"""
	# Cleanup alte Fallen
	for i in range(active_traps.size() - 1, -1, -1):
		if not is_instance_valid(active_traps[i]):
			active_traps.remove_at(i)
	
	# Max Fallen erreicht
	if active_traps.size() >= max_traps:
		print("[Tower] Max Fallen erreicht (%d/%d)" % [active_traps.size(), max_traps])
		return
	
	# Finde Position
	var trap_pos := _find_trap_position()
	if trap_pos == Vector2.ZERO:
		return
	
	# ✅ Erstelle Falle mit preload (besser für Performance)
	var trap: Node2D = preload("res://trap.tscn").instantiate()
	trap.position = trap_pos
	
	var elem := get_effective_element()
	
	if trap.has_method("setup"):
		trap.setup({
			"damage": damage,
			"splash": splash_radius,
			"element": elem,
			"duration": trap_duration,
			"special_type": special_type,
			"tower": self
		})
		print("[Tower] Falle mit Slow: %.0f%%, Splash: %.0f" % [slow_amount * 100, splash_radius])

	
	get_parent().add_child(trap)
	active_traps.append(trap)

	if VFX:
		VFX.spawn_pixel_burst(trap_pos, elem if elem != "" else "earth", 4)
	
	Sound.play_click()
	print("[Tower] Falle platziert bei %s (aktiv: %d/%d)" % [trap_pos, active_traps.size(), max_traps])


func _find_trap_position() -> Vector2:
	"""Findet eine gute Position für eine Falle - idealerweise auf dem Pfad"""
	
	# Versuche Pfad vom WaveManager zu holen
	var wave_manager: Node = get_node_or_null("/root/Main/WaveManager")
	if not wave_manager or not wave_manager.has_method("get_path_points_in_range"):
		return _find_random_trap_position()
	
	# Hole Pfad-Punkte in Reichweite
	var path_points: Array = wave_manager.get_path_points_in_range(position, tower_range)
	
	if path_points.is_empty():
		return _find_random_trap_position()
	
	# Filtere Punkte die nicht zu nah an existierenden Fallen sind
	var valid_points: Array[Vector2] = []
	for point in path_points:
		var too_close := false
		for trap in active_traps:
			if is_instance_valid(trap) and point.distance_to(trap.position) < 50.0:
				too_close = true
				break
		
		if not too_close:
			valid_points.append(point)
	
	if valid_points.is_empty():
		# Alle Pfad-Punkte sind belegt, nimm den am weitesten entfernten
		var furthest_point: Vector2 = path_points[0]  # ✅ Typ explizit
		var max_dist: float = 0.0  # ✅ Typ explizit
		for point in path_points:
			var min_trap_dist := 999999.0
			for trap in active_traps:
				if is_instance_valid(trap):
					min_trap_dist = min(min_trap_dist, point.distance_to(trap.position))
			if min_trap_dist > max_dist:
				max_dist = min_trap_dist
				furthest_point = point
		return furthest_point
	
	# Nimm zufälligen gültigen Punkt
	return valid_points[randi() % valid_points.size()]


func _find_random_trap_position() -> Vector2:
	"""Fallback: Zufällige Position in Reichweite"""
	var angle := randf() * TAU
	var dist := randf_range(tower_range * 0.6, tower_range * 0.95)
	return position + Vector2(cos(angle), sin(angle)) * dist


func _update_aura_buffs() -> void:
	"""Updated welche Türme vom Aura-Buff betroffen sind"""
	if attack_type != "none" or special_type != "aura":
		return
	
	# Finde alle Türme in Reichweite
	var new_affected: Array[Node2D] = []
	
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if tower.attack_type == "none":  # Keine Support-Türme buffed
			continue
		
		var dist := position.distance_to(tower.position)
		if dist <= aura_range:
			new_affected.append(tower)
	
	# Wenn sich die Liste geändert hat, Stats neu berechnen
	if new_affected.size() != affected_towers.size():
		affected_towers = new_affected
		
		# Triggere Recalc bei allen betroffenen Türmen
		for tower in affected_towers:
			if tower.has_method("recalculate_stats"):
				tower.recalculate_stats()


func get_aura_buffs() -> Dictionary:
	"""Gibt die Buffs zurück die dieser Aura-Turm gibt"""
	if attack_type != "none" or special_type != "aura":
		return {}
	
	if aura_buff_type == "":
		return {}  # Noch nicht konfiguriert
	
	var buffs := {}
	
	match aura_buff_type:
		"damage":
			buffs["damage_mult"] = buff_strength
		"range":
			buffs["range_mult"] = buff_strength
		"fire_rate":
			buffs["fire_rate_mult"] = buff_strength
	
	return buffs



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


func get_total_crit_chance() -> float:
	var total := base_crit_chance
	
	if UpgradeSystem:
		total += UpgradeSystem.get_crit_chance()
	
	if ItemSystem:
		total += ItemSystem.get_tower_item_bonus_percent(self, "crit_chance")
	
	return total


func _start_float_animation() -> void:
	if not selection_corners:
		return
	if selection_tween:
		selection_tween.kill()
	selection_tween = create_tween().set_loops()
	selection_tween.tween_property(selection_corners, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	selection_tween.tween_property(selection_corners, "position:y", 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
