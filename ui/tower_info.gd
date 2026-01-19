# ui/tower_info.gd
# Panel für Tower-Info, Verkauf, Upgrade, Engraving und Pickup
# Zeigt Upgrade-Boni bei Stats an
extends PanelContainer
class_name TowerInfo

signal sell_pressed
signal upgrade_pressed
signal close_pressed
signal engrave_pressed(element: String)
signal pickup_pressed

var tower_name_label: RichTextLabel
var tower_level_label: Label
var stats_label: RichTextLabel
var element_label: RichTextLabel
var supply_info_label: RichTextLabel
var blocked_info_label: RichTextLabel
var sell_button: Button
var upgrade_button: Button
var pickup_button: Button
var engrave_container: HBoxContainer
var close_button: Button
var vbox: VBoxContainer

var current_tower: Node2D = null
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var tower_manager: TowerManager = null

var equipment_container: HBoxContainer
var equipment_slots: Array[PanelContainer] = []
var equip_hint_label: Label
var _pending_equip_slot: int = -1


func _ready() -> void:
	visible = false
	_setup_panel_style()
	_setup_ui()
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	z_as_relative = false
	z_index = 200
	if ItemSystem:
		if not ItemSystem.item_equipped.is_connected(_on_item_equipment_changed):
			ItemSystem.item_equipped.connect(_on_item_equipment_changed)
		if not ItemSystem.item_unequipped.is_connected(_on_item_equipment_changed):
			ItemSystem.item_unequipped.connect(_on_item_equipment_changed)


func _bring_to_front() -> void:
	var p := get_parent()
	if p:
		p.move_child(self, p.get_child_count() - 1)


func _setup_panel_style() -> void:
	UITheme.style_panel(self, "panel_dark")


func _create_rich_label(font_size: int = 11, min_width: float = 200.0) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(min_width, 0)
	label.add_theme_font_size_override("normal_font_size", font_size)
	return label


func _setup_ui() -> void:
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)

	tower_name_label = _create_rich_label(16, 220)
	tower_name_label.name = "TowerNameLabel"
	vbox.add_child(tower_name_label)

	tower_level_label = Label.new()
	tower_level_label.name = "TowerLevelLabel"
	tower_level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tower_level_label)

	element_label = _create_rich_label(11, 200)
	element_label.name = "ElementLabel"
	element_label.visible = false
	vbox.add_child(element_label)

	stats_label = _create_rich_label(11, 200)
	stats_label.name = "StatsLabel"
	vbox.add_child(stats_label)

	supply_info_label = _create_rich_label(10, 180)
	supply_info_label.name = "SupplyInfoLabel"
	vbox.add_child(supply_info_label)

	blocked_info_label = _create_rich_label(11, 200)
	blocked_info_label.name = "BlockedInfoLabel"
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

	var equip_sep := HSeparator.new()
	vbox.add_child(equip_sep)

	var equip_header := Label.new()
	equip_header.text = "Ausrüstung:"
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_header.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))
	vbox.add_child(equip_header)

	equipment_container = HBoxContainer.new()
	equipment_container.name = "EquipmentContainer"
	equipment_container.add_theme_constant_override("separation", 8)
	vbox.add_child(equipment_container)

	for i in range(2):
		var slot := _create_equipment_slot(i)
		equipment_container.add_child(slot)
		equipment_slots.append(slot)

	equip_hint_label = Label.new()
	equip_hint_label.text = "Klicke Slot → Wähle Item aus Inventar"
	equip_hint_label.add_theme_font_size_override("font_size", 8)
	equip_hint_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	equip_hint_label.visible = false
	vbox.add_child(equip_hint_label)

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
	UITheme.style_button_colors(upgrade_button)


