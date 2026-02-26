# ui/hud.gd
# Zeigt Gold, Leben, Welle, Element-Kerne, Seed, Start-Button und Fast-Forward
extends Control
class_name HUD

signal start_wave_pressed
signal open_element_panel_pressed
signal open_upgrades_panel_pressed
signal open_inventory_pressed

@export var gold_label: RichTextLabel
@export var lives_label: RichTextLabel
@export var wave_label: Label
@export var enemies_label: Label
@export var cores_label: RichTextLabel
@export var cores_button: Button
@export var upgrades_button: Button
@export var start_button: Button
var wave_preview_label: RichTextLabel
@export var wave_element_icon: TextureRect
@export var wave_element_label: Label
@export var seed_label: Label
@export var fast_forward_button: Button
@export var bonus_preview_label: Label
@export var supply_label: RichTextLabel
@export var blocked_warning_label: Label
@export var wave_events_label: RichTextLabel
@export var inventory_button: Button

const ENEMY_TYPE_INFO := {
	"tank":     {"weak": "archer",  "resist": "sword",   "name": "Tank"},
	"swift":    {"weak": "sword",   "resist": "archer",  "name": "Flinker"},
	"ethereal": {"weak": "wizard",  "resist": "cannon",  "name": "Ätherisch"},
	"brute":    {"weak": "cannon",  "resist": "wizard",  "name": "Brute"},
	"burrower": {"weak": "trapper", "resist": "archer",  "name": "Gräber"},
}

const TOWER_NAMES := {
	"archer":  "Bogenschütze",
	"sword":   "Schwert",
	"wizard":  "Zauberer",
	"cannon":  "Kanone",
	"trapper": "Falle",
}

var inventory_notification: Label
var core_notification: Label

var current_wave_element_area: Control
var current_wave_element_icon: TextureRect
var current_wave_element_label: Label
var current_wave_info_label: Label

var is_fast_forward := false
const FAST_FORWARD_SPEED := 2.5

var ff_idle_tex: Texture2D
var ff_pressed_tex: Texture2D

var element_textures: Dictionary = {}

var wave_element_area: Control
var wave_tooltip: PanelContainer
var wave_tooltip_title: Label
var wave_tooltip_weak_icon: TextureRect
var wave_tooltip_weak_label: Label
var wave_tooltip_resist_icon: TextureRect
var wave_tooltip_resist_label: Label
var _tooltip_visible := false

var _next_wave_element: String = "neutral"
var _current_wave_element: String = "neutral"
var _next_wave_preview: Dictionary = {}   # gecachte Preview für Tooltip
var _blocked_tower_count: int = 0


func _ready() -> void:
	_load_fast_forward_textures()
	_load_element_textures()
	_setup_hud_size()
	_find_or_create_ui_elements()
	_apply_styles()
	_connect_signals()
	_create_wave_tooltip()
	_connect_tooltip_hover_area()
	update_all()


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


func _load_element_textures() -> void:
	var elements := ["water", "fire", "earth", "air"]
	for elem in elements:
		var path := "res://assets/elemental_symbols/%s_element.png" % elem
		if ResourceLoader.exists(path):
			element_textures[elem] = load(path)


func _load_fast_forward_textures() -> void:
	var base_path := "res://assets/ui/"
	if ResourceLoader.exists(base_path + "fast_forward_idle.png"):
		ff_idle_tex = load(base_path + "fast_forward_idle.png")
	if ResourceLoader.exists(base_path + "fast_forward_pressed.png"):
		ff_pressed_tex = load(base_path + "fast_forward_pressed.png")


func _setup_hud_size() -> void:
	var hud_height := 105
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = -hud_height
	offset_bottom = 0

	if not has_node("HUDBackground"):
		var bg := Panel.new()
		bg.name = "HUDBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.22, 0.95)
		bg.add_theme_stylebox_override("panel", style)
		add_child(bg)
		move_child(bg, 0)


