# ui/hud.gd
# Zeigt Gold, Leben, Welle, Element-Kerne, Seed, Start-Button und Fast-Forward
extends Control
class_name HUD

const RunSchedule = preload("res://autoload/run_schedule.gd")

signal start_wave_pressed
signal open_element_panel_pressed
signal open_upgrades_panel_pressed
signal open_inventory_pressed
signal open_research_pressed
signal open_synergy_panel_pressed
signal open_schedule_pressed
signal open_forge_pressed
signal open_tower_stats_pressed
signal pause_pressed

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
@export var fast_forward_button: Button
@export var bonus_preview_label: Label
@export var supply_label: RichTextLabel
@export var blocked_warning_label: Label
@export var wave_events_label: RichTextLabel
@export var inventory_button: Button
var synergy_button: Button
var schedule_button: Button
var forge_button: Button
var tower_stats_button: Button

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

const TOWER_SHORT_NAMES := {
	"archer":  "Bogen",
	"sword":   "Schwert",
	"wizard":  "Magier",
	"cannon":  "Kanone",
	"trapper": "Falle",
}

var inventory_notification: Label
var core_notification: Label
var item_toast_container: VBoxContainer

var current_wave_element_area: Control
var current_wave_element_icon: TextureRect
var current_wave_element_label: Label
var current_wave_info_label: Label
var current_wave_status_row: HBoxContainer

var is_fast_forward := false
const FAST_FORWARD_SPEED := 2.5

var ff_idle_tex: Texture2D
var ff_pressed_tex: Texture2D

var element_textures: Dictionary = {}

var wave_element_area: Control
var wave_status_panel: PanelContainer
var next_wave_title_label: Label
var wave_advice_label: RichTextLabel
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
var wave_action_row: HBoxContainer
var research_button: Button
var auto_wave_button: Button
var pause_button: Button
var streak_panel: PanelContainer
var streak_label: Label
var streak_bar: ProgressBar

const BOSS_BAR_WIDTH := 620.0
const BOSS_BAR_TOP_MARGIN := 14.0

var boss_bar_root: VBoxContainer
var boss_bar_label: Label
var boss_bar: ProgressBar
var tracked_boss: Node2D

var bottom_strip: Control
var top_bar: Control
var top_bar_row: HBoxContainer
var hp_dot: ColorRect
var hp_bar: ProgressBar
var top_bar_icon_cluster: HBoxContainer


func _ready() -> void:
	add_to_group("hud")
	_load_fast_forward_textures()
	_load_element_textures()
	_setup_hud_size()
	_find_or_create_ui_elements()
	_build_top_bar_content()
	_create_wave_status_ui()
	_create_progression_ui()
	_create_item_toast_layer()
	_create_boss_bar()
	_apply_styles()
	_connect_signals()
	_create_wave_tooltip()
	_connect_tooltip_hover_area()
	update_all()


func _process(_delta: float) -> void:
	_update_boss_bar()


func _get_or_create_rich_label(node_name: String, default_pos: Vector2, min_width: float = 120.0) -> RichTextLabel:
	var label: RichTextLabel = bottom_strip.get_node_or_null(node_name) as RichTextLabel
	if not label:
		label = RichTextLabel.new()
		label.name = node_name
		label.position = default_pos
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size = Vector2(min_width, 20)
		bottom_strip.add_child(label)
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
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not is_instance_valid(bottom_strip):
		bottom_strip = Control.new()
		bottom_strip.name = "BottomStrip"
		bottom_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bottom_strip)

	bottom_strip.anchor_left = 0.0
	bottom_strip.anchor_right = 1.0
	bottom_strip.anchor_top = 1.0
	bottom_strip.anchor_bottom = 1.0
	bottom_strip.offset_left = 0
	bottom_strip.offset_right = 0
	bottom_strip.offset_top = -hud_height
	bottom_strip.offset_bottom = 0

	if not bottom_strip.has_node("HUDBackground"):
		var bg := Panel.new()
		bg.name = "HUDBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.05, 0.09, 0.97)
		style.border_color = Color(0.15, 0.38, 0.58, 0.8)
		style.border_width_top = 2
		bg.add_theme_stylebox_override("panel", style)
		bottom_strip.add_child(bg)
		bottom_strip.move_child(bg, 0)

	_setup_top_bar()


# PanelContainer schrumpfte hier trotz Vollbreiten-Anchors auf Inhaltsbreite
# (Container-Eigenverhalten ausserhalb eines Eltern-Containers) - deshalb wie
# BottomStrip/HUDBackground ein plain Control fuers Anchoring plus ein separates
# Panel-Kind nur fuers Stylebox.
func _setup_top_bar() -> void:
	if is_instance_valid(top_bar):
		return

	top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0
	top_bar.offset_right = 0
	top_bar.offset_top = 0
	top_bar.offset_bottom = UI.TOPBAR_H
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var top_bar_bg := Panel.new()
	top_bar_bg.name = "TopBarBackground"
	top_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var top_bar_style := UI.panel()
	top_bar_style.content_margin_top = 0
	top_bar_style.content_margin_bottom = 0
	top_bar_bg.add_theme_stylebox_override("panel", top_bar_style)
	top_bar.add_child(top_bar_bg)

	top_bar_row = HBoxContainer.new()
	top_bar_row.name = "TopBarRow"
	top_bar_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bar_row.offset_left = UI.SP_5
	top_bar_row.offset_right = -UI.SP_5
	top_bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar_row.add_theme_constant_override("separation", UI.SP_4)
	top_bar.add_child(top_bar_row)


func _topbar_separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 1
	var line := StyleBoxFlat.new()
	line.bg_color = UI.BORDER_SOFT
	line.content_margin_left = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


# Zieht Gold/Leben/Welle/Kerne/Supply aus dem BottomStrip in die TopBar-Reihe.
# Die Update-Funktionen (_on_gold_changed usw.) bleiben unveraendert - nur das
# Parenting aendert sich, das Reihenfolge-Skelett entsteht hier einmalig.
func _build_top_bar_content() -> void:
	var hp_group := HBoxContainer.new()
	hp_group.name = "HPGroup"
	hp_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_group.add_theme_constant_override("separation", UI.SP_2)
	top_bar_row.add_child(hp_group)

	hp_dot = ColorRect.new()
	hp_dot.name = "HPDot"
	hp_dot.custom_minimum_size = Vector2(12, 12)
	hp_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_dot.color = UI.SUCCESS
	hp_group.add_child(hp_dot)

	lives_label.reparent(hp_group, false)
	lives_label.position = Vector2.ZERO
	lives_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(64, UI.BAR_H_HP)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.show_percentage = false
	hp_bar.min_value = 0.0
	hp_bar.max_value = 1.0
	hp_bar.add_theme_stylebox_override("background", UI.bar(true))
	hp_bar.add_theme_stylebox_override("fill", UI.bar(false, UI.SUCCESS))
	hp_group.add_child(hp_bar)

	top_bar_row.add_child(_topbar_separator())

	var wave_group := HBoxContainer.new()
	wave_group.name = "WaveGroup"
	wave_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wave_group.add_theme_constant_override("separation", UI.SP_2)
	top_bar_row.add_child(wave_group)

	var wave_micro := Label.new()
	wave_micro.name = "WaveMicroLabel"
	wave_micro.text = "WELLE"
	wave_micro.add_theme_font_size_override("font_size", UI.FS_MICRO)
	wave_micro.add_theme_color_override("font_color", UI.TEXT_SECOND)
	wave_group.add_child(wave_micro)

	wave_label.reparent(wave_group, false)
	wave_label.position = Vector2.ZERO
	wave_label.add_theme_font_size_override("font_size", UI.FS_SECTION)

	enemies_label.reparent(wave_group, false)
	enemies_label.position = Vector2.ZERO
	enemies_label.add_theme_font_size_override("font_size", UI.FS_MICRO)
	enemies_label.add_theme_color_override("font_color", UI.TEXT_SECOND)

	top_bar_row.add_child(_topbar_separator())

	var pod := HBoxContainer.new()
	pod.name = "ResourcePod"
	pod.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pod.add_theme_constant_override("separation", UI.SP_3)
	top_bar_row.add_child(pod)

	gold_label.reparent(pod, false)
	gold_label.position = Vector2.ZERO

	pod.add_child(_topbar_separator())
	cores_label.reparent(pod, false)
	cores_label.position = Vector2.ZERO

	pod.add_child(_topbar_separator())
	supply_label.reparent(pod, false)
	supply_label.position = Vector2.ZERO
	supply_label.custom_minimum_size = Vector2(0, 20)

	var spacer := Control.new()
	spacer.name = "TopBarSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar_row.add_child(spacer)

	top_bar_icon_cluster = HBoxContainer.new()
	top_bar_icon_cluster.name = "TopBarIconCluster"
	top_bar_icon_cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar_icon_cluster.add_theme_constant_override("separation", UI.SP_1)
	top_bar_row.add_child(top_bar_icon_cluster)

	for btn in [inventory_button, cores_button, upgrades_button, synergy_button,
			schedule_button, forge_button, tower_stats_button]:
		_dock_icon_button(btn)


