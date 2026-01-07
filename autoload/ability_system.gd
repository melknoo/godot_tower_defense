# autoload/ability_system.gd
# Active Abilities für direktes Gameplay während Wellen
extends Node

signal ability_used(ability_id: String)
signal ability_ready(ability_id: String)
signal cooldown_updated(ability_id: String, remaining: float, total: float)

# Ability-Definitionen
const ABILITIES := {
	"lightning": {
		"name": "Blitzschlag",
		"description": "Schlägt mit Blitz ein und springt zu nahen Gegnern",
		"icon": "⚡",
		"element": "air",
		"cooldown": 8.0,
		"base_damage": 80,
		"radius": 40.0,
		"chain_count": 3,
		"chain_range": 120.0,
		"hotkey": KEY_1
	},
	"frost_nova": {
		"name": "Frostnova",
		"description": "Friert alle Gegner im Bereich ein",
		"icon": "❄️",
		"element": "water",
		"cooldown": 12.0,
		"base_damage": 30,
		"radius": 100.0,
		"freeze_duration": 2.5,
		"hotkey": KEY_2
	},
	"meteor": {
		"name": "Meteor",
		"description": "Ruft einen Meteor herbei (0.8s Verzögerung)",
		"icon": "☄️",
		"element": "fire",
		"cooldown": 15.0,
		"base_damage": 200,
		"radius": 80.0,
		"impact_delay": 0.8,
		"burn_damage": 15,
		"burn_duration": 3.0,
		"hotkey": KEY_3
	},
	"earthquake": {
		"name": "Erdbeben",
		"description": "Stunt alle Gegner auf dem Bildschirm",
		"icon": "🌋",
		"element": "earth",
		"cooldown": 20.0,
		"base_damage": 50,
		"stun_duration": 1.5,
		"hotkey": KEY_4
	}
}

# Aktive Cooldowns
var cooldowns: Dictionary = {}

# Ob gerade eine Ability ausgewählt ist (für Targeting)
var selected_ability: String = ""
var is_targeting := false


func _ready() -> void:
	# Cooldowns initialisieren (alle bereit)
	for ability_id in ABILITIES:
		cooldowns[ability_id] = 0.0
	print("[AbilitySystem] Initialisiert mit %d Abilities" % ABILITIES.size())


func _process(delta: float) -> void:
	# Cooldowns nur während aktiver Welle aktualisieren
	if not GameState.wave_active:
		return
	
	for ability_id in cooldowns:
		if cooldowns[ability_id] > 0:
			cooldowns[ability_id] = maxf(0.0, cooldowns[ability_id] - delta)
			cooldown_updated.emit(ability_id, cooldowns[ability_id], ABILITIES[ability_id]["cooldown"])
			
			if cooldowns[ability_id] <= 0:
				ability_ready.emit(ability_id)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	# Hotkey-Check
	for ability_id in ABILITIES:
		if event.keycode == ABILITIES[ability_id]["hotkey"]:
			_on_ability_hotkey(ability_id)
			return


func _on_ability_hotkey(ability_id: String) -> void:
	# Wenn bereits diese Ability ausgewählt, abbrechen
	if selected_ability == ability_id:
		cancel_targeting()
		return
	
	# Prüfen ob verfügbar
	if not can_use_ability(ability_id):
		Sound.play_error()
		return
	
	# Targeting starten
	start_targeting(ability_id)


func start_targeting(ability_id: String) -> void:
	selected_ability = ability_id
	is_targeting = true
	Sound.play_click()
	print("[AbilitySystem] Targeting: %s" % ability_id)


func cancel_targeting() -> void:
	selected_ability = ""
	is_targeting = false


func can_use_ability(ability_id: String) -> bool:
	if not ABILITIES.has(ability_id):
		return false
	if cooldowns.get(ability_id, 0.0) > 0:
		return false
	if not GameState.wave_active:
		return false
	return true


func is_ability_ready(ability_id: String) -> bool:
	return cooldowns.get(ability_id, 0.0) <= 0


func get_cooldown_percent(ability_id: String) -> float:
	if not ABILITIES.has(ability_id):
		return 0.0
	var total: float = ABILITIES[ability_id]["cooldown"]
	var remaining: float = cooldowns.get(ability_id, 0.0)
	if total <= 0:
		return 0.0
	return remaining / total


func get_remaining_cooldown(ability_id: String) -> float:
	return cooldowns.get(ability_id, 0.0)


# === ABILITY EXECUTION ===

