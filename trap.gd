# trap.gd
# Falle die vom Trapper-Turm platziert wird
extends Node2D
class_name Trap

var damage := 25
var splash_radius := 0.0
var element := ""
var duration := 15.0
var special_type := ""
var source_tower: Node2D = null

var lifetime := 0.0
var is_triggered := false
var hit_enemies: Array[Node2D] = []

# Visuals
var sprite: Sprite2D
var trigger_area: Area2D
var timer_bar: ProgressBar
var armed_indicator: Node2D


func _ready() -> void:
	add_to_group("traps")
	_create_visuals()
	_create_trigger_area()



func setup(data: Dictionary) -> void:
	"""Initialisiert die Falle mit Daten"""
	damage = data.get("damage", 25)
	splash_radius = data.get("splash", 0.0)
	element = data.get("element", "")
	duration = data.get("duration", 15.0)
	special_type = data.get("special_type", "")
	source_tower = data.get("tower", null)
	
	if source_tower and "slow_amount" in source_tower:
		var trap_slow: float = source_tower.slow_amount
		if trap_slow > 0:
			print("[Trap] Falle mit %d%% Slow erstellt" % int(trap_slow * 100))
	
	print("[Trap] Falle platziert - Damage: %d, Element: %s, Duration: %.1fs" % [
		damage, element, duration
	])


func _create_visuals() -> void:
	"""Erstellt die visuelle Darstellung der Falle"""
	# Versuche Sprite zu laden
	var texture_path := "res://assets/traps/trap_%s.png" % element if element != "" else "res://assets/traps/trap_basic.png"
	
	if ResourceLoader.exists(texture_path):
		sprite = Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(2, 2)
		add_child(sprite)
	else:
		# Platzhalter: Kleines Polygon
		var poly := Polygon2D.new()
		
		# Verschiedene Formen je nach Element
		match element:
			"fire":
				# Kreisförmige Sprengfalle
				var points := PackedVector2Array()
				for i in range(8):
					var angle := i * TAU / 8
					points.append(Vector2(cos(angle), sin(angle)) * 12)
				poly.polygon = points
				poly.color = Color(1.0, 0.3, 0.0, 0.7)
			
			"water":
				# Eiskristall-Form
				poly.polygon = PackedVector2Array([
					Vector2(0, -14), Vector2(10, -7), Vector2(10, 7),
					Vector2(0, 14), Vector2(-10, 7), Vector2(-10, -7)
				])
				poly.color = Color(0.5, 0.8, 1.0, 0.7)
			
			"earth":
				# Spikes
				poly.polygon = PackedVector2Array([
					Vector2(-12, 8), Vector2(-6, -10), Vector2(0, 8),
					Vector2(6, -10), Vector2(12, 8), Vector2(0, 12)
				])
				poly.color = Color(0.6, 0.4, 0.2, 0.8)
			
			"air":
				# Blitz-Symbol
				poly.polygon = PackedVector2Array([
					Vector2(-4, -12), Vector2(4, -4), Vector2(0, 0),
					Vector2(8, 0), Vector2(-2, 12), Vector2(2, 4),
					Vector2(-6, 4)
				])
				poly.color = Color(0.9, 0.9, 1.0, 0.8)
			
			_:
				# Standard: Quadrat
				poly.polygon = PackedVector2Array([
					Vector2(-10, -10), Vector2(10, -10),
					Vector2(10, 10), Vector2(-10, 10)
				])
				poly.color = Color(0.4, 0.6, 0.3, 0.7)
		
		add_child(poly)
	
	# Trigger-Radius Anzeige (schwach sichtbar)
	var radius_circle := Line2D.new()
	radius_circle.width = 1
	radius_circle.default_color = Color(1, 1, 0, 0.2)
	var trigger_radius := 30.0  # Trigger-Bereich
	for i in range(17):
		var angle := i * TAU / 16
		radius_circle.add_point(Vector2(cos(angle), sin(angle)) * trigger_radius)
	add_child(radius_circle)
	
	# Timer-Anzeige (kleiner Balken)
	timer_bar = ProgressBar.new()
	timer_bar.position = Vector2(-15, -25)
	timer_bar.size = Vector2(30, 4)
	timer_bar.max_value = duration
	timer_bar.value = duration
	timer_bar.show_percentage = false
	
	# Style Timer Bar
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	timer_bar.add_theme_stylebox_override("background", style)
	
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.8, 0, 0.8)
	timer_bar.add_theme_stylebox_override("fill", fill)
	
	add_child(timer_bar)
	
	# "Armed" Blink-Indicator
	armed_indicator = Node2D.new()
	var arm_dot := Polygon2D.new()
	arm_dot.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
	])
	arm_dot.color = Color(1, 0, 0)
	arm_dot.position = Vector2(0, -18)
	armed_indicator.add_child(arm_dot)
	add_child(armed_indicator)
	
	# Blink-Animation
	var tween := create_tween().set_loops()
	tween.tween_property(armed_indicator, "modulate:a", 0.2, 0.5)
	tween.tween_property(armed_indicator, "modulate:a", 1.0, 0.5)