# Loest einen Panel-Button aus dem BottomStrip und macht ihn zu einem
# 56x56-Icon-Button im TopBar-Cluster (rechtes Ende). pause_button/research_button
# kommen erst spaeter dazu, sobald _create_progression_ui() sie angelegt hat.
func _dock_icon_button(btn: Button) -> void:
	if not btn:
		return
	btn.reparent(top_bar_icon_cluster, false)
	btn.position = Vector2.ZERO
	btn.custom_minimum_size = Vector2(UI.ICON_BTN, UI.ICON_BTN)
	btn.add_theme_stylebox_override("normal", UI.btn_icon("normal"))
	btn.add_theme_stylebox_override("hover", UI.btn_icon("hover"))
	btn.add_theme_stylebox_override("pressed", UI.btn_icon("pressed"))
	btn.add_theme_stylebox_override("disabled", UI.btn_icon("disabled"))


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

	# Panel-Buttons docken in _build_top_bar_content()/_dock_icon_button() sofort in
	# der TopBar an - die hier uebergebene Position/Groesse ist nur der Erstwert fuer
	# den Fall, dass der Knoten neu erzeugt wird, und wird gleich danach ueberschrieben.
	inventory_button   = _get_or_create_button("InventoryButton",   Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	cores_button       = _get_or_create_button("CoresButton",       Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	upgrades_button    = _get_or_create_button("UpgradesButton",    Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	synergy_button     = _get_or_create_button("SynergyButton",     Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	schedule_button    = _get_or_create_button("ScheduleButton",    Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	forge_button       = _get_or_create_button("ForgeButton",       Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	tower_stats_button = _get_or_create_button("TowerStatsButton",  Vector2.ZERO, Vector2(UI.ICON_BTN, UI.ICON_BTN))
	start_button     = _get_or_create_button("StartWaveButton",  Vector2(viewport_size.x - 740, first_row_y  - 5), Vector2(130, 32))
	fast_forward_button = _get_or_create_button("FastForwardButton", Vector2(viewport_size.x - 740, second_row_y - 5), Vector2(48, 48))


func _create_wave_status_ui() -> void:
	wave_status_panel = PanelContainer.new()
	wave_status_panel.name = "WaveStatusPanel"
	# Kein Anchor-Overlay mehr (Phase3b_ShopRow_Konzept.md §3): wird von main.gd
	# als Kind der gemeinsamen BottomBar-HBox neben den Tower-Shop gesetzt.
	# Feste Mindestbreite statt der alten Anchor-Offsets (-785/-5 = 780px), damit
	# next_column (EXPAND_FILL) weiterhin genug Platz für die Wellenvorschau hat.
	wave_status_panel.custom_minimum_size.x = 780
	wave_status_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	wave_status_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wave_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# UI.panel() bringt SP_5-Padding mit; diese kompakte Statusleiste hat unten ihre
	# eigene 6px-MarginContainer, sonst verdoppelt sich der Innenabstand.
	var wave_panel_style := UI.panel()
	wave_panel_style.content_margin_left = 0
	wave_panel_style.content_margin_right = 0
	wave_panel_style.content_margin_top = 0
	wave_panel_style.content_margin_bottom = 0
	wave_status_panel.add_theme_stylebox_override("panel", wave_panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	wave_status_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size.x = 220
	action_column.add_theme_constant_override("separation", 3)
	row.add_child(action_column)

	var action_title := _create_wave_heading("WELLENSTEUERUNG")
	action_column.add_child(action_title)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 7)
	action_column.add_child(action_row)
	wave_action_row = action_row
	start_button.reparent(action_row, false)
	start_button.position = Vector2.ZERO
	start_button.custom_minimum_size = Vector2(171, 42)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Einziger Messing-Button im HUD (README §Bottombar) - explizit gestylt statt
	# auf den geerbten Theme-Default zu vertrauen, damit die Betonung nicht von
	# Panel-Verschachtelung/Theme-Vererbung abhaengt.
	start_button.add_theme_stylebox_override("normal", UI.btn_primary("normal"))
	start_button.add_theme_stylebox_override("hover", UI.btn_primary("hover"))
	start_button.add_theme_stylebox_override("pressed", UI.btn_primary("pressed"))
	start_button.add_theme_stylebox_override("disabled", UI.btn_primary("disabled"))
	start_button.add_theme_color_override("font_color", UI.ACCENT)
	start_button.add_theme_color_override("font_hover_color", UI.ACCENT_HOVER)
	start_button.add_theme_color_override("font_pressed_color", UI.TEXT_ON_ACCENT)
	start_button.add_theme_color_override("font_disabled_color", UI.TEXT_DISABLED)
	start_button.add_theme_font_size_override("font_size", UI.FS_SECTION)
	fast_forward_button.reparent(action_row, false)
	fast_forward_button.position = Vector2.ZERO
	fast_forward_button.custom_minimum_size = Vector2(42, 42)

	current_wave_status_row = HBoxContainer.new()
	current_wave_status_row.name = "CurrentWaveStatusRow"
	current_wave_status_row.custom_minimum_size.y = 16
	current_wave_status_row.add_theme_constant_override("separation", 6)
	action_column.add_child(current_wave_status_row)

	current_wave_info_label.reparent(current_wave_status_row, false)
	current_wave_info_label.position = Vector2.ZERO
	current_wave_info_label.custom_minimum_size = Vector2(78, 16)

	current_wave_element_area.reparent(current_wave_status_row, false)
	current_wave_element_area.position = Vector2.ZERO
	current_wave_element_area.custom_minimum_size = Vector2(130, 16)
	current_wave_element_icon.position = Vector2(0, 1)
	current_wave_element_icon.custom_minimum_size = Vector2(14, 14)
	current_wave_element_icon.size = Vector2(14, 14)
	current_wave_element_label.position = Vector2(19, 1)

	blocked_warning_label.reparent(action_column, false)
	blocked_warning_label.position = Vector2.ZERO
	blocked_warning_label.custom_minimum_size = Vector2(220, 16)
	blocked_warning_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	row.add_child(_create_wave_separator())

	var next_column := VBoxContainer.new()
	next_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_column.add_theme_constant_override("separation", 2)
	row.add_child(next_column)

	next_wave_title_label = _create_wave_heading("NÄCHSTE WELLE")
	next_column.add_child(next_wave_title_label)

	wave_preview_label.reparent(next_column, false)
	wave_preview_label.position = Vector2.ZERO
	wave_preview_label.custom_minimum_size = Vector2(0, 19)
	wave_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_preview_label.fit_content = false
	wave_preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	wave_advice_label = RichTextLabel.new()
	wave_advice_label.name = "WaveAdviceLabel"
	wave_advice_label.bbcode_enabled = true
	wave_advice_label.fit_content = false
	wave_advice_label.scroll_active = false
	wave_advice_label.custom_minimum_size = Vector2(0, 28)
	wave_advice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_advice_label.mouse_filter = Control.MOUSE_FILTER_STOP
	next_column.add_child(wave_advice_label)

	wave_events_label.reparent(next_column, false)
	wave_events_label.position = Vector2.ZERO
	wave_events_label.custom_minimum_size = Vector2(0, 18)
	wave_events_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_events_label.fit_content = true
	wave_events_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wave_events_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Wellenbelohnung gehoert inhaltlich zur Wellenvorschau, nicht in die Topbar.
	bonus_preview_label.reparent(next_column, false)
	bonus_preview_label.position = Vector2.ZERO
	bonus_preview_label.custom_minimum_size = Vector2(0, 18)
	bonus_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Das Element steht jetzt kompakt in der immer sichtbaren Beratung.
	# Die alte frei positionierte Zeile bleibt nur als Kompatibilitäts-Knoten erhalten.
	wave_element_area.visible = false
	wave_element_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _create_wave_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	return label


func _create_wave_separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 1
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.4, 0.35, 0.3, 0.72)
	line.content_margin_left = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func _create_progression_ui() -> void:
	var viewport_size := get_viewport_rect().size

	# Aether/Archiv-Stufe/Meilenstein sind kein Dauerplatz mehr im Kampf-HUD (README
	# "Zurücktreten"-Tier) - meta_progression_ui.gd zeigt dieselben Werte bereits
	# eigenstaendig im [U]-Overlay, ein zweites permanentes Label waere Duplikat.
	auto_wave_button = Button.new()
	auto_wave_button.custom_minimum_size = Vector2(76, 38)
	auto_wave_button.tooltip_text = "Wellen automatisch starten"
	auto_wave_button.pressed.connect(_on_auto_wave_pressed)
	wave_action_row.add_child(auto_wave_button)

	_style_progression_button(auto_wave_button)

	# "ARCHIV" wird ein reiner Icon-Button im TopBar-Cluster (kein eigenes Icon-Asset
	# vorhanden -> thematisches Glyph, gleiches Muster wie Synergie/Schmiede oben).
	research_button = Button.new()
	research_button.name = "ResearchButton"
	research_button.text = "▤"
	research_button.add_theme_font_size_override("font_size", 24)
	research_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	research_button.tooltip_text = "Dauerhafte Forschung öffnen (M)"
	research_button.pressed.connect(_on_research_pressed)
	bottom_strip.add_child(research_button)
	_dock_icon_button(research_button)

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.icon = IconSystem.get_texture("settings") if IconSystem else null
	pause_button.tooltip_text = "Pause & Optionen (Esc)"
	pause_button.pressed.connect(func(): pause_pressed.emit())
	pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bottom_strip.add_child(pause_button)
	_dock_icon_button(pause_button)
	if UITheme:
		UITheme.center_button_icon(pause_button)

	streak_panel = PanelContainer.new()
	streak_panel.position = Vector2(viewport_size.x * 0.5 - 145, -viewport_size.y + 135)
	streak_panel.custom_minimum_size = Vector2(290, 58)
	streak_panel.visible = false
	bottom_strip.add_child(streak_panel)
	var streak_margin := MarginContainer.new()
	streak_margin.add_theme_constant_override("margin_left", 12)
	streak_margin.add_theme_constant_override("margin_right", 12)
	streak_margin.add_theme_constant_override("margin_top", 7)
	streak_margin.add_theme_constant_override("margin_bottom", 7)
	streak_panel.add_child(streak_margin)
	var streak_box := VBoxContainer.new()
	streak_box.add_theme_constant_override("separation", 4)
	streak_margin.add_child(streak_box)
	streak_label = Label.new()
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_color_override("font_color", Color("6d277d"))
	streak_label.add_theme_font_size_override("font_size", 16)
	streak_box.add_child(streak_label)
	streak_bar = ProgressBar.new()
	streak_bar.custom_minimum_size.y = 10
	streak_bar.max_value = ProgressionSystem.STREAK_WINDOW if ProgressionSystem else 3.0
	streak_bar.show_percentage = false
	_style_arcane_progress_bar(streak_bar, Color("c35cf0"))
	streak_box.add_child(streak_bar)


func _create_item_toast_layer() -> void:
	item_toast_container = VBoxContainer.new()
	item_toast_container.name = "ItemToastContainer"
	item_toast_container.anchor_left = 1.0
	item_toast_container.anchor_right = 1.0
	item_toast_container.anchor_top = 0.0
	item_toast_container.anchor_bottom = 0.0
	item_toast_container.offset_left = -390.0
	item_toast_container.offset_right = -18.0
	item_toast_container.offset_top = -300.0
	item_toast_container.offset_bottom = -12.0
	item_toast_container.alignment = BoxContainer.ALIGNMENT_END
	item_toast_container.add_theme_constant_override("separation", 7)
	item_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_strip.add_child(item_toast_container)


func _show_item_toast(item: Dictionary) -> void:
	if not item_toast_container:
		return
	while item_toast_container.get_child_count() >= 4:
		var oldest := item_toast_container.get_child(0)
		item_toast_container.remove_child(oldest)
		oldest.queue_free()

	var rarity_color: Color = item.get("color", Color("75ddff"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.075, 0.96)
	style.border_color = rarity_color
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.28)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)
	item_toast_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemSystem.get_item_texture(item) if ItemSystem else null
	icon.modulate = rarity_color.lerp(Color.WHITE, 0.45)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 1)
	row.add_child(labels)
	var title := Label.new()
	title.text = String(item.get("name", "Unbekanntes Item"))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	labels.add_child(title)
	var rarity_names := {
		"common": "GEWÖHNLICH", "uncommon": "UNGEWÖHNLICH",
		"rare": "SELTEN", "epic": "EPISCH", "legendary": "LEGENDÄR",
	}
	var rarity := String(item.get("rarity", "common"))
	var detail := Label.new()
	detail.text = "%s  ·  INS INVENTAR AUFGENOMMEN" % rarity_names.get(rarity, rarity.to_upper())
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", rarity_color)
	labels.add_child(detail)
	for label in [title, detail]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var in_tween := panel.create_tween()
	in_tween.set_parallel(true)
	in_tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	in_tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await in_tween.finished
	if not is_instance_valid(panel):
		return

	# ignore_time_scale=true haelt die Anzeigedauer unabhaengig vom Vorspulen (Engine.time_scale)
	await get_tree().create_timer(4.5, true, false, true).timeout
	if not is_instance_valid(panel):
		return

	var out_tween := panel.create_tween()
	out_tween.set_parallel(true)
	out_tween.tween_property(panel, "modulate:a", 0.0, 0.22)
	out_tween.tween_property(panel, "scale", Vector2(0.97, 0.97), 0.22)
	await out_tween.finished
	if is_instance_valid(panel):
		panel.queue_free()


# === BOSS-LEISTE ===
# Eigene Leiste am oberen Bildrand, solange ein Boss lebt. Sie macht den
# wichtigsten Gegner einer Welle als eigenen Kampf lesbar, statt ihn als
# groesseren Gegner in der Masse untergehen zu lassen.
func _create_boss_bar() -> void:
	boss_bar_root = VBoxContainer.new()
	boss_bar_root.name = "BossBar"
	boss_bar_root.visible = false
	boss_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_root.add_theme_constant_override("separation", 4)
	# Gehoert an den oberen Bildschirmrand, nicht in die HUD-Leiste unten -
	# deshalb im UI-CanvasLayer statt im HUD-Control.
	boss_bar_root.anchor_left = 0.5
	boss_bar_root.anchor_right = 0.5
	boss_bar_root.anchor_top = 0.0
	boss_bar_root.anchor_bottom = 0.0
	boss_bar_root.offset_left = -BOSS_BAR_WIDTH * 0.5
	boss_bar_root.offset_right = BOSS_BAR_WIDTH * 0.5
	boss_bar_root.offset_top = BOSS_BAR_TOP_MARGIN
	boss_bar_root.offset_bottom = BOSS_BAR_TOP_MARGIN + 46.0
	# Deferred, weil der UI-CanvasLayer waehrend _ready() noch seine Kinder aufbaut.
	var host: Node = get_parent() if get_parent() else self
	host.add_child.call_deferred(boss_bar_root)

	boss_bar_label = Label.new()
	boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar_label.add_theme_font_size_override("font_size", 16)
	boss_bar_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	boss_bar_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	boss_bar_label.add_theme_constant_override("outline_size", 4)
	boss_bar_root.add_child(boss_bar_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(BOSS_BAR_WIDTH, 18)
	boss_bar.show_percentage = false
	boss_bar.max_value = 1.0
	_style_arcane_progress_bar(boss_bar, Color(0.85, 0.25, 0.2))
	boss_bar_root.add_child(boss_bar)


func show_boss_bar(boss: Node2D) -> void:
	if not boss_bar_root or not is_instance_valid(boss):
		return
	tracked_boss = boss
	boss_bar_label.text = "BOSS"
	boss_bar.value = 1.0
	boss_bar_root.visible = true
	boss_bar_root.modulate.a = 0.0
	var tween := boss_bar_root.create_tween()
	tween.tween_property(boss_bar_root, "modulate:a", 1.0, 0.25)


func _update_boss_bar() -> void:
	if not boss_bar_root or not boss_bar_root.visible:
		return

	# Ein toter Boss gibt die Leiste an den naechsten weiter; ab Welle 10 spawnen mehrere.
	if not _is_living_boss(tracked_boss):
		var bosses := _living_bosses()
		if bosses.is_empty():
			boss_bar_root.visible = false
			tracked_boss = null
			return
		tracked_boss = bosses[0]

	var max_health: float = maxf(1.0, float(tracked_boss.max_health))
	boss_bar.value = clampf(float(tracked_boss.health) / max_health, 0.0, 1.0)

	var boss_count := _living_bosses().size()
	boss_bar_label.text = "BOSS" if boss_count <= 1 else "BOSS  (%d)" % boss_count


# Bewusst untypisiert: die Referenz kann bereits freigegeben sein, und ein
# typisierter Parameter wuerde beim Uebergeben genau daran scheitern.
func _is_living_boss(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	return enemy.get("enemy_type") == "boss" and float(enemy.health) > 0.0


func _living_bosses() -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _is_living_boss(enemy):
			result.append(enemy)
	return result


func _style_arcane_progress_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.03, 0.06, 0.9)
	background.set_corner_radius_all(4)
	var fill: StyleBoxFlat = background.duplicate()
	fill.bg_color = color
	fill.shadow_color = Color(color.r, color.g, color.b, 0.35)
	fill.shadow_size = 3
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


func _style_progression_button(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)


func _get_or_create_label(node_name: String, default_pos: Vector2) -> Label:
	var label: Label = bottom_strip.get_node_or_null(node_name) as Label
	if not label:
		label = Label.new()
		label.name = node_name
		label.position = default_pos
		bottom_strip.add_child(label)
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
	var btn: Button = bottom_strip.get_node_or_null(node_name) as Button
	if not btn:
		btn = Button.new()
		btn.name = node_name
		btn.position = default_pos
		btn.custom_minimum_size = default_size
		bottom_strip.add_child(btn)
	return btn


func _get_or_create_control(node_name: String, default_pos: Vector2, default_size: Vector2) -> Control:
	var c: Control = bottom_strip.get_node_or_null(node_name) as Control
	if not c:
		c = Control.new()
		c.name = node_name
		c.position = default_pos
		c.custom_minimum_size = default_size
		c.size = default_size
		bottom_strip.add_child(c)
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
	if gold_label:
		gold_label.add_theme_font_size_override("normal_font_size", 16)

	if bonus_preview_label:
		bonus_preview_label.add_theme_font_size_override("font_size", 16)
		bonus_preview_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		bonus_preview_label.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.0))
		bonus_preview_label.add_theme_constant_override("outline_size", 2)
	if enemies_label:
		enemies_label.add_theme_font_size_override("font_size", 16)

	if cores_label:
		cores_label.add_theme_font_size_override("font_size", 16)
		cores_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))

	if current_wave_info_label:
		current_wave_info_label.add_theme_font_size_override("font_size", 16)
		current_wave_info_label.text = "AKTUELL"
		current_wave_info_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))

	if current_wave_element_area:
		current_wave_element_area.visible = true
		current_wave_element_area.mouse_filter = Control.MOUSE_FILTER_STOP

	if current_wave_element_label:
		current_wave_element_label.text = "—"
		current_wave_element_label.add_theme_font_size_override("font_size", 16)
		current_wave_element_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.7))

	if wave_preview_label:
		wave_preview_label.add_theme_font_size_override("normal_font_size", 16)
		wave_preview_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.98))
		wave_preview_label.mouse_filter = Control.MOUSE_FILTER_STOP

	if wave_element_area:
		wave_element_area.visible = false
		wave_element_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if wave_element_label:
		wave_element_label.add_theme_font_size_override("font_size", 16)


	if supply_label:
		supply_label.add_theme_font_size_override("font_size", 16)
		supply_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))

	if blocked_warning_label:
		blocked_warning_label.add_theme_font_size_override("font_size", 16)
		blocked_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		blocked_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		blocked_warning_label.add_theme_constant_override("outline_size", 2)
		blocked_warning_label.visible = false

	if wave_events_label:
		wave_events_label.add_theme_font_size_override("normal_font_size", 16)
		wave_events_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))

	if wave_advice_label:
		wave_advice_label.add_theme_font_size_override("normal_font_size", 16)

	if inventory_button:
		inventory_button.icon = IconSystem.get_texture("inventory")
		if UITheme:
			UITheme.center_button_icon(inventory_button)
		inventory_button.add_theme_constant_override("icon_max_width", 26)
		inventory_button.tooltip_text = "Inventar öffnen (I)"

		inventory_notification = Label.new()
		inventory_notification.name = "InventoryNotification"
		inventory_notification.position = Vector2(32, -5)
		inventory_notification.add_theme_font_size_override("font_size", 16)
		inventory_notification.add_theme_color_override("font_color", Color(1, 1, 1))
		inventory_notification.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.2))
		inventory_notification.add_theme_constant_override("outline_size", 3)
		inventory_notification.visible = false
		inventory_button.add_child(inventory_notification)

	if cores_button:
		core_notification = Label.new()
		core_notification.name = "CoresNotification"
		core_notification.position = Vector2(32, -5)
		core_notification.add_theme_font_size_override("font_size", 16)
		core_notification.add_theme_color_override("font_color", Color(1, 1, 1))
		core_notification.add_theme_color_override("font_outline_color", Color(0.8, 0.2, 0.2))
		core_notification.add_theme_constant_override("outline_size", 3)
		core_notification.visible = false
		cores_button.add_child(core_notification)

	if inventory_button:
		inventory_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_font_color(inventory_button)

	if cores_button:
		cores_button.text = ""
		if UITheme:
			UITheme.center_button_icon(cores_button)
		cores_button.add_theme_constant_override("icon_max_width", 30)
		var icon_path := "res://assets/elemental_symbols/four_elements.png"
		if ResourceLoader.exists(icon_path):
			cores_button.icon = load(icon_path)

	if upgrades_button:
		upgrades_button.icon = IconSystem.get_texture("upgrades")
		if UITheme:
			UITheme.center_button_icon(upgrades_button)
		upgrades_button.add_theme_constant_override("icon_max_width", 26)
		upgrades_button.tooltip_text = "Aktive Upgrades anzeigen (U)"

	if synergy_button:
		# Kein eigenes Icon-Asset vorhanden -> thematisches Glyph
		synergy_button.text = "✦"
		synergy_button.add_theme_font_size_override("font_size", 24)
		synergy_button.tooltip_text = "Meisterschaft & Synergien (Y)"

	if schedule_button:
		schedule_button.icon = IconSystem.get_texture("path")
		if UITheme:
			UITheme.center_button_icon(schedule_button)
		schedule_button.add_theme_constant_override("icon_max_width", 26)
		schedule_button.tooltip_text = "Fahrplan der kommenden Wellen (F)"

	if forge_button:
		# Kein eigenes Schmiede-Asset vorhanden -> thematisches Glyph
		forge_button.text = "⚒"
		forge_button.add_theme_font_size_override("font_size", 24)
		forge_button.tooltip_text = "Schmiede: zwei Items kombinieren"

	if tower_stats_button:
		tower_stats_button.icon = IconSystem.get_texture("damage")
		if UITheme:
			UITheme.center_button_icon(tower_stats_button)
		tower_stats_button.add_theme_constant_override("icon_max_width", 26)
		tower_stats_button.tooltip_text = "Turm-Statistik: Kills & Schaden aller Türme (T)"

	if start_button:
		start_button.text = "Nächste Welle"

	if fast_forward_button:
		fast_forward_button.text = ""
		fast_forward_button.visible = false
		if UITheme:
			UITheme.center_button_icon(fast_forward_button)
		fast_forward_button.flat = true
		_update_fast_forward_icon()
		_style_fast_forward_button()

	if start_button:
		start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_font_color(start_button)
	if cores_button:
		cores_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if upgrades_button:
		upgrades_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if schedule_button:
		schedule_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Synergie und Schmiede tragen ein Textglyph statt eines Icons - sie brauchen
	# zusaetzlich die dunkle Schriftfarbe, damit sie auf dem hellen Button lesbar sind.
	if synergy_button:
		synergy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_font_color(synergy_button)
	if forge_button:
		forge_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_font_color(forge_button)
	if tower_stats_button:
		tower_stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND



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


