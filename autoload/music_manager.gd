# autoload/music_manager.gd
# Hintergrundmusik mit Crossfade zwischen Spielzustaenden.
#
# Die Tracks liegen als res://assets/music/<zustand>.ogg. Fehlt eine Datei, ist der
# Zustandswechsel ein No-Op — das Spiel laeuft ohne Musik genauso wie mit. Dadurch
# koennen Tracks nachgereicht werden, ohne dass Code angefasst werden muss
# (siehe assets/music/README.md).
extends Node

const MUSIC_PATH := "res://assets/music/"
const CROSSFADE_TIME := 1.2
const SILENT_DB := -60.0

# Bekannte Zustaende -> Dateiname ohne Endung.
const STATES := {
	"menu": "menu",         # Hauptmenue
	"build": "build",       # Bauphase zwischen den Wellen
	"wave": "wave",         # laufende Welle
	"boss": "boss",         # Bosswelle
	"game_over": "game_over",
}

const EXTENSIONS := [".ogg", ".wav", ".mp3"]

var music_volume: float = 0.0   # vom Options-Slider, in dB
var master_volume: float = 0.0  # gemeinsamer Master aus den Optionen

var _players: Array[AudioStreamPlayer] = []
var _active_index := 0
var _current_state := ""
var _tween: Tween

var _stream_cache: Dictionary = {}


func _ready() -> void:
	# Musik laeuft weiter, wenn der Baum pausiert (Pausenmenue, Panels).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		player.bus = "Master"
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	print("[Music] Manager geladen - %d Tracks gefunden" % _available_states().size())


func _available_states() -> Array[String]:
	var found: Array[String] = []
	for state in STATES:
		if _find_stream_path(state) != "":
			found.append(state)
	return found


func _find_stream_path(state: String) -> String:
	if not STATES.has(state):
		return ""
	for ext in EXTENSIONS:
		var path: String = MUSIC_PATH + STATES[state] + ext
		if ResourceLoader.exists(path):
			return path
	return ""


func _get_stream(state: String) -> AudioStream:
	if _stream_cache.has(state):
		return _stream_cache[state]
	var path := _find_stream_path(state)
	var stream: AudioStream = load(path) if path != "" else null
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_stream_cache[state] = stream
	return stream


# Wechselt den Zustand. Ohne passenden Track passiert bewusst nichts, damit ein
# fehlendes File nicht die gerade laufende Musik abwuergt.
func play_state(state: String) -> void:
	if state == _current_state:
		return
	var stream := _get_stream(state)
	if stream == null:
		return

	_current_state = state
	var next_index := 1 - _active_index
	var next_player := _players[next_index]
	var previous_player := _players[_active_index]

	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(next_player, "volume_db", _target_volume_db(), CROSSFADE_TIME)
	if previous_player.playing:
		_tween.tween_property(previous_player, "volume_db", SILENT_DB, CROSSFADE_TIME)
		_tween.chain().tween_callback(previous_player.stop)

	_active_index = next_index


func stop_music() -> void:
	_current_state = ""
	if _tween and _tween.is_valid():
		_tween.kill()
	for player in _players:
		player.stop()


func get_state() -> String:
	return _current_state


# === LAUTSTAERKE ===

func set_music_volume(volume_db: float) -> void:
	music_volume = volume_db
	_apply_volume()


func set_master_volume(volume_db: float) -> void:
	master_volume = volume_db
	_apply_volume()


func _target_volume_db() -> float:
	return music_volume + master_volume


func _apply_volume() -> void:
	var active := _players[_active_index]
	if active.playing:
		active.volume_db = _target_volume_db()