func _create_equipment_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.name = "EquipSlot_%d" % index
	slot.custom_minimum_size = Vector2(44, 44)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.22)
	style.border_color = Color(0.4, 0.4, 0.45)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)

	slot.set_meta("style", style)
	slot.set_meta("slot_index", index)

	var empty_label := Label.new()
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_label.name = "EmptyLabel"
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_label.add_theme_font_size_override("font_size", 20)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	slot.add_child(empty_label)

	var item_container := CenterContainer.new()
	item_container.name = "ItemContainer"
	item_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_container.visible = false
	item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(item_container)

	slot.gui_input.connect(_on_equipment_slot_input.bind(slot))
	slot.mouse_entered.connect(_on_equipment_slot_hover.bind(slot, true))
	slot.mouse_exited.connect(_on_equipment_slot_hover.bind(slot, false))

	return slot


func _update_equipment_display() -> void:
	if not current_tower or not ItemSystem:
		equipment_container.visible = false
		return

	if TowerData.is_supply_building(current_tower.tower_type):
		equipment_container.visible = false
		return

	equipment_container.visible = true

	var equipped: Array = ItemSystem.get_tower_equipped_items(current_tower)

	for i in range(equipment_slots.size()):
		var slot: PanelContainer = equipment_slots[i]
		var item: Dictionary = (equipped[i] as Dictionary) if i < equipped.size() else {}
		_update_slot_display(slot, item)

	var has_empty := false
	for it in equipped:
		if (it as Dictionary).is_empty():
			has_empty = true
			break
	equip_hint_label.visible = has_empty and ItemSystem.get_inventory().size() > 0


func _update_slot_display(slot: PanelContainer, item: Dictionary) -> void:
	var empty_label: Label = slot.get_node("EmptyLabel")
	var item_container: CenterContainer = slot.get_node("ItemContainer")
	var style: StyleBoxFlat = slot.get_meta("style")

	for child in item_container.get_children():
		child.queue_free()

	if item.is_empty():
		empty_label.visible = true
		item_container.visible = false
		style.border_color = Color(0.4, 0.4, 0.45)
		slot.tooltip_text = "Leer - Klicken um Item auszurüsten"
	else:
		empty_label.visible = false
		item_container.visible = true

		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var tex := ItemSystem.get_item_texture(item)
		if tex:
			tex_rect.texture = tex

		item_container.add_child(tex_rect)

		var rarity_color: Color = item.get("color", Color.WHITE)
		style.border_color = rarity_color

		slot.tooltip_text = "%s\n%s\nRechtsklick zum Entfernen" % [
			item.get("name", "Item"),
			item.get("description", "")
		]


func _on_item_equipment_changed(tower: Node2D, _item: Dictionary, _slot: int) -> void:
	if not visible:
		return
	if tower != current_tower:
		return
	call_deferred("_update_display")


func _on_equipment_slot_input(event: InputEvent, slot: PanelContainer) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	
	# Diese Zeilen fehlen:
	if not current_tower or not ItemSystem:
		return

	var slot_index: int = int(slot.get_meta("slot_index"))
	var equipped: Array = ItemSystem.get_tower_equipped_items(current_tower)
	var current_item: Dictionary = (equipped[slot_index] as Dictionary) if slot_index < equipped.size() else {}

	if event.button_index == MOUSE_BUTTON_RIGHT and not current_item.is_empty():
		_unequip_item(slot_index)
		get_viewport().set_input_as_handled()  
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_try_equip_from_inventory(slot_index)
		get_viewport().set_input_as_handled()  



func _on_equipment_slot_hover(slot: PanelContainer, entered: bool) -> void:
	var style: StyleBoxFlat = slot.get_meta("style")
	style.bg_color = Color(0.3, 0.3, 0.35) if entered else Color(0.2, 0.2, 0.22)


