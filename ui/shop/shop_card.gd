extends PanelContainer
class_name ShopCard
## Fixe Karten-Box für die Shop-Row (Bottombar). Breite/Höhe kommen ausschließlich
## aus ui_theme.gd-Tokens, nie aus Textbreite (Phase3b_ShopRow_Konzept.md, §2/§4).

signal pressed(tower_id: String)

const RangeGridHelper = preload("res://autoload/range_grid.gd")


## Der flache Button liegt ueber der ganzen Karte und bekommt die Maus - nur er kann
## den Tooltip zeigen (die Karte selbst ist MOUSE_FILTER_IGNORE).
class CardButton extends Button:
	var tooltip_builder: Callable

	func _make_custom_tooltip(_for_text: String) -> Object:
		return tooltip_builder.call() if tooltip_builder.is_valid() else null

## Einzige Quelle der Wahrheit für die Kartengröße — Aufrufer (z.B. tower_shop.gd)
## sollen daraus ihre Scroll-/Frame-Geometrie ableiten statt die Maße zu duplizieren.
static func preferred_size() -> Vector2:
	# Breite: Pixel-Font-Namen bis ~9 Zeichen ("Aura-Turm") brauchen ~88 px Text.
	return Vector2(
		UI.SLOT_SIZE + UI.SP_4 * 2,
		UI.SLOT_SIZE + UI.SP_3 * 2 + UI.SP_1 * 2 + UI.FS_MICRO * 2
	)

var tower_id: String = ""
var _affordable := true
var _selected := false

var _button: Button
var _cost_row: HBoxContainer
var _cost_label: Label
var _coin_icon: TextureRect
var _icon_slot: Control
var _icon_rect: TextureRect
var _name_label: Label
var _description := ""


func _init() -> void:
	custom_minimum_size = preferred_size()
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UI.shop_card("normal"))

	_button = CardButton.new()
	_button.tooltip_builder = _build_tooltip
	_button.flat = true
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(func(): pressed.emit(tower_id))
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	add_child(_button)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UI.SP_1)
	margin.add_theme_constant_override("margin_right", UI.SP_1)
	margin.add_theme_constant_override("margin_top", UI.SP_3)
	margin.add_theme_constant_override("margin_bottom", UI.SP_3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UI.SP_1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_cost_row = HBoxContainer.new()
	_cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cost_row.add_theme_constant_override("separation", 2)
	_cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_cost_row)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", UI.FS_MICRO)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_row.add_child(_cost_label)

	_coin_icon = TextureRect.new()
	_coin_icon.custom_minimum_size = Vector2(16, 16)
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_tex := IconSystem.get_texture("coin") if IconSystem else null
	if coin_tex:
		_coin_icon.texture = coin_tex
	else:
		_coin_icon.visible = false
	_cost_row.add_child(_coin_icon)

	_icon_slot = Control.new()
	_icon_slot.custom_minimum_size = Vector2(UI.SLOT_SIZE, UI.SLOT_SIZE)
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_icon_slot)

	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_slot.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.custom_minimum_size.x = 0
	_name_label.add_theme_font_size_override("font_size", UI.FS_MICRO)
	_name_label.add_theme_color_override("font_color", UI.TEXT_PRIMARY)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)


## tower_data erwartet: {id, name, cost, texture, affordable}
func setup(tower_data: Dictionary) -> void:
	tower_id = tower_data.get("id", "")
	_name_label.text = tower_data.get("name", tower_id.capitalize())
	_description = tower_data.get("description", "")
	# Nicht-leerer Text ist noetig, damit Godot ueberhaupt einen Tooltip anfordert;
	# den Inhalt baut _build_tooltip().
	_button.tooltip_text = tower_data.get("name", tower_id.capitalize())

	var cost: int = tower_data.get("cost", 0)
	_cost_label.text = str(cost)

	for child in _icon_slot.get_children():
		if child != _icon_rect:
			child.queue_free()

	var texture: Texture2D = tower_data.get("texture")
	_icon_rect.texture = texture

	if not texture:
		var placeholder := ColorRect.new()
		placeholder.color = UI.BG_3
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_slot.add_child(placeholder)
		_icon_slot.move_child(placeholder, 0)

	_affordable = tower_data.get("affordable", true)
	_cost_label.add_theme_color_override("font_color", UI.TEXT_SECOND if _affordable else UI.DANGER)
	modulate.a = 1.0 if _affordable else 0.45
	_button.disabled = not _affordable

	_apply_state()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_state()


func _on_mouse_entered() -> void:
	if _affordable and not _selected:
		add_theme_stylebox_override("panel", UI.shop_card("hover"))


func _on_mouse_exited() -> void:
	_apply_state()


func _apply_state() -> void:
	if not _affordable:
		add_theme_stylebox_override("panel", UI.shop_card("disabled"))
	elif _selected:
		add_theme_stylebox_override("panel", UI.shop_card("selected"))
	else:
		add_theme_stylebox_override("panel", UI.shop_card("normal"))


func _build_tooltip() -> Control:
	var data := TowerData.get_tower_data(tower_id)
	if data.is_empty():
		return null
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.tooltip())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI.SP_1)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s  ·  %d Gold" % [data.get("name", tower_id), TowerData.get_tower_cost(tower_id)]
	title.add_theme_color_override("font_color", UI.ACCENT)
	vbox.add_child(title)

	if _description != "":
		var desc := Label.new()
		desc.text = _description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 280
		desc.add_theme_color_override("font_color", UI.TEXT_SECOND)
		vbox.add_child(desc)

	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.custom_minimum_size.x = 280
	var lines: Array[String] = []
	var damage = TowerData.get_stat(tower_id, "damage")
	if damage != null and float(damage) > 0.0:
		lines.append("%s Schaden: %d" % [_icon("damage"), int(damage)])
	var range_px = TowerData.get_stat(tower_id, "range")
	if range_px != null and float(range_px) > 0.0:
		lines.append("%s Reichweite: %d Felder" % [_icon("range"), RangeGridHelper.get_cell_radius(float(range_px))])
	var fire_rate = TowerData.get_stat(tower_id, "fire_rate")
	if fire_rate != null and float(fire_rate) > 0.0:
		lines.append("%s Angriffe/s: %.1f" % [_icon("fire_rate"), 1.0 / float(fire_rate)])
	stats.text = "\n".join(lines)
	if not lines.is_empty():
		vbox.add_child(stats)
	return panel


func _icon(icon_name: String) -> String:
	return IconSystem.bb(icon_name, 16) if IconSystem else ""
