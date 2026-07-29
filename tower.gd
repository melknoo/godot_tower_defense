# tower.gd
# Tower mit Elemental Engraving, Upgrades, Spezialeffekten und Blocked-Status
extends Node2D
class_name Tower

const RangeGridHelper = preload("res://autoload/range_grid.gd")

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
var min_range_visual: Node2D = null

# Trapper-spezifisch
var active_traps: Array[Node2D] = []
var max_traps := 2
var trap_duration := 15.0

# Aura-spezifisch
var aura_range := 0.0
var buff_strength := 0.0
var affected_towers: Array[Node2D] = []
var aura_visual: Node2D = null
var aura_visual_tween: Tween = null
var aura_buff_type := ""

# Spezialeffekte
var special_type := ""
var slow_amount := 0.0
var burn_damage := 0
var stun_chance := 0.0
var chain_targets := 0
var base_crit_chance := 0.0
var shots_fired := 0   # für Proc-Items (jeder N-te Schuss)
# Anteil des Schadens, der aus element-gebundenen Items stammt (z. B. Feuerrubin).
# Nur für die Anzeige in TowerInfo - der Wert steckt bereits in `damage`.
var item_element_damage_bonus := 0.0

# Kampfstatistik: Kills & Schaden, getrennt nach aktueller Runde und gesamtem Run.
# Hängt an der Turm-Node, überlebt also das Verschieben eines Turms.
var kills_run := 0
var kills_round := 0
var damage_run := 0
var damage_round := 0

var bullet_scene: PackedScene
var fire_timer := 0.0
var target: Node2D = null

# Blocked Status (Turm steht auf Pfad)
var is_blocked := false
var blocked_overlay: ColorRect
var blocked_pulse_tween: Tween

# Visuals
var range_circle: Line2D
var range_visual: Node2D
var turret: Node2D
var sprite: Sprite2D
var level_indicator: Node2D
var selection_corners: Node2D
var selection_tween: Tween
var engraving_indicator: RichTextLabel
# Glueh-Aura, die mit dem Upgrade-Level staerker wird (rein visuell).
var level_glow: Node2D
var level_glow_tween: Tween
# Hervorhebung aus der Turm-Statistik heraus (Hover ueber eine Zeile).
var highlight_tween: Tween
# Reichweiten-Raster wird nur beim ausgewaehlten Turm eingeblendet.
var is_selected := false

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

# Platzhalter-Darstellung fuer Tuerme ohne eigenes Sprite (siehe ASSETS_TODO.md).
# PLACEHOLDER_PIXEL entspricht der 3x-Skalierung der echten 16x16-Sprites, damit
# der Platzhalter im selben Raster sitzt.
const PLACEHOLDER_PIXEL := 3.0
const PLACEHOLDER_GLYPHS := {
	"wizard": "abilities",
	"cannon": "damage",
	"trapper": "path",
	"aura": "star_full",
}

# Glueh-Aura je Upgrade-Stufe: ineinander liegende, additiv gemischte Kreise.
const GLOW_RING_COUNT := 4
const GLOW_CIRCLE_SEGMENTS := 24

# Stadt: aufgenommene Farmen. Ihr Supply bleibt erhalten, ihr Feld wird frei.
var stored_farms := 0

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


# === KAMPFSTATISTIK (Kills & Schaden) ===

func register_damage_dealt(amount: int) -> void:
	"""Schreibt real ausgeteilten Schaden diesem Turm gut"""
	if amount <= 0:
		return
	damage_run += amount
	damage_round += amount


func register_kill() -> void:
	"""Schreibt einen erledigten Gegner diesem Turm gut"""
	kills_run += 1
	kills_round += 1


