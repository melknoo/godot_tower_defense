# ui/tower_info.gd
# Panel für Tower-Info, Verkauf, Upgrade, Engraving und Pickup
extends PanelContainer
class_name TowerInfo

signal sell_pressed
signal upgrade_pressed
signal close_pressed
signal engrave_pressed(element: String)
signal pickup_pressed  # NEU

var tower_name_label: Label
var tower_level_label: Label
var stats_label: Label
var element_label: Label
var supply_info_label: Label
var blocked_info_label: Label  # NEU: Zeigt "Auf Pfad" Warnung
var sell_button: Button
var upgrade_button: Button
var pickup_button: Button  # NEU
var engrave_container: HBoxContainer
var close_button: Button
var vbox: VBoxContainer

var current_tower: Node2D = null
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var tower_manager: TowerManager = null


func _ready() -> void:
	visible = false
	_setup_panel_style()
	_setup_ui()
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	z_as_relative = false
	z_index = 200


func _bring_to_front() -> void:
	var p := get_parent()
	if p:
		p.move_child(self, p.get_child_count() - 1)


func _setup_panel_style() -> void:
	UITheme.style_panel(self, "panel_dark")


func _setup_ui() -> void:
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)
	
	tower_name_label = Label.new()
	tower_name_label.name = "TowerNameLabel"
	tower_name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tower_name_label)
	
	tower_level_label = Label.new()
	tower_level_label.name = "TowerLevelLabel"
	tower_level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tower_level_label)
	
	element_label = Label.new()
	element_label.name = "ElementLabel"
	element_label.add_theme_font_size_override("font_size", 11)
	element_label.visible = false
	vbox.add_child(element_label)
	
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(stats_label)
	
	supply_info_label = Label.new()
	supply_info_label.name = "SupplyInfoLabel"
	supply_info_label.add_theme_font_size_override("font_size", 10)
	supply_info_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(supply_info_label)
	
	# NEU: Blocked-Info Label
	blocked_info_label = Label.new()
	blocked_info_label.name = "BlockedInfoLabel"
	blocked_info_label.add_theme_font_size_override("font_size", 11)
	blocked_info_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	blocked_info_label.visible = false
	vbox.add_child(blocked_info_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	engrave_container = HBoxContainer.new()
	engrave_container.name = "EngraveContainer"
	engrave_container.add_theme_constant_override("separation", 4)
	engrave_container.visible = false
	vbox.add_child(engrave_container)
	
	var engrave_label := Label.new()
	engrave_label.text = "Gravieren:"
	engrave_label.add_theme_font_size_override("font_size", 10)
	engrave_label.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	engrave_container.add_child(engrave_label)
	
	# NEU: Pickup Button (für Umplatzierung)
	pickup_button = Button.new()
	pickup_button.name = "PickupButton"
	pickup_button.text = "Aufnehmen"
	pickup_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	pickup_button.pressed.connect(_on_pickup_pressed)
	vbox.add_child(pickup_button)
	
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(upgrade_button)
	
	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	sell_button.pressed.connect(_on_sell_pressed)
	vbox.add_child(sell_button)
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Schließen"
	close_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)
	
	UITheme.style_button(pickup_button)
	UITheme.style_button(upgrade_button)
	UITheme.style_button(sell_button)
	UITheme.style_button(close_button)


func set_tower_manager(tm: TowerManager) -> void:
	tower_manager = tm


func show_tower(tower: Node2D, grid_pos: Vector2i) -> void:
	current_tower = tower
	current_grid_pos = grid_pos
	
	_update_display()
	visible = true
	
	size = get_combined_minimum_size()

	var screen_size := get_viewport_rect().size
	var margin := 10.0
	var tile := 64.0

	var tower_y := float(grid_pos.y) * tile + tile * 0.5
	var open_up := tower_y > screen_size.y * 0.5

	position.x = float(grid_pos.x) * tile + tile + margin
	position.y = (tower_y - size.y - margin) if open_up else (tower_y + margin)

	if position.x + size.x > screen_size.x - margin:
		position.x = float(grid_pos.x) * tile - size.x - margin

	position.x = clamp(position.x, margin, screen_size.x - size.x - margin)
	position.y = clamp(position.y, margin, screen_size.y - size.y - margin)

	call_deferred("_bring_to_front")


func hide_panel() -> void:
	visible = false
	current_tower = null
	current_grid_pos = Vector2i(-1, -1)


