# ui/ability_bar.gd
# Zeigt die 4 aktiven Abilities mit Cooldowns
extends Control
class_name AbilityBar

signal ability_clicked(ability_id: String)

var ability_buttons: Dictionary = {}
var ability_order: Array[String] = ["lightning", "frost_nova", "meteor", "earthquake"]
var selection_tweens: Dictionary = {}

const BUTTON_SIZE := 56
const BUTTON_SPACING := 8
const HOTKEY_NAMES := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4"}

const ELEMENT_COLORS := {
	"air": Color(0.7, 0.85, 1.0),
	"water": Color(0.4, 0.7, 1.0),
	"fire": Color(1.0, 0.5, 0.2),
	"earth": Color(0.7, 0.5, 0.3)
}


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_all_buttons()


func _setup_ui() -> void:
	var total_width := ability_order.size() * (BUTTON_SIZE + BUTTON_SPACING) - BUTTON_SPACING
	custom_minimum_size = Vector2(total_width + 20, BUTTON_SIZE + 30)
	
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.border_width_top = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	bg.add_theme_stylebox_override("panel", style)
	
	var title := Label.new()
	title.text = "Abilities"
	title.position = Vector2(10, 2)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(title)
	
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(10, 18)
	hbox.add_theme_constant_override("separation", BUTTON_SPACING)
	add_child(hbox)
	
	for ability_id in ability_order:
		var btn := _create_ability_button(ability_id)
		hbox.add_child(btn)
		ability_buttons[ability_id] = btn


func _create_ability_button(ability_id: String) -> Control:
	var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
	var element: String = data.get("element", "")
	var elem_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	var icon_name: String = data.get("icon_name", "")
	
	var container := Control.new()
	container.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 14)
	container.name = ability_id
	
	# Selection Glow (hinter dem Button)
	var glow := ColorRect.new()
	glow.name = "SelectionGlow"
	glow.color = elem_color
	glow.color.a = 0.0
	glow.position = Vector2(-4, -4)
	glow.size = Vector2(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow)
	
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	
	# Normal Style
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.18)
	normal_style.border_color = elem_color.darkened(0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal_style)
	
	# Selected Style (für später)
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = elem_color.darkened(0.7)
	selected_style.border_color = elem_color
	selected_style.set_border_width_all(3)
	selected_style.set_corner_radius_all(6)
	
	# Styles in Meta speichern
	btn.set_meta("normal_style", normal_style)
	btn.set_meta("selected_style", selected_style)
	btn.set_meta("elem_color", elem_color)
	
	# Hover style
	var hover := normal_style.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.25)
	hover.border_color = elem_color
	btn.add_theme_stylebox_override("hover", hover)
	
	# Disabled style
	var disabled := normal_style.duplicate()
	disabled.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)
	
	container.add_child(btn)
	
	# === ICON (TextureRect direkt im Button, manuell zentriert) ===
	var icon_tex: Texture2D = null
	if IconSystem and icon_name:
		icon_tex = IconSystem.get_texture(icon_name)
	
	var icon_size := 32
	var icon_offset := (BUTTON_SIZE - icon_size) / 2
	
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
		# Fallback auf Element-Buchstabe
		var fallback := Label.new()
		fallback.name = "Icon"
		fallback.text = element.substr(0, 1).to_upper()
		fallback.position = Vector2(icon_offset, icon_offset - 4)
		fallback.add_theme_font_size_override("font_size", 24)
		fallback.add_theme_color_override("font_color", elem_color)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(fallback)
	
	# Cooldown Overlay (halbtransparentes Rechteck)
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
	cd_label.add_theme_color_override("font_color", Color.BLACK)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.visible = false
	btn.add_child(cd_label)
	
	# Hotkey Label unter dem Button
	var hotkey := Label.new()
	hotkey.name = "Hotkey"
	var key: int = data.get("hotkey", 0)
	hotkey.text = HOTKEY_NAMES.get(key, "?")
	hotkey.position = Vector2(BUTTON_SIZE / 2 - 4, BUTTON_SIZE + 1)
	hotkey.add_theme_font_size_override("font_size", 10)
	hotkey.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	container.add_child(hotkey)
	
	# Selected Indicator (Balken unten)
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
	
	return container


