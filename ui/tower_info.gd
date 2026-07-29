# ui/tower_info.gd
# Panel für Tower-Info, Verkauf, Upgrade, Engraving und Pickup
# Zeigt Upgrade-Boni bei Stats an
extends PanelContainer
class_name TowerInfo

const RangeGridHelper = preload("res://autoload/range_grid.gd")

signal sell_pressed
signal upgrade_pressed
signal close_pressed
signal engrave_pressed(element: String)
signal aura_buff_selected(buff_type: String)
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
var absorb_button: Button
var engrave_container: HBoxContainer
var engrave_header_label: Label
var close_button: Button
var vbox: VBoxContainer

var current_tower: Node2D = null
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var tower_manager: TowerManager = null

var equipment_container: HBoxContainer
var equipment_slots: Array[PanelContainer] = []
var equip_hint_label: Label
var _pending_equip_slot: int = -1

const COLOR_TEXT := Color("edf3ff")
const COLOR_MUTED := Color("9aa8c2")
const COLOR_ACCENT := Color("f4cf6a")
const COLOR_DARK_BUTTON_TEXT := Color("181512")

# Datengetriebene Liste fuer die Upgrade-Vorschau ("jetzt -> nachher").
# Jeder Turmtyp bekommt automatisch nur die Zeilen, deren Schluessel in seinen
# data/tower_data.gd-Eintraegen existieren - kein Sonderfall-Block pro Typ noetig
# (siehe _build_upgrade_preview_lines). "format" steuert die Darstellung:
# "int" = Ganzzahl, "range_cells" = ueber RangeGridHelper in Rasterfelder
# umgerechnet (fuer Reichweite UND Splash-Radius, beides Pixel-Radien),
# "fire_rate" = 1/Wert als Angriffe/Sekunde (kleinerer Wert = schneller),
# "seconds" = Sekunden mit einer Nachkommastelle, "percent" = Bruchteil * 100.
const UPGRADE_PREVIEW_STATS := [
	{"key": "damage", "label": "Schaden", "format": "int"},
	{"key": "range", "label": "Reichweite", "format": "range_cells"},
	{"key": "fire_rate", "label": "Angriffe/s", "format": "fire_rate"},
	{"key": "splash", "label": "Splash-Radius", "format": "range_cells"},
	{"key": "max_traps", "label": "Max. Fallen", "format": "int"},
	{"key": "trap_duration", "label": "Fallen-Dauer", "format": "seconds"},
	{"key": "burn_damage", "label": "Brand-Schaden", "format": "int"},
	{"key": "chain_targets", "label": "Kettenziele", "format": "int"},
	{"key": "buff_strength", "label": "Bonus", "format": "percent"},
]


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
	label.add_theme_color_override("default_color", COLOR_TEXT)
	if UITheme and UITheme.game_font:
		label.add_theme_font_override("normal_font", UITheme.game_font)
	return label


func _setup_ui() -> void:
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)

	tower_name_label = _create_rich_label(16, 220)
	tower_name_label.name = "TowerNameLabel"
	tower_name_label.add_theme_color_override("default_color", COLOR_ACCENT)
	vbox.add_child(tower_name_label)

	tower_level_label = Label.new()
	tower_level_label.name = "TowerLevelLabel"
	tower_level_label.add_theme_font_size_override("font_size", 12)
	tower_level_label.add_theme_color_override("font_color", COLOR_MUTED)
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

	engrave_header_label = Label.new()
	engrave_header_label.name = "EngraveHeaderLabel"
	engrave_header_label.text = "Gravieren:"
	engrave_header_label.add_theme_font_size_override("font_size", 10)
	engrave_header_label.add_theme_color_override("font_color", COLOR_MUTED)
	engrave_container.add_child(engrave_header_label)

	var equip_sep := HSeparator.new()
	vbox.add_child(equip_sep)

	var equip_header := Label.new()
	equip_header.text = "Ausrüstung:"
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_header.add_theme_color_override("font_color", COLOR_MUTED)
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
	equip_hint_label.add_theme_color_override("font_color", COLOR_MUTED.darkened(0.1))
	equip_hint_label.visible = false
	vbox.add_child(equip_hint_label)

	absorb_button = Button.new()
	absorb_button.name = "AbsorbButton"
	absorb_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)
	absorb_button.pressed.connect(_on_absorb_pressed)
	absorb_button.visible = false
	vbox.add_child(absorb_button)

	pickup_button = Button.new()
	pickup_button.name = "PickupButton"
	pickup_button.text = "Aufnehmen"
	pickup_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)
	pickup_button.pressed.connect(_on_pickup_pressed)
	vbox.add_child(pickup_button)

	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(upgrade_button)

	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)
	sell_button.pressed.connect(_on_sell_pressed)
	vbox.add_child(sell_button)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Schließen"
	close_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

	UITheme.style_button(absorb_button)
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

		# Auswahl im Inventar aufheben, sonst blockiert das tote Item die Hover-Details
		var inventory_ui := _get_inventory_ui()
		if inventory_ui:
			inventory_ui.deselect_item()

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



