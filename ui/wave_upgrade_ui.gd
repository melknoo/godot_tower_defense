# ui/wave_upgrade_ui.gd
# Zeigt nach jeder Welle 3 Upgrade-Optionen mit Reroll-Option
extends CanvasLayer
class_name WaveUpgradeUI

signal upgrade_chosen(upgrade_id: String)
signal panel_closed

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var cards_container: HBoxContainer
var skip_button: Button
var reroll_button: Button

var current_options: Array[String] = []
var current_wave: int = 0

# Reroll-Kosten steigen pro Benutzung
const BASE_REROLL_COST := 30
var rerolls_used := 0

const CARD_WIDTH := 180
const CARD_HEIGHT := 220
const CATEGORY_COLORS := {
	"element": Color(0.4, 0.6, 1.0),
	"economy": Color(1.0, 0.85, 0.3),
	"supply": Color(0.5, 0.8, 0.4),
	"global": Color(0.9, 0.5, 0.9),
	"special": Color(1.0, 0.5, 0.3),
	"instant": Color(0.3, 1.0, 0.6),
	"tower_type": Color(0.7, 0.7, 0.8),
	"wave": Color(0.8, 0.4, 0.8)
}


func _ready() -> void:
	layer = 150  # Höher als andere UI-Panels (Inventar etc.)
	visible = false
	# WICHTIG: Muss während Pause funktionieren
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()


func _setup_ui() -> void:
	# Dunkler Hintergrund
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	add_child(bg)
	
	# Zentrierter Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	add_child(center)
	
	# Hauptpanel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 420)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	center.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UI.SP_5)
	margin.add_theme_constant_override("margin_right", UI.SP_5)
	margin.add_theme_constant_override("margin_top", UI.SP_5)
	margin.add_theme_constant_override("margin_bottom", UI.SP_5)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	margin.add_child(vbox)
	
	# Titel
	title_label = Label.new()
	title_label.text = "Welle abgeschlossen!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("edf3ff"))
	vbox.add_child(title_label)
	
	# Untertitel
	subtitle_label = Label.new()
	subtitle_label.text = "Wähle ein Upgrade für diesen Run:"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color("9aa8c2"))
	vbox.add_child(subtitle_label)
	
	# Cards Container
	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 15)
	cards_container.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	vbox.add_child(cards_container)
	
	# Button-Container
	var button_hbox := HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	button_hbox.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	vbox.add_child(button_hbox)
	
	# Reroll Button
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(140, 35)
	reroll_button.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_button.theme_type_variation = &"SecondaryButton"
	_update_reroll_button_text()
	button_hbox.add_child(reroll_button)

	reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Skip Button
	skip_button = Button.new()
	skip_button.text = "Überspringen"
	skip_button.custom_minimum_size = Vector2(140, 35)
	skip_button.visible = false
	skip_button.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	skip_button.pressed.connect(_on_skip_pressed)
	skip_button.theme_type_variation = &"SecondaryButton"
	button_hbox.add_child(skip_button)

	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func show_upgrades(wave: int) -> void:
	current_wave = wave
	rerolls_used = 0
	
	# Schließe alle anderen UI-Panels die offen sein könnten
	_close_other_panels()
	
	get_tree().paused = true
	
	title_label.text = "Welle %d abgeschlossen!" % wave
	
	# Upgrades holen
	if not UpgradeSystem:
		print("[WaveUpgradeUI] ERROR: UpgradeSystem nicht gefunden!")
		hide_panel()
		return
	
	current_options = UpgradeSystem.get_random_upgrades(3)
	
	_create_upgrade_cards()
	_update_reroll_button_text()
	
	if current_options.is_empty():
		subtitle_label.text = "Alle Upgrades bereits maximiert!"
		skip_button.visible = true
		reroll_button.visible = false
	else:
		subtitle_label.text = "Wähle ein Upgrade für diesen Run:"
		skip_button.visible = false
		reroll_button.visible = true
	
	visible = true

	# Animation (Panel-Tween läuft weiter, obwohl der Baum pausiert ist)
	if UITheme:
		UITheme.animate_panel_open(panel)

	print("[WaveUpgradeUI] Panel angezeigt mit %d Optionen" % current_options.size())


func hide_panel() -> void:
	if UITheme:
		UITheme.animate_panel_close(panel, func():
			visible = false
			get_tree().paused = false
		)
	panel_closed.emit()