func _apply_button_font_color(_btn: Button) -> void:
	pass  # Buttons erben jetzt die helle Schriftfarbe aus dem globalen UI-Theme.


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
	if synergy_button:    synergy_button.pressed.connect(_on_synergy_button_pressed)
	if schedule_button:   schedule_button.pressed.connect(_on_schedule_button_pressed)
	if forge_button:      forge_button.pressed.connect(_on_forge_button_pressed)
	if tower_stats_button: tower_stats_button.pressed.connect(_on_tower_stats_button_pressed)
	if ItemSystem:
		ItemSystem.item_collected.connect(_on_item_collected)
		ItemSystem.inventory_changed.connect(_on_inventory_changed)
	if ProgressionSystem:
		ProgressionSystem.essence_changed.connect(_on_essence_changed)
		ProgressionSystem.account_progress_changed.connect(_on_account_progress_changed)
		ProgressionSystem.streak_changed.connect(_on_streak_changed)
		ProgressionSystem.milestone_reached.connect(_on_milestone_reached)
		ProgressionSystem.research_changed.connect(_on_research_changed)
		ProgressionSystem.auto_wave_changed.connect(_on_auto_wave_changed)


func _on_essence_changed(_total: int, delta: int) -> void:
	if delta > 0 and VFX and gold_label:
		var pos: Vector2 = gold_label.get_global_rect().get_center()
		VFX.spawn_pixel_burst(pos, "water", 6, _vfx_layer())
		VFX.spawn_status_text(pos, "+%d ✦" % delta, Color("75ddff"), _vfx_layer())