func _get_inventory_ui() -> ItemInventoryUI:
	var main := get_node_or_null("/root/Main")
	if not main:
		return null
	return main.get_node_or_null("ItemInventoryUI") as ItemInventoryUI


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

	if inventory_ui.has_selection():
		inventory_ui.set_filter_tower(current_tower)
		_on_inventory_item_selected(inventory_ui.get_selected_item())
		return

	# Equip-Kontext setzen, damit passende Items im Inventar hervorgehoben werden
	if not inventory_ui.visible:
		inventory_ui.show_panel(current_tower)
	else:
		inventory_ui.set_filter_tower(current_tower)


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

	# Inventar über den Equip-Kontext informieren (Hervorhebung passender Items)
	var inventory_ui := _get_inventory_ui()
	if inventory_ui:
		inventory_ui.set_filter_tower(tower)

	_update_display()
	visible = true

	_refit_and_position()

	# Kurze Fade+Scale-Animation statt des Standard-Panel-Tweens (UITheme.animate_panel_open):
	# das Panel öffnet sehr häufig beim Anklicken von Türmen, die Standard-Dauer wirkt hier träge.
	# _refit_and_position() muss zwingend vorher laufen, sonst wird gegen die falsche
	# Panelgröße animiert und das Panel springt beim Öffnen.
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	call_deferred("_bring_to_front")


# Groesse an den aktuellen Inhalt anpassen und neben dem Turm platzieren.
# Muss nach jeder Inhaltsaenderung laufen, die die Hoehe/Breite veraendert -
# sonst behaelt das Panel die Masse vom Oeffnen.
func _refit_and_position() -> void:
	if current_grid_pos.x < 0:
		return

	size = get_combined_minimum_size()

	var screen_size := get_viewport_rect().size
	var margin := 10.0
	var top_safe_margin := 72.0
	var tile := 64.0

	var tower_y := float(current_grid_pos.y) * tile + tile * 0.5
	var open_up := tower_y > screen_size.y * 0.5

	position.x = float(current_grid_pos.x) * tile + tile + margin
	position.y = (tower_y - size.y - margin) if open_up else (tower_y + margin)

	if position.x + size.x > screen_size.x - margin:
		position.x = float(current_grid_pos.x) * tile - size.x - margin

	position.x = clamp(position.x, margin, screen_size.x - size.x - margin)
	position.y = clamp(position.y, top_safe_margin, screen_size.y - size.y - margin)


func hide_panel() -> void:
	visible = false
	current_tower = null
	current_grid_pos = Vector2i(-1, -1)
	_pending_equip_slot = -1

	# Equip-Kontext im Inventar wieder aufheben
	var inventory_ui := _get_inventory_ui()
	if inventory_ui:
		inventory_ui.set_filter_tower(null)