func _update_reroll_button_text() -> void:
	var cost := get_reroll_cost()
	
	# Für Buttons können wir kein BBCode nutzen, also setzen wir das Icon direkt
	var gold_tex: Texture2D = null
	if IconSystem:
		gold_tex = IconSystem.get_texture("gold")
	
	if gold_tex:
		reroll_button.icon = gold_tex
		reroll_button.text = "🎲 Reroll (%d)" % cost
	else:
		reroll_button.icon = null
		reroll_button.text = "🎲 Reroll (%d💰)" % cost
	
	if GameState and GameState.can_afford(cost):
		reroll_button.disabled = false
		reroll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		reroll_button.disabled = true


func get_reroll_cost() -> int:
	return BASE_REROLL_COST + (rerolls_used * 20)


func _on_reroll_pressed() -> void:
	var cost := get_reroll_cost()
	if not GameState or not GameState.can_afford(cost):
		if Sound:
			Sound.play_error()
		return
	
	# Gold abziehen
	GameState.gold -= cost
	rerolls_used += 1
	
	if Sound:
		Sound.play_click()
	if VFX:
		VFX.screen_flash(Color(1.0, 1.0, 0.3), 0.1)
	
	# Neue Optionen generieren
	current_options = UpgradeSystem.get_random_upgrades(3)
	_create_upgrade_cards()
	_update_reroll_button_text()


func _create_upgrade_cards() -> void:
	# Alte Cards entfernen
	for child in cards_container.get_children():
		child.queue_free()
	
	for upgrade_id in current_options:
		var card := _create_card(upgrade_id)
		cards_container.add_child(card)


func _create_card(upgrade_id: String) -> PanelContainer:
	var data: Dictionary = UpgradeSystem.get_upgrade_data(upgrade_id)
	var current_stacks: int = UpgradeSystem.get_upgrade_stacks(upgrade_id)
	var stat: String = data.get("stat")
	var max_stacks: int = data.get("max_stacks", 1)
	var category: String = data.get("category", "special")
	var cat_color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	
	# Card Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20273b")
	style.border_color = cat_color.darkened(0.15)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	margin.add_child(vbox)
	
	# Icon - versuche IconSystem, Fallback auf Emoji
	var icon_name := _get_icon_for_upgrade(upgrade_id, data)
	var icon_tex: Texture2D = null
	if IconSystem and not icon_name.is_empty():
		icon_tex = IconSystem.get_texture(icon_name)
	
	if icon_tex:
		# Icon als TextureRect
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)
	else:
		# Fallback: Emoji Label
		var icon_label := Label.new()
		icon_label.text = data.get("icon", "?")
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 48)
		vbox.add_child(icon_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("f2f5ff"))
	vbox.add_child(name_label)
	
	# Stack-Anzeige
	if current_stacks > 0:
		var stack_label := Label.new()
		stack_label.text = "★".repeat(mini(current_stacks, 5))
		if current_stacks > 5:
			stack_label.text += " +%d" % (current_stacks - 5)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_label.add_theme_font_size_override("font_size", 16)
		stack_label.add_theme_color_override("font_color", Color("f4cf6a"))
		vbox.add_child(stack_label)
	
	# Beschreibung
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = CARD_WIDTH - 20
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color("c1cbe0"))
	vbox.add_child(desc_label)
	
	# Tooltip falls vorhanden
	if data.has("tooltip"):
		var tooltip_label := Label.new()
		tooltip_label.text = data.get("tooltip", "")
		tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		tooltip_label.custom_minimum_size.x = CARD_WIDTH - 20
		tooltip_label.add_theme_font_size_override("font_size", 16)
		tooltip_label.add_theme_color_override("font_color", Color("8f9bb2"))
		vbox.add_child(tooltip_label)
	
	# Kategorie-Badge
	var category_label := Label.new()
	var cat_name: String = _get_category_name(category)
	category_label.text = cat_name
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", 16)
	category_label.add_theme_color_override("font_color", cat_color.lightened(0.18))
	vbox.add_child(category_label)
	
	# Stack-Info
	if max_stacks > 1:
		var stack_info := Label.new()
		stack_info.text = "(%d/%d)" % [current_stacks + 1, max_stacks]
		stack_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack_info.add_theme_font_size_override("font_size", 16)
		stack_info.add_theme_color_override("font_color", Color("8491aa"))
		vbox.add_child(stack_info)
	
	# Spacer - drückt Button nach unten
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size.y = 5  # Mindestabstand
	vbox.add_child(spacer)
	
	# Button
	var btn := Button.new()
	btn.text = "Wählen"
	btn.custom_minimum_size.y = 32
	btn.process_mode = Node.PROCESS_MODE_ALWAYS  # WICHTIG
	btn.pressed.connect(_on_card_selected.bind(upgrade_id))
	vbox.add_child(btn)
	
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Hover-Effekt
	card.mouse_entered.connect(func():
		var hover_style := style.duplicate()
		hover_style.bg_color = Color("2b3550")
		hover_style.border_color = cat_color
		card.add_theme_stylebox_override("panel", hover_style)
	)
	
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", style)
	)
	
	return card