func _find_or_create_ui_elements() -> void:
	var hud_height := 105
	var bottom_y := hud_height - 22
	var second_row_y := hud_height - 44
	var third_row_y := hud_height - 66
	var first_row_y := hud_height - 88
	var zero_row_y := hud_height - 110
	var viewport_size := get_viewport_rect().size

	gold_label    = _get_or_create_rich_label("GoldLabel",   Vector2(20, third_row_y))
	lives_label   = _get_or_create_rich_label("LivesLabel",  Vector2(20, second_row_y))
	wave_label    = _get_or_create_label("WaveLabel",        Vector2(150, third_row_y))
	enemies_label = _get_or_create_label("EnemiesLabel",     Vector2(150, second_row_y))
	cores_label   = _get_or_create_rich_label("CoresLabel",  Vector2(20, bottom_y), 200)
	seed_label    = _get_or_create_label("SeedLabel",        Vector2(10, -hud_height - 25))

	bonus_preview_label = _get_or_create_label("BonusPreviewLabel", Vector2(20, first_row_y))
	supply_label = _get_or_create_rich_label("SupplyLabel", Vector2(20, zero_row_y))
	supply_label.custom_minimum_size = Vector2(300, 20)

	blocked_warning_label = _get_or_create_label("BlockedWarningLabel", Vector2(viewport_size.x - 780, hud_height - 110))
	wave_events_label     = _get_or_create_rich_label("WaveEventsLabel", Vector2(viewport_size.x - 360, hud_height - 110), 350)
	current_wave_info_label = _get_or_create_label("CurrentWaveInfoLabel", Vector2(viewport_size.x - 530, hud_height - 105))

	var current_area_pos  := Vector2(viewport_size.x - 570, hud_height - 90)
	var current_area_size := Vector2(190, 34)
	current_wave_element_area  = _get_or_create_control("CurrentWaveElementArea", current_area_pos, current_area_size)
	current_wave_element_icon  = _get_or_create_texture_rect_child(current_wave_element_area, "CurrentWaveElementIcon",  Vector2(8, 5),  Vector2(24, 24))
	current_wave_element_label = _get_or_create_label_child(current_wave_element_area,         "CurrentWaveElementLabel", Vector2(40, 8))

	# Wave-Preview-Label bekommt eigene hover-Area damit Tooltip auch dort triggert
	wave_preview_label = _get_or_create_rich_label("WavePreviewLabel", Vector2(viewport_size.x - 360, hud_height - 68), 355)
	wave_preview_label.fit_content = true

	var area_pos  := Vector2(viewport_size.x - 400, hud_height - 35)
	var area_size := Vector2(190, 34)
	wave_element_area = _get_or_create_control("WaveElementArea", area_pos, area_size)

	wave_element_icon  = _get_or_create_texture_rect_child(wave_element_area, "WaveElementIcon",  Vector2(8, 5),  Vector2(24, 24))
	wave_element_label = _get_or_create_label_child(wave_element_area,        "WaveElementLabel", Vector2(40, 8))

	cores_button     = _get_or_create_button("CoresButton",      Vector2(440, zero_row_y - 5),              Vector2(64, 64))
	upgrades_button  = _get_or_create_button("UpgradesButton",   Vector2(520, zero_row_y - 5),              Vector2(48, 48))
	inventory_button = _get_or_create_button("InventoryButton",  Vector2(380, zero_row_y - 5),              Vector2(48, 48))
	start_button     = _get_or_create_button("StartWaveButton",  Vector2(viewport_size.x - 740, first_row_y  - 5), Vector2(130, 32))
	fast_forward_button = _get_or_create_button("FastForwardButton", Vector2(viewport_size.x - 740, second_row_y - 5), Vector2(48, 48))


func _get_or_create_label(node_name: String, default_pos: Vector2) -> Label:
	var label: Label = get_node_or_null(node_name) as Label
	if not label:
		label = Label.new()
		label.name = node_name
		label.position = default_pos
		add_child(label)
	return label


func _get_or_create_label_child(parent: Node, node_name: String, local_pos: Vector2) -> Label:
	var lbl: Label = parent.get_node_or_null(node_name) as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = node_name
		lbl.position = local_pos
		parent.add_child(lbl)
	return lbl


func _get_or_create_button(node_name: String, default_pos: Vector2, default_size: Vector2) -> Button:
	var btn: Button = get_node_or_null(node_name) as Button
	if not btn:
		btn = Button.new()
		btn.name = node_name
		btn.position = default_pos
		btn.custom_minimum_size = default_size
		add_child(btn)
	return btn


func _get_or_create_control(node_name: String, default_pos: Vector2, default_size: Vector2) -> Control:
	var c: Control = get_node_or_null(node_name) as Control
	if not c:
		c = Control.new()
		c.name = node_name
		c.position = default_pos
		c.custom_minimum_size = default_size
		c.size = default_size
		add_child(c)
	return c


func _get_or_create_texture_rect_child(parent: Node, node_name: String, local_pos: Vector2, default_size: Vector2) -> TextureRect:
	var tex_rect: TextureRect = parent.get_node_or_null(node_name) as TextureRect
	if not tex_rect:
		tex_rect = TextureRect.new()
		tex_rect.name = node_name
		tex_rect.position = local_pos
		tex_rect.custom_minimum_size = default_size
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(tex_rect)
	return tex_rect


