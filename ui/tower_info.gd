# ui/tower_info.gd
# Panel für Tower-Info, Verkauf und Upgrade
# Als PanelContainer in der UI einbinden
extends PanelContainer
class_name TowerInfo

signal sell_pressed
signal upgrade_pressed
signal close_pressed

var tower_name_label: Label
var tower_level_label: Label
var stats_label: Label
var sell_button: Button
var upgrade_button: Button
var close_button: Button
var vbox: VBoxContainer

var current_tower: Node2D = null
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var tower_manager: TowerManager = null


func _ready() -> void:
	visible = false
	_setup_panel_style()
	_setup_ui()


func _setup_panel_style() -> void:
	UITheme.style_panel(self, "panel_dark")  # Name anpassen falls nötig


func _setup_ui() -> void:
	# VBox erstellen
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)
	
	# Tower Name Label
	tower_name_label = Label.new()
	tower_name_label.name = "TowerNameLabel"
	tower_name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tower_name_label)
	
	# Level Label
	tower_level_label = Label.new()
	tower_level_label.name = "TowerLevelLabel"
	tower_level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tower_level_label)
	
	# Stats Label
	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(stats_label)
	
	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Upgrade Button
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(upgrade_button)
	
	# Sell Button
	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	sell_button.pressed.connect(_on_sell_pressed)
	vbox.add_child(sell_button)
	
	# Close Button
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Schließen"
	close_button.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)
	
	UITheme.style_button(upgrade_button)
	UITheme.style_button(sell_button)
	UITheme.style_button(close_button)


func set_tower_manager(tm: TowerManager) -> void:
	tower_manager = tm


func show_tower(tower: Node2D, grid_pos: Vector2i) -> void:
	current_tower = tower
	current_grid_pos = grid_pos
	
	_update_display()
	
	# Position neben dem Tower
	var world_pos := Vector2(grid_pos) * 64 + Vector2(64 + 10, 0)
	position = world_pos
	
	# Sicherstellen dass Panel im Bildschirm bleibt
	var screen_size := get_viewport_rect().size
	if position.x + size.x > screen_size.x:
		position.x = Vector2(grid_pos).x * 64 - size.x - 10
	if position.y + size.y > screen_size.y:
		position.y = screen_size.y - size.y - 10
	
	visible = true


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
	
	# Name
	var display_name: String = data.get("name", tower_type.capitalize())
	tower_name_label.text = display_name
	
	# Level
	tower_level_label.text = "Level %d / %d" % [level + 1, TowerData.MAX_LEVEL + 1]
	
	# Stats
	var damage_val: int = TowerData.get_stat(tower_type, "damage", level)
	var range_val: float = TowerData.get_stat(tower_type, "range", level)
	var fire_rate_val: float = TowerData.get_stat(tower_type, "fire_rate", level)
	
	stats_label.text = "Schaden: %d\nReichweite: %d\nFeuerrate: %.1f/s" % [
		damage_val, int(range_val), 1.0 / fire_rate_val
	]
	tower_name_label.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	tower_level_label.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	stats_label.add_theme_color_override("font_color", Color(0.094, 0.094, 0.094, 1.0))
	
	# Upgrade Button
	_update_upgrade_button(tower_type, level)
	
	# Sell Button
	_update_sell_button()


func _update_upgrade_button(tower_type: String, level: int) -> void:
	if TowerData.can_upgrade(tower_type, level):
		var cost := TowerData.get_upgrade_cost(tower_type, level)
		upgrade_button.text = "Upgrade (%dg)" % cost
		upgrade_button.visible = true
		
		if GameState.can_afford(cost) and not GameState.wave_active:
			upgrade_button.disabled = false
			var new_damage: int = TowerData.get_stat(tower_type, "damage", level + 1)
			var new_range: float = TowerData.get_stat(tower_type, "range", level + 1)
			upgrade_button.tooltip_text = "→ Schaden: %d, Reichweite: %d" % [new_damage, int(new_range)]
		else:
			upgrade_button.disabled = true
			if GameState.wave_active:
				upgrade_button.tooltip_text = "Nicht während einer Welle"
			else:
				upgrade_button.tooltip_text = "Nicht genug Gold"
	else:
		upgrade_button.text = "Max Level"
		upgrade_button.disabled = true
		upgrade_button.visible = true


func _update_sell_button() -> void:
	var sell_value := tower_manager.get_sell_value(current_grid_pos)
	var sell_percent := tower_manager.get_sell_percent(current_grid_pos)
	
	sell_button.text = "Verkaufen: %dg (%d%%)" % [sell_value, sell_percent]
	
	if sell_percent == 100:
		sell_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		sell_button.remove_theme_color_override("font_color")


func _on_upgrade_pressed() -> void:
	upgrade_pressed.emit()


func _on_sell_pressed() -> void:
	sell_pressed.emit()


func _on_close_pressed() -> void:
	close_pressed.emit()