func reset_round_stats() -> void:
	"""Runden-Zähler zurücksetzen (bei Wellenstart)"""
	kills_round = 0
	damage_round = 0


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

	# Meisterschaft: Element-Schaden (T2) + Combo-Capstone (skaliert mit beiden Elternelementen)
	if elem != "" and SynergySystem:
		damage = int(float(damage) * (1.0 + SynergySystem.get_element_damage_bonus(elem)))

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

	# Charakter-Passive (Aeromant): wirkt auf alle Tuerme des Spielers.
	if AbilitySystem:
		fire_rate_mult *= AbilitySystem.get_passive_modifier("tower_fire_rate_mult", 1.0)

	fire_rate = base_fire_rate / (1.0 + fire_rate_mult - 1.0)
	
	# Splash
	if base_splash > 0:
		var splash_mult := UpgradeSystem.get_splash_multiplier()
		if SynergySystem:
			splash_mult += SynergySystem.get_splash_radius_bonus()  # Meisterschaft: splash T1
		splash_radius = base_splash * splash_mult

	# Element-spezifische Boni
	if elem != "":
		slow_amount += UpgradeSystem.get_slow_bonus(elem)
		stun_chance += UpgradeSystem.get_stun_bonus(elem)
		chain_targets += UpgradeSystem.get_chain_bonus(elem)

	# Meisterschaft: Status-Stärken (nur wenn der Turm den Effekt überhaupt hat)
	if SynergySystem:
		if slow_amount > 0.0:
			slow_amount += SynergySystem.get_slow_strength_bonus()   # water T1
		if stun_chance > 0.0:
			stun_chance += SynergySystem.get_stun_chance_bonus()     # earth T1
		if chain_targets > 0:
			chain_targets += SynergySystem.get_chain_bonus()         # air T1
		if burn_damage > 0:
			burn_damage = int(float(burn_damage) * (1.0 + SynergySystem.get_burn_damage_bonus()))  # fire T1

	# NEU: Crit von Aura
	if aura_buffs.has("crit_chance"):
		base_crit_chance += aura_buffs["crit_chance"]

	# Meisterschaft: crit T1 (+Crit-Chance)
	if SynergySystem:
		base_crit_chance += SynergySystem.get_crit_chance_bonus()


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
		
		if not RangeGridHelper.contains_point(tower.position, position, tower.aura_range):
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
	item_element_damage_bonus = 0.0

	# Damage
	var damage_bonus := ItemSystem.get_tower_item_bonus_percent(self, "damage")
	damage = int(float(damage) * (1.0 + damage_bonus))

	# Element-Schaden (z. B. Feuerrubin = "fire_damage"): wirkt nur, wenn der Turm dieses
	# Element traegt - Engrave oder nativ. Gleiche Key-Konvention wie SynergySystem und
	# UpgradeSystem, damit kuenftige Element-Items automatisch greifen.
	if elem != "":
		var elem_damage_bonus := ItemSystem.get_tower_item_bonus_percent(self, elem + "_damage")
		if elem_damage_bonus > 0.0:
			item_element_damage_bonus = elem_damage_bonus
			damage = int(float(damage) * (1.0 + elem_damage_bonus))

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

	# Charakter-Passive (Geomant): additiv, damit sie auch auf Tuermen ohne eigene
	# Stun-Quelle ueberhaupt eine Chance erzeugt.
	if AbilitySystem:
		stun_chance += AbilitySystem.get_passive_modifier("stun_chance_add", 0.0)
	
	# "chain_bonus" liefert die Windessenz, "chain" das Kettenglied - beide erhoehen
	# dieselbe Sprungzahl.
	var chain_bonus := ItemSystem.get_tower_item_bonus(self, "chain_bonus")
	chain_bonus += ItemSystem.get_tower_item_bonus(self, "chain")
	chain_targets += int(chain_bonus)

	# "chain_damage" war wie "fire_damage" ein Stat ohne Leser. Zaehlt als Schadensbonus
	# fuer Tuerme, die tatsaechlich Ketten schlagen.
	if chain_targets > 0:
		var chain_damage_bonus := ItemSystem.get_tower_item_bonus_percent(self, "chain_damage")
		if chain_damage_bonus > 0.0:
			damage = int(float(damage) * (1.0 + chain_damage_bonus))
	if special_type == "aura":
		aura_range = tower_range


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
	# Voller Recalc statt nur _load_engraving_effects(): sonst gehen die bereits
	# angewandten Item-/Upgrade-Boni (z. B. stun_bonus) bis zum naechsten Recalc verloren.
	recalculate_stats()

	if SynergySystem:
		SynergySystem.on_tower_engraved(element)

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
		return
	match engraved_element:
		"water":
			special_type = "slow"
			# Gedeckelt bei 0.45: bei Stufe 7 waeren es sonst 0.50, also praktisch Stillstand.
			slow_amount = minf(0.15 + level * 0.05, 0.45)
		"fire":
			special_type = "burn"
			burn_damage = 2 + level * 2
		"earth":
			special_type = "stun"
			stun_chance = 0.05 + level * 0.03
		"air":
			special_type = "chain"
			# Gedeckelt bei 5: sonst haette ein Stufe-7-Turm 7 (mit Items sogar 12) Kettensprünge.
			chain_targets = mini(level, 5)


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
	level_glow = Node2D.new()
	level_glow.name = "LevelGlow"
	level_glow.z_index = -2
	add_child(level_glow)
	turret = Node2D.new()
	add_child(turret)
	range_visual = Node2D.new()
	range_visual.name = "RangeGrid"
	range_visual.z_index = -6
	add_child(range_visual)
	level_indicator = Node2D.new()
	level_indicator.position = Vector2(18, -42)
	level_indicator.z_index = 12
	add_child(level_indicator)
	
	engraving_indicator = _get_or_create_rich_label("engraving_indicator", Vector2(-25, -45))
	engraving_indicator.add_theme_font_size_override("font_size", 14)
	engraving_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	engraving_indicator.add_theme_constant_override("outline_size", 2)
	engraving_indicator.visible = false