func _apply_styles() -> void:
	if enemies_label:
		enemies_label.add_theme_font_size_override("font_size", 11)

	if cores_label:
		cores_label.add_theme_font_size_override("font_size", 11)
		cores_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))

	if seed_label:
		seed_label.add_theme_font_size_override("font_size", 10)
		seed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))

	if current_wave_info_label:
		current_wave_info_label.add_theme_font_size_override("font_size", 10)
		current_wave_info_label.text = "Aktuelle Welle:"
		current_wave_info_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))

	if current_wave_element_area:
		current_wave_element_area.visible = false
		current_wave_element_area.mouse_filter = Control.MOUSE_FILTER_STOP

	if current_wave_element_label:
		current_wave_element_label.add_theme_font_size_override("font_size", 11)

	if wave_preview_label:
		wave_preview_label.add_theme_font_size_override("font_size", 10)
		wave_preview_label.mouse_filter = Control.MOUSE_FILTER_STOP

	if wave_element_area:
		wave_element_area.visible = true
		wave_element_area.mouse_filter = Control.MOUSE_FILTER_STOP

	if wave_element_label:
		wave_element_label.add_theme_font_size_override("font_size", 11)

	if bonus_preview_label:
		bonus_preview_label.add_theme_font_size_override("font_size", 11)
		bonus_preview_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	if supply_label:
		supply_label.add_theme_font_size_override("font_size", 11)
		supply_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))

	if blocked_warning_label:
		blocked_warning_label.add_theme_font_size_override("font_size", 12)
		blocked_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		blocked_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		blocked_warning_label.add_theme_constant_override("outline_size", 2)
		blocked_warning_label.visible = false

	if wave_events_label:
		wave_events_label.add_theme_font_size_override("font_size", 10)
		wave_events_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))

	if inventory_button:
		inventory_button.icon = IconSystem.get_texture("inventory")
		inventory_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		inventory_button.expand_icon = true
		inventory_button.tooltip_text = "Inventar öffnen (I)"

		inventory_notification = Label.new()
		inventory_notification.name = "InventoryNotification"
		inventory_notification.position = Vector2(32, -5)
		inventory_notification.add_theme_font_size_override("font_size", 10)
		inventory_notification.add_theme_color_override("font_color", Color(1, 1, 1))
		inventory_notification.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.2))
		inventory_notification.add_theme_constant_override("outline_size", 3)
		inventory_notification.visible = false
		inventory_button.add_child(inventory_notification)

	if cores_button:
		core_notification = Label.new()
		core_notification.name = "CoresNotification"
		core_notification.position = Vector2(32, -5)
		core_notification.add_theme_font_size_override("font_size", 10)
		core_notification.add_theme_color_override("font_color", Color(1, 1, 1))
		core_notification.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.2))
		core_notification.add_theme_constant_override("outline_size", 3)
		core_notification.visible = false
		cores_button.add_child(core_notification)

	if UITheme and inventory_button:
		UITheme.style_button(inventory_button)
	if inventory_button:
		_apply_button_font_color(inventory_button)

	if cores_button:
		cores_button.text = ""
		cores_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cores_button.expand_icon = true
		var icon_path := "res://assets/elemental_symbols/four_elements.png"
		if ResourceLoader.exists(icon_path):
			cores_button.icon = load(icon_path)

	if upgrades_button:
		upgrades_button.icon = IconSystem.get_texture("upgrades")
		upgrades_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrades_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		upgrades_button.expand_icon = true
		upgrades_button.tooltip_text = "Aktive Upgrades anzeigen (U)"

	if start_button:
		start_button.text = "Nächste Welle"

	if fast_forward_button:
		fast_forward_button.text = ""
		fast_forward_button.visible = false
		fast_forward_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fast_forward_button.expand_icon = true
		fast_forward_button.flat = true
		_update_fast_forward_icon()
		_style_fast_forward_button()

	if UITheme:
		if start_button:   UITheme.style_button_light_text(start_button)
		if cores_button:   UITheme.style_button(cores_button)
		if upgrades_button: UITheme.style_button(upgrades_button)

	if cores_button:     _apply_button_font_color(cores_button)
	if upgrades_button:  _apply_button_font_color(upgrades_button)


func _style_fast_forward_button() -> void:
	if not fast_forward_button:
		return
	var empty := StyleBoxEmpty.new()
	fast_forward_button.add_theme_stylebox_override("normal",   empty)
	fast_forward_button.add_theme_stylebox_override("hover",    empty)
	fast_forward_button.add_theme_stylebox_override("pressed",  empty)
	fast_forward_button.add_theme_stylebox_override("focus",    empty)
	fast_forward_button.add_theme_stylebox_override("disabled", empty)


func _update_fast_forward_icon() -> void:
	if not fast_forward_button:
		return
	if is_fast_forward and ff_pressed_tex:
		fast_forward_button.icon = ff_pressed_tex
	elif ff_idle_tex:
		fast_forward_button.icon = ff_idle_tex


func _apply_button_font_color(btn: Button) -> void:
	if not btn:
		return
	var dark_font := Color(0.1, 0.1, 0.1)
	btn.add_theme_color_override("font_color",          dark_font)
	btn.add_theme_color_override("font_hover_color",    dark_font)
	btn.add_theme_color_override("font_pressed_color",  dark_font)
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))


func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.wave_started.connect(_on_wave_started)
	GameState.wave_completed.connect(_on_wave_completed)
	GameState.enemy_count_changed.connect(_on_enemy_count_changed)
	GameState.element_cores_changed.connect(_on_cores_changed)
	GameState.element_core_earned.connect(_on_core_earned)
	GameState.supply_changed.connect(_on_supply_changed)

	TowerData.element_unlocked.connect(_on_element_invested)
	TowerData.element_upgraded.connect(_on_element_upgraded)

	if start_button:      start_button.pressed.connect(_on_start_button_pressed)
	if cores_button:      cores_button.pressed.connect(_on_cores_button_pressed)
	if upgrades_button:   upgrades_button.pressed.connect(_on_upgrades_button_pressed)
	if fast_forward_button: fast_forward_button.pressed.connect(_on_fast_forward_pressed)
	if inventory_button:  inventory_button.pressed.connect(_on_inventory_button_pressed)
	if ItemSystem:
		ItemSystem.item_collected.connect(_on_item_collected)
		ItemSystem.inventory_changed.connect(_on_inventory_changed)


