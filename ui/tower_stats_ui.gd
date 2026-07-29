# ui/tower_stats_ui.gd
# Kills und Schaden aller platzierten Tuerme in einer Liste. Frueher stand die
# Kampfstatistik in jedem Turm-Panel einzeln - wer den staerksten Turm finden
# wollte, musste jeden anklicken. Hier stehen sie nebeneinander, und wer eine
# Zeile hovert, sieht den zugehoerigen Turm auf dem Spielfeld leuchten.
extends CanvasLayer
class_name TowerStatsUI

signal panel_closed

var panel: PanelContainer
var side_holder: CenterContainer
var title_label: Label
var count_label: Label
var scroll_container: ScrollContainer
var rows_container: VBoxContainer
var empty_label: Label
var close_button: Button

var tower_manager: TowerManager = null
var _highlighted_tower: Node2D = null

const ROW_BG := Color(0.15, 0.15, 0.18, 0.6)
const ROW_BG_HOVER := Color(0.28, 0.24, 0.18, 0.9)

# Das Panel sitzt am rechten Rand statt in der Bildmitte und faehrt von dort ein:
# mittig verdeckte es das halbe Spielfeld, waehrend man die Zahlen mit dem Aufbau
# vergleichen will. Der Hintergrund dimmt nur leicht, damit die Karte lesbar bleibt.
const PANEL_SIZE := Vector2(560, 460)
const SIDE_MARGIN := 16.0

# Waehrend einer Welle wachsen Kills und Schaden weiter - regelmaessig nachziehen.
const REFRESH_INTERVAL := 0.5
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 100
	visible = false
	_setup_ui()


func set_tower_manager(manager: TowerManager) -> void:
	tower_manager = manager


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	# Rechter Streifen in Panelbreite; der CenterContainer zentriert das Panel darin
	# vertikal. Ein- und Ausfahren laeuft ueber die Offsets dieses Halters, nicht ueber
	# `panel.position` - Container-Kinder bekommen ihre Position sonst jedes Layout
	# wieder ueberschrieben.
	side_holder = CenterContainer.new()
	side_holder.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_holder.offset_left = -(PANEL_SIZE.x + SIDE_MARGIN)
	side_holder.offset_right = -SIDE_MARGIN
	side_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_holder)

	panel = PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	side_holder.add_child(panel)

	if UITheme:
		UITheme.style_panel(panel, "carved")

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	vbox.add_child(header)

	title_label = Label.new()
	title_label.text = "Turm-Statistik"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_DARK)
	header.add_child(title_label)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color("554731"))
	header.add_child(count_label)

	var hint := Label.new()
	hint.text = "Zeile hovern → Turm leuchtet auf dem Spielfeld"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("554731"))
	vbox.add_child(hint)

	var legend := RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.scroll_active = false
	legend.custom_minimum_size.y = 16
	legend.add_theme_font_size_override("normal_font_size", 10)
	legend.add_theme_color_override("default_color", Color("554731"))
	if UITheme and UITheme.game_font:
		legend.add_theme_font_override("normal_font", UITheme.game_font)
	var legend_damage := IconSystem.bb("damage", 12) if IconSystem else ""
	var legend_kills := IconSystem.bb("star_full", 12) if IconSystem else ""
	legend.text = "[right]%s Schaden Runde/Run     %s Kills Runde/Run[/right]" % [
		legend_damage, legend_kills
	]
	vbox.add_child(legend)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color("785d32"))
	vbox.add_child(sep)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 310)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)

	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 5)
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(rows_container)

	empty_label = Label.new()
	empty_label.text = "Noch keine Türme gebaut."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", Color("554731"))
	empty_label.visible = false
	rows_container.add_child(empty_label)

	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)

	close_button = Button.new()
	close_button.text = "Schließen"
	close_button.custom_minimum_size = Vector2(120, 32)
	close_button.pressed.connect(_on_close_pressed)
	btn_center.add_child(close_button)

	if UITheme:
		UITheme.style_button(close_button)
	close_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))

	for label in [title_label, count_label, hint, empty_label]:
		if UITheme and UITheme.game_font:
			label.add_theme_font_override("font", UITheme.game_font)


func show_panel() -> void:
	Sound.play_click()
	_refresh_rows()
	visible = true

	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE
	_set_slide_offset(PANEL_SIZE.x + SIDE_MARGIN)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_method(_set_slide_offset, PANEL_SIZE.x + SIDE_MARGIN, 0.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	_clear_highlight()
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.tween_method(_set_slide_offset, 0.0, PANEL_SIZE.x + SIDE_MARGIN, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): visible = false)
	panel_closed.emit()