func _update_visuals() -> void:
	if turret.get_child_count() > 0:
		for child in turret.get_children():
			turret.remove_child(child)
			child.queue_free()

	archer_sprite = null
	sword_sprite = null
	sprite = null

	# SPRITE SETUP - nur eine Funktion wird aufgerufen
	if tower_type == "archer":
		_setup_archer_sprite()
	elif tower_type == "sword":
		_setup_sword_sprite()
	elif tower_type == "farm":
		_setup_farm_sprite()
	elif tower_type == "city":
		_setup_city_sprite()
	else:
		_setup_standard_sprite()

	_refresh_range_visuals()

	_update_level_glow()
	_update_level_indicator()
	_update_isolation_visual()
	_update_engraving_indicator()


# Baut Reichweiten-, Mindestreichweiten- und Aura-Raster neu auf.
# Die Raster bleiben unsichtbar, solange der Turm nicht ausgewaehlt ist,
# werden aber bei jeder Auswahl mit den aktuellen Stats neu erzeugt.
func _refresh_range_visuals() -> void:
	if not range_visual:
		return

	# Mindestreichweite der Kanone folgt demselben quadratischen Raster.
	if tower_type == "cannon" and min_range > 0:
		if not min_range_visual:
			min_range_visual = Node2D.new()
			min_range_visual.name = "MinimumRangeGrid"
			min_range_visual.z_index = -5
			add_child(min_range_visual)
		min_range_circle = RangeGridHelper.rebuild_visual(
			min_range_visual, min_range, Color(1, 0.3, 0.3, 0.24), 2.0, false
		)
		min_range_visual.visible = is_selected
	elif min_range_visual:
		min_range_visual.queue_free()
		min_range_visual = null
		min_range_circle = null

	# Angriffs- und Aura-Reichweiten werden als exakte Rasterfelder angezeigt.
	if attack_type != "none" and tower_range > 0:
		var range_color := Color(1, 1, 1, 0.16)
		if engraved_element != "":
			var elem_color := ElementalSystem.get_element_color(engraved_element) if ElementalSystem else Color.WHITE
			range_color = elem_color.lerp(Color.WHITE, 0.7)
			range_color.a = 0.2
		if is_selected:
			range_color = Color(1, 0.5, 0.5, 0.34)
		range_circle = RangeGridHelper.rebuild_visual(range_visual, tower_range, range_color, 2.0, true)
		range_visual.visible = is_selected
	elif attack_type == "none" and special_type == "aura":
		if not aura_visual:
			aura_visual = Node2D.new()
			aura_visual.name = "AuraRangeGrid"
			aura_visual.z_index = -1
			add_child(aura_visual)
		range_visual.visible = false
		RangeGridHelper.clear_visual(range_visual)
		range_circle = null
		var aura_color := _get_aura_buff_color()
		aura_color.a = 0.42 if is_selected else 0.28
		RangeGridHelper.rebuild_visual(aura_visual, aura_range, aura_color, 2.0, true)
		if aura_visual_tween:
			aura_visual_tween.kill()
			aura_visual_tween = null
		aura_visual.modulate.a = 1.0
		aura_visual.visible = is_selected
		if is_selected:
			aura_visual_tween = create_tween().set_loops()
			aura_visual_tween.tween_property(aura_visual, "modulate:a", 0.45, 1.2)
			aura_visual_tween.tween_property(aura_visual, "modulate:a", 1.0, 1.2)
	else:
		range_visual.visible = false
		RangeGridHelper.clear_visual(range_visual)
		range_circle = null
		if aura_visual:
			aura_visual.visible = false