func _update_display() -> void:
	if not current_tower or not tower_manager:
		return

	var tower_type: String = current_tower.tower_type
	var level: int = tower_manager.get_tower_level(current_grid_pos)
	var data := TowerData.get_tower_data(tower_type)
	var is_blocked := tower_manager.is_tower_blocked(current_grid_pos)
	var display_name: String = data.get("name", tower_type.capitalize())

	if tower_type == "aura" and String(current_tower.aura_buff_type) != "":
		# Aura-Tuerme gravieren einen Buff statt eines Elements - er gehoert genauso
		# sichtbar in den Titel wie das Elementsymbol bei den uebrigen Tuermen.
		var buff_type: String = current_tower.aura_buff_type
		tower_name_label.text = "%s %s %s" % [
			display_name, _get_aura_buff_icon_bb(buff_type), _get_aura_buff_name(buff_type)
		]
	elif current_tower.has_method("is_engraved") and current_tower.is_engraved():
		var elem_icon := IconSystem.bb(current_tower.engraved_element, 16) if IconSystem else ""
		tower_name_label.text = "%s %s" % [display_name, elem_icon]
	else:
		tower_name_label.text = display_name

	if TowerData.is_supply_building(tower_type):
		tower_level_label.text = "Supply-Gebäude"
	elif tower_type in TowerData.UNLOCKABLE_ELEMENTS:
		var elem_level: int = TowerData.get_element_level(tower_type)
		var max_allowed: int = TowerData.get_max_tower_level_for_element(tower_type)
		tower_level_label.text = "Level %d / %d (Element: %d/3)" % [level + 1, max_allowed + 1, elem_level]
	else:
		tower_level_label.text = "Level %d / %d" % [level + 1, TowerData.MAX_LEVEL + 1]

	_update_element_display()
	_update_stats_with_upgrades(tower_type, level)
	_update_supply_info(level)
	_update_blocked_info(is_blocked)
	_update_equipment_display()

	tower_name_label.add_theme_color_override("default_color", COLOR_ACCENT)
	tower_level_label.add_theme_color_override("font_color", COLOR_MUTED)
	stats_label.add_theme_color_override("default_color", COLOR_TEXT)

	_update_absorb_button(tower_type)
	_update_pickup_button(is_blocked)
	_update_upgrade_button(tower_type, level)
	_update_sell_button(level)
	_update_engrave_buttons()


