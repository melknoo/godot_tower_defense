# ui/ability_upgrade_ui.gd
# UI für Ability-Upgrades nach bestimmten Wellen
extends CanvasLayer

signal upgrade_selected(choice: Dictionary)
signal panel_closed

var panel: PanelContainer
var choices_container: HBoxContainer
var current_choices: Array[Dictionary] = []
var equipped_display: HBoxContainer

# Styles
var panel_style: StyleBoxFlat
var choice_normal_style: StyleBoxFlat
var choice_hover_style: StyleBoxFlat
var new_ability_style: StyleBoxFlat
var upgrade_style: StyleBoxFlat


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # Wichtig für pausiertes Spiel!
	_create_styles()
	_create_ui()
	hide_panel()


func _create_styles() -> void:
	panel_style = UI.panel()

	choice_normal_style = StyleBoxFlat.new()
	choice_normal_style.bg_color = UI.BG_2
	choice_normal_style.border_color = UI.BORDER_SOFT
	choice_normal_style.set_border_width_all(UI.BW_PANEL)
	choice_normal_style.set_corner_radius_all(UI.RADIUS)
	choice_normal_style.set_content_margin_all(UI.SP_4)

	choice_hover_style = StyleBoxFlat.new()
	choice_hover_style.bg_color = UI.BG_2
	choice_hover_style.border_color = UI.BORDER_FOCUS
	choice_hover_style.set_border_width_all(UI.BW_PANEL)
	choice_hover_style.set_corner_radius_all(UI.RADIUS)
	choice_hover_style.set_content_margin_all(UI.SP_4)

	new_ability_style = StyleBoxFlat.new()
	new_ability_style.bg_color = UI.BG_2
	new_ability_style.border_color = UI.SUCCESS
	new_ability_style.set_border_width_all(UI.BW_PANEL)
	new_ability_style.set_corner_radius_all(UI.RADIUS)
	new_ability_style.set_content_margin_all(UI.SP_4)

	upgrade_style = StyleBoxFlat.new()
	upgrade_style.bg_color = UI.BG_2
	upgrade_style.border_color = UI.ACCENT
	upgrade_style.set_border_width_all(UI.BW_PANEL)
	upgrade_style.set_corner_radius_all(UI.RADIUS)
	upgrade_style.set_content_margin_all(UI.SP_4)


func _create_ui() -> void:
	# Dimmed Background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Center Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main Panel
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	# Titel
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.text = "[center]%s ABILITY UPGRADE %s[/center]" % [_get_icon_bb("ability_lightning", 28), _get_icon_bb("ability_lightning", 28)]
	title.add_theme_font_size_override("normal_font_size", 32)
	title.add_theme_color_override("default_color", UI.ACCENT)
	vbox.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Wähle eine Verbesserung für deine Abilities"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", UI.TEXT_SECOND)
	vbox.add_child(subtitle)
	
	# Aktuelle Abilities anzeigen
	var equipped_label := Label.new()
	equipped_label.text = "Aktuelle Abilities:"
	equipped_label.add_theme_font_size_override("font_size", 16)
	equipped_label.add_theme_color_override("font_color", UI.TEXT_SECOND)
	vbox.add_child(equipped_label)
	
	equipped_display = HBoxContainer.new()
	equipped_display.add_theme_constant_override("separation", 10)
	equipped_display.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(equipped_display)
	
	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)
	
	# Choices Container
	choices_container = HBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 20)
	choices_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(choices_container)
	
	# Skip Button Container
	var skip_container := CenterContainer.new()
	skip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skip_container)
	
	var skip_btn := Button.new()
	skip_btn.theme_type_variation = &"SecondaryButton"
	skip_btn.text = "Überspringen"
	skip_btn.custom_minimum_size = Vector2(150, 40)
	skip_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.add_theme_stylebox_override("normal", choice_normal_style)
	skip_btn.add_theme_stylebox_override("hover", choice_hover_style)
	skip_btn.pressed.connect(_on_skip_pressed)
	skip_container.add_child(skip_btn)


func show_panel() -> void:
	if not AbilitySystem:
		return
	
	current_choices = AbilitySystem.generate_ability_upgrade_choices(3)
	_update_equipped_display()
	_update_choices_display()
	visible = true

	# Spiel pausieren
	get_tree().paused = true

	if UITheme:
		UITheme.animate_panel_open(panel)


func hide_panel() -> void:
	visible = false
	get_tree().paused = false
	panel_closed.emit()