# Glueh-Aura, deren Staerke das Upgrade-Level ablesbar macht: ab Level 1 sichtbar,
# auf Maximalstufe hell und pulsierend. Die Farbe folgt der Gravur, damit ein
# Blick aufs Feld Stufe und Element gleichzeitig verraet. Rein visuell.
func _update_level_glow() -> void:
	if not level_glow:
		return

	if level_glow_tween:
		level_glow_tween.kill()
		level_glow_tween = null
	for child in level_glow.get_children():
		level_glow.remove_child(child)
		child.queue_free()

	level_glow.modulate.a = 1.0

	if level <= 0:
		level_glow.visible = false
		return

	level_glow.visible = true

	var is_max_level: bool = level >= TowerData.MAX_LEVEL
	var color := _get_level_glow_color()
	var progress := float(level) / float(maxi(1, TowerData.MAX_LEVEL))
	var base_radius := 20.0 + 16.0 * progress
	var base_alpha := 0.10 + 0.20 * progress

	# Additiv uebereinander gelegte Kreise ergeben einen weichen Verlauf, ohne dass
	# ein eigenes Glow-Sprite noetig waere.
	for i in range(GLOW_RING_COUNT):
		var t := float(i) / float(GLOW_RING_COUNT - 1)
		var ring := Polygon2D.new()
		ring.polygon = _make_circle_polygon(base_radius * (1.0 - t * 0.55))
		ring.color = Color(color.r, color.g, color.b, base_alpha * (0.35 + t * 0.65))
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = material
		level_glow.add_child(ring)

	if is_max_level:
		level_glow_tween = create_tween().set_loops()
		level_glow_tween.tween_property(level_glow, "modulate:a", 0.55, 0.9)
		level_glow_tween.tween_property(level_glow, "modulate:a", 1.0, 0.9)


func _get_level_glow_color() -> Color:
	if tower_type == "aura" and aura_buff_type != "":
		return _get_aura_buff_color()
	if engraved_element != "" and ElementalSystem:
		return ElementalSystem.get_element_color(engraved_element)
	return Color(1.0, 0.92, 0.62)


func _make_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(GLOW_CIRCLE_SEGMENTS):
		var angle := TAU * float(i) / float(GLOW_CIRCLE_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle) * 0.75) * radius)
	return points


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


# Stadt: eigenes Asset fehlt noch (siehe ASSETS_TODO.md), deshalb ein Platzhalter
# aus der Farm-Formsprache - breiter Sockel mit mehreren Daechern.
func _setup_city_sprite() -> void:
	var texture_path := "res://assets/elemental_tower/city.png"
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(2.0, 2.0)
		sprite.offset.y = -8
		turret.add_child(sprite)
	else:
		var base := Polygon2D.new()
		base.polygon = PackedVector2Array([
			Vector2(-26, 22), Vector2(26, 22), Vector2(26, 2), Vector2(-26, 2)
		])
		base.color = Color(0.55, 0.5, 0.4)
		turret.add_child(base)

		for roof_data in [[-16.0, 14.0], [0.0, 22.0], [16.0, 16.0]]:
			var roof := Polygon2D.new()
			var x: float = roof_data[0]
			var height: float = roof_data[1]
			roof.polygon = PackedVector2Array([
				Vector2(x - 10, 2), Vector2(x, 2 - height), Vector2(x + 10, 2)
			])
			roof.color = Color(0.68, 0.42, 0.3)
			turret.add_child(roof)