func _create_trigger_area() -> void:
	"""Erstellt den Trigger-Bereich der Falle"""
	trigger_area = Area2D.new()
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 2  # Enemy-Layer
	add_child(trigger_area)
	
	var shape := CircleShape2D.new()
	shape.radius = 30.0  # Trigger-Reichweite
	
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.name = "TrapCollision"  # ✅ Namen geben für später
	trigger_area.add_child(collision)
	
	# Signals
	trigger_area.area_entered.connect(_on_enemy_entered)



func _on_enemy_entered(area: Area2D) -> void:
	"""Wird aufgerufen wenn ein Enemy in die Falle läuft"""
	if is_triggered:
		return
	
	# ✅ Check das Parent-Node (der Enemy selbst)
	var body := area.get_parent()
	if not body or not body.is_in_group("enemies"):
		return
	
	# Trigger sofort!
	_trigger_trap(body)


func _trigger_trap(triggering_enemy: Node2D) -> void:
	"""Aktiviert die Falle"""
	if is_triggered:  # ✅ Double-check
		return
	
	is_triggered = true
	
	# ✅ SOFORT Kollision deaktivieren damit keine weiteren Triggers kommen
	if trigger_area:
		trigger_area.set_deferred("monitoring", false)
		trigger_area.set_deferred("monitorable", false)
		var collision := trigger_area.get_node_or_null("TrapCollision")
		if collision:
			collision.set_deferred("disabled", true)
	
	print("[Trap] Falle ausgelöst von Enemy!")
	
	# Finde alle Enemies in Splash-Reichweite
	var affected_enemies: Array[Node2D] = []
	
	if is_instance_valid(triggering_enemy):
		affected_enemies.append(triggering_enemy)
		print("[Trap] Triggering Enemy hinzugefügt")
	
	if splash_radius > 0:
		var all_enemies := get_tree().get_nodes_in_group("enemies")
		for enemy in all_enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy == triggering_enemy:  
				continue
			
			var dist := position.distance_to(enemy.position)
			if dist <= splash_radius:
				affected_enemies.append(enemy)
				print("[Trap] Extra Enemy in Splash: %.0f" % dist)
	
	print("[Trap] Treffe insgesamt %d Enemies" % affected_enemies.size())
	
	# ✅ Slow-Amount vom Source-Tower holen
	var trap_slow := 0.0
	if source_tower and "slow_amount" in source_tower:
		trap_slow = source_tower.slow_amount
	
	# Schaden anwenden
	for enemy in affected_enemies:
		if not is_instance_valid(enemy):
			continue
		
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, false, element, false)
			print("[Trap] Schaden angewendet: %d" % damage)
		
		# ✅ Base-Slow anwenden
		if trap_slow > 0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(trap_slow, 2.0)
		
		# Spezial-Effekte
		_apply_trap_effects(enemy)
	
	# VFX
	if VFX:
		match element:
			"fire":
				VFX.spawn_pixel_explosion(position, element, 12, 40.0)
				VFX.spawn_pixel_ring(position, element, 60.0)
			"water":
				VFX.spawn_pixel_burst(position, element, 8)
				VFX.spawn_freeze_effect(position)
			"earth":
				VFX.spawn_pixel_burst(position, element, 10)
				for i in range(4):
					var angle := i * TAU / 4
					VFX.spawn_spike(position + Vector2(cos(angle), sin(angle)) * 20)
			"air":
				VFX.spawn_lightning_arc(position, triggering_enemy.position if is_instance_valid(triggering_enemy) else position + Vector2(0, -30))
				VFX.spawn_pixel_burst(position, element, 6)
			_:
				VFX.spawn_pixel_explosion(position, "earth", 8, 30.0)
	
	# Sound
	Sound.play_explosion() if Sound.has_method("play_explosion") else Sound.play_impact()
	
	# Screen Shake bei großer Explosion
	if splash_radius > 50 and VFX:
		VFX.screen_shake(2.0, 0.1)
	
	# ✅ Falle SOFORT unsichtbar machen
	visible = false
	
	# ✅ Falle entfernen (deferred ist okay, da wir schon disabled haben)
	queue_free()