func _on_inventory_item_selected(item: Dictionary) -> void:
	if _pending_equip_slot < 0:
		return
	if not current_tower:
		_pending_equip_slot = -1
		return
	if not ItemSystem:
		_pending_equip_slot = -1
		return

	if not ItemSystem.can_equip_on_tower(item, current_tower):
		Sound.play_error()
		return

	var uid: String = item.get("uid", "")
	if uid == "":
		return

	if ItemSystem.equip_item(current_tower, uid, _pending_equip_slot):
		Sound.play_place()

		var equipped_now: Array = ItemSystem.get_tower_equipped_items(current_tower)
		_pending_equip_slot = _get_next_equip_slot(_pending_equip_slot, equipped_now)

		_update_equipment_display()
		call_deferred("_update_display")


func _get_next_equip_slot(last_slot: int, equipped: Array) -> int:
	if equipped.size() < 2:
		return 0

	var slot0: Dictionary = equipped[0] as Dictionary
	var slot1: Dictionary = equipped[1] as Dictionary

	var slot0_empty: bool = slot0.is_empty()
	var slot1_empty: bool = slot1.is_empty()

	if (not slot0_empty) and (not slot1_empty):
		return 1

	var clamped_last: int = clampi(last_slot, 0, 1)
	var other: int = 1 - clamped_last

	var other_dict: Dictionary = equipped[other] as Dictionary
	if other_dict.is_empty():
		return other

	return 0 if slot0_empty else 1


func _on_inventory_panel_closed() -> void:
	_pending_equip_slot = -1



func _try_equip_from_inventory(slot_index: int) -> void:
	if not ItemSystem:
		return

	if not current_tower:
		return

	_pending_equip_slot = slot_index

	var main := get_node_or_null("/root/Main")
	if not main:
		return

	var inventory_ui := main.get_node_or_null("ItemInventoryUI") as ItemInventoryUI

	if not inventory_ui:
		if main.has_method("_on_open_inventory"):
			main._on_open_inventory()
		return

	if not inventory_ui.item_selected.is_connected(_on_inventory_item_selected):
		inventory_ui.item_selected.connect(_on_inventory_item_selected)

	if not inventory_ui.has_selection():
		if not inventory_ui.visible:
			inventory_ui.show_panel()
		return

	_on_inventory_item_selected(inventory_ui.get_selected_item())


func _unequip_item(slot_index: int) -> void:
	if not ItemSystem:
		return

	if ItemSystem.unequip_item(current_tower, slot_index):
		Sound.play_sell()
		_update_equipment_display()
		_update_display()


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
	_pending_equip_slot = -1


func _update_display() -> void:
	if not current_tower or not tower_manager:
		return

	var tower_type: String = current_tower.tower_type
	var level: int = tower_manager.get_tower_level(current_grid_pos)
	var data := TowerData.get_tower_data(tower_type)
	var is_blocked := tower_manager.is_tower_blocked(current_grid_pos)
	var display_name: String = data.get("name", tower_type.capitalize())

	if current_tower.has_method("is_engraved") and current_tower.is_engraved():
		var elem_icon := IconSystem.bb(current_tower.engraved_element, 16) if IconSystem else ""
		tower_name_label.text = "%s %s" % [display_name, elem_icon]
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
	_update_stats_with_upgrades(tower_type, level)
	_update_supply_info(level)
	_update_blocked_info(is_blocked)
	_update_equipment_display()

	var dark_color := Color(0.094, 0.094, 0.094)
	tower_name_label.add_theme_color_override("default_color", dark_color)
	tower_level_label.add_theme_color_override("font_color", dark_color)
	stats_label.add_theme_color_override("default_color", dark_color)

	_update_pickup_button(is_blocked)
	_update_upgrade_button(tower_type, level)
	_update_sell_button(level)
	_update_engrave_buttons()