# Zeigt "N/6" ueber der Stadt, damit die Restkapazitaet ohne Klick lesbar ist.
func _update_city_counter() -> void:
	if tower_type != "city":
		return
	engraving_indicator.visible = true
	engraving_indicator.text = "[b]%d/%d[/b]" % [stored_farms, TowerData.CITY_CAPACITY]
	engraving_indicator.add_theme_color_override("font_color", Color(0.65, 0.9, 0.55))


func _update_engraving_indicator() -> void:
	# Aura-Tuerme gravieren einen Buff statt eines Elements - der bekommt dieselbe
	# Kennzeichnung ueber dem Turm, damit man Schaden/Tempo/Reichweite auf dem
	# Spielfeld unterscheiden kann.
	if tower_type == "aura":
		_update_aura_buff_indicator()
		return

	if tower_type == "city":
		_update_city_counter()
		return

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


func _update_aura_buff_indicator() -> void:
	if aura_buff_type == "":
		engraving_indicator.visible = false
		return

	engraving_indicator.visible = true
	engraving_indicator.text = IconSystem.bb(_get_aura_buff_icon_name(), 16) if IconSystem else "+"

	var buff_color := _get_aura_buff_color()
	engraving_indicator.add_theme_color_override("font_color", buff_color)

	if sprite:
		sprite.modulate = Color.WHITE.lerp(buff_color, 0.25)


func _get_aura_buff_icon_name() -> String:
	match aura_buff_type:
		"damage": return "damage"
		"range": return "range"
		"fire_rate": return "fire_rate"
		_: return "star_full"


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

	if not ResourceLoader.exists(texture_path):
		_setup_placeholder_sprite(data)
		sprite = null
		return

	sprite = Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.hframes = 1
	sprite.scale = Vector2(3, 3)
	if is_animated:
		sprite.vframes = 4
		var timer := Timer.new()
		timer.name = "AnimTimer"
		timer.wait_time = 0.15
		timer.autostart = true
		timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % 4)
		turret.add_child(timer)
	else:
		sprite.vframes = 1
	turret.add_child(sprite)


# Einheitlicher Platzhalter fuer Tuerme ohne Sprite (aktuell Zauberer, Kanone,
# Falle und Aura - siehe ASSETS_TODO.md). Bewusst ein Look fuer alle: vier
# verschiedene Vektorformen lesen sich wie ein Bug, ein konsistenter Sockel mit
# Typ-Glyphe wie eine Designentscheidung. Raster und Groesse folgen den echten
# Sprites (16x16 bei Skalierung 3).
func _setup_placeholder_sprite(data: Dictionary) -> void:
	var color: Color = data.get("color", Color.WHITE)

	var shadow := Polygon2D.new()
	shadow.polygon = _placeholder_silhouette(1.12, Vector2(0, PLACEHOLDER_PIXEL))
	shadow.color = Color(0.04, 0.05, 0.09, 0.5)
	turret.add_child(shadow)

	var outline := Polygon2D.new()
	outline.polygon = _placeholder_silhouette(1.12, Vector2.ZERO)
	outline.color = Color(0.08, 0.09, 0.14)
	turret.add_child(outline)

	var body := Polygon2D.new()
	body.polygon = _placeholder_silhouette(1.0, Vector2.ZERO)
	body.color = color
	turret.add_child(body)

	# Oberer Absatz etwas heller, damit der Sockel Volumen bekommt.
	var highlight := Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-5, -3) * PLACEHOLDER_PIXEL, Vector2(5, -3) * PLACEHOLDER_PIXEL,
		Vector2(5, -1) * PLACEHOLDER_PIXEL, Vector2(-5, -1) * PLACEHOLDER_PIXEL
	])
	highlight.color = color.lightened(0.35)
	turret.add_child(highlight)

	var glyph_name: String = PLACEHOLDER_GLYPHS.get(tower_type, "upgrades")
	var glyph_texture: Texture2D = IconSystem.get_texture(glyph_name) if IconSystem else null
	if glyph_texture:
		var glyph := Sprite2D.new()
		glyph.texture = glyph_texture
		glyph.position = Vector2(0, -PLACEHOLDER_PIXEL)
		glyph.modulate = Color(0.96, 0.96, 1.0)
		turret.add_child(glyph)


