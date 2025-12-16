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
	"shoot": {
		"path": "res://assets/sounds/shoot.wav",
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
		"path": "res://assets/sounds/sell.wav",
		"volume": -4.0,
		"pitch_var": 0.05
	},
}


func _ready() -> void:
	_setup_sounds()
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


func play_shoot() -> void:
	play("shoot")


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