func _update_stats_with_upgrades(tower_type: String, level: int) -> void:
	if tower_type == "city":
		var stored: int = int(current_tower.stored_farms)
		stats_label.text = "Gespeicherte Farmen: %d/%d\nSupply Bonus: +%d" % [
			stored, TowerData.CITY_CAPACITY, int(current_tower.get_supply_bonus())
		]
		stats_label.tooltip_text = "Jede aufgenommene Farm liefert weiterhin ihr Supply,\nbelegt aber kein Feld mehr."
		return

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

	if tower_type == "aura":
		_update_aura_stats()
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

	var final_damage: int = int(current_tower.damage)
	var final_range: float = float(current_tower.tower_range)
	var final_fire_rate: float = float(current_tower.fire_rate)

	var damage_bonus: int = final_damage - base_damage
	var base_range_cells := RangeGridHelper.get_cell_radius(base_range)
	var final_range_cells := RangeGridHelper.get_cell_radius(final_range)
	var range_cell_bonus := final_range_cells - base_range_cells
	var shots_per_sec: float = 1.0 / final_fire_rate if final_fire_rate > 0 else 0.0
	var base_shots: float = 1.0 / base_fire_rate if base_fire_rate > 0 else 0.0
	var fire_rate_bonus: float = shots_per_sec - base_shots

	# NEU: Crit-Chance berechnen
	var crit_chance: float = 0.0
	var crit_base: float = 0.0
	var crit_from_upgrades: float = 0.0
	var crit_from_items: float = 0.0
	
	# Base Crit (z.B. Archer haben 15%)
	if "base_crit_chance" in current_tower:
		crit_base = current_tower.base_crit_chance
		crit_chance += crit_base
	
	if UpgradeSystem:
		crit_from_upgrades = UpgradeSystem.get_crit_chance()
		crit_chance += crit_from_upgrades
	
	if ItemSystem:
		crit_from_items = ItemSystem.get_tower_item_bonus_percent(current_tower, "crit_chance")
		crit_chance += crit_from_items
	
	# NEU: Crit-Multiplikator holen
	var crit_mult: float = 1.5  # Default
	if UpgradeSystem and UpgradeSystem.has_method("get_crit_multiplier"):
		crit_mult = UpgradeSystem.get_crit_multiplier()

	# Stats-Text zusammenbauen
	var damage_icon := IconSystem.bb("damage", 14) if IconSystem else ""
	var range_icon := IconSystem.bb("range", 14) if IconSystem else ""
	var speed_icon := IconSystem.bb("fire_rate", 14) if IconSystem else ""
	var damage_text := "%s Schaden: [b]%d[/b]" % [damage_icon, final_damage]
	if damage_bonus > 0:
		damage_text += " [color=#75ddff](+%d)[/color]" % damage_bonus

	var range_text := "%s Reichweite: [b]%d Felder[/b]" % [range_icon, final_range_cells]
	if range_cell_bonus > 0:
		range_text += " [color=#75ddff](+%d)[/color]" % range_cell_bonus

	var fire_rate_text := "%s Angriffe/s: [b]%.1f[/b]" % [speed_icon, shots_per_sec]
	if fire_rate_bonus > 0.01:
		fire_rate_text += " [color=#75ddff](+%.1f)[/color]" % fire_rate_bonus

	# NEU: Crit-Text nur wenn Crit-Chance > 0
	var stats_lines: Array[String] = [damage_text, range_text, fire_rate_text]
	
	if crit_chance > 0.0:
		var crit_percent := int(crit_chance * 100)
		var crit_damage_percent := int((crit_mult - 1.0) * 100)
		var crit_icon := IconSystem.bb("star_full", 14) if IconSystem else ""
		var crit_text := "%s Crit: [b]%d%%[/b] (x%.1f)" % [crit_icon, crit_percent, crit_mult]
		stats_lines.append(crit_text)

	# Element-gebundener Item-Bonus (z. B. Feuerrubin auf einem feuer-gravierten Turm).
	# Der Wert steckt bereits in `final_damage` - die Zeile macht nur die Quelle sichtbar.
	var elem_damage_bonus: float = float(current_tower.item_element_damage_bonus)
	if elem_damage_bonus > 0.0 and elem != "":
		var elem_icon := ElementalSystem.get_element_bb(elem, 14) if ElementalSystem else ""
		var elem_color := ElementalSystem.get_element_color(elem) if ElementalSystem else Color.WHITE
		stats_lines.append("%s Elementarschaden: [color=#%s][b]+%d%%[/b][/color]" % [
			elem_icon, elem_color.to_html(false), int(round(elem_damage_bonus * 100.0))
		])

	stats_label.text = "\n".join(stats_lines)

	# Tooltip erweitern
	var tooltip_lines: Array[String] = [
		"Schaden: %d" % final_damage,
		"Reichweite: %d quadratische Rasterfelder" % final_range_cells,
		"Angriffe pro Sekunde: %.1f" % shots_per_sec
	]
	
	if damage_bonus > 0:
		tooltip_lines.append("Schaden: %d Basis + %d Upgrade" % [base_damage, damage_bonus])
	
	if range_cell_bonus > 0:
		tooltip_lines.append("Reichweite: %d Basisfelder + %d Bonusfeld(er)" % [base_range_cells, range_cell_bonus])
	
	if fire_rate_bonus > 0.01:
		tooltip_lines.append("Feuerrate: %.1f Basis + %.1f Upgrade" % [base_shots, fire_rate_bonus])
	
	# NEU: Crit-Details im Tooltip
	if crit_chance > 0.0:
		var crit_percent := int(crit_chance * 100)
		var crit_details: Array[String] = []
		
		if crit_base > 0.0:
			crit_details.append("Basis: %d%%" % int(crit_base * 100))
		
		if crit_from_upgrades > 0.0:
			crit_details.append("Upgrades: %d%%" % int(crit_from_upgrades * 100))
		
		if crit_from_items > 0.0:
			crit_details.append("Items: %d%%" % int(crit_from_items * 100))
		
		var crit_tooltip := "Crit-Chance: %d%%" % crit_percent
		if crit_details.size() > 0:
			crit_tooltip += " (%s)" % ", ".join(crit_details)
		
		var crit_damage_percent := int((crit_mult - 1.0) * 100)
		crit_tooltip += "\nCrit-Schaden: +%d%% (x%.1f)" % [crit_damage_percent, crit_mult]
		
		tooltip_lines.append(crit_tooltip)

	if elem_damage_bonus > 0.0 and elem != "":
		tooltip_lines.append("Elementarschaden: +%d%% aus Items - wirkt nur, weil der Turm das passende Element traegt" % int(round(elem_damage_bonus * 100.0)))

	stats_label.tooltip_text = "Aktuelle Tower-Stats:\n" + "\n".join(tooltip_lines)


