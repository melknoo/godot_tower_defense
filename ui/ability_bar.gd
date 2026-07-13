# ui/ability_bar.gd
# Zeigt nur die ausgerüsteten Abilities mit Cooldowns
extends Control
class_name AbilityBar

signal ability_clicked(ability_id: String)

var ability_buttons: Dictionary = {}
var button_container: HBoxContainer
var selection_tweens: Dictionary = {}

const BUTTON_SIZE := 56
const BUTTON_SPACING := 8
const MAX_SLOTS := 4

const ELEMENT_COLORS := {
	"air": Color(0.7, 0.85, 1.0),
	"water": Color(0.4, 0.7, 1.0),
	"fire": Color(1.0, 0.5, 0.2),
	"earth": Color(0.7, 0.5, 0.3)
}


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_rebuild_ability_buttons()


func _setup_ui() -> void:
	var total_width := MAX_SLOTS * (BUTTON_SIZE + BUTTON_SPACING) - BUTTON_SPACING
	custom_minimum_size = Vector2(total_width + 20, BUTTON_SIZE + 52)
	
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	if UITheme:
		UITheme.style_panel(bg, "carved_small")
	
	var title := Label.new()
	title.text = "Fähigkeiten"
	title.position = Vector2(14, 9)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
	if UITheme and UITheme.game_font:
		title.add_theme_font_override("font", UITheme.game_font)
	add_child(title)
	
	button_container = HBoxContainer.new()
	button_container.position = Vector2(10, 29)
	button_container.add_theme_constant_override("separation", BUTTON_SPACING)
	add_child(button_container)


func _connect_signals() -> void:
	if AbilitySystem:
		AbilitySystem.cooldown_updated.connect(_on_cooldown_updated)
		AbilitySystem.ability_used.connect(_on_ability_used)
		AbilitySystem.ability_ready.connect(_on_ability_ready)
		AbilitySystem.abilities_changed.connect(_on_abilities_changed)
		AbilitySystem.ability_upgraded.connect(_on_ability_upgraded)
	
	if GameState:
		GameState.wave_started.connect(_on_wave_started)
		GameState.wave_completed.connect(_on_wave_completed)


func _on_ability_upgraded(ability_id: String, _stat: String, _new_value: float) -> void:
	_update_ability_tooltip(ability_id)