func _get_category_name(category: String) -> String:
	match category:
		"economy": return "Wirtschaft"
		"supply": return "Versorgung"
		"global": return "Global"
		"element": return "Element"
		"special": return "Spezial"
		"instant": return "Sofort"
		"tower_type": return "Turm-Typ"
		"wave": return "Wellen"
		_: return category.capitalize()


func _close_other_panels() -> void:
	"""Schließt andere UI-Panels die im Weg sein könnten"""
	# Inventar schließen
	var item_inventory := get_node_or_null("/root/Main/ItemInventoryUI")
	if item_inventory and item_inventory.has_method("hide_panel") and item_inventory.visible:
		item_inventory.hide_panel()
		print("[WaveUpgradeUI] Inventar geschlossen")
	
	# Element-Unlock-UI schließen
	var element_ui := get_node_or_null("/root/Main/ElementUnlockUI")
	if element_ui and element_ui.has_method("hide_panel") and element_ui.visible:
		element_ui.hide_panel()
		print("[WaveUpgradeUI] Element-UI geschlossen")
	
	# Upgrade-Overview schließen
	var upgrade_overview := get_node_or_null("/root/Main/UpgradeOverviewUI")
	if upgrade_overview and upgrade_overview.has_method("hide_panel") and upgrade_overview.visible:
		upgrade_overview.hide_panel()
		print("[WaveUpgradeUI] Upgrade-Overview geschlossen")


func _get_icon_for_upgrade(upgrade_id: String, data: Dictionary) -> String:
	"""Versucht ein passendes Icon aus IconSystem zu finden"""
	var category: String = data.get("category", "")
	var element: String = data.get("element", "")
	
	# Element-basierte Upgrades
	if not element.is_empty():
		if element == "fire":
			return "fire"
		elif element == "water":
			return "water"
		elif element == "earth":
			return "earth"
		elif element == "air":
			return "air"
		elif element == "ice":
			return "ice"
		elif element == "lightning":
			return "lightning"
		elif element == "nature":
			return "nature"
		elif element == "lava":
			return "lava"
		elif element == "steam":
			return "steam"
	
	# Spezifische Upgrade-IDs mit passenden Icons
	match upgrade_id:
		# Economy - Gold Icon
		"interest_bonus", "flat_bonus", "interest_rate", "starting_gold", "enemy_gold", "tower_discount", "sell_value":
			return "gold"
		# Supply
		"supply_max", "farm_bonus":
			return "supply"
		# Global/Combat
		"global_damage", "global_range", "global_fire_rate", "crit_chance", "splash_bonus":
			return "upgrades"
		# Abilities
		"isolated_damage", "isolated_range":
			return "upgrades"
		# Tower-Type spezifisch (falls Icons existieren)
		"archer_damage":
			return ""  # Kein Archer-Icon verfügbar
		"wizard_damage":
			return ""  # Kein Wizard-Icon verfügbar
		"sword_damage":
			return ""  # Kein Sword-Icon verfügbar
		# Wellen-Spawn
		"fire_spawn_rate":
			return "fire"
		"water_spawn_rate":
			return "water"
		"earth_spawn_rate":
			return "earth"
		"air_spawn_rate":
			return "air"
		_:
			# Kein Icon gefunden - verwende Emoji
			return ""


func _on_card_selected(upgrade_id: String) -> void:
	if Sound:
		Sound.play_click()
	
	UpgradeSystem.activate_upgrade(upgrade_id)
	hide_panel()
	upgrade_chosen.emit(upgrade_id)


func _on_skip_pressed() -> void:
	if Sound:
		Sound.play_click()
	hide_panel()
	upgrade_chosen.emit("")
