# ui/ability_bar.gd
# Zeigt die 4 aktiven Abilities mit Cooldowns
extends Control
class_name AbilityBar

signal ability_clicked(ability_id: String)

var ability_buttons: Dictionary = {}
var ability_order: Array[String] = ["lightning", "frost_nova", "meteor", "earthquake"]

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
	# Container Setup
	var total_width := ability_order.size() * (BUTTON_SIZE + BUTTON_SPACING) - BUTTON_SPACING
	custom_minimum_size = Vector2(total_width + 20, BUTTON_SIZE + 30)
	
	# Background Panel
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
	
	# Title
	var title := Label.new()
	title.text = "Abilities"
	title.position = Vector2(10, 2)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(title)
	
	# HBox für Buttons
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(10, 18)
	hbox.add_theme_constant_override("separation", BUTTON_SPACING)
	add_child(hbox)
	
	# Ability Buttons erstellen
	for ability_id in ability_order:
		var btn := _create_ability_button(ability_id)
		hbox.add_child(btn)
		ability_buttons[ability_id] = btn


func _create_ability_button(ability_id: String) -> Control:
	var data: Dictionary = AbilitySystem.get_ability_data(ability_id)
	var element: String = data.get("element", "")
	var elem_color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	
	# Container für Button + Overlays
	var container := Control.new()
	container.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 14)
	container.name = ability_id
	
	# Haupt-Button
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.position = Vector2(0, 0)
	btn.flat = true
	btn.pressed.connect(_on_ability_button_pressed.bind(ability_id))
	container.add_child(btn)
	
	# Button Style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.18, 0.22)
	btn_style.border_color = elem_color.darkened(0.3)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style)
	
	var hover_style := btn_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.3)
	hover_style.border_color = elem_color
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := btn_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.15, 0.18)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Icon Label
	var icon := Label.new()
	icon.name = "Icon"
	icon.text = data.get("icon", "?")
	icon.position = Vector2(BUTTON_SIZE/2 - 14, 4)
	icon.add_theme_font_size_override("font_size", 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon)
	
	# Cooldown Overlay (dunkler Balken der von oben nach unten schrumpft)
	var cooldown_overlay := ColorRect.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.color = Color(0.1, 0.1, 0.1, 0.7)
	cooldown_overlay.position = Vector2(2, 2)
	cooldown_overlay.size = Vector2(BUTTON_SIZE - 4, BUTTON_SIZE - 4)
	cooldown_overlay.visible = false
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(cooldown_overlay)
	
	# Cooldown Text
	var cd_label := Label.new()
	cd_label.name = "CooldownLabel"
	cd_label.position = Vector2(BUTTON_SIZE/2 - 10, BUTTON_SIZE/2 - 10)
	cd_label.add_theme_font_size_override("font_size", 16)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cd_label.add_theme_constant_override("outline_size", 3)
	cd_label.visible = false
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(cd_label)
	
	# Hotkey Label
	var hotkey := Label.new()
	hotkey.name = "Hotkey"
	var hotkey_code: int = data.get("hotkey", 0)
	hotkey.text = HOTKEY_NAMES.get(hotkey_code, "?")
	hotkey.position = Vector2(BUTTON_SIZE/2 - 4, BUTTON_SIZE + 2)
	hotkey.add_theme_font_size_override("font_size", 10)
	hotkey.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hotkey)
	
	# Selected Indicator
	var selected_indicator := ColorRect.new()
	selected_indicator.name = "SelectedIndicator"
	selected_indicator.color = elem_color
	selected_indicator.position = Vector2(0, BUTTON_SIZE - 3)
	selected_indicator.size = Vector2(BUTTON_SIZE, 3)
	selected_indicator.visible = false
	selected_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(selected_indicator)
	
	# Tooltip
	btn.tooltip_text = "%s\n%s\nCooldown: %.0fs\nHotkey: %s" % [
		data.get("name", ability_id),
		data.get("description", ""),
		data.get("cooldown", 0.0),
		HOTKEY_NAMES.get(hotkey_code, "?")
	]
	
	return container


func _connect_signals() -> void:
	if AbilitySystem:
		AbilitySystem.cooldown_updated.connect(_on_cooldown_updated)
		AbilitySystem.ability_used.connect(_on_ability_used)
		AbilitySystem.ability_ready.connect(_on_ability_ready)
	
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)


func _process(_delta: float) -> void:
	# Selected state aktualisieren
	if AbilitySystem:
		for ability_id in ability_buttons:
			var container: Control = ability_buttons[ability_id]
			var indicator := container.get_node_or_null("SelectedIndicator") as ColorRect
			if indicator:
				indicator.visible = AbilitySystem.selected_ability == ability_id


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
	var overlay := container.get_node_or_null("CooldownOverlay") as ColorRect
	var cd_label := container.get_node_or_null("CooldownLabel") as Label
	
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
	var icon := container.get_node_or_null("Icon") as Label
	
	if icon:
		# Flash Animation
		var tw := icon.create_tween()
		tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.1)
		tw.tween_property(icon, "modulate", Color.WHITE, 0.2)


func _on_ability_ready(ability_id: String) -> void:
	if not ability_buttons.has(ability_id):
		return
	
	var container: Control = ability_buttons[ability_id]
	var btn := container.get_node_or_null("Button") as Button
	var icon := container.get_node_or_null("Icon") as Label
	
	# Ready pulse animation
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
	
	# Targeting abbrechen
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
