# sound_manager.gd
# Autoload für alle Sound-Effekte - Optimiert für minimale Latenz
extends Node

# Sound Pool für gleichzeitige Sounds
var sound_pools: Dictionary = {}
const POOL_SIZE := 4  # Anzahl Player pro Sound für Polyphonie

# Lautstärke-Einstellungen (in dB)
var master_volume: float = 0.0
var sfx_volume: float = 0.0

# Sound-Definitionen
const SOUND_DEFS := {
	"coin": {"path": "res://assets/sounds/coin_sound.wav", "volume": -5.0, "pitch_var": 0.05},
	"element_core_select": {"path": "res://assets/sounds/element_select.wav", "volume": -5.0, "pitch_var": 0.05},
	"click": {"path": "res://assets/sounds/click.wav", "volume": -5.0, "pitch_var": 0.05},
	"place": {"path": "res://assets/sounds/tower_place.wav", "volume": -3.0, "pitch_var": 0.05},
	"shoot_base": {"path": "res://assets/sounds/shoot_base.wav", "volume": -10.0, "pitch_var": 0.1},
	"hit": {"path": "res://assets/sounds/hit.wav", "volume": -8.0, "pitch_var": 0.1},
	"enemy_death": {"path": "res://assets/sounds/enemy_death.wav", "volume": -5.0, "pitch_var": 0.08},
	"upgrade": {"path": "res://assets/sounds/upgrade.wav", "volume": -3.0, "pitch_var": 0.03},
	"wave_start": {"path": "res://assets/sounds/wave_start.wav", "volume": -2.0, "pitch_var": 0.0},
	"error": {"path": "res://assets/sounds/error.wav", "volume": -5.0, "pitch_var": 0.0},
	"sell": {"path": "res://assets/sounds/tower_sell.wav", "volume": -4.0, "pitch_var": 0.05},
}

const TOWER_ELEMENTS := ["base", "water", "fire", "earth", "air", "ice", "steam", "lava", "nature", "sword"]
const MAX_TOWER_LEVEL := 3
const SHOOT_VOLUME := -10.0
const SHOOT_PITCH_VAR := 0.08

# Preloaded streams für schnelleren Zugriff
var preloaded_streams: Dictionary = {}


func _ready() -> void:
	# Audio-Einstellungen für minimale Latenz
	# Diese können auch in den Projekteinstellungen gesetzt werden
	_setup_audio_settings()
	_preload_all_streams()
	_setup_sound_pools()
	print("[Sound] Manager geladen - %d Sound-Pools erstellt" % sound_pools.size())


func _setup_audio_settings() -> void:
	# Hinweis: Für beste Ergebnisse in Project Settings > Audio:
	# - Output Latency auf 15ms oder niedriger setzen
	# - Mix Rate: 44100 oder 48000
	pass


func _preload_all_streams() -> void:
	# Alle Standard-Sounds vorladen
	for sound_name in SOUND_DEFS:
		var path: String = SOUND_DEFS[sound_name]["path"]
		if ResourceLoader.exists(path):
			preloaded_streams[sound_name] = load(path)
	
	# Shoot-Sounds vorladen
	for element in TOWER_ELEMENTS:
		for level in range(1, MAX_TOWER_LEVEL + 1):
			var sound_name := "shoot_%s_level_%d" % [element, level]
			var path := "res://assets/sounds/%s.wav" % sound_name
			if ResourceLoader.exists(path):
				preloaded_streams[sound_name] = load(path)


func _setup_sound_pools() -> void:
	# Pool für jeden Sound erstellen
	for sound_name in preloaded_streams:
		_create_pool(sound_name)


func _create_pool(sound_name: String) -> void:
	if not preloaded_streams.has(sound_name):
		return
	
	var pool: Array[AudioStreamPlayer] = []
	var stream: AudioStream = preloaded_streams[sound_name]
	
	# Volume aus Definition holen
	var volume := SHOOT_VOLUME
	if SOUND_DEFS.has(sound_name):
		volume = SOUND_DEFS[sound_name].get("volume", -5.0)
	
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "%s_%d" % [sound_name, i]
		player.stream = stream
		player.volume_db = volume
		player.bus = "Master"  # Oder eigenen SFX Bus verwenden
		add_child(player)
		pool.append(player)
	
	sound_pools[sound_name] = {"players": pool, "index": 0}


func _get_available_player(sound_name: String) -> AudioStreamPlayer:
	if not sound_pools.has(sound_name):
		return null
	
	var pool_data: Dictionary = sound_pools[sound_name]
	var players: Array = pool_data["players"]
	var start_index: int = pool_data["index"]
	
	# Round-Robin durch den Pool
	for i in range(POOL_SIZE):
		var idx := (start_index + i) % POOL_SIZE
		var player: AudioStreamPlayer = players[idx]
		if not player.playing:
			pool_data["index"] = (idx + 1) % POOL_SIZE
			return player
	
	# Alle spielen - nimm den nächsten im Round-Robin (überschreibt ältesten)
	var player: AudioStreamPlayer = players[start_index]
	pool_data["index"] = (start_index + 1) % POOL_SIZE
	return player


func play(sound_name: String) -> void:
	var player := _get_available_player(sound_name)
	if not player:
		return
	
	# Pitch Variation
	var pitch_var := 0.0
	if SOUND_DEFS.has(sound_name):
		pitch_var = SOUND_DEFS[sound_name].get("pitch_var", 0.0)
	elif sound_name.begins_with("shoot_"):
		pitch_var = SHOOT_PITCH_VAR
	
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var) if pitch_var > 0 else 1.0
	player.play()


# Convenience-Funktionen
func play_click() -> void:
	play("click")

func play_coin() -> void:
	play("coin")

func play_place() -> void:
	play("place")

func play_shoot_base() -> void:
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


func play_shoot(element: String = "base", level: int = 0) -> void:
	var display_level := level + 1
	var sound_name := "shoot_%s_level_%d" % [element, display_level]
	
	# Fallback-Kette
	if not sound_pools.has(sound_name):
		sound_name = "shoot_%s_level_1" % element
	if not sound_pools.has(sound_name):
		sound_name = "shoot_base_level_1"
	if not sound_pools.has(sound_name):
		sound_name = "shoot_base"
	if not sound_pools.has(sound_name):
		return
	
	play(sound_name)


# Lautstärke-Steuerung
func set_sfx_volume(volume_db: float) -> void:
	sfx_volume = volume_db
	_update_all_volumes()


func set_master_volume(volume_db: float) -> void:
	master_volume = volume_db
	_update_all_volumes()


func _update_all_volumes() -> void:
	for sound_name in sound_pools:
		var base_vol := SHOOT_VOLUME
		if SOUND_DEFS.has(sound_name):
			base_vol = SOUND_DEFS[sound_name].get("volume", -5.0)
		
		var pool_data: Dictionary = sound_pools[sound_name]
		for player in pool_data["players"]:
			player.volume_db = base_vol + sfx_volume + master_volume