# Aura-Tuerme haben weder Schaden noch Feuerrate - fuer sie zaehlt nur, welcher
# Buff graviert ist, wie stark er wirkt und wie weit er reicht.
func _update_aura_stats() -> void:
	var buff_type: String = current_tower.aura_buff_type
	var range_cells := RangeGridHelper.get_cell_radius(current_tower.aura_range)
	var range_icon := IconSystem.bb("range", 14) if IconSystem else ""
	var lines: Array[String] = []

	if buff_type == "":
		lines.append("[color=#c98d6b]Noch kein Buff graviert[/color]")
	else:
		var percent := int(current_tower.buff_strength * 100)
		lines.append("%s Aura: [b]%s +%d%%[/b]" % [
			_get_aura_buff_icon_bb(buff_type, 14), _get_aura_buff_name(buff_type), percent
		])

	lines.append("%s Reichweite: [b]%d Felder[/b]" % [range_icon, range_cells])
	stats_label.text = "\n".join(lines)

	if buff_type == "":
		stats_label.tooltip_text = "Waehle einen Buff - die Gravur ist dauerhaft.\nWirkt auf alle Tuerme im Raster."
	else:
		stats_label.tooltip_text = "Verstaerkt %s aller Tuerme im Umkreis von %d Feldern um %d%%." % [
			_get_aura_buff_name(buff_type), range_cells, int(current_tower.buff_strength * 100)
		]


func _update_blocked_info(is_blocked: bool) -> void:
	blocked_info_label.visible = is_blocked
	if is_blocked:
		var warning_icon := IconSystem.bb("warning", 14) if IconSystem else "⚠"
		blocked_info_label.text = "%s Steht auf dem Pfad!\nKlicke 'Aufnehmen' zum Umplatzieren" % warning_icon


func _update_absorb_button(tower_type: String) -> void:
	if not absorb_button:
		return

	if tower_type != "city":
		absorb_button.visible = false
		return

	absorb_button.visible = true

	var free_slots: int = int(current_tower.get_free_farm_slots())
	var free_farms: int = tower_manager.count_free_farms()
	var absorbable: int = mini(free_slots, free_farms)

	absorb_button.text = "Farmen aufnehmen (%d)" % absorbable

	if GameState.wave_active:
		absorb_button.disabled = true
		absorb_button.tooltip_text = "Nicht während einer Welle"
	elif free_slots <= 0:
		absorb_button.disabled = true
		absorb_button.tooltip_text = "Stadt ist voll (%d/%d)" % [
			int(current_tower.stored_farms), TowerData.CITY_CAPACITY
		]
	elif free_farms <= 0:
		absorb_button.disabled = true
		absorb_button.tooltip_text = "Keine Farm auf dem Spielfeld"
	else:
		absorb_button.disabled = false
		absorb_button.tooltip_text = "Nimmt %d Farm(en) auf.\nDas Supply bleibt erhalten, die Felder werden frei." % absorbable


func _on_absorb_pressed() -> void:
	if not current_tower or not tower_manager:
		return
	if tower_manager.absorb_farms(current_grid_pos) <= 0:
		Sound.play_error()
		return
	_update_display()
	call_deferred("_refit_and_position")


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
			pickup_button.add_theme_color_override("font_color", Color("8f241d"))
		else:
			pickup_button.text = "Aufnehmen"
			pickup_button.tooltip_text = "Turm aufnehmen und umplatzieren (kostenlos)"
			pickup_button.add_theme_color_override("font_color", COLOR_DARK_BUTTON_TEXT)


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
	_clear_engrave_container()

	if not current_tower:
		engrave_container.visible = false
		return

	# ✅ NEU: Spezielle Behandlung für Aura-Türme
	if current_tower.tower_type == "aura":
		_update_aura_buff_buttons()
		return

	engrave_header_label.text = "Gravieren:"

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
		btn.custom_minimum_size = Vector2(40, 36)
		if UITheme:
			UITheme.center_button_icon(btn)
		btn.tooltip_text = "%s gravieren (%dg)\nFügt Elementar-Effekte hinzu" % [element.capitalize(), cost]

		if not can_afford or GameState.wave_active:
			btn.disabled = true
			btn.modulate.a = 0.5

		btn.pressed.connect(_on_engrave_button_pressed.bind(element))
		UITheme.style_icon_button(btn)
		engrave_container.add_child(btn)