# Turm-Silhouette in "Pixeln" a PLACEHOLDER_PIXEL: breiter Sockel, verjuengter Kopf.
func _placeholder_silhouette(scale_factor: float, offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([
		Vector2(-7, 7), Vector2(7, 7), Vector2(7, 2), Vector2(5, 2),
		Vector2(5, -3), Vector2(3, -6), Vector2(-3, -6), Vector2(-5, -3),
		Vector2(-5, 2), Vector2(-7, 2)
	])
	var result := PackedVector2Array()
	for point in points:
		result.append(point * PLACEHOLDER_PIXEL * scale_factor + offset)
	return result


func _get_tower_texture_path() -> String:
	if level == 0:
		return "res://assets/elemental_tower/tower_%s.png" % tower_type
	else:
		return "res://assets/elemental_tower/tower_%s_level_%d.png" % [tower_type, level + 1]


func _update_level_indicator() -> void:
	for child in level_indicator.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(38, 17)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.075, 0.94)
	var accent: Color = TowerData.get_tower_data(tower_type).get("color", Color("75ddff"))
	if engraved_element != "" and ElementalSystem:
		accent = ElementalSystem.get_element_color(engraved_element)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	level_indicator.add_child(panel)

	var label := Label.new()
	label.text = "LV %d" % (level + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	level_indicator.scale = Vector2(1.18, 1.18)
	var tween := level_indicator.create_tween()
	tween.tween_property(level_indicator, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		if not RangeGridHelper.contains_point(position, enemy.position, tower_range):
			continue
		
		if tower_type == "cannon" and RangeGridHelper.is_inside_minimum(position, enemy.position, min_range):
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
		if RangeGridHelper.contains_point(position, enemy.position, tower_range):
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
		if SynergySystem:
			crit_mult += SynergySystem.get_crit_damage_bonus()
		melee_damage = int(float(damage) * crit_mult)
		if VFX:
			VFX.spawn_pixels(position, "crit", 6, 20.0)

	var kills := 0

	# Proc-Items (jeder N-te Schwung / bei Crit)
	shots_fired += 1
	if ItemSystem:
		var proc_target: Node2D = hit_enemies[0] if not hit_enemies.is_empty() else null
		ItemSystem.on_tower_shot(self, proc_target, is_crit, shots_fired)

	for enemy in hit_enemies:
		var was_alive: bool = true
		var h: Variant = enemy.get("health")
		if typeof(h) == TYPE_INT or typeof(h) == TYPE_FLOAT:
			was_alive = h > 0

		# Situative Items: Schadensbonus nur bei passendem Gegner-Zustand
		var bonus_mult := 1.0
		if ItemSystem:
			bonus_mult = ItemSystem.get_tower_conditional_mult(self, enemy)

		if enemy.has_method("take_damage"):
			# NEU: tower_type als 5. Parameter, bonus_mult als 6., self als Verursacher
			var dealt: int = enemy.take_damage(melee_damage, true, elem, is_crit, tower_type, bonus_mult, self)
			register_damage_dealt(dealt)
		_apply_melee_effects(enemy)

		# Treffer-basierte Procs (chance_on_hit / execute)
		if ItemSystem:
			ItemSystem.on_tower_hit(self, enemy)

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


# Meisterschafts-Multiplikator für Status-Dauern (control T1, water T3 für Freeze)
func _status_duration_mult(status: String) -> float:
	if SynergySystem:
		return SynergySystem.get_status_duration_mult(status)
	return 1.0


const MELEE_BURN_DURATION := 3.0


# Status-Effekte werden unabhaengig voneinander geprueft, nicht per `match special_type`.
# Gruende: (1) ein Item wie der Erdkern gibt stun_chance, ohne special_type zu setzen —
# ueber ein match waere der Bonus wirkungslos; (2) ein feuer-graviertes Schwert hatte gar
# keinen Burn-Zweig und brannte nie an; (3) Cleave und Stun koennen so koexistieren.
func _apply_melee_effects(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if stun_chance > 0.0 and randf() < stun_chance and enemy.has_method("apply_stun"):
		enemy.apply_stun(0.5 * _status_duration_mult("stun"))
	if slow_amount > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_amount, 2.0 * _status_duration_mult("slow"))
	if burn_damage > 0 and enemy.has_method("apply_burn"):
		enemy.apply_burn(burn_damage, MELEE_BURN_DURATION * _status_duration_mult("burn"))


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

		# Meisterschaft: crit T2 (+Crit-Schaden)
		if SynergySystem:
			crit_mult += SynergySystem.get_crit_damage_bonus()

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

	# Proc-Items (jeder N-te Schuss / bei Crit)
	shots_fired += 1
	if ItemSystem:
		ItemSystem.on_tower_shot(self, target, is_crit, shots_fired)

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
		"source_tower":      self,          # NEU: Referenz für situative Items & Procs
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
		if SynergySystem:
			crit_mult += SynergySystem.get_crit_damage_bonus()
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
		"source_tower_type": "cannon",
		"source_tower": self,
	}

	# Proc-Items (jeder N-te Schuss / bei Crit)
	shots_fired += 1
	if ItemSystem:
		ItemSystem.on_tower_shot(self, target, is_crit, shots_fired)
	
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

	
	get_parent().add_child(trap)
	active_traps.append(trap)

	if VFX:
		VFX.spawn_pixel_burst(trap_pos, elem if elem != "" else "earth", 4)
	
	Sound.play_click()


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
	"""Fallback: Zufällige Position in der quadratischen Rasterreichweite"""
	var extent := RangeGridHelper.get_half_extent(tower_range) * 0.9
	return position + Vector2(randf_range(-extent, extent), randf_range(-extent, extent))


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
		
		if RangeGridHelper.contains_point(position, tower.position, aura_range):
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
	is_selected = true
	# Reichweiten-Raster mit aktuellen Stats neu aufbauen und einblenden.
	_refresh_range_visuals()
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


func deselect() -> void:
	is_selected = false
	if selection_corners:
		selection_corners.queue_free()
		selection_corners = null
	if selection_tween:
		selection_tween.kill()
		selection_tween = null
	# Reichweiten-Raster wieder ausblenden.
	_refresh_range_visuals()


# Hebt den Turm auf dem Spielfeld hervor, ohne ihn auszuwaehlen - fuer das
# Hovern einer Zeile in der Turm-Statistik. Beisst sich bewusst nicht mit
# select()/deselect(), damit eine offene Auswahl erhalten bleibt.
func set_highlight(enabled: bool) -> void:
	if highlight_tween:
		highlight_tween.kill()
		highlight_tween = null

	if not enabled:
		modulate = Color.WHITE
		if range_visual:
			range_visual.visible = is_selected
		return

	if range_visual and attack_type != "none":
		range_visual.visible = true

	highlight_tween = create_tween().set_loops()
	highlight_tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.3), 0.3)
	highlight_tween.tween_property(self, "modulate", Color.WHITE, 0.3)


# Supply, das dieses Gebaeude beisteuert. Die Stadt hat einen eigenen Basiswert -
# aufgenommene Farmen kommen obendrauf.
func get_supply_bonus() -> int:
	if tower_type == "city":
		return TowerData.get_supply_bonus("city") + stored_farms * TowerData.get_supply_bonus("farm")
	return TowerData.get_supply_bonus(tower_type)


# Nimmt eine Farm auf. Deren Supply zaehlt danach ueber die Stadt weiter.
func store_farm() -> bool:
	if tower_type != "city" or stored_farms >= TowerData.CITY_CAPACITY:
		return false
	stored_farms += 1
	_update_city_counter()
	return true


func get_free_farm_slots() -> int:
	if tower_type != "city":
		return 0
	return maxi(0, TowerData.CITY_CAPACITY - stored_farms)


func get_range_cells() -> int:
	return RangeGridHelper.get_cell_radius(tower_range)


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