func _update_stats_with_upgrades(tower_type: String, level: int) -> void:
	if TowerData.is_supply_building(tower_type):
		var bonus: int = TowerData.get_supply_bonus(tower_type)
		var farm_upgrade_bonus: int = 0
		if UpgradeSystem:
			farm_upgrade_bonus = UpgradeSystem.get_farm_supply_bonus()
		if farm_upgrade_bonus > 0:
			stats_label.text = "Supply Bonus: +%d (+%d)" % [bonus - farm_upgrade_bonus, farm_upgrade_bonus]
			stats_label.tooltip_text = "Basis: +%d\nUpgrade-Bonus: +%d" % [bonus - farm_upgrade_bonus, farm_upgrade_bonus]
		else:
			stats_label.text = "Supply Bonus: +%d" % bonus
			stats_label.tooltip_text = ""
		return

	var base_damage: int = int(TowerData.get_stat(tower_type, "damage", level))
	var base_range: float = float(TowerData.get_stat(tower_type, "range", level))
	var base_fire_rate: float = float(TowerData.get_stat(tower_type, "fire_rate", level))

	var elem: String = ""
	if current_tower.has_method("get_effective_element"):
		elem = current_tower.get_effective_element()

	var damage_mult: float = 1.0
	var range_mult: float = 1.0
	var fire_rate_mult: float = 1.0

	if UpgradeSystem:
		damage_mult = UpgradeSystem.get_damage_multiplier(tower_type, elem)
		range_mult = UpgradeSystem.get_range_multiplier(tower_type)
		fire_rate_mult = UpgradeSystem.get_fire_rate_multiplier(tower_type)
		
		if current_tower.has_method("is_isolated") and current_tower.is_isolated():
			damage_mult *= UpgradeSystem.get_isolated_damage_multiplier()
			range_mult *= UpgradeSystem.get_isolated_range_multiplier()

	var final_damage: int = int(current_tower.damage)
	var final_range: float = float(current_tower.tower_range)
	var final_fire_rate: float = float(current_tower.fire_rate)

	var damage_bonus: int = final_damage - base_damage
	var range_bonus: int = int(final_range - base_range)
	var shots_per_sec: float = 1.0 / final_fire_rate if final_fire_rate > 0 else 0.0
	var base_shots: float = 1.0 / base_fire_rate if base_fire_rate > 0 else 0.0
	var fire_rate_bonus: float = shots_per_sec - base_shots

	var damage_text := "Schaden: %d" % final_damage
	if damage_bonus > 0:
		damage_text += " (+%d)" % damage_bonus

	var range_text := "Reichweite: %d" % int(final_range)
	if range_bonus > 0:
		range_text += " (+%d)" % range_bonus

	var fire_rate_text := "Feuerrate: %.1f/s" % shots_per_sec
	if fire_rate_bonus > 0.01:
		fire_rate_text += " (+%.1f)" % fire_rate_bonus

	stats_label.text = "%s\n%s\n%s" % [damage_text, range_text, fire_rate_text]

	var tooltip_lines: Array[String] = []
	if current_tower.has_method("is_isolated"):
		var is_isolated: bool = current_tower.is_isolated()
		if UpgradeSystem and (UpgradeSystem.get_upgrade_stacks("isolated_damage") > 0 or UpgradeSystem.get_upgrade_stacks("isolated_range") > 0):
			if is_isolated:
				tooltip_lines.append("🏔️ Isoliert: Keine Türme im Umkreis von 350")
				if UpgradeSystem.get_upgrade_stacks("isolated_damage") > 0:
					var iso_dmg := (UpgradeSystem.get_isolated_damage_multiplier() - 1.0) * 100.0
					tooltip_lines.append("  → +%.0f%% Schaden" % iso_dmg)
				if UpgradeSystem.get_upgrade_stacks("isolated_range") > 0:
					var iso_range := (UpgradeSystem.get_isolated_range_multiplier() - 1.0) * 100.0
					tooltip_lines.append("  → +%.0f%% Reichweite" % iso_range)
			else:
				tooltip_lines.append("🏘️ Nicht isoliert: Türme in der Nähe")
	if damage_bonus > 0:
		tooltip_lines.append("Schaden: %d Basis + %d Upgrade" % [base_damage, damage_bonus])
	if range_bonus > 0:
		tooltip_lines.append("Reichweite: %d Basis + %d Upgrade" % [int(base_range), range_bonus])
	if fire_rate_bonus > 0.01:
		tooltip_lines.append("Feuerrate: %.1f Basis + %.1f Upgrade" % [base_shots, fire_rate_bonus])

	if tooltip_lines.size() > 0:
		stats_label.tooltip_text = "Upgrade-Boni aktiv:\n" + "\n".join(tooltip_lines)
	else:
		stats_label.tooltip_text = ""