var _last_account_level := 0

func _on_account_progress_changed(level: int, _xp: int, _required: int) -> void:
	if level > _last_account_level and _last_account_level > 0 and VFX:
		var pos: Vector2 = get_viewport().get_visible_rect().size * 0.5
		VFX.spawn_pixel_ring(pos, "gold", 50.0, _vfx_layer())
		VFX.screen_flash(Color(1.0, 0.85, 0.4, 0.4), 0.12)
		VFX.spawn_status_text(pos, "STUFE %d ERREICHT" % level, Color("f4cf6a"), _vfx_layer())
	_last_account_level = level


# HUD-Effekte müssen im UI-CanvasLayer landen, sonst verschwinden sie hinter den Panels
func _vfx_layer() -> Node:
	return get_parent() if get_parent() is CanvasLayer else null


func _on_streak_changed(streak: int, multiplier: float, time_left: float) -> void:
	if not streak_panel:
		return
	streak_panel.visible = streak >= 2 and GameState.wave_active
	if not streak_panel.visible:
		return
	streak_label.text = "%d KILL-SERIE   ·   x%.1f GOLD" % [streak, multiplier]
	streak_bar.value = time_left
	if streak % 8 == 0 and time_left >= ProgressionSystem.STREAK_WINDOW - 0.1:
		var tween := streak_panel.create_tween()
		tween.tween_property(streak_panel, "scale", Vector2(1.08, 1.08), 0.08)
		tween.tween_property(streak_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
		if VFX:
			VFX.spawn_pixel_burst(streak_panel.get_global_rect().get_center(), "crit", 8, _vfx_layer())


func _on_milestone_reached(_wave: int, _reward: int) -> void:
	if VFX:
		var pos: Vector2 = get_viewport().get_visible_rect().size * 0.5
		VFX.spawn_pixel_burst(pos, "gold", 12, _vfx_layer())


func _on_research_changed(_research_id: String, _level: int) -> void:
	_update_progression_display()


func _on_auto_wave_changed(enabled: bool) -> void:
	if auto_wave_button:
		auto_wave_button.text = "AUTO AN" if enabled else "AUTO AUS"
	if not enabled and start_button and not GameState.wave_active:
		start_button.text = "Nächste Welle"
	_update_progression_display()


func _on_research_pressed() -> void:
	open_research_pressed.emit()


func _on_auto_wave_pressed() -> void:
	if not ProgressionSystem or not ProgressionSystem.is_automation_unlocked():
		Sound.play_error()
		return
	Sound.play_click()
	ProgressionSystem.set_auto_wave_enabled(not ProgressionSystem.auto_wave_enabled)


func _update_progression_display() -> void:
	if not ProgressionSystem:
		return
	if auto_wave_button:
		auto_wave_button.visible = ProgressionSystem.is_automation_unlocked()
		auto_wave_button.text = "AUTO AN" if ProgressionSystem.auto_wave_enabled else "AUTO AUS"


func _on_inventory_button_pressed() -> void:
	open_inventory_pressed.emit()


func _on_item_collected(item: Dictionary) -> void:
	if inventory_button:
		var tween := inventory_button.create_tween()
		tween.tween_property(inventory_button, "modulate", Color(1.5, 1.5, 0.5), 0.15)
		tween.tween_property(inventory_button, "modulate", Color.WHITE, 0.2)
	_show_item_toast(item)
	_update_inventory_notification()


func _on_element_invested(_element: String) -> void:
	_on_cores_changed(GameState.element_cores)


func _on_inventory_changed() -> void:
	_update_inventory_notification()
	_update_forge_button()


# Die Schmiede steht die ganze Bauphase ueber offen - Items, die nach der Welle
# noch am Boden lagen, lassen sich so nachtraeglich einschmelzen.
func _update_forge_button() -> void:
	if not forge_button:
		return
	var has_pair: bool = ItemSystem.has_combinable_pair() if ItemSystem else false
	forge_button.visible = not GameState.wave_active and has_pair
	forge_button.disabled = not has_pair


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
	_update_progression_display()
	_update_forge_button()


func update_blocked_towers_warning(count: int) -> void:
	_blocked_tower_count = count

	if not blocked_warning_label:
		return

	if count > 0:
		if current_wave_status_row:
			current_wave_status_row.visible = false
		blocked_warning_label.visible = true
		blocked_warning_label.text = "⚠ %d Türme blockieren den Pfad" % count

		if not blocked_warning_label.has_meta("pulse_tween"):
			var tween := blocked_warning_label.create_tween().set_loops()
			tween.tween_property(blocked_warning_label, "modulate:a", 0.5, 0.4)
			tween.tween_property(blocked_warning_label, "modulate:a", 1.0, 0.4)
			blocked_warning_label.set_meta("pulse_tween", tween)

		if start_button:
			start_button.disabled = true
			start_button.text = "Türme umplatzieren!"
	else:
		if current_wave_status_row:
			current_wave_status_row.visible = true
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

	var schedule := RunSchedule.get_events(next_wave)
	if schedule.is_empty():
		wave_events_label.text = ""
		wave_events_label.visible = false
		return

	var events: Array[String] = []
	for event in schedule:
		events.append("%s %s" % [IconSystem.bb(event["icon"], 14), event["label"]])

	wave_events_label.text = "DANACH  %s" % " · ".join(events)
	wave_events_label.visible = true
	# Faerbung nach dem wichtigsten Ereignis - get_events() liefert es zuerst.
	wave_events_label.add_theme_color_override("font_color", schedule[0]["color"])


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "%s %d" % [IconSystem.bb("gold", 24), amount]
	_update_bonus_preview()


var _last_lives := -1

func _on_lives_changed(amount: int) -> void:
	if not lives_label:
		return
	if _last_lives >= 0 and amount < _last_lives and VFX:
		var pos: Vector2 = lives_label.get_global_rect().get_center()
		VFX.spawn_pixels(pos, "damage", 6, 20.0, _vfx_layer())
		var shake_tween := lives_label.create_tween()
		var base_pos: Vector2 = lives_label.position
		for i in range(3):
			shake_tween.tween_property(lives_label, "position", base_pos + Vector2(3 - i, 0), 0.03)
			shake_tween.tween_property(lives_label, "position", base_pos - Vector2(3 - i, 0), 0.03)
		shake_tween.tween_property(lives_label, "position", base_pos, 0.03)
	_last_lives = amount
	lives_label.text = "%s %d" % [IconSystem.bb("life", 22), amount]
	if amount <= 5:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif amount <= 10:
		lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lives_label.remove_theme_color_override("font_color")

	var max_lives: int = GameState.get_max_lives()
	var ratio: float = clampf(float(amount) / float(max_lives), 0.0, 1.0) if max_lives > 0 else 0.0
	if hp_bar:
		hp_bar.value = ratio
		hp_bar.add_theme_stylebox_override("fill", UI.bar(false, UI.hp_color(ratio)))
	if hp_dot:
		hp_dot.color = UI.hp_color(ratio)


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


func _on_supply_changed(_used: int, _max_supply: int) -> void:
	if not supply_label:
		return

	var info := GameState.get_supply_info()
	var used := int(info.get("used", 0))
	var effective_max := int(info.get("max", 0))
	var available := int(info.get("available", 0))
	var archive_bonus := int(info.get("archive_bonus", 0))
	var farm_bonus := int(info.get("farm_bonus", 0))
	var run_bonus := int(info.get("run_bonus", 0))

	supply_label.text = "%s %d/%d" % [IconSystem.bb("supply", 24), used, effective_max]
	var breakdown: Array[String] = ["Basis: %d" % GameState.STARTING_MAX_SUPPLY]
	if archive_bonus > 0:
		breakdown.append("Arkanes Lager: +%d" % archive_bonus)
	if farm_bonus > 0:
		breakdown.append("Farmen: +%d" % farm_bonus)
	if run_bonus > 0:
		breakdown.append("Run-Upgrades: +%d" % run_bonus)
	supply_label.tooltip_text = "Supply: %d verwendet von %d\n%d verfügbar\n%s" % [
		used, effective_max, available, "\n".join(breakdown)
	]

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
		cores_button.remove_theme_color_override("font_color")


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
		start_button.text = "WELLE %d LÄUFT" % wave

	if blocked_warning_label:
		blocked_warning_label.visible = false
	if current_wave_status_row:
		current_wave_status_row.visible = true

	if fast_forward_button:
		fast_forward_button.visible = true
	_set_fast_forward(false)
	_update_forge_button()

	call_deferred("_refresh_wave_panels_after_wave_started", wave)


func _refresh_wave_panels_after_wave_started(wave: int) -> void:
	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if wave_manager:
		_current_wave_element = wave_manager.current_wave_element
	_update_current_wave_element_display(_current_wave_element)

	if current_wave_info_label:
		current_wave_info_label.visible = true
		current_wave_info_label.text = "AKTUELL · %d" % wave

	_update_wave_preview(wave + 1)
	update_wave_events_preview(wave + 1)


func _on_wave_completed(wave: int) -> void:
	if start_button:
		if _blocked_tower_count <= 0:
			start_button.disabled = false
			start_button.text = "Nächste Welle"
		else:
			start_button.disabled = true
			start_button.text = "Türme umplatzieren!"

	if current_wave_element_area:
		current_wave_element_area.visible = true
	if current_wave_status_row:
		current_wave_status_row.visible = true
	if current_wave_info_label:
		current_wave_info_label.visible = true
		current_wave_info_label.text = "LETZTE · %d" % wave
	if enemies_label:              enemies_label.visible              = false

	_update_bonus_preview()
	update_wave_events_preview(wave + 1)
	_update_forge_button()

	if fast_forward_button:
		fast_forward_button.visible = false
	_set_fast_forward(false)


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
		wave_label.text = "--"
		if not GameState.wave_active:
			if current_wave_info_label:
				current_wave_info_label.text = "AKTUELL"
			if current_wave_element_area:
				current_wave_element_area.visible = true
			if current_wave_element_icon:
				current_wave_element_icon.texture = null
				current_wave_element_icon.visible = false
			if current_wave_element_label:
				current_wave_element_label.text = "—"
				current_wave_element_label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.7))
	else:
		wave_label.text = "%d" % GameState.current_wave