func execute_ability(ability_id: String, target_pos: Vector2) -> bool:
	if not can_use_ability(ability_id):
		return false
	
	# Cooldown starten
	cooldowns[ability_id] = ABILITIES[ability_id]["cooldown"]
	
	# Element-Bonus berechnen
	var element: String = ABILITIES[ability_id]["element"]
	var power_mult := get_ability_power_multiplier(ability_id)
	
	# Ability ausführen
	match ability_id:
		"lightning":
			_execute_lightning(target_pos, power_mult)
		"frost_nova":
			_execute_frost_nova(target_pos, power_mult)
		"meteor":
			_execute_meteor(target_pos, power_mult)
		"earthquake":
			_execute_earthquake(power_mult)
	
	ability_used.emit(ability_id)
	cancel_targeting()
	
	print("[AbilitySystem] %s ausgeführt bei %s (x%.1f Power)" % [ability_id, target_pos, power_mult])
	return true


func get_ability_power_multiplier(ability_id: String) -> float:
	var element: String = ABILITIES[ability_id]["element"]
	var base_mult := 1.0
	
	# Bonus wenn Element freigeschaltet
	if TowerData:
		var elem_level := TowerData.get_element_level(element)
		base_mult += elem_level * 0.25  # +25% pro Element-Level
	
	# Upgrade-System Boni
	if UpgradeSystem:
		var elem_bonus := UpgradeSystem.get_element_bonus(element, "damage")
		base_mult += elem_bonus
	
	return base_mult


# === LIGHTNING ===

func _execute_lightning(pos: Vector2, power: float) -> void:
	var data: Dictionary = ABILITIES["lightning"]
	var damage := int(data["base_damage"] * power)
	var chain_count: int = data["chain_count"]
	var chain_range: float = data["chain_range"]
	
	# Ersten Treffer finden
	var first_target := _find_closest_enemy(pos, data["radius"])
	var hit_pos := pos
	
	if first_target:
		hit_pos = first_target.position
		_deal_damage_to(first_target, damage, "air")
	
	# VFX für ersten Einschlag
	if VFX:
		VFX.spawn_pixel_burst(hit_pos, "air", 20)
		VFX.spawn_pixel_ring(hit_pos, "air", 60.0)
		VFX.screen_shake(6.0, 0.15)
		VFX.screen_flash(Color(0.8, 0.9, 1.0), 0.1)
	
	Sound.play_shoot("air", 2)
	
	# Chain Lightning
	if first_target:
		_do_lightning_chain(first_target, damage / 2, chain_count, chain_range, [first_target])


func _do_lightning_chain(from_enemy: Node2D, damage: int, remaining: int, range: float, hit_list: Array) -> void:
	if remaining <= 0:
		return
	
	var next_target: Node2D = null
	var closest_dist := range
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in hit_list:
			continue
		var dist := from_enemy.position.distance_to(enemy.position)
		if dist < closest_dist:
			closest_dist = dist
			next_target = enemy
	
	if next_target:
		hit_list.append(next_target)
		_deal_damage_to(next_target, damage, "air")
		_draw_lightning_bolt(from_enemy.position, next_target.position)
		
		# Rekursiv weiter
		var tree := get_tree()
		if tree:
			await tree.create_timer(0.05).timeout
			_do_lightning_chain(next_target, int(damage * 0.8), remaining - 1, range, hit_list)


func _draw_lightning_bolt(from: Vector2, to: Vector2) -> void:
	var main := get_tree().current_scene
	if not main:
		return
	
	var line := Line2D.new()
	line.width = 3
	line.default_color = Color(0.7, 0.85, 1.0)
	
	var segments := 6
	var dir := (to - from) / segments
	var perp := dir.rotated(PI/2).normalized()
	
	line.add_point(from)
	for i in range(1, segments):
		line.add_point(from + dir * i + perp * randf_range(-15, 15))
	line.add_point(to)
	
	main.add_child(line)
	
	if VFX:
		VFX.spawn_pixels(to, "air", 6, 20.0)
	
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)


# === FROST NOVA ===

func _execute_frost_nova(pos: Vector2, power: float) -> void:
	var data: Dictionary = ABILITIES["frost_nova"]
	var damage := int(data["base_damage"] * power)
	var radius: float = data["radius"]
	var freeze_duration: float = data["freeze_duration"] * power
	
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if pos.distance_to(enemy.position) <= radius:
			_deal_damage_to(enemy, damage, "water")
			if enemy.has_method("apply_freeze"):
				enemy.apply_freeze(freeze_duration)
			hit_count += 1
	
	# VFX
	if VFX:
		VFX.spawn_pixel_ring(pos, "ice", radius)
		VFX.spawn_pixel_burst(pos, "ice", 24)
		
		# Expanding frost ring
		for i in range(3):
			await get_tree().create_timer(0.1).timeout
			VFX.spawn_pixel_ring(pos, "water", radius * (0.4 + i * 0.3))
		
		if hit_count > 3:
			VFX.screen_shake(4.0, 0.1)
		VFX.screen_flash(Color(0.7, 0.9, 1.0), 0.1)
	
	Sound.play_shoot("ice", 2)
	print("[AbilitySystem] Frost Nova traf %d Gegner" % hit_count)