# 0 = eingefahren (Panel am rechten Rand), PANEL_SIZE.x + SIDE_MARGIN = ganz draussen.
func _set_slide_offset(slide: float) -> void:
	if not is_instance_valid(side_holder):
		return
	side_holder.offset_left = -(PANEL_SIZE.x + SIDE_MARGIN) + slide
	side_holder.offset_right = -SIDE_MARGIN + slide


func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	for row in rows_container.get_children():
		if row.has_meta("tower"):
			_update_row_values(row as PanelContainer)


func _refresh_rows() -> void:
	for child in rows_container.get_children():
		if child != empty_label:
			child.queue_free()

	var towers := _collect_towers()
	empty_label.visible = towers.is_empty()
	count_label.text = "1 Turm" if towers.size() == 1 else "%d Türme" % towers.size()

	for tower in towers:
		rows_container.add_child(_create_row(tower))


# Nur angreifende Tuerme - Farmen und Staedte haben keine Kampfstatistik.
# Sortiert nach Gesamtschaden, damit die Traeger des Runs oben stehen.
func _collect_towers() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not tower_manager:
		return result

	for tower in tower_manager.get_all_towers():
		if not is_instance_valid(tower):
			continue
		if TowerData.is_supply_building(tower.tower_type):
			continue
		result.append(tower)

	result.sort_custom(func(a, b): return int(a.damage_run) > int(b.damage_run))
	return result


func _create_row(tower: Node2D) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 46
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)
	row.set_meta("style", style)
	row.set_meta("tower", tower)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = TowerData.get_tower_icon_texture(tower.tower_type)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = "%s  Lv%d" % [
		TowerData.get_tower_data(tower.tower_type).get("name", tower.tower_type.capitalize()),
		int(tower.level) + 1
	]
	name_label.custom_minimum_size.x = 150
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color("edf3ff"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var stats := RichTextLabel.new()
	row.set_meta("stats_label", stats)
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_font_size_override("normal_font_size", 11)
	stats.add_theme_color_override("default_color", Color("edf3ff"))
	box.add_child(stats)

	if UITheme and UITheme.game_font:
		name_label.add_theme_font_override("font", UITheme.game_font)
		stats.add_theme_font_override("normal_font", UITheme.game_font)

	_update_row_values(row)

	row.mouse_entered.connect(_on_row_hover.bind(row, true))
	row.mouse_exited.connect(_on_row_hover.bind(row, false))

	return row


# Nur die Zahlen einer Zeile nachziehen. Die Reihenfolge bleibt bewusst stehen,
# sonst springen die Zeilen waehrend einer Welle unter dem Mauszeiger weg.
func _update_row_values(row: PanelContainer) -> void:
	var tower: Node2D = row.get_meta("tower") as Node2D
	if not is_instance_valid(tower):
		return

	var stats: RichTextLabel = row.get_meta("stats_label")
	var damage_icon := IconSystem.bb("damage", 13) if IconSystem else ""
	var kill_icon := IconSystem.bb("star_full", 13) if IconSystem else ""
	stats.text = "%s [b]%s[/b] / %s   %s [b]%d[/b] / %d" % [
		damage_icon, _format_number(int(tower.damage_round)), _format_number(int(tower.damage_run)),
		kill_icon, int(tower.kills_round), int(tower.kills_run)
	]

	row.tooltip_text = "Schaden: %d in dieser Runde, %d im gesamten Run\nKills: %d in dieser Runde, %d im gesamten Run" % [
		int(tower.damage_round), int(tower.damage_run), int(tower.kills_round), int(tower.kills_run)
	]


func _on_row_hover(row: PanelContainer, entered: bool) -> void:
	var style: StyleBoxFlat = row.get_meta("style")
	style.bg_color = ROW_BG_HOVER if entered else ROW_BG

	if entered:
		_set_highlight(row.get_meta("tower") as Node2D)
	elif _highlighted_tower == row.get_meta("tower"):
		_clear_highlight()


func _set_highlight(tower: Node2D) -> void:
	_clear_highlight()
	if not is_instance_valid(tower) or not tower.has_method("set_highlight"):
		return
	_highlighted_tower = tower
	tower.set_highlight(true)


func _clear_highlight() -> void:
	if is_instance_valid(_highlighted_tower) and _highlighted_tower.has_method("set_highlight"):
		_highlighted_tower.set_highlight(false)
	_highlighted_tower = null


func _format_number(value: int) -> String:
	if value >= 1_000_000:
		return "%.2fM" % (float(value) / 1_000_000.0)
	if value >= 10_000:
		return "%.1fK" % (float(value) / 1_000.0)
	return str(value)


func _on_close_pressed() -> void:
	Sound.play_click()
	hide_panel()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
			hide_panel()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_T:
			hide_panel()
			get_viewport().set_input_as_handled()