# Erweiterte Tooltip-Generierung:
func _update_ability_tooltip(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	if not btn or not AbilitySystem:
		return
	
	var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
	if data.is_empty():
		return
	
	var tooltip_parts: Array[String] = []
	
	# === HEADER ===
	var ability_name: String = data.get("name", ability_id)
	var element: String = data.get("element", "")
	tooltip_parts.append("[b]%s[/b] (%s)" % [ability_name, element.capitalize()])
	
	# === BESCHREIBUNG ===
	var desc: String = data.get("description", "")
	if not desc.is_empty():
		tooltip_parts.append(desc)
		tooltip_parts.append("")  # Leerzeile
	
	# === HAUPTSTATS ===
	var stats: Array[String] = []
	
	# Cooldown
	var cooldown := AbilitySystem.get_effective_cooldown(ability_id)
	stats.append("⏱ Cooldown: %.1fs" % cooldown)
	
	# Damage (falls vorhanden)
	if data.has("base_damage") and data.base_damage > 0:
		var damage := int(AbilitySystem.get_effective_damage(ability_id))
		stats.append("⚔ Schaden: %d" % damage)
	
	# Radius/Range
	if data.has("radius"):
		var radius := AbilitySystem.get_effective_stat(ability_id, "radius")
		stats.append("◯ Reichweite: %.0f" % radius)
	elif data.has("range"):
		var range_val := AbilitySystem.get_effective_stat(ability_id, "range")
		stats.append("◯ Reichweite: %.0f" % range_val)
	
	tooltip_parts.append("\n".join(stats))
	
	# === SPEZIELLE EFFEKTE ===
	var special_effects: Array[String] = []
	
	# Chain Lightning
	if data.has("chain_count"):
		var chains := int(AbilitySystem.get_effective_stat(ability_id, "chain_count"))
		var chain_range := AbilitySystem.get_effective_stat(ability_id, "chain_range")
		special_effects.append("⚡ Ketten: %d (Reichweite: %.0f)" % [chains, chain_range])
	
	# Freeze
	if data.has("freeze_duration"):
		var freeze := AbilitySystem.get_effective_stat(ability_id, "freeze_duration")
		special_effects.append("❄ Einfrieren: %.1fs" % freeze)
	
	# Stun
	if data.has("stun_duration"):
		var stun := AbilitySystem.get_effective_stat(ability_id, "stun_duration")
		special_effects.append("💫 Betäubung: %.1fs" % stun)
	
	# Burn
	if data.has("burn_damage"):
		var burn_dmg := int(AbilitySystem.get_effective_stat(ability_id, "burn_damage"))
		var burn_dur := AbilitySystem.get_effective_stat(ability_id, "burn_duration")
		special_effects.append("🔥 Verbrennung: %d/s für %.1fs" % [burn_dmg, burn_dur])
	
	# Slow
	if data.has("slow_amount"):
		var slow := AbilitySystem.get_effective_stat(ability_id, "slow_amount") * 100
		var slow_dur := AbilitySystem.get_effective_stat(ability_id, "slow_duration")
		special_effects.append("🐌 Verlangsamung: %.0f%% für %.1fs" % [slow, slow_dur])
	
	# Duration-based abilities
	if data.has("duration") and not data.has("freeze_duration") and not data.has("slow_duration"):
		var duration := AbilitySystem.get_effective_stat(ability_id, "duration")
		special_effects.append("⏳ Dauer: %.1fs" % duration)
	
	# Meteor Shower specific
	if data.has("meteor_count"):
		var count := int(AbilitySystem.get_effective_stat(ability_id, "meteor_count"))
		special_effects.append("☄ Meteore: %d" % count)
	
	# Area Radius (für Abilities wie Meteor Shower)
	if data.has("area_radius"):
		var area := AbilitySystem.get_effective_stat(ability_id, "area_radius")
		special_effects.append("◯ Bereich: %.0f" % area)
	
	# Wall specific
	if data.has("wall_health"):
		var health := int(AbilitySystem.get_effective_stat(ability_id, "wall_health"))
		var wall_dur := AbilitySystem.get_effective_stat(ability_id, "wall_duration")
		special_effects.append("🧱 Wand: %d HP für %.1fs" % [health, wall_dur])
	
	if not special_effects.is_empty():
		tooltip_parts.append("")  # Leerzeile
		tooltip_parts.append("\n".join(special_effects))
	
	# === UPGRADES ===
	var total_upgrades := AbilitySystem.get_total_upgrade_stacks(ability_id)
	if total_upgrades > 0:
		tooltip_parts.append("")  # Leerzeile
		var upgrade_text := "★ Upgrades: %d" % total_upgrades
		
		# Details zu einzelnen Upgrade-Typen
		var upgrade_details: Array[String] = []
		var upgrades: Dictionary = AbilitySystem.get_ability_upgrades(ability_id)
		
		for stat in upgrades:
			var stacks: int = upgrades[stat]
			if stacks > 0:
				var display_name := _get_stat_display_name(stat)
				upgrade_details.append("  • %s +%d" % [display_name, stacks])
		
		tooltip_parts.append(upgrade_text)
		if not upgrade_details.is_empty():
			tooltip_parts.append("\n".join(upgrade_details))
	
	# Tooltip setzen
	btn.tooltip_text = "\n".join(tooltip_parts)


func _on_abilities_changed() -> void:
	_rebuild_ability_buttons()


func _get_stat_display_name(stat: String) -> String:
	match stat:
		"cooldown": return "Cooldown"
		"damage": return "Schaden"
		"radius": return "Reichweite"
		"chain_count": return "Ketten"
		"chain_range": return "Kettenreichweite"
		"freeze_duration": return "Einfrierdauer"
		"stun_duration": return "Betäubungsdauer"
		"burn_damage": return "Verbrennungsschaden"
		"burn_duration": return "Verbrennungsdauer"
		"slow_amount": return "Verlangsamung"
		"slow_duration": return "Verlangsamungsdauer"
		"duration": return "Dauer"
		"meteor_count": return "Meteore"
		"area_radius": return "Bereich"
		"wall_health": return "Wandgesundheit"
		"wall_duration": return "Wanddauer"
		"length": return "Länge"
		"width": return "Breite"
		"push_distance": return "Rückstoß"
		"tick_rate": return "Tick-Rate"
		"damage_falloff": return "Schadensabfall"
		_: return stat.capitalize()


func _rebuild_ability_buttons() -> void:
	# Alte Buttons entfernen
	for child in button_container.get_children():
		child.queue_free()
	ability_buttons.clear()
	selection_tweens.clear()
	
	if not AbilitySystem:
		return
	
	var equipped := AbilitySystem.get_equipped_abilities()
	
	# Buttons für equipped Abilities erstellen
	for i in range(equipped.size()):
		var ability_id: String = equipped[i]
		var slot_index: int = i
		var btn := _create_ability_button(ability_id, slot_index)
		button_container.add_child(btn)
		ability_buttons[ability_id] = btn
	
	# Leere Slots für nicht-belegte Plätze
	for i in range(equipped.size(), MAX_SLOTS):
		var empty_slot := _create_empty_slot(i)
		button_container.add_child(empty_slot)
	
	_update_all_buttons()


func _create_ability_button(ability_id: String, slot_index: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 15)
	container.name = "Ability_%s" % ability_id
	
	var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
	var element: String = data.get("element", "")
	var elem_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	var icon_name: String = data.get("icon_name", "")
	
	# Selection Glow (hinter dem Button)
	var glow := ColorRect.new()
	glow.name = "SelectionGlow"
	glow.color = Color(elem_color.r, elem_color.g, elem_color.b, 0.0)
	glow.position = Vector2(-4, -4)
	glow.size = Vector2(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow)
	
	# Button
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.position = Vector2.ZERO
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.2)
	normal_style.border_color = elem_color.darkened(0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.25)
	hover_style.border_color = elem_color
	
	var selected_style := normal_style.duplicate()
	selected_style.bg_color = elem_color.darkened(0.6)
	selected_style.border_color = elem_color.lightened(0.2)
	selected_style.set_border_width_all(3)
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	
	btn.set_meta("normal_style", normal_style)
	btn.set_meta("selected_style", selected_style)
	btn.set_meta("elem_color", elem_color)
	
	container.add_child(btn)
	
	# Icon
	var icon_offset := (BUTTON_SIZE - 32) / 2
	var icon_size := 32
	
	var icon_tex: Texture2D = null
	if IconSystem:
		icon_tex = IconSystem.get_texture(icon_name)
		if not icon_tex:
			icon_tex = IconSystem.get_texture(element)
	
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.texture = icon_tex
		icon_rect.position = Vector2(icon_offset, icon_offset)
		icon_rect.size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.modulate = elem_color.lightened(0.2)
		btn.add_child(icon_rect)
	else:
		var fallback := Label.new()
		fallback.name = "Icon"
		fallback.text = element.substr(0, 1).to_upper()
		fallback.position = Vector2(icon_offset, icon_offset - 4)
		fallback.add_theme_font_size_override("font_size", 24)
		fallback.add_theme_color_override("font_color", elem_color)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(fallback)
	
	# Cooldown Overlay
	var cooldown_overlay := ColorRect.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.color = Color(0.2, 0.2, 0.2, 0.7)
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.visible = false
	btn.add_child(cooldown_overlay)
	
	# Cooldown Text
	var cd_label := Label.new()
	cd_label.name = "CooldownLabel"
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_label.add_theme_font_size_override("font_size", 16)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cd_label.add_theme_constant_override("outline_size", 3)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	btn.add_child(cd_label)
	
	# Hotkey Label (1-4 basierend auf Slot)
	var hotkey := Label.new()
	hotkey.name = "Hotkey"
	hotkey.text = str(slot_index + 1)
	hotkey.position = Vector2(BUTTON_SIZE / 2 - 4, BUTTON_SIZE + 1)
	hotkey.add_theme_font_size_override("font_size", 10)
	hotkey.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	container.add_child(hotkey)
	
	# Upgrade Stars
	var upgrade_stacks: int = AbilitySystem.get_total_upgrade_stacks(ability_id)
	if upgrade_stacks > 0:
		var stars := Label.new()
		stars.name = "UpgradeStars"
		stars.text = ""
		for _i in range(mini(upgrade_stacks, 5)):
			stars.text += "★"
		stars.position = Vector2(2, -2)
		stars.add_theme_font_size_override("font_size", 8)
		stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(stars)
	
	# Selected Indicator
	var indicator := ColorRect.new()
	indicator.name = "SelectedIndicator"
	indicator.color = elem_color
	indicator.position = Vector2(0, BUTTON_SIZE - 3)
	indicator.size = Vector2(BUTTON_SIZE, 3)
	indicator.visible = false
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(indicator)
	
	# Click Handler
	btn.pressed.connect(_on_ability_button_pressed.bind(ability_id))

	call_deferred("_update_ability_tooltip", ability_id)
	
	return container