func _on_inventory_button_pressed() -> void:
	open_inventory_pressed.emit()


func _on_item_collected(_item: Dictionary) -> void:
	if inventory_button:
		var tween := inventory_button.create_tween()
		tween.tween_property(inventory_button, "modulate", Color(1.5, 1.5, 0.5), 0.15)
		tween.tween_property(inventory_button, "modulate", Color.WHITE, 0.2)
	_update_inventory_notification()


func _on_element_invested(_element: String) -> void:
	_on_cores_changed(GameState.element_cores)


func _on_inventory_changed() -> void:
	_update_inventory_notification()


func _update_inventory_notification() -> void:
	if not inventory_notification or not ItemSystem:
		return
	var count := ItemSystem.get_inventory().size()
	if count > 0:
		inventory_notification.text = str(count)
		inventory_notification.visible = true
	else:
		inventory_notification.visible = false


func _on_element_upgraded(_element: String, _level: int) -> void:
	_on_cores_changed(GameState.element_cores)


func update_all() -> void:
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)
	_update_wave_display()
	_on_enemy_count_changed(GameState.enemies_remaining)
	_on_cores_changed(GameState.element_cores)
	_on_supply_changed(GameState.supply_used, GameState.supply_max)
	_update_bonus_preview()
	_update_wave_preview(1)
	update_wave_events_preview(1)


func update_blocked_towers_warning(count: int) -> void:
	_blocked_tower_count = count

	if not blocked_warning_label:
		return

	if count > 0:
		blocked_warning_label.visible = true
		blocked_warning_label.text = "⚠ %d Turm(e) auf Pfad! Umplatzieren!" % count

		if not blocked_warning_label.has_meta("pulse_tween"):
			var tween := blocked_warning_label.create_tween().set_loops()
			tween.tween_property(blocked_warning_label, "modulate:a", 0.5, 0.4)
			tween.tween_property(blocked_warning_label, "modulate:a", 1.0, 0.4)
			blocked_warning_label.set_meta("pulse_tween", tween)

		if start_button:
			start_button.disabled = true
			start_button.text = "Türme umplatzieren!"
	else:
		blocked_warning_label.visible = false
		blocked_warning_label.modulate.a = 1.0

		if blocked_warning_label.has_meta("pulse_tween"):
			var tween: Tween = blocked_warning_label.get_meta("pulse_tween")
			if tween: tween.kill()
			blocked_warning_label.remove_meta("pulse_tween")

		if start_button and not GameState.wave_active:
			start_button.disabled = false
			start_button.text = "Nächste Welle"


func update_wave_events_preview(next_wave: int) -> void:
	if not wave_events_label:
		return

	var events: Array[String] = []

	if next_wave >= 2 and (next_wave - 2) % 3 == 0:
		events.append("%s Neuer Pfad" % IconSystem.bb("path", 22))

	if next_wave >= 3 and next_wave % 3 == 0:
		events.append("%s Upgrade" % IconSystem.bb("upgrades", 22))

	if AbilitySystem.should_show_ability_upgrades(next_wave):
		events.append("%s Ability Upgrade" % IconSystem.bb("abilities", 22))

	if next_wave == 1 or (next_wave > 0 and next_wave % 5 == 0):
		events.append("+1 %s" % IconSystem.bb("core", 22))

	if events.is_empty():
		wave_events_label.text = ""
		wave_events_label.visible = false
	else:
		wave_events_label.text = "Nach Welle %d: %s" % [next_wave, ", ".join(events)]
		wave_events_label.visible = true

		if "Upgrade" in wave_events_label.text:
			wave_events_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif "Neuer Pfad" in wave_events_label.text:
			wave_events_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		else:
			wave_events_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "%s %d" % [IconSystem.bb("gold", 24), amount]
	_update_bonus_preview()


func _on_lives_changed(amount: int) -> void:
	if not lives_label:
		return
	lives_label.text = "%s %d" % [IconSystem.bb("life", 22), amount]
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lives_label.remove_theme_color_override("font_color")


func _on_cores_changed(amount: int) -> void:
	var invested      := TowerData.get_total_cores_invested()
	var max_possible  := TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL

	if cores_label:
		cores_label.text = "%s Kerne: %d | %d/%d" % [IconSystem.bb('core', 22), amount, invested, max_possible]
		if amount > 0:
			cores_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		else:
			cores_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	if cores_button:
		cores_button.visible = true
		var has_upgradeable := not TowerData.get_upgradeable_elements().is_empty()
		if amount > 0 and has_upgradeable:
			core_notification.text = str(amount)
			core_notification.visible = true
			_highlight_cores_button(true)
		elif not has_upgradeable:
			core_notification.visible = false
			_highlight_cores_button(false)
		else:
			core_notification.visible = false
			_highlight_cores_button(false)


func _on_core_earned() -> void:
	_flash_cores_label()