func _update_display() -> void:
	if not current_tower or not tower_manager:
		return
	
	var tower_type: String = current_tower.tower_type
	var level: int = tower_manager.get_tower_level(current_grid_pos)
	var data := TowerData.get_tower_data(tower_type)
	var is_blocked := tower_manager.is_tower_blocked(current_grid_pos)
	
	var display_name: String = data.get("name", tower_type.capitalize())
	
	if current_tower.has_method("is_engraved") and current_tower.is_engraved():
		var elem_symbol := ElementalSystem.get_element_symbol(current_tower.engraved_element) if ElementalSystem else ""
		tower_name_label.text = "%s %s" % [display_name, elem_symbol]
	else:
		tower_name_label.text = display_name
	
	if TowerData.is_supply_building(tower_type):
		tower_level_label.text = "Supply-Gebäude"
	elif tower_type in TowerData.UNLOCKABLE_ELEMENTS:
		var elem_level := TowerData.get_element_level(tower_type)
		var max_allowed := TowerData.get_max_tower_level_for_element(tower_type)
		tower_level_label.text = "Level %d / %d (Element: %d/3)" % [level + 1, max_allowed + 1, elem_level]
	else:
		tower_level_label.text = "Level %d / %d" % [level + 1, TowerData.MAX_LEVEL + 1]
	
	_update_element_display()
	
	if TowerData.is_supply_building(tower_type):
		var bonus := TowerData.get_supply_bonus(tower_type)
		stats_label.text = "Supply Bonus: +%d" % bonus
	else:
		var damage_val: int = TowerData.get_stat(tower_type, "damage", level)
		var range_val: float = TowerData.get_stat(tower_type, "range", level)
		var fire_rate_val: float = TowerData.get_stat(tower_type, "fire_rate", level)
		
		stats_label.text = "Schaden: %d\nReichweite: %d\nFeuerrate: %.1f/s" % [
			damage_val, int(range_val), 1.0 / fire_rate_val if fire_rate_val > 0 else 0
		]
	
	_update_supply_info(level)
	_update_blocked_info(is_blocked)
	
	var dark_color := Color(0.094, 0.094, 0.094)
	tower_name_label.add_theme_color_override("font_color", dark_color)
	tower_level_label.add_theme_color_override("font_color", dark_color)
	stats_label.add_theme_color_override("font_color", dark_color)
	
	_update_pickup_button(is_blocked)
	_update_upgrade_button(tower_type, level)
	_update_sell_button(level)
	_update_engrave_buttons()


func _update_blocked_info(is_blocked: bool) -> void:
	if is_blocked:
		blocked_info_label.visible = true
		blocked_info_label.text = "⚠ Steht auf dem Pfad!\nKlicke 'Aufnehmen' zum Umplatzieren"
	else:
		blocked_info_label.visible = false


func _update_pickup_button(is_blocked: bool) -> void:
	if not pickup_button:
		return
	
	pickup_button.visible = true
	
	if GameState.wave_active:
		pickup_button.disabled = true
		pickup_button.text = "Aufnehmen"
		pickup_button.tooltip_text = "Nicht während einer Welle"
	else:
		pickup_button.disabled = false
		if is_blocked:
			pickup_button.text = "⚠ Aufnehmen"
			pickup_button.tooltip_text = "Turm aufnehmen und umplatzieren (kostenlos)"
			# Hervorheben wenn blockiert
			pickup_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		else:
			pickup_button.text = "Aufnehmen"
			pickup_button.tooltip_text = "Turm aufnehmen und umplatzieren (kostenlos)"
			pickup_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))


func _update_supply_info(level: int) -> void:
	if TowerData.is_supply_building(current_tower.tower_type):
		supply_info_label.text = "⛺ Supply: 0 (gratis!)"
		supply_info_label.tooltip_text = "Supply-Gebäude kosten kein Supply"
		return
	
	var supply_used := TowerData.get_supply_cost_place() + (level * TowerData.get_supply_cost_upgrade())
	supply_info_label.text = "⛺ Supply: %d" % supply_used
	supply_info_label.tooltip_text = "Dieser Tower verwendet %d Supply\n(1 Basis + %d für Upgrades)" % [supply_used, level]


func _update_element_display() -> void:
	if not current_tower:
		element_label.visible = false
		return
	
	if not current_tower.has_method("get_effective_element"):
		element_label.visible = false
		return
	
	var effective_elem: String = current_tower.get_effective_element()
	if effective_elem == "":
		element_label.visible = false
		return
	
	element_label.visible = true
	var elem_color := ElementalSystem.get_element_color(effective_elem) if ElementalSystem else Color.WHITE
	var elem_symbol := ElementalSystem.get_element_symbol(effective_elem) if ElementalSystem else ""
	
	var effectiveness_info := ""
	if ElementalSystem:
		for defender in ["water", "fire", "earth", "air"]:
			if ElementalSystem.is_effective(effective_elem, defender):
				var def_symbol := ElementalSystem.get_element_symbol(defender)
				effectiveness_info = "Effektiv gegen: %s" % def_symbol
				break
	
	element_label.text = "%s %s" % [elem_symbol, effectiveness_info]
	element_label.add_theme_color_override("font_color", elem_color)