func _apply_trap_effects(enemy: Node2D) -> void:
	"""Wendet spezielle Effekte basierend auf Element an"""
	if not is_instance_valid(enemy):
		return
	
	match element:
		"fire":
			# Brennen
			if enemy.has_method("apply_burn"):
				var burn_dmg := int(damage * 0.3)  # 30% vom Schaden als DoT
				enemy.apply_burn(burn_dmg, 3.0)
		
		"water":
			# Freeze + Slow
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.5, 2.0)  # 50% langsamer für 2s
			if enemy.has_method("apply_freeze"):
				if randf() < 0.3:  # 30% Chance
					enemy.apply_freeze(1.0)
		
		"earth":
			# Stun + Bleed
			if enemy.has_method("apply_stun"):
				if randf() < 0.4:  # 40% Stun-Chance
					enemy.apply_stun(1.5)
			# Bleed (DoT über Zeit)
			if enemy.has_method("apply_burn"):  # Reuse burn für bleed
				var bleed_dmg := int(damage * 0.2)
				enemy.apply_burn(bleed_dmg, 4.0)
		
		"air":
			# Chain Lightning zu nahen Enemies
			var chain_range := 100.0
			var chained := 0
			var max_chains := 2
			
			for other in get_tree().get_nodes_in_group("enemies"):
				if other == enemy or chained >= max_chains:
					continue
				var dist := enemy.position.distance_to(other.position)
				if dist <= chain_range:
					if other.has_method("take_damage"):
						var chain_dmg := int(damage * 0.6)  # 60% auf gekettet
						other.take_damage(chain_dmg, false, element, false)
						chained += 1
						
						if VFX:
							VFX.spawn_lightning_arc(enemy.position, other.position)


func _process(delta: float) -> void:
	"""Update Lifetime und zerstöre Falle wenn abgelaufen"""
	if is_triggered:
		return
	
	lifetime += delta
	
	# Update Timer Bar
	if timer_bar:
		timer_bar.value = duration - lifetime
	
	# Abgelaufen?
	if lifetime >= duration:
		_expire()


func _expire() -> void:
	"""Falle ist abgelaufen ohne zu triggern"""
	print("[Trap] Falle abgelaufen")
	
	# Kleiner Verpuff-Effekt
	if VFX:
		VFX.spawn_pixel_burst(position, element if element != "" else "earth", 3)
	
	queue_free()


func get_remaining_time() -> float:
	"""Gibt verbleibende Zeit zurück"""
	return max(0.0, duration - lifetime)


func is_active() -> bool:
	"""Ist die Falle noch aktiv?"""
	return not is_triggered and lifetime < duration