# === METEOR ===

func _execute_meteor(pos: Vector2, power: float) -> void:
	var data: Dictionary = ABILITIES["meteor"]
	var delay: float = data["impact_delay"]
	
	# Warning indicator
	_spawn_meteor_warning(pos, data["radius"], delay)
	
	# Sound für ankommenden Meteor
	Sound.play_shoot("fire", 1)
	
	# Verzögerter Impact
	await get_tree().create_timer(delay).timeout
	_meteor_impact(pos, power)


func _spawn_meteor_warning(pos: Vector2, radius: float, duration: float) -> void:
	var main := get_tree().current_scene
	if not main:
		return
	
	# Roter Kreis der schrumpft
	var warning := Node2D.new()
	warning.position = pos
	main.add_child(warning)
	
	var circle := Line2D.new()
	circle.width = 3
	circle.default_color = Color(1.0, 0.3, 0.1, 0.6)
	
	for i in range(33):
		var angle := i * TAU / 32
		circle.add_point(Vector2(cos(angle), sin(angle)) * radius)
	
	warning.add_child(circle)
	
	# Innerer pulsierender Kreis
	var inner := Line2D.new()
	inner.width = 2
	inner.default_color = Color(1.0, 0.5, 0.0, 0.4)
	
	for i in range(33):
		var angle := i * TAU / 32
		inner.add_point(Vector2(cos(angle), sin(angle)) * radius * 0.5)
	
	warning.add_child(inner)
	
	# Animation
	var tw := warning.create_tween()
	tw.set_parallel(true)
	tw.tween_property(circle, "scale", Vector2(0.3, 0.3), duration)
	tw.tween_property(circle, "default_color:a", 1.0, duration)
	tw.tween_property(inner, "scale", Vector2(1.5, 1.5), duration)
	tw.tween_property(inner, "default_color:a", 0.0, duration)
	tw.chain().tween_callback(warning.queue_free)


func _meteor_impact(pos: Vector2, power: float) -> void:
	var data: Dictionary = ABILITIES["meteor"]
	var damage := int(data["base_damage"] * power)
	var radius: float = data["radius"]
	var burn_dmg: int = int(data["burn_damage"] * power)
	var burn_dur: float = data["burn_duration"]
	
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := pos.distance_to(enemy.position)
		if dist <= radius:
			# Schaden fällt mit Distanz ab
			var damage_mult := 1.0 - (dist / radius) * 0.5
			_deal_damage_to(enemy, int(damage * damage_mult), "fire")
			if enemy.has_method("apply_burn"):
				enemy.apply_burn(burn_dmg, burn_dur)
			hit_count += 1
	
	# EPIC VFX
	if VFX:
		VFX.spawn_pixel_burst(pos, "fire", 30)
		VFX.spawn_pixel_burst(pos, "lava", 20)
		VFX.spawn_pixel_ring(pos, "fire", radius)
		VFX.spawn_pixel_ring(pos, "lava", radius * 0.6)
		VFX.screen_shake(12.0, 0.3)
		VFX.screen_flash(Color(1.0, 0.6, 0.2), 0.15)
	
	Sound.play_shoot("fire", 2)
	Sound.play_shoot("lava", 2)
	
	print("[AbilitySystem] Meteor Impact traf %d Gegner" % hit_count)


# === EARTHQUAKE ===

func _execute_earthquake(power: float) -> void:
	var data: Dictionary = ABILITIES["earthquake"]
	var damage := int(data["base_damage"] * power)
	var stun_dur: float = data["stun_duration"] * power
	
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_deal_damage_to(enemy, damage, "earth")
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(stun_dur)
		hit_count += 1
	
	# Screen-wide VFX
	if VFX:
		var viewport := get_viewport()
		if viewport:
			var center := viewport.get_visible_rect().size / 2
			
			# Multiple shockwaves
			for i in range(4):
				await get_tree().create_timer(0.08).timeout
				VFX.spawn_pixel_ring(center + Vector2(randf_range(-100, 100), randf_range(-50, 50)), "earth", 150.0 + i * 50)
			
			VFX.spawn_pixel_burst(center, "earth", 40)
		
		VFX.screen_shake(15.0, 0.4)
		VFX.screen_flash(Color(0.6, 0.4, 0.2), 0.1)
	
	Sound.play_shoot("earth", 2)
	print("[AbilitySystem] Earthquake traf %d Gegner" % hit_count)


# === HELPERS ===

func _find_closest_enemy(pos: Vector2, max_range: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist := max_range
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := pos.distance_to(enemy.position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	
	return closest


func _deal_damage_to(enemy: Node2D, damage: int, element: String) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, true, element)


# === API ===

func get_ability_data(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


func get_all_ability_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ABILITIES:
		ids.append(id)
	return ids
