extends Node

@export_range(-10.0, 0.0, 0.5) var music_volume_db: float = -8.5
@export_range(-10.0, 0.0, 0.5) var sfx_volume_db: float = -3.0
@export_range(2, 16, 1) var sfx_pool_size: int = 8
@export var start_music_on_ready: bool = true

var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _next_player_index: int = 0
var _music_enabled: bool = true


func _ready() -> void:
	add_to_group("audio_manager")
	_music = AudioStreamPlayer.new()
	_music.name = "AmbientMusic"
	_music.volume_db = -45.0
	_music.bus = "Master"
	add_child(_music)

	for index in range(sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%02d" % index
		player.volume_db = sfx_volume_db
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	_load_sound("music", "res://assets/audio/gym_ambient_lofi.wav", true)
	if not _sounds.has("music"):
		_load_sound("music", "res://assets/audio/gym_life_theme.wav", true)
	_load_sound("footstep", "res://assets/audio/footstep.wav")
	_load_sound("interact", "res://assets/audio/interact.wav")
	_load_sound("collect", "res://assets/audio/collect.wav")
	_load_sound("eat", "res://assets/audio/eat.wav")
	_load_sound("workout", "res://assets/audio/workout.wav")
	_load_sound("climb", "res://assets/audio/climb.wav")
	_load_sound("sleep", "res://assets/audio/sleep.wav")
	_load_sound("engine_start", "res://assets/audio/engine_start.wav")
	_load_sound("victory", "res://assets/audio/victory.wav")

	if start_music_on_ready and _sounds.has("music"):
		_music.stream = _sounds["music"] as AudioStream
		_music.play()
		var fade := create_tween()
		fade.tween_property(_music, "volume_db", music_volume_db, 1.25)


func _load_sound(key: String, path: String, looped: bool = false) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Audio no encontrado: %s" % path)
		return
	var stream := load(path)
	if not stream is AudioStream:
		push_warning("El recurso no es un AudioStream: %s" % path)
		return
	if stream is AudioStreamWAV and looped:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# loop_end = 0 usa un límite ambiguo en algunos WAV importados; cuando
		# el stream es PCM, lo fijamos al total de muestras para cerrar el bucle.
		if wav.loop_end <= wav.loop_begin and wav.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
			var bytes_per_sample := 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
			var channel_count := 2 if wav.stereo else 1
			wav.loop_begin = 0
			wav.loop_end = int(float(wav.data.size()) / float(bytes_per_sample * channel_count))
	_sounds[key] = stream


func play_sfx(sound_name: String) -> void:
	if not _sounds.has(sound_name) or _sfx_players.is_empty():
		return
	var stream := _sounds[sound_name] as AudioStream
	if stream == null:
		return
	var player := _get_next_player()
	player.stop()
	player.stream = stream
	player.volume_db = sfx_volume_db
	player.pitch_scale = randf_range(0.94, 1.06) if sound_name == "footstep" else 1.0
	player.play()


func _get_next_player() -> AudioStreamPlayer:
	for offset in range(_sfx_players.size()):
		var index := (_next_player_index + offset) % _sfx_players.size()
		if not _sfx_players[index].playing:
			_next_player_index = (index + 1) % _sfx_players.size()
			return _sfx_players[index]
	var fallback := _sfx_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _sfx_players.size()
	return fallback


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if not is_instance_valid(_music):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if enabled:
		if _music.stream != null and not _music.playing:
			_music.play()
		tween.tween_property(_music, "volume_db", music_volume_db, 0.4)
	else:
		tween.tween_property(_music, "volume_db", -45.0, 0.4)
		tween.tween_callback(_music.stop)


func is_music_enabled() -> bool:
	return _music_enabled


func set_master_volume(linear_value: float) -> void:
	var volume: float = clampf(linear_value, 0.0, 1.0)
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.001)))