func _on_supply_changed(used: int, max_supply: int) -> void:
	if not supply_label:
		return

	var upgrade_bonus := 0
	if UpgradeSystem:
		upgrade_bonus = UpgradeSystem.get_supply_max_bonus()

	var effective_max := max_supply + upgrade_bonus
	var available     := effective_max - used

	if upgrade_bonus > 0:
		supply_label.text = "%s %d/%d (+%d)" % [IconSystem.bb("supply", 24), used, max_supply, upgrade_bonus]
	else:
		supply_label.text = "%s %d/%d" % [IconSystem.bb("supply", 24), used, effective_max]

	supply_label.tooltip_text = "Supply: %d verwendet von %d\n%d verfügbar" % [used, effective_max, available]

	if available <= 0:
		supply_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif available <= 1:
		supply_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		supply_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))


func _highlight_cores_button(highlight: bool) -> void:
	if not cores_button:
		return
	if highlight:
		cores_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		cores_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))


func _flash_cores_label() -> void:
	if not cores_label:
		return
	var tween := cores_label.create_tween()
	tween.tween_property(cores_label, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	tween.tween_property(cores_label, "modulate", Color.WHITE, 0.3)


func _update_bonus_preview() -> void:
	if not bonus_preview_label:
		return

	bonus_preview_label.visible = true
	var preview           := GameState.get_wave_end_bonus_preview()
	var flat: int          = preview["flat"]
	var base_flat: int     = preview["base_flat"]
	var flat_bonus: int    = preview["flat_upgrade_bonus"]
	var interest: int      = preview["interest"]
	var base_interest: int = preview["base_interest"]
	var interest_upgrade_bonus: int = preview["interest_upgrade_bonus"]
	var total: int         = preview["total"]

	var flat_text := "%d" % flat
	if flat_bonus > 0:
		flat_text = "%d(+%d)" % [base_flat, flat_bonus]

	var interest_text := "%d💰" % interest
	if interest_upgrade_bonus > 0:
		interest_text = "%d(+%d)💰" % [base_interest, interest_upgrade_bonus]

	if interest > 0:
		bonus_preview_label.text = "Wellen-Ende: +%s +%s = %d" % [flat_text, interest_text, total]
	else:
		bonus_preview_label.text = "Wellen-Ende: +%s = %d" % [flat_text, total]

	var tooltip_lines: Array[String] = []
	tooltip_lines.append("=== Wellen-Bonus Berechnung ===")
	tooltip_lines.append("")
	tooltip_lines.append("📦 Flat Bonus: %d Gold" % flat)
	if flat_bonus > 0:
		tooltip_lines.append("    Basis: %d" % base_flat)
		tooltip_lines.append("    Upgrade (Kriegskasse): +%d" % flat_bonus)
	tooltip_lines.append("")
	var rate_percent := int(preview["interest_rate"] * 100)
	tooltip_lines.append("💰 Zinsen: %d Gold" % interest)
	tooltip_lines.append("    Berechnung: %d%% von %d Gold" % [rate_percent, GameState.gold])
	if UpgradeSystem:
		var rate_bonus := UpgradeSystem.get_interest_rate_bonus()
		if rate_bonus > 0:
			tooltip_lines.append("    Zinsrate: %d%% (+%d%% Upgrade)" % [rate_percent, int(rate_bonus * 100)])
		if interest_upgrade_bonus > 0:
			tooltip_lines.append("    Mehr durch Upgrades: +%d" % interest_upgrade_bonus)
		tooltip_lines.append("    Max-Zinsen: %d" % preview["max_interest"])
	if interest == 0 and GameState.gold < 10:
		tooltip_lines.append("")
		tooltip_lines.append("💡 Tipp: Spare Gold für mehr Zinsen!")
	tooltip_lines.append("")
	tooltip_lines.append("=== Gesamt: %d Gold ===" % total)
	bonus_preview_label.tooltip_text = "\n".join(tooltip_lines)


func _on_wave_started(wave: int) -> void:
	_update_wave_display()
	_update_bonus_preview()

	if start_button:
		start_button.disabled = true
		start_button.text = "Wave läuft..."

	if blocked_warning_label:
		blocked_warning_label.visible = false

	if wave_events_label:
		wave_events_label.visible = false

	if fast_forward_button:
		fast_forward_button.visible = true
	_set_fast_forward(false)

	call_deferred("_refresh_wave_panels_after_wave_started", wave)


func _refresh_wave_panels_after_wave_started(wave: int) -> void:
	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if wave_manager:
		_current_wave_element = wave_manager.current_wave_element
	_update_current_wave_element_display(_current_wave_element)

	if current_wave_info_label:
		current_wave_info_label.visible = true

	_update_wave_preview(wave + 1)


func _on_wave_completed(wave: int) -> void:
	if start_button:
		if _blocked_tower_count <= 0:
			start_button.disabled = false
			start_button.text = "Nächste Welle"
		else:
			start_button.disabled = true
			start_button.text = "Türme umplatzieren!"

	if current_wave_element_area:  current_wave_element_area.visible = false
	if current_wave_info_label:    current_wave_info_label.visible   = false
	if enemies_label:              enemies_label.visible              = false

	_update_bonus_preview()
	update_wave_events_preview(wave + 1)

	if fast_forward_button:
		fast_forward_button.visible = false
	_set_fast_forward(false)


func update_wave_preview_after_regen() -> void:
	_update_wave_preview(GameState.current_wave + 1)


func _on_enemy_count_changed(count: int) -> void:
	if not enemies_label:
		return
	if GameState.wave_active:
		enemies_label.text    = "Gegner: %d" % count
		enemies_label.visible = true
	else:
		enemies_label.visible = false


func _update_wave_display() -> void:
	if not wave_label:
		return
	if GameState.current_wave == 0:
		wave_label.text = "Welle: --"
	else:
		wave_label.text = "Welle: %d" % GameState.current_wave


func _update_current_wave_element_display(wave_elem: String) -> void:
	if not current_wave_element_area or not current_wave_element_icon or not current_wave_element_label:
		return

	if current_wave_info_label:
		current_wave_info_label.visible = true
		current_wave_info_label.text    = "Aktuelle Welle:"

	wave_elem = String(wave_elem).to_lower()
	current_wave_element_area.visible = true

	if wave_elem == "neutral" or wave_elem == "":
		current_wave_element_icon.texture = null
		current_wave_element_icon.visible = false
		current_wave_element_label.text = "Neutral"
		current_wave_element_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		if element_textures.has(wave_elem):
			current_wave_element_icon.texture = element_textures[wave_elem]
			current_wave_element_icon.visible = true
		else:
			current_wave_element_icon.texture = null
			current_wave_element_icon.visible = false

		current_wave_element_label.text = wave_elem.capitalize()
		var elem_color := ElementalSystem.get_element_color(wave_elem) if ElementalSystem else Color.WHITE
		current_wave_element_label.add_theme_color_override("font_color", elem_color)


func _update_wave_preview(next_wave: int) -> void:
	if not wave_preview_label:
		return

	wave_preview_label.visible = true

	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if not wave_manager:
		wave_preview_label.text = "Nächste Welle bereit"
		_next_wave_element = "neutral"
		_next_wave_preview = {}
		return

	var info      := wave_manager.get_wave_info(next_wave)
	var preview   := wave_manager.get_wave_preview(next_wave)
	var wave_elem : String = String(preview.get("wave_element", "neutral")).to_lower()

	_next_wave_element = wave_elem
	_next_wave_preview = preview

	# Element-Icon inline einbetten
	var elem_bb := ""
	if wave_elem != "neutral" and wave_elem != "":
		var tex_path := "res://assets/elemental_symbols/%s_element.png" % wave_elem
		if ResourceLoader.exists(tex_path):
			elem_bb = " [img=18]%s[/img] [color=%s]%s[/color]" % [
				tex_path,
				"#%s" % ElementalSystem.get_element_color(wave_elem).to_html(false) if ElementalSystem else "white",
				wave_elem.capitalize()
			]
		elif ElementalSystem:
			elem_bb = " " + ElementalSystem.get_element_bb(wave_elem, 14)

	var boss_line := ""
	if next_wave % 5 == 0:
		boss_line = "\n[color=#ffaa44]Boss-Welle![/color]"

	wave_preview_label.bbcode_enabled = true
	wave_preview_label.text = "Nächste Welle: %s%s%s" % [info, elem_bb, boss_line]


func _update_wave_element_display(wave_elem: String) -> void:
	if not wave_element_area or not wave_element_icon or not wave_element_label:
		return

	wave_elem = String(wave_elem).to_lower()
	wave_element_area.visible = true

	if wave_elem == "neutral" or wave_elem == "":
		wave_element_icon.texture = null
		wave_element_icon.visible = false
		wave_element_label.text = "Neutral"
		wave_element_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		if element_textures.has(wave_elem):
			wave_element_icon.texture = element_textures[wave_elem]
			wave_element_icon.visible = true
		else:
			wave_element_icon.texture = null
			wave_element_icon.visible = false

		wave_element_label.text = wave_elem.capitalize()
		var elem_color := ElementalSystem.get_element_color(wave_elem) if ElementalSystem else Color.WHITE
		wave_element_label.add_theme_color_override("font_color", elem_color)


# ===================================================================
# TOOLTIP
# ===================================================================

func _create_wave_tooltip() -> void:
	if is_instance_valid(wave_tooltip):
		return

	var tip_layer := CanvasLayer.new()
	tip_layer.name = "TooltipLayer"
	tip_layer.layer = 250
	add_child(tip_layer)

	wave_tooltip = PanelContainer.new()
	wave_tooltip.visible      = false
	wave_tooltip.z_index      = 200
	wave_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_layer.add_child(wave_tooltip)

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.12, 0.12, 0.14, 0.95)
	style.border_color        = Color(0.35, 0.35, 0.4,  0.9)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	wave_tooltip.add_theme_stylebox_override("panel", style)

	var marginc := MarginContainer.new()
	marginc.add_theme_constant_override("margin_left",   10)
	marginc.add_theme_constant_override("margin_right",  10)
	marginc.add_theme_constant_override("margin_top",     8)
	marginc.add_theme_constant_override("margin_bottom",  8)
	wave_tooltip.add_child(marginc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(260, 0)
	marginc.add_child(vb)

	# --- Titel ---
	wave_tooltip_title = Label.new()
	wave_tooltip_title.add_theme_font_size_override("font_size", 12)
	wave_tooltip_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(wave_tooltip_title)

	# --- Elementar-Schwäche ---
	var weak_row := HBoxContainer.new()
	weak_row.add_theme_constant_override("separation", 8)
	vb.add_child(weak_row)

	var weak_text := Label.new()
	weak_text.text = "Schwach gegen:"
	weak_text.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	weak_row.add_child(weak_text)

	wave_tooltip_weak_icon = TextureRect.new()
	wave_tooltip_weak_icon.custom_minimum_size = Vector2(18, 18)
	wave_tooltip_weak_icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	wave_tooltip_weak_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weak_row.add_child(wave_tooltip_weak_icon)

	wave_tooltip_weak_label = Label.new()
	wave_tooltip_weak_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	weak_row.add_child(wave_tooltip_weak_label)

	# --- Elementar-Resistenz ---
	var resist_row := HBoxContainer.new()
	resist_row.add_theme_constant_override("separation", 8)
	vb.add_child(resist_row)

	var resist_text := Label.new()
	resist_text.text = "Resistent gegen:"
	resist_text.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	resist_row.add_child(resist_text)

	wave_tooltip_resist_icon = TextureRect.new()
	wave_tooltip_resist_icon.custom_minimum_size = Vector2(18, 18)
	wave_tooltip_resist_icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	wave_tooltip_resist_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resist_row.add_child(wave_tooltip_resist_icon)

	wave_tooltip_resist_label = Label.new()
	wave_tooltip_resist_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	resist_row.add_child(wave_tooltip_resist_label)

	# --- Trennlinie ---
	var sep := HSeparator.new()
	sep.name = "WeaknessSep"
	vb.add_child(sep)

	# --- Gegner-Schwächen-Titel ---
	var wk_title := Label.new()
	wk_title.name = "WeaknessTitle"
	wk_title.text = "Gegner dieser Welle:"
	wk_title.add_theme_font_size_override("font_size", 10)
	wk_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vb.add_child(wk_title)

	# --- Container für dynamische Gegner-Zeilen ---
	var wk_container := VBoxContainer.new()
	wk_container.name = "WeaknessContainer"
	wk_container.add_theme_constant_override("separation", 2)
	vb.add_child(wk_container)


func _connect_tooltip_hover_area() -> void:
	if wave_element_area:
		wave_element_area.mouse_entered.connect(_on_wave_element_hover_enter.bind("next"))
		wave_element_area.mouse_exited.connect(_on_wave_element_hover_exit)
	if current_wave_element_area:
		current_wave_element_area.mouse_entered.connect(_on_wave_element_hover_enter.bind("current"))
		current_wave_element_area.mouse_exited.connect(_on_wave_element_hover_exit)
	# wave_preview_label triggert denselben Tooltip
	if wave_preview_label:
		wave_preview_label.mouse_entered.connect(_on_wave_element_hover_enter.bind("next"))
		wave_preview_label.mouse_exited.connect(_on_wave_element_hover_exit)


func _on_wave_element_hover_enter(which: String) -> void:
	_show_wave_tooltip(which)


func _on_wave_element_hover_exit() -> void:
	_hide_wave_tooltip()


func _show_wave_tooltip(which: String) -> void:
	if not wave_tooltip:
		return

	var wave_elem: String
	var hover_area: Control
	var title_prefix: String
	var preview: Dictionary

	if which == "current":
		wave_elem    = String(_current_wave_element).to_lower()
		hover_area   = current_wave_element_area
		title_prefix = "Aktuelle Welle: "
		# Für die laufende Welle kein Preview verfügbar → leeres Dict
		preview = {}
	else:
		wave_elem    = String(_next_wave_element).to_lower()
		hover_area   = wave_element_area if wave_element_area else wave_preview_label
		title_prefix = "Nächste Welle: "
		preview = _next_wave_preview

	# Titel setzen (auch bei neutralem Element zeigen wir Gegner-Infos)
	if wave_elem == "" or wave_elem == "neutral":
		wave_tooltip_title.text = "%sNeutral" % title_prefix
	else:
		wave_tooltip_title.text = "%s%s Gegner" % [title_prefix, wave_elem.capitalize()]

	# --- Elementar-Schwäche / Resistenz ---
	var weak_against := ""
	var resists      := ""
	if ElementalSystem and wave_elem != "" and wave_elem != "neutral":
		weak_against = String(ElementalSystem.get_effective_element(wave_elem)).to_lower()
		resists      = String(ElementalSystem.RESISTANCES.get(wave_elem, "")).to_lower()

	if weak_against != "" and weak_against != "neutral" and element_textures.has(weak_against):
		wave_tooltip_weak_icon.texture = element_textures[weak_against]
		wave_tooltip_weak_label.text   = weak_against.capitalize()
	else:
		wave_tooltip_weak_icon.texture = null
		wave_tooltip_weak_label.text   = "-"

	if resists != "" and element_textures.has(resists):
		wave_tooltip_resist_icon.texture = element_textures[resists]
		wave_tooltip_resist_label.text   = resists.capitalize()
	else:
		wave_tooltip_resist_icon.texture = null
		wave_tooltip_resist_label.text   = "-"

	# --- Tower-Schwächen Sektion befüllen ---
	var wk_container: Node = wave_tooltip.find_child("WeaknessContainer", true, false)
	var wk_title: Node     = wave_tooltip.find_child("WeaknessTitle",     true, false)
	var wk_sep: Node       = wave_tooltip.find_child("WeaknessSep",       true, false)

	if wk_container:
		for child in wk_container.get_children():
			child.queue_free()

		var lines_added := 0
		for enemy_type in ENEMY_TYPE_INFO.keys():
			if not preview.get(enemy_type, 0) > 0:
				continue

			var info: Dictionary    = ENEMY_TYPE_INFO[enemy_type]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			wk_container.add_child(row)

			var name_lbl := Label.new()
			name_lbl.text = info["name"] + ":"
			name_lbl.custom_minimum_size = Vector2(72, 0)
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			row.add_child(name_lbl)

			var weak_lbl := Label.new()
			weak_lbl.text = "▲ " + TOWER_NAMES.get(info["weak"], info["weak"])
			weak_lbl.add_theme_font_size_override("font_size", 10)
			weak_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
			row.add_child(weak_lbl)

			var resist_lbl := Label.new()
			resist_lbl.text = "▼ " + TOWER_NAMES.get(info["resist"], info["resist"])
			resist_lbl.add_theme_font_size_override("font_size", 10)
			resist_lbl.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
			row.add_child(resist_lbl)

			lines_added += 1

		# Separator + Titel nur zeigen wenn Gegner-Einträge vorhanden
		var has_entries := lines_added > 0
		if wk_title: wk_title.visible = has_entries
		if wk_sep:   wk_sep.visible   = has_entries

	# --- Tooltip positionieren ---
	var margin       : float   = 10.0
	var viewport_size: Vector2 = get_viewport_rect().size
	var tip_size     : Vector2 = wave_tooltip.get_combined_minimum_size()
	if tip_size == Vector2.ZERO:
		tip_size = wave_tooltip.size

	var desired_pos := Vector2.ZERO
	if hover_area:
		var area_pos  : Vector2 = hover_area.get_global_position()
		var right_pos : Vector2 = area_pos + Vector2(hover_area.size.x + 10.0, -8.0)
		var left_pos  : Vector2 = area_pos + Vector2(-tip_size.x - 10.0,        -8.0)
		desired_pos = left_pos if right_pos.x + tip_size.x + margin > viewport_size.x else right_pos
	else:
		desired_pos = Vector2(margin, margin)

	var max_x := viewport_size.x - tip_size.x - margin
	var max_y := viewport_size.y - tip_size.y - margin
	wave_tooltip.global_position = Vector2(clampf(desired_pos.x, margin, max_x),
										   clampf(desired_pos.y, margin, max_y))
	wave_tooltip.visible  = true
	_tooltip_visible      = true


func _hide_wave_tooltip() -> void:
	if wave_tooltip:
		wave_tooltip.visible = false
	_tooltip_visible = false


# ===================================================================
# GAME OVER
# ===================================================================

func show_game_over() -> void:
	_set_fast_forward(false)
	_hide_wave_tooltip()

	for node in [start_button, cores_button, upgrades_button, fast_forward_button,
			bonus_preview_label, blocked_warning_label, wave_element_area,
			current_wave_element_area, wave_preview_label,
			current_wave_info_label, wave_events_label]:
		if node:
			node.visible = false

	var main := get_node_or_null("/root/Main")
	var seed_text := ""
	if main and main.has_method("get_current_seed"):
		seed_text = "\nSeed: %d" % main.get_current_seed()

	var game_over_label := Label.new()
	game_over_label.text = "GAME OVER\nWelle: %d\nKerne investiert: %d/%d%s" % [
		GameState.current_wave,
		TowerData.get_total_cores_invested(),
		TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL,
		seed_text
	]
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	game_over_label.position = Vector2(280, 100)
	game_over_label.name     = "GameOverLabel"
	add_child(game_over_label)

	var restart_btn := Button.new()
	restart_btn.text = "Neustart"
	restart_btn.position = Vector2(350, 240)
	restart_btn.custom_minimum_size = Vector2(100, 35)
	restart_btn.pressed.connect(_on_restart_pressed)
	add_child(restart_btn)

	if UITheme: UITheme.style_button(restart_btn)
	_apply_button_font_color(restart_btn)


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


func _on_cores_button_pressed() -> void:
	open_element_panel_pressed.emit()


func _on_upgrades_button_pressed() -> void:
	open_upgrades_panel_pressed.emit()


func _on_fast_forward_pressed() -> void:
	Sound.play_click()
	_set_fast_forward(not is_fast_forward)


func _set_fast_forward(enabled: bool) -> void:
	is_fast_forward = enabled
	_update_fast_forward_icon()
	Engine.time_scale = FAST_FORWARD_SPEED if enabled else 1.0


func _on_restart_pressed() -> void:
	GameState.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