func _update_current_wave_element_display(wave_elem: String) -> void:
	if not current_wave_element_area or not current_wave_element_icon or not current_wave_element_label:
		return

	if current_wave_info_label:
		current_wave_info_label.visible = true
		current_wave_info_label.text = "AKTUELL · %d" % GameState.current_wave

	wave_elem = String(wave_elem).to_lower()
	current_wave_element_area.visible = true

	if wave_elem == "neutral" or wave_elem == "":
		current_wave_element_icon.texture = null
		current_wave_element_icon.visible = false
		current_wave_element_label.text = "NEUTRAL"
		current_wave_element_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		if element_textures.has(wave_elem):
			current_wave_element_icon.texture = element_textures[wave_elem]
			current_wave_element_icon.visible = true
		else:
			current_wave_element_icon.texture = null
			current_wave_element_icon.visible = false

		current_wave_element_label.text = wave_elem.to_upper()
		var elem_color := ElementalSystem.get_element_color(wave_elem) if ElementalSystem else Color.WHITE
		current_wave_element_label.add_theme_color_override("font_color", elem_color)


func _update_wave_preview(next_wave: int) -> void:
	if not wave_preview_label:
		return

	wave_preview_label.visible = true

	var wave_manager := get_node_or_null("/root/Main/WaveManager") as WaveManager
	if not wave_manager:
		if next_wave_title_label:
			next_wave_title_label.text = "NÄCHSTE WELLE"
		wave_preview_label.text = "BEREIT"
		if wave_advice_label:
			wave_advice_label.text = "[color=#7d8b99]Vorschau wird vorbereitet[/color]"
		_next_wave_element = "neutral"
		_next_wave_preview = {}
		return

	var info      := wave_manager.get_wave_info(next_wave)
	var preview   := wave_manager.get_wave_preview(next_wave)
	var wave_elem : String = String(preview.get("wave_element", "neutral")).to_lower()

	_next_wave_element = wave_elem
	_next_wave_preview = preview
	if next_wave_title_label:
		next_wave_title_label.text = "NÄCHSTE WELLE · %d" % next_wave

	var boss_badge := ""
	if next_wave % 5 == 0:
		boss_badge = "  [color=#ffaa44]· BOSS-WELLE[/color]"

	wave_preview_label.bbcode_enabled = true
	wave_preview_label.text = "%s%s" % [info, boss_badge]
	_update_wave_advice(preview, wave_elem)