func _create_empty_slot(slot_index: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 15)
	container.name = "EmptySlot_%d" % slot_index
	
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.disabled = true
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.border_color = Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	container.add_child(btn)
	
	# Slot Nummer
	var slot_label := Label.new()
	slot_label.text = str(slot_index + 1)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_label.add_theme_font_size_override("font_size", 20)
	slot_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(slot_label)
	
	# Hotkey Label
	var hotkey := Label.new()
	hotkey.name = "Hotkey"
	hotkey.text = str(slot_index + 1)
	hotkey.position = Vector2(BUTTON_SIZE / 2 - 4, BUTTON_SIZE + 1)
	hotkey.add_theme_font_size_override("font_size", 10)
	hotkey.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	container.add_child(hotkey)
	
	return container


func _update_all_buttons() -> void:
	if not AbilitySystem:
		return
	
	for ability_id in ability_buttons:
		var remaining := AbilitySystem.get_remaining_cooldown(ability_id)
		var total := AbilitySystem.get_effective_cooldown(ability_id)
		_update_cooldown_display(ability_id, remaining, total)


func _update_cooldown_display(ability_id: String, remaining: float, total: float) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	if not btn:
		return
	
	var overlay := btn.get_node_or_null("CooldownOverlay") as ColorRect
	var cd_label := btn.get_node_or_null("CooldownLabel") as Label
	
	if remaining > 0:
		if overlay:
			overlay.visible = true
			var percent := remaining / total
			overlay.size.y = BUTTON_SIZE * percent
			overlay.position.y = BUTTON_SIZE * (1.0 - percent)
		if cd_label:
			cd_label.visible = true
			cd_label.text = "%.1f" % remaining
		btn.disabled = true
	else:
		if overlay:
			overlay.visible = false
		if cd_label:
			cd_label.visible = false
		btn.disabled = false