func _has_prop(obj: Object, prop: StringName) -> bool:
	for p in obj.get_property_list():
		if p is Dictionary and p.get("name", "") == prop:
			return true
	return false


func _update_blocked_info(is_blocked: bool) -> void:
	blocked_info_label.visible = is_blocked
	if is_blocked:
		var warning_icon := IconSystem.bb("warning", 14) if IconSystem else "⚠"
		blocked_info_label.text = "%s Steht auf dem Pfad!\nKlicke 'Aufnehmen' zum Umplatzieren" % warning_icon


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
			pickup_button.text = "Aufnehmen"
			pickup_button.tooltip_text = "Turm aufnehmen und umplatzieren (kostenlos)"
			pickup_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		else:
			pickup_button.text = "Aufnehmen"
			pickup_button.tooltip_text = "Turm aufnehmen und umplatzieren (kostenlos)"
			pickup_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094))


func _update_supply_info(level: int) -> void:
	var supply_icon := IconSystem.bb("supply", 12) if IconSystem else "⛺"
	
	if TowerData.is_supply_building(current_tower.tower_type):
		supply_info_label.text = "%s Supply: 0 (gratis!)" % supply_icon
		supply_info_label.tooltip_text = "Supply-Gebäude kosten kein Supply"
		return

	var supply_used := TowerData.get_supply_cost_place() + (level * TowerData.get_supply_cost_upgrade())
	supply_info_label.text = "%s Supply: %d" % [supply_icon, supply_used]
	supply_info_label.tooltip_text = "Dieser Tower verwendet %d Supply\n(1 Basis + %d für Upgrades)" % [supply_used, level]


func _update_element_display() -> void:
	if not current_tower or not current_tower.has_method("get_effective_element"):
		element_label.visible = false
		return

	var effective_elem: String = current_tower.get_effective_element()
	if effective_elem == "":
		element_label.visible = false
		return

	element_label.visible = true

	var elem_color: Color = ElementalSystem.get_element_color(effective_elem) if ElementalSystem else Color.WHITE
	var elem_icon: String = IconSystem.bb(effective_elem, 14) if IconSystem else ""
	var effectiveness_info: String = ""

	if ElementalSystem:
		for defender in ["water", "fire", "earth", "air"]:
			if ElementalSystem.is_effective(effective_elem, defender):
				var def_icon: String = IconSystem.bb(defender, 14) if IconSystem else defender
				effectiveness_info = "Effektiv gegen: %s" % def_icon
				break

	element_label.text = "%s %s" % [elem_icon, effectiveness_info]


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
		btn.text = ""
		btn.icon = IconSystem.get_texture(element) if IconSystem else null
		btn.custom_minimum_size = Vector2(32, 28)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.tooltip_text = "%s gravieren (%dg)\nFügt Elementar-Effekte hinzu" % [element.capitalize(), cost]

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

	upgrade_button.text = "Upgrade (%dg, %d)" % [cost, supply_cost]
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

	var supply_icon := IconSystem.bb("supply", 12) if IconSystem else "⛺"

	if TowerData.is_supply_building(current_tower.tower_type):
		sell_button.text = "Verkaufen: %dg (%d%%)" % [sell_value, sell_percent]
	else:
		var supply_refund := TowerData.get_supply_cost_place() + (level * TowerData.get_supply_cost_upgrade())
		sell_button.text = "Verkaufen: %dg +%d (%d%%)" % [sell_value, supply_refund, sell_percent]

	if sell_percent == 100:
		sell_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		sell_button.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))


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