# Entfernt alles ausser dem Header, damit sich Auswahlbuttons und Statuszeile
# nicht ueberlagern. Der Header bleibt erhalten - er wird nur umbenannt.
func _clear_engrave_container() -> void:
	for child in engrave_container.get_children():
		if child == engrave_header_label:
			continue
		engrave_container.remove_child(child)
		child.queue_free()


func _update_aura_buff_buttons() -> void:
	"""Zeigt Buff-Auswahl für Aura-Türme"""
	if not current_tower.has_method("can_select_aura_buff"):
		engrave_container.visible = false
		return

	# Die Gravur ist gesetzt und dauerhaft - der Auswahlbereich verschwindet dann,
	# genau wie bei elementar gravierten Tuermen. Was graviert wurde, steht im Titel
	# und in der Statszeile.
	if not current_tower.can_select_aura_buff():
		engrave_container.visible = false
		return

	# Buff noch nicht gewählt - zeige Auswahlbuttons
	engrave_container.visible = true
	engrave_header_label.text = "Buff wählen:"

	# ✅ Aktuellen buff_strength Wert holen
	var buff_percent := int(current_tower.buff_strength * 100)
	
	var buff_options := [
		{"type": "damage", "desc": "Erhöht Schaden naher Türme um %d%%" % buff_percent},
		{"type": "range", "desc": "Erhöht Reichweite naher Türme um %d%%" % buff_percent},
		{"type": "fire_rate", "desc": "Erhöht Feuerrate naher Türme um %d%%" % buff_percent}
	]

	for option in buff_options:
		var btn := Button.new()
		btn.text = ""

		# ✅ Icon über IconSystem laden
		if IconSystem:
			btn.icon = IconSystem.get_texture(_get_aura_buff_icon_name(option["type"]))

		# Fallback wenn kein Icon
		if not btn.icon:
			btn.text = _get_aura_buff_fallback_icon(option["type"])
		
		btn.custom_minimum_size = Vector2(48, 40)
		if UITheme:
			UITheme.center_button_icon(btn)

		# ✅ Detaillierter Tooltip mit Prozent-Wert
		btn.tooltip_text = "%s\n%s\n(Reichweite: %d Felder)" % [
			_get_aura_buff_name(option["type"]),
			option["desc"],
			RangeGridHelper.get_cell_radius(current_tower.aura_range)
		]
		
		if GameState.wave_active:
			btn.disabled = true
			btn.modulate.a = 0.5
			btn.tooltip_text += "\n\nNicht während einer Welle"
		
		btn.pressed.connect(_on_aura_buff_button_pressed.bind(option["type"]))
		UITheme.style_icon_button(btn)
		
		# ✅ Farbe für Button basierend auf Typ
		var bg_color := _get_aura_buff_button_color(option["type"])
		btn.modulate = bg_color.lerp(Color.WHITE, 0.7)
		
		engrave_container.add_child(btn)


func _get_aura_buff_icon_name(buff_type: String) -> String:
	"""IconSystem-Schluessel je Buff-Typ"""
	match buff_type:
		"damage": return "damage"
		"range": return "range"
		"fire_rate": return "fire_rate"
		_: return "star_full"


func _get_aura_buff_icon_bb(buff_type: String, size: int = 16) -> String:
	"""Gibt BBCode-Icon zurück wenn IconSystem verfügbar"""
	if not IconSystem:
		return _get_aura_buff_fallback_icon(buff_type)
	return IconSystem.bb(_get_aura_buff_icon_name(buff_type), size)


func _get_aura_buff_fallback_icon(buff_type: String) -> String:
	"""Fallback Text-Icons wenn IconSystem nicht verfügbar"""
	match buff_type:
		"damage": return "⚔"
		"range": return "🎯"
		"fire_rate": return "⚡"
		_: return "?"


func _get_aura_buff_button_color(buff_type: String) -> Color:
	"""Gibt Farbe für Buff-Button zurück"""
	match buff_type:
		"damage": return Color(1.0, 0.3, 0.3)  # Rot
		"range": return Color(0.3, 0.5, 1.0)   # Blau
		"fire_rate": return Color(0.3, 1.0, 0.4)  # Grün
		_: return Color(1.0, 0.9, 0.4)  # Gold