func _process(_delta: float) -> void:
	if not AbilitySystem:
		return
	
	for ability_id in ability_buttons:
		var container: Control = ability_buttons[ability_id]
		var is_selected: bool = AbilitySystem.selected_ability == ability_id
		var was_selected: bool = container.get_meta("was_selected", false)
		
		if is_selected != was_selected:
			container.set_meta("was_selected", is_selected)
			_update_selection_visual(ability_id, is_selected)


func _update_selection_visual(ability_id: String, is_selected: bool) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	var indicator := container.get_node_or_null("SelectedIndicator") as ColorRect
	var glow := container.get_node_or_null("SelectionGlow") as ColorRect
	
	if not btn:
		return
	
	var elem_color: Color = btn.get_meta("elem_color", Color.WHITE)
	
	# Alte Animation stoppen
	if selection_tweens.has(ability_id) and selection_tweens[ability_id]:
		selection_tweens[ability_id].kill()
		selection_tweens.erase(ability_id)
	
	if is_selected:
		var selected_style: StyleBoxFlat = btn.get_meta("selected_style")
		if selected_style:
			btn.add_theme_stylebox_override("normal", selected_style)
		
		if indicator:
			indicator.visible = true
		
		if glow:
			glow.color.a = 0.2
			var tw := create_tween().set_loops()
			tw.tween_property(glow, "color:a", 0.4, 0.5).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(glow, "color:a", 0.15, 0.5).set_ease(Tween.EASE_IN_OUT)
			selection_tweens[ability_id] = tw
	else:
		var normal_style: StyleBoxFlat = btn.get_meta("normal_style")
		if normal_style:
			btn.add_theme_stylebox_override("normal", normal_style)
		
		if indicator:
			indicator.visible = false
		
		if glow:
			glow.color.a = 0.0


func _on_ability_button_pressed(ability_id: String) -> void:
	if not AbilitySystem:
		return
	
	if AbilitySystem.can_use_ability(ability_id):
		AbilitySystem.start_targeting(ability_id)
		ability_clicked.emit(ability_id)
	elif Sound:
		Sound.play_error()


func _on_cooldown_updated(ability_id: String, remaining: float, total: float) -> void:
	_update_cooldown_display(ability_id, remaining, total)


func _on_ability_used(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	if btn:
		# Flash Effekt
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.2)


func _on_ability_ready(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	if btn:
		# Ready Pulse
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1.3, 1.3, 1.0), 0.15)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.15)
	
	if Sound:
		Sound.play_click()


func _on_wave_started(_wave: int) -> void:
	_update_all_buttons()


func _on_wave_completed(_wave: int) -> void:
	# Cooldowns bei Wellenende optional zurücksetzen
	pass