func _update_engrave_buttons() -> void:
	for child in engrave_container.get_children():
		if child is Button:
			child.queue_free()
	
	if not current_tower:
		engrave_container.visible = false
		return
	
	if not current_tower.has_method("can_be_engraved") or not current_tower.can_be_engraved():
		engrave_container.visible = false
		return
	
	var available := TowerData.get_available_engravings()
	if available.is_empty():
		engrave_container.visible = false
		return
	
	engrave_container.visible = true
	var cost := TowerData.get_engraving_cost()
	var can_afford := TowerData.can_afford_engraving()
	
	for element in available:
		var btn := Button.new()
		var symbol := ElementalSystem.get_element_symbol(element) if ElementalSystem else element.substr(0, 1).to_upper()
		btn.text = symbol
		btn.custom_minimum_size = Vector2(32, 28)
		btn.tooltip_text = "%s gravieren (%dg)\nFügt Elementar-Effekte hinzu" % [element.capitalize(), cost]
		
		var elem_color := ElementalSystem.get_element_color(element) if ElementalSystem else Color.WHITE
		btn.add_theme_color_override("font_color", elem_color)
		
		if not can_afford or GameState.wave_active:
			btn.disabled = true
			btn.modulate.a = 0.5
		
		btn.pressed.connect(_on_engrave_button_pressed.bind(element))
		UITheme.style_button(btn)
		engrave_container.add_child(btn)


func _update_upgrade_button(tower_type: String, level: int) -> void:
	if TowerData.is_supply_building(tower_type):
		upgrade_button.visible = false
		return
	
	var can_upgrade_element := TowerData.can_upgrade(tower_type, level)
	var at_game_max := level >= TowerData.MAX_LEVEL
	
	if at_game_max:
		upgrade_button.text = "Max Level"
		upgrade_button.disabled = true
		upgrade_button.tooltip_text = "Maximales Tower-Level erreicht"
		upgrade_button.visible = true
		return
	
	if not can_upgrade_element:
		if tower_type in TowerData.UNLOCKABLE_ELEMENTS:
			var elem_level := TowerData.get_element_level(tower_type)
			var needed_level := level + 2
			upgrade_button.text = "Element Lvl %d nötig" % needed_level
			upgrade_button.tooltip_text = "Investiere mehr Kerne in %s\n(Aktuell: Level %d, Benötigt: Level %d)" % [
				TowerData.get_tower_data(tower_type).get("name", tower_type), elem_level, needed_level
			]
		else:
			upgrade_button.text = "Upgrade gesperrt"
			upgrade_button.tooltip_text = "Upgrade nicht verfügbar"
		upgrade_button.disabled = true
		upgrade_button.visible = true
		return
	
	var cost := TowerData.get_upgrade_cost(tower_type, level)
	var supply_cost := TowerData.get_supply_cost_upgrade()
	var has_supply := GameState.can_use_supply(supply_cost)
	
	upgrade_button.text = "Upgrade (%dg, ⛺%d)" % [cost, supply_cost]
	upgrade_button.visible = true
	
	if GameState.can_afford(cost) and has_supply and not GameState.wave_active:
		upgrade_button.disabled = false
		var new_damage: int = TowerData.get_stat(tower_type, "damage", level + 1)
		var new_range: float = TowerData.get_stat(tower_type, "range", level + 1)
		upgrade_button.tooltip_text = "→ Schaden: %d, Reichweite: %d\nKostet %d Gold und %d Supply" % [
			new_damage, int(new_range), cost, supply_cost
		]
	else:
		upgrade_button.disabled = true
		if not has_supply:
			upgrade_button.tooltip_text = "Nicht genug Supply! (Baue eine Farm)"
		elif GameState.wave_active:
			upgrade_button.tooltip_text = "Nicht während einer Welle"
		else:
			upgrade_button.tooltip_text = "Nicht genug Gold"


func _update_sell_button(level: int) -> void:
	var sell_value := tower_manager.get_sell_value(current_grid_pos)
	var sell_percent := tower_manager.get_sell_percent(current_grid_pos)
	
	if current_tower and current_tower.has_method("is_engraved") and current_tower.is_engraved():
		var engrave_refund := TowerData.get_engraving_cost() / 2 if sell_percent < 100 else TowerData.get_engraving_cost()
		sell_value += engrave_refund
	
	if TowerData.is_supply_building(current_tower.tower_type):
		sell_button.text = "Verkaufen: %dg (%d%%)" % [sell_value, sell_percent]
	else:
		var supply_refund := TowerData.get_supply_cost_place() + (level * TowerData.get_supply_cost_upgrade())
		sell_button.text = "Verkaufen: %dg +⛺%d (%d%%)" % [sell_value, supply_refund, sell_percent]
	
	if sell_percent == 100:
		sell_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		sell_button.remove_theme_color_override("font_color")


func _on_engrave_button_pressed(element: String) -> void:
	if current_tower and current_tower.engrave(element):
		engrave_pressed.emit(element)
		_update_display()
		
		if VFX:
			VFX.spawn_pixel_burst(current_tower.position, element, 12)


func _on_pickup_pressed() -> void:
	pickup_pressed.emit()


func _on_upgrade_pressed() -> void:
	upgrade_pressed.emit()


func _on_sell_pressed() -> void:
	sell_pressed.emit()


func _on_close_pressed() -> void:
	close_pressed.emit()
