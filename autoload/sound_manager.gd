# sound_manager.gd
# Autoload für alle Sound-Effekte
extends Node

# Sound Players
var sounds: Dictionary = {}

# Lautstärke-Einstellungen (in dB)
var master_volume: float = 0.0
var sfx_volume: float = 0.0

# Sound-Definitionen: Name -> {path, volume, pitch_variation}
const SOUND_DEFS := {
	"coin": {
		"path": "res://assets/sounds/coin_sound.wav",
		"volume": -5.0,
		"pitch_var": 0.05
	},
	"element_core_select": {
		"path": "res://assets/sounds/element_select.wav",
		"volume": -5.0,
		"pitch_var": 0.05
	},
	"click": {
		"path": "res://assets/sounds/click.wav",
		"volume": -5.0,
		"pitch_var": 0.05
	},
	"place": {
		"path": "res://assets/sounds/tower_place.wav",
		"volume": -3.0,
		"pitch_var": 0.05
	},
	"shoot_base": {
		"path": "res://assets/sounds/shoot_base.wav",
		"volume": -10.0,
		"pitch_var": 0.1
	},
	"hit": {
		"path": "res://assets/sounds/hit.wav",
		"volume": -8.0,
		"pitch_var": 0.1
	},
	"enemy_death": {
		"path": "res://assets/sounds/enemy_death.wav",
		"volume": -5.0,
		"pitch_var": 0.08
	},
	"upgrade": {
		"path": "res://assets/sounds/upgrade.wav",
		"volume": -3.0,
		"pitch_var": 0.03
	},
	"wave_start": {
		"path": "res://assets/sounds/wave_start.wav",
		"volume": -2.0,
		"pitch_var": 0.0
	},
	"error": {
		"path": "res://assets/sounds/error.wav",
		"volume": -5.0,
		"pitch_var": 0.0
	},
	"sell": {
		"path": "res://assets/sounds/tower_sell.wav",
		"volume": -4.0,
		"pitch_var": 0.05
	},
}

# Tower-Elemente für dynamische Shoot-Sounds
const TOWER_ELEMENTS := ["base", "sword", "water", "fire", "earth", "air", "ice", "steam", "lava", "nature"]
const MAX_TOWER_LEVEL := 3

# Shoot-Sound Einstellungen
const SHOOT_VOLUME := -10.0
const SHOOT_PITCH_VAR := 0.08

func _ready() -> void:
	_setup_sounds()
	_setup_shoot_sounds()
	print("[Sound] Manager geladen - %d Sounds registriert" % sounds.size())


func _setup_sounds() -> void:
	for sound_name in SOUND_DEFS:
		var def: Dictionary = SOUND_DEFS[sound_name]
		var path: String = def["path"]
		
		if ResourceLoader.exists(path):
			var player := AudioStreamPlayer.new()
			player.name = sound_name.capitalize() + "Sound"
			player.stream = load(path)
			player.volume_db = def["volume"]
			add_child(player)
			sounds[sound_name] = player

func _setup_shoot_sounds() -> void:
	# Lade alle shoot_<element>_level_<level>.wav Sounds
	for element in TOWER_ELEMENTS:
		for level in range(1, MAX_TOWER_LEVEL + 1):
			var sound_name := "shoot_%s_level_%d" % [element, level]
			var path := "res://assets/sounds/%s.wav" % sound_name
			
			if ResourceLoader.exists(path):
				var player := AudioStreamPlayer.new()
				player.name = sound_name
				player.stream = load(path)
				player.volume_db = SHOOT_VOLUME
				add_child(player)
				sounds[sound_name] = player

func play(sound_name: String) -> void:
	if not sounds.has(sound_name):
		return
	
	var player: AudioStreamPlayer = sounds[sound_name]
	var def: Dictionary = SOUND_DEFS[sound_name]
	var pitch_var: float = def.get("pitch_var", 0.0)
	
	if pitch_var > 0:
		player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	else:
		player.pitch_scale = 1.0
	
	player.play()


# Convenience-Funktionen für häufig genutzte Sounds
func play_click() -> void:
	play("click")


func play_coin() -> void:
	play("coin")


func play_place() -> void:
	play("place")


func play_shoot_base() -> void:
	play("shoot_base")
	
func play_shoot_fire_level_1() -> void:
	play("shoot_base")


func play_hit() -> void:
	play("hit")


func play_enemy_death() -> void:
	play("enemy_death")


func play_upgrade() -> void:
	play("upgrade")


func play_wave_start() -> void:
	play("wave_start")


func play_error() -> void:
	play("error")


func play_sell() -> void:
	play("sell")

func play_element_select() -> void:
	play("element_core_select")

# Tower-Shoot mit Element und Level
func play_shoot(element: String = "base", level: int = 0) -> void:
	# Level 0 = Level 1 Sound, Level 1 = Level 2 Sound, etc.
	var display_level := level + 1
	var sound_name := "shoot_%s_level_%d" % [element, display_level]
	
	# Fallback-Kette: Element+Level -> Element Level 1 -> Base Level 1
	if not sounds.has(sound_name):
		sound_name = "shoot_%s_level_1" % element
	if not sounds.has(sound_name):
		sound_name = "shoot_base_level_1"
	if not sounds.has(sound_name):
		return
	
	var player: AudioStreamPlayer = sounds[sound_name]
	player.pitch_scale = randf_range(1.0 - SHOOT_PITCH_VAR, 1.0 + SHOOT_PITCH_VAR)
	player.play()

# Lautstärke-Steuerung
func set_sfx_volume(volume_db: float) -> void:
	sfx_volume = volume_db
	for player in sounds.values():
		var base_vol: float = SOUND_DEFS[_get_sound_name(player)].get("volume", 0.0)
		player.volume_db = base_vol + sfx_volume + master_volume


func set_master_volume(volume_db: float) -> void:
	master_volume = volume_db
	set_sfx_volume(sfx_volume)  # Recalculate all


func _get_sound_name(player: AudioStreamPlayer) -> String:
	for sound_name in sounds:
		if sounds[sound_name] == player:
			return sound_name
	return ""