func _update_wave_advice(preview: Dictionary, wave_elem: String) -> void:
	if not wave_advice_label:
		return

	wave_elem = wave_elem.to_lower()
	var element_line := "[color=#718293]ELEMENT[/color]  [color=#c2c8ce]NEUTRAL[/color]"
	if wave_elem != "" and wave_elem != "neutral":
		var element_color := "#ffffff"
		if ElementalSystem:
			element_color = "#%s" % ElementalSystem.get_element_color(wave_elem).to_html(false)
		var weak_element := ""
		var resisted_element := ""
		if ElementalSystem:
			weak_element = String(ElementalSystem.get_effective_element(wave_elem)).to_upper()
			resisted_element = String(ElementalSystem.RESISTANCES.get(wave_elem, "")).to_upper()
		element_line = "[color=#718293]ELEMENT[/color]  [color=%s]%s[/color]" % [element_color, wave_elem.to_upper()]
		if weak_element != "" and weak_element != "NEUTRAL":
			element_line += "   [color=#65d879]SCHWACH[/color] %s" % weak_element
		if resisted_element != "":
			element_line += "   [color=#e06b6b]RESISTIERT[/color] %s" % resisted_element

	var recommended: Array[String] = []
	var ineffective: Array[String] = []
	for enemy_type in ENEMY_TYPE_INFO:
		if int(preview.get(enemy_type, 0)) <= 0:
			continue
		var type_info: Dictionary = ENEMY_TYPE_INFO[enemy_type]
		var recommended_name := String(TOWER_SHORT_NAMES.get(type_info["weak"], type_info["weak"]))
		var ineffective_name := String(TOWER_SHORT_NAMES.get(type_info["resist"], type_info["resist"]))
		if not recommended.has(recommended_name):
			recommended.append(recommended_name)
		if not ineffective.has(ineffective_name):
			ineffective.append(ineffective_name)

	var tower_line := "[color=#718293]TURM-TIPP[/color]  Keine besonderen Konter"
	if not recommended.is_empty() or not ineffective.is_empty():
		tower_line = "[color=#718293]TURM-TIPP[/color]"
		if not recommended.is_empty():
			tower_line += "  [color=#65d879]▲[/color] %s" % ", ".join(recommended)
		if not ineffective.is_empty():
			tower_line += "   [color=#e06b6b]▼[/color] %s" % ", ".join(ineffective)

	wave_advice_label.text = "%s\n%s" % [element_line, tower_line]


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
	wave_tooltip_title.add_theme_font_size_override("font_size", 16)
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
	wk_title.add_theme_font_size_override("font_size", 16)
	wk_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vb.add_child(wk_title)

	# --- Container für dynamische Gegner-Zeilen ---
	var wk_container := VBoxContainer.new()
	wk_container.name = "WeaknessContainer"
	wk_container.add_theme_constant_override("separation", 2)
	vb.add_child(wk_container)


