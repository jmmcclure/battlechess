extends Node
## Manages all audio playback: music, SFX, and positional battle audio.

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music_volume: float = 0.8:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		music_player.volume_db = linear_to_db(music_volume)

var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		sfx_player.volume_db = linear_to_db(sfx_volume)

var _sfx_cache: Dictionary = {}


func _ready() -> void:
	add_child(music_player)
	add_child(sfx_player)
	music_player.bus = "Music"
	sfx_player.bus = "SFX"
	EventBus.settings_changed.connect(_on_settings_changed)


func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	if music_player.playing:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, 0.5)
		await tween.finished
	music_player.stream = stream
	music_player.volume_db = -80.0
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_in)


func stop_music(fade_out: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_out)
	await tween.finished
	music_player.stop()


func play_sfx(path: String) -> void:
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	sfx_player.stream = _sfx_cache[path]
	sfx_player.play()


func play_sfx_3d(path: String, position: Vector3) -> void:
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = _sfx_cache[path]
	player.global_position = position
	player.bus = "SFX"
	player.volume_db = linear_to_db(sfx_volume)
	player.play()
	player.finished.connect(player.queue_free)


func _on_settings_changed(key: String, value: Variant) -> void:
	match key:
		"music_volume":
			music_volume = value
		"sfx_volume":
			sfx_volume = value