func _connect_signals() -> void:
	if AbilitySystem:
		AbilitySystem.cooldown_updated.connect(_on_cooldown_updated)
		AbilitySystem.ability_used.connect(_on_ability_used)
		AbilitySystem.ability_ready.connect(_on_ability_ready)
	
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)


func _process(_delta: float) -> void:
	if not AbilitySystem:
		return
	
	for ability_id in ability_buttons:
		var container: Control = ability_buttons[ability_id]
		var is_selected: bool = AbilitySystem.selected_ability == ability_id
		var was_selected: bool = container.get_meta("was_selected", false)
		
		# Nur bei Änderung aktualisieren
		if is_selected != was_selected:
			container.set_meta("was_selected", is_selected)
			_update_selection_visual(ability_id, is_selected)


func _update_selection_visual(ability_id: String, is_selected: bool) -> void:
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
		# Selected Style anwenden
		var selected_style: StyleBoxFlat = btn.get_meta("selected_style")
		btn.add_theme_stylebox_override("normal", selected_style)
		
		if indicator:
			indicator.visible = true
		
		# Glow einblenden + Pulsieren starten
		if glow:
			var tw := create_tween().set_loops()
			tw.tween_property(glow, "color:a", 0.4, 0.5).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(glow, "color:a", 0.15, 0.5).set_ease(Tween.EASE_IN_OUT)
			selection_tweens[ability_id] = tw
	else:
		# Normal Style zurück
		var normal_style: StyleBoxFlat = btn.get_meta("normal_style")
		btn.add_theme_stylebox_override("normal", normal_style)
		
		if indicator:
			indicator.visible = false
		
		# Glow ausblenden
		if glow:
			glow.color.a = 0.0


func _on_ability_button_pressed(ability_id: String) -> void:
	if not AbilitySystem:
		return
	
	if AbilitySystem.can_use_ability(ability_id):
		AbilitySystem.start_targeting(ability_id)
		ability_clicked.emit(ability_id)
	else:
		Sound.play_error()


func _on_cooldown_updated(ability_id: String, remaining: float, total: float) -> void:
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
			overlay.size.y = (BUTTON_SIZE - 4) * percent
		if cd_label:
			cd_label.visible = true
			cd_label.text = "%.0f" % ceilf(remaining)
	else:
		if overlay:
			overlay.visible = false
		if cd_label:
			cd_label.visible = false


func _on_ability_used(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	if not btn:
		return
	
	var icon := btn.get_node_or_null("Icon")
	
	if icon:
		var tw := icon.create_tween()
		tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.1)
		tw.tween_property(icon, "modulate", Color.WHITE, 0.2)


func _on_ability_ready(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	
	if btn:
		var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
		var element: String = data.get("element", "")
		var elem_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
		
		var tw := container.create_tween()
		tw.tween_property(container, "modulate", elem_color.lightened(0.3), 0.15)
		tw.tween_property(container, "modulate", Color.WHITE, 0.2)


func _on_wave_started(_wave: int) -> void:
	_set_buttons_enabled(true)


func _on_wave_completed(_wave: int) -> void:
	_set_buttons_enabled(false)
	
	if AbilitySystem:
		AbilitySystem.cancel_targeting()


func _set_buttons_enabled(enabled: bool) -> void:
	for ability_id in ability_buttons:
		var container: Control = ability_buttons[ability_id]
		var btn := container.get_node_or_null("Button") as Button
		if btn:
			btn.disabled = not enabled
		
		container.modulate.a = 1.0 if enabled else 0.5


func _update_all_buttons() -> void:
	_set_buttons_enabled(GameState.wave_active)