func _connect_tooltip_hover_area() -> void:
	if current_wave_element_area:
		current_wave_element_area.mouse_entered.connect(_on_wave_element_hover_enter.bind("current"))
		current_wave_element_area.mouse_exited.connect(_on_wave_element_hover_exit)
	if wave_preview_label:
		wave_preview_label.mouse_entered.connect(_on_wave_element_hover_enter.bind("next"))
		wave_preview_label.mouse_exited.connect(_on_wave_element_hover_exit)
	if wave_advice_label:
		wave_advice_label.mouse_entered.connect(_on_wave_element_hover_enter.bind("next"))
		wave_advice_label.mouse_exited.connect(_on_wave_element_hover_exit)


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
		hover_area   = wave_preview_label
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
			name_lbl.add_theme_font_size_override("font_size", 16)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			row.add_child(name_lbl)

			var weak_lbl := Label.new()
			weak_lbl.text = "▲ " + TOWER_NAMES.get(info["weak"], info["weak"])
			weak_lbl.add_theme_font_size_override("font_size", 16)
			weak_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
			row.add_child(weak_lbl)

			var resist_lbl := Label.new()
			resist_lbl.text = "▼ " + TOWER_NAMES.get(info["resist"], info["resist"])
			resist_lbl.add_theme_font_size_override("font_size", 16)
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

func show_game_over(summary: Dictionary = {}) -> void:
	show_run_summary(summary, false)