func _update_equipped_display() -> void:
	for child in equipped_display.get_children():
		child.queue_free()
	
	if not AbilitySystem:
		return
	
	var equipped := AbilitySystem.get_equipped_abilities()
	
	for i in range(AbilitySystem.MAX_ABILITY_SLOTS):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(80, 80)
		
		var style := StyleBoxFlat.new()
		if i < equipped.size():
			var ability_data: Dictionary = AbilitySystem.get_ability_data(equipped[i])
			var element: String = ability_data.get("element", "")
			style.bg_color = _get_element_bg_color(element)
			style.border_color = _get_element_color(element)
		else:
			style.bg_color = Color(0.1, 0.1, 0.1)
			style.border_color = Color(0.25, 0.25, 0.25)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)
		
		var slot_vbox := VBoxContainer.new()
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_panel.add_child(slot_vbox)
		
		if i < equipped.size():
			var ability_data: Dictionary = AbilitySystem.get_ability_data(equipped[i])
			var element: String = ability_data.get("element", "")
			
			# Icon
			var icon_label := RichTextLabel.new()
			icon_label.bbcode_enabled = true
			icon_label.fit_content = true
			icon_label.scroll_active = false
			icon_label.text = "[center]%s[/center]" % _get_element_icon_bb(element, 32)
			slot_vbox.add_child(icon_label)
			
			# Name
			var name_label := Label.new()
			name_label.text = ability_data.get("name", equipped[i])
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			slot_vbox.add_child(name_label)
			
			# Upgrade-Sterne anzeigen
			var total_upgrades: int = AbilitySystem.get_total_upgrade_stacks(equipped[i])
			if total_upgrades > 0:
				var stars := Label.new()
				var star_count: int = mini(total_upgrades, 5)
				stars.text = ""
				for _j in range(star_count):
					stars.text += "★"
				stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				stars.add_theme_font_size_override("font_size", 16)
				stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				slot_vbox.add_child(stars)
		else:
			var slot_label := Label.new()
			slot_label.text = str(i + 1)
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot_label.add_theme_font_size_override("font_size", 20)
			slot_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
			slot_vbox.add_child(slot_label)
		
		equipped_display.add_child(slot_panel)


func _update_choices_display() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	
	for i in range(current_choices.size()):
		var choice: Dictionary = current_choices[i]
		var choice_panel := _create_choice_panel(choice, i)
		choices_container.add_child(choice_panel)


func _create_choice_panel(choice: Dictionary, index: int) -> PanelContainer:
	var panel_node := PanelContainer.new()
	panel_node.custom_minimum_size = Vector2(200, 220)
	
	var choice_type: String = choice.get("type", "")
	var is_new_ability: bool = choice_type == "new_ability"
	var base_style: StyleBoxFlat = new_ability_style if is_new_ability else upgrade_style
	panel_node.add_theme_stylebox_override("panel", base_style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_node.add_child(vbox)
	
	if is_new_ability:
		_populate_new_ability_choice(vbox, choice)
	else:
		_populate_upgrade_choice(vbox, choice)
	
	# Klick-Handler - muss PROCESS_MODE_ALWAYS haben für Pause!
	var btn := Button.new()
	btn.flat = true
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_choice_selected.bind(index))
	btn.mouse_entered.connect(_on_choice_hover.bind(panel_node, true, is_new_ability))
	btn.mouse_exited.connect(_on_choice_hover.bind(panel_node, false, is_new_ability))
	panel_node.add_child(btn)
	
	return panel_node


func _populate_new_ability_choice(vbox: VBoxContainer, choice: Dictionary) -> void:
	var ability_data: Dictionary = choice.get("data", {})
	var element: String = ability_data.get("element", "")
	
	# Header
	var header := Label.new()
	header.text = "NEUE ABILITY"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", UI.SUCCESS)
	vbox.add_child(header)
	
	# Element Icon
	var icon := RichTextLabel.new()
	icon.bbcode_enabled = true
	icon.fit_content = true
	icon.scroll_active = false
	icon.text = "[center]%s[/center]" % _get_element_icon_bb(element, 40)
	vbox.add_child(icon)
	
	# Name
	var name_label := Label.new()
	name_label.text = ability_data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", _get_element_color(element))
	vbox.add_child(name_label)
	
	# Beschreibung
	var desc := Label.new()
	desc.text = ability_data.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", UI.TEXT_SECOND)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 180
	vbox.add_child(desc)
	
	# Cooldown Info
	var cooldown: float = ability_data.get("cooldown", 10.0)
	var cd_label := RichTextLabel.new()
	cd_label.bbcode_enabled = true
	cd_label.fit_content = true
	cd_label.scroll_active = false
	cd_label.text = "[center]%s %.1fs Cooldown[/center]" % [_get_icon_bb("cooldown", 14), cooldown]
	cd_label.add_theme_font_size_override("normal_font_size", 16)
	cd_label.add_theme_color_override("default_color", UI.TEXT_SECOND)
	vbox.add_child(cd_label)