func _get_aura_buff_name(buff_type: String) -> String:
	match buff_type:
		"damage": return "Schaden"
		"range": return "Reichweite"
		"fire_rate": return "Tempo"
		_: return "Unbekannt"


func _on_aura_buff_button_pressed(buff_type: String) -> void:
	if current_tower and current_tower.select_aura_buff(buff_type):
		aura_buff_selected.emit(buff_type)
		_update_display()
		# Aus drei Buttons wird eine Statuszeile - das Panel muss schrumpfen duerfen.
		call_deferred("_refit_and_position")
		if VFX:
			VFX.spawn_pixel_burst(current_tower.position, "air", 12)


func _format_upgrade_stat_value(format: String, value: Variant) -> String:
	"""Formatiert einen Roh-Statwert aus tower_data.gd typgerecht fuer die Vorschau."""
	match format:
		"range_cells":
			# Reichweite und Splash sind beides Pixel-Radien - dieselbe Umrechnung
			# wie in der Stat-Anzeige (RangeGridHelper), damit nichts auseinanderlaeuft.
			return "%d Felder" % RangeGridHelper.get_cell_radius(float(value))
		"fire_rate":
			# fire_rate ist eine Abklingzeit (kleiner = schneller) - wie in der
			# Stat-Anzeige oben in Angriffe/Sekunde umrechnen (1 / Wert).
			var shots_per_sec := 1.0 / float(value) if float(value) > 0.0 else 0.0
			return "%.1f" % shots_per_sec
		"seconds":
			return "%.1f s" % float(value)
		"percent":
			return "%d%%" % int(round(float(value) * 100.0))
		_:
			return str(int(round(float(value))))


# Baut die "jetzt -> nachher"-Zeilen der Upgrade-Vorschau aus UPGRADE_PREVIEW_STATS.
# Datengetrieben statt hart verdrahteter Stats: jeder Schluessel, der im
# tower_data.gd-Eintrag existiert, wird geprueft - Schluessel, die auf allen
# Stufen 0 sind (z.B. Schaden/Feuerrate beim Aura-Turm), fallen automatisch weg,
# genau wie Stats, die sich durchs Upgrade nicht aendern.
func _build_upgrade_preview_lines(tower_type: String, level: int) -> Array[String]:
	var data := TowerData.get_tower_data(tower_type)
	var lines: Array[String] = []

	for entry in UPGRADE_PREVIEW_STATS:
		var key: String = entry["key"]
		if not data.has(key):
			continue

		var raw_values = data[key]
		if raw_values is Array:
			var all_zero := true
			for v in raw_values:
				if float(v) != 0.0:
					all_zero = false
					break
			if all_zero:
				continue

		var current_value = TowerData.get_stat(tower_type, key, level)
		var next_value = TowerData.get_stat(tower_type, key, level + 1)
		if current_value == null or next_value == null:
			continue

		var format: String = entry["format"]
		var label: String = entry["label"]

		# Aura-Bonus: der Buff-Typ (Schaden/Reichweite/Tempo) steckt am Turm, nicht
		# in tower_data.gd - Label dynamisch daraus ableiten statt Sonderfall pro Typ.
		if key == "buff_strength":
			var buff_type: String = ""
			if is_instance_valid(current_tower):
				buff_type = current_tower.aura_buff_type
			label = ("%s-Bonus" % _get_aura_buff_name(buff_type)) if buff_type != "" else "Aura-Bonus"

		var current_text := _format_upgrade_stat_value(format, current_value)
		var next_text := _format_upgrade_stat_value(format, next_value)
		if current_text == next_text:
			continue

		lines.append("%s: %s → %s" % [label, current_text, next_text])

	return lines


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
		var preview_lines := _build_upgrade_preview_lines(tower_type, level)
		var tooltip_parts: Array[String] = []
		for preview_line in preview_lines:
			tooltip_parts.append("→ %s" % preview_line)
		tooltip_parts.append("Kostet %d Gold und %d Supply" % [cost, supply_cost])
		upgrade_button.tooltip_text = "\n".join(tooltip_parts)
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
		sell_button.add_theme_color_override("font_color", Color("12652d"))
	else:
		sell_button.add_theme_color_override("font_color", Color("555555"))


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