# Nach der letzten regulaeren Welle: weiterspielen oder sauber abschliessen.
# Pausiert das Spiel, bis eine der beiden Optionen gewaehlt wurde.
func show_final_wave_choice(on_endless: Callable, on_finish: Callable) -> void:
	_set_fast_forward(false)
	_hide_wave_tooltip()

	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "FinalWaveChoiceLayer"
	overlay_layer.layer = 235
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.07, 0.85)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(center)

	var choice_panel := PanelContainer.new()
	choice_panel.custom_minimum_size = Vector2(600, 340)
	center.add_child(choice_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UI.SP_5)
	margin.add_theme_constant_override("margin_right", UI.SP_5)
	margin.add_theme_constant_override("margin_top", UI.SP_5)
	margin.add_theme_constant_override("margin_bottom", UI.SP_5)
	choice_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = "WELLE %d GESCHAFFT" % RunSchedule.FINAL_WAVE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(480, 32)
	title.custom_minimum_size.y = 58
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)

	var text := Label.new()
	text.text = "Der reguläre Run ist damit gewonnen.\nWeiterspielen oder jetzt abschließen und auszahlen lassen?"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_constant_override("line_spacing", 6)
	box.add_child(text)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)

	var endless_btn := Button.new()
	endless_btn.text = "ENDLOS WEITER"
	endless_btn.custom_minimum_size = Vector2(210, 50)
	endless_btn.tooltip_text = "Die Wellen laufen weiter. Der Run endet erst, wenn die Bastion fällt."
	buttons.add_child(endless_btn)

	var finish_btn := Button.new()
	finish_btn.text = "RUN BEENDEN"
	finish_btn.custom_minimum_size = Vector2(210, 50)
	finish_btn.tooltip_text = "Schließt den Run als Sieg ab und zahlt Aether und Archiv-XP aus."
	finish_btn.theme_type_variation = &"SecondaryButton"
	buttons.add_child(finish_btn)

	for button in [endless_btn, finish_btn]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 16)

	var close_and_call := func(callback: Callable) -> void:
		Sound.play_click()
		overlay_layer.queue_free()
		get_tree().paused = false
		callback.call()

	endless_btn.pressed.connect(close_and_call.bind(on_endless))
	finish_btn.pressed.connect(close_and_call.bind(on_finish))

	get_tree().paused = true

	choice_panel.modulate.a = 0.0
	choice_panel.scale = Vector2(0.9, 0.9)
	var tween := choice_panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(choice_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(choice_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Abschluss-Bildschirm eines Runs. Niederlage und Sieg teilen sich denselben
# Aufbau - nur Titel und Rahmenfarbe unterscheiden sich.
func show_run_summary(summary: Dictionary = {}, is_victory: bool = false) -> void:
	_set_fast_forward(false)
	_hide_wave_tooltip()
	if streak_panel: streak_panel.visible = false

	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "RunSummaryLayer"
	overlay_layer.layer = 240
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.07, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(center)
	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(650, 480)
	center.add_child(summary_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UI.SP_5)
	margin.add_theme_constant_override("margin_right", UI.SP_5)
	margin.add_theme_constant_override("margin_top", UI.SP_5)
	margin.add_theme_constant_override("margin_bottom", UI.SP_5)
	summary_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "BASTION GEHALTEN" if is_victory else "DIE BASTION IST GEFALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(520, 32)
	title.custom_minimum_size.y = 58
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	var wave_result := Label.new()
	wave_result.text = "WELLE %d" % GameState.current_wave
	wave_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_result.add_theme_font_size_override("font_size", 48)
	wave_result.add_theme_color_override("font_color", UI.ACCENT)
	box.add_child(wave_result)

	var payout_panel := PanelContainer.new()
	box.add_child(payout_panel)
	var payout := Label.new()
	payout.text = "+%d AETHER   ·   +%d ARCHIV-XP" % [
		int(summary.get("run_essence", 0)), int(summary.get("run_xp", 0))
	]
	payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	payout.custom_minimum_size.y = 62
	payout.add_theme_font_size_override("font_size", 20)
	payout.add_theme_color_override("font_color", UI.ACCENT)
	payout_panel.add_child(payout)

	var detail := Label.new()
	detail.text = "Gegner besiegt: %d\nHöchste Kill-Serie: %d\nElement-Kerne investiert: %d/%d\nArchiv-Stufe: %d   ·   Aether gesamt: %d" % [
		int(summary.get("kills", GameState.stats.get("enemies_killed", 0))),
		int(summary.get("max_streak", 0)),
		TowerData.get_total_cores_invested(),
		TowerData.UNLOCKABLE_ELEMENTS.size() * TowerData.MAX_ELEMENT_LEVEL,
		int(summary.get("account_level", 1)),
		int(summary.get("essence_total", 0))
	]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_constant_override("line_spacing", 6)
	box.add_child(detail)

	var hint := Label.new()
	hint.text = "Welle %d überstanden. Investiere Aether im Archiv und starte dauerhaft stärker." % RunSchedule.FINAL_WAVE \
		if is_victory else "Investiere Aether im Archiv und starte dauerhaft stärker."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("554731"))
	box.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var archive_btn := Button.new()
	archive_btn.text = "ARKANES ARCHIV"
	archive_btn.custom_minimum_size = Vector2(180, 46)
	archive_btn.pressed.connect(_on_research_pressed)
	archive_btn.theme_type_variation = &"SecondaryButton"
	buttons.add_child(archive_btn)
	var restart_btn := Button.new()
	restart_btn.text = "NEUER RUN"
	restart_btn.custom_minimum_size = Vector2(160, 46)
	restart_btn.pressed.connect(_on_restart_pressed)
	buttons.add_child(restart_btn)
	var menu_btn := Button.new()
	menu_btn.text = "HAUPTMENÜ"
	menu_btn.custom_minimum_size = Vector2(150, 46)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	buttons.add_child(menu_btn)
	for button in [archive_btn, restart_btn]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 16)
	menu_btn.theme_type_variation = &"DangerButton"
	menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_btn.add_theme_font_size_override("font_size", 16)

	summary_panel.modulate.a = 0.0
	summary_panel.scale = Vector2(0.9, 0.9)
	var tween := summary_panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(summary_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(summary_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_button_pressed() -> void:
	start_wave_pressed.emit()


func _on_cores_button_pressed() -> void:
	open_element_panel_pressed.emit()


func _on_upgrades_button_pressed() -> void:
	open_upgrades_panel_pressed.emit()


func _on_synergy_button_pressed() -> void:
	open_synergy_panel_pressed.emit()


func _on_schedule_button_pressed() -> void:
	open_schedule_pressed.emit()


func _on_forge_button_pressed() -> void:
	open_forge_pressed.emit()


func _on_tower_stats_button_pressed() -> void:
	open_tower_stats_pressed.emit()


func _on_fast_forward_pressed() -> void:
	Sound.play_click()
	_set_fast_forward(not is_fast_forward)


func _set_fast_forward(enabled: bool) -> void:
	is_fast_forward = enabled
	_update_fast_forward_icon()
	var fast_speed := ProgressionSystem.get_max_time_scale() if ProgressionSystem else FAST_FORWARD_SPEED
	Engine.time_scale = fast_speed if enabled else 1.0
	if fast_forward_button:
		fast_forward_button.tooltip_text = "Spieltempo: x%.1f" % fast_speed


func show_auto_wave_countdown(seconds: int) -> void:
	if start_button and not GameState.wave_active:
		start_button.text = "Auto in %d ..." % seconds


func _on_restart_pressed() -> void:
	GameState.reset()
	if ProgressionSystem:
		ProgressionSystem.begin_run()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