func _populate_upgrade_choice(vbox: VBoxContainer, choice: Dictionary) -> void:
	var ability_id: String = choice.get("ability_id", "")
	var stat: String = choice.get("stat", "")
	var current_stacks: int = choice.get("current_stacks", 0)
	var upgrade_info: Dictionary = choice.get("upgrade_info", {})
	
	var ability_data: Dictionary = {}
	if AbilitySystem:
		ability_data = AbilitySystem.get_ability_data(ability_id)
	var element: String = ability_data.get("element", "")
	
	# Header
	var header := Label.new()
	header.text = "UPGRADE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", UI.ACCENT)
	vbox.add_child(header)
	
	# Element Icon
	var icon := RichTextLabel.new()
	icon.bbcode_enabled = true
	icon.fit_content = true
	icon.scroll_active = false
	icon.text = "[center]%s[/center]" % _get_element_icon_bb(element, 32)
	vbox.add_child(icon)
	
	# Ability Name
	var name_label := Label.new()
	name_label.text = ability_data.get("name", ability_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _get_element_color(element))
	vbox.add_child(name_label)
	
	# Upgrade-Effekt
	var effect := Label.new()
	effect.text = upgrade_info.get("display", stat)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.add_theme_font_size_override("font_size", 16)
	effect.add_theme_color_override("font_color", UI.ACCENT)
	vbox.add_child(effect)
	
	# Aktueller Fortschritt
	var progress := Label.new()
	progress.text = "Level: %d → %d" % [current_stacks, current_stacks + 1]
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", UI.TEXT_SECOND)
	vbox.add_child(progress)
	
	# Sterne für visuellen Fortschritt
	var stars_container := HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stars_container)
	
	var max_stacks: int = AbilitySystem.MAX_UPGRADE_STACKS if AbilitySystem else 5
	for i in range(max_stacks):
		var star := Label.new()
		if i < current_stacks:
			star.text = "★"
			star.add_theme_color_override("font_color", UI.ACCENT)
		elif i == current_stacks:
			star.text = "★"
			star.add_theme_color_override("font_color", UI.SUCCESS)
		else:
			star.text = "☆"
			star.add_theme_color_override("font_color", UI.TEXT_DISABLED)
		star.add_theme_font_size_override("font_size", 16)
		stars_container.add_child(star)


func _on_choice_hover(panel_node: PanelContainer, hovering: bool, is_new: bool) -> void:
	if hovering:
		var hover_style: StyleBoxFlat = new_ability_style.duplicate() if is_new else upgrade_style.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		hover_style.border_color = hover_style.border_color.lightened(0.2)
		panel_node.add_theme_stylebox_override("panel", hover_style)
	else:
		var base_style: StyleBoxFlat = new_ability_style if is_new else upgrade_style
		panel_node.add_theme_stylebox_override("panel", base_style)


func _on_choice_selected(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	
	var choice: Dictionary = current_choices[index]
	
	if AbilitySystem:
		var choice_type: String = choice.get("type", "")
		if choice_type == "new_ability":
			var ability_id: String = choice.get("ability_id", "")
			AbilitySystem.add_ability_to_slot(ability_id)
		else:
			var ability_id: String = choice.get("ability_id", "")
			var stat: String = choice.get("stat", "")
			AbilitySystem.upgrade_ability_stat(ability_id, stat)
	
	if Sound:
		Sound.play_confirm()
	
	upgrade_selected.emit(choice)
	hide_panel()


func _on_skip_pressed() -> void:
	if Sound:
		Sound.play_click()
	hide_panel()


# === ICON HELPER ===

func _get_icon_bb(icon_name: String, size: int = 16) -> String:
	if IconSystem:
		return IconSystem.bb(icon_name, size)
	return ""


func _get_element_icon_bb(element: String, size: int = 16) -> String:
	if IconSystem:
		return IconSystem.bb(element, size)
	# Fallback falls kein IconSystem
	return "[color=%s]●[/color]" % _get_element_color(element).to_html()


func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.5, 0.3)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.7, 0.5, 0.3)
		"air": return Color(0.8, 0.9, 1.0)
		_: return Color.WHITE


func _get_element_bg_color(element: String) -> Color:
	return _get_element_color(element) * 0.2


# === INPUT ===

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if current_choices.size() > 0:
					_on_choice_selected(0)
			KEY_2:
				if current_choices.size() > 1:
					_on_choice_selected(1)
			KEY_3:
				if current_choices.size() > 2:
					_on_choice_selected(2)
			KEY_ESCAPE:
				_on_skip_pressed()
