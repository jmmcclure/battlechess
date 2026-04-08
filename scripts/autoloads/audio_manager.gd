extends Node
## Manages all audio playback: music, SFX, and positional battle audio.

# SFX path constants
const SFX := {
	"sword_clash": "res://assets/audio/sfx/sword_clash.mp3",
	"sword_draw": "res://assets/audio/sfx/sword_draw.mp3",
	"death_scream": "res://assets/audio/sfx/death_scream.mp3",
	"battle_grunt": "res://assets/audio/sfx/battle_grunt.mp3",
	"armor_fall": "res://assets/audio/sfx/armor_fall.mp3",
	"blood_splatter": "res://assets/audio/sfx/blood_splatter.mp3",
	"stone_step": "res://assets/audio/sfx/stone_step.mp3",
	"stone_crumble": "res://assets/audio/sfx/stone_crumble.mp3",
	"horse_neigh": "res://assets/audio/sfx/horse_neigh.mp3",
	"magic_cast": "res://assets/audio/sfx/magic_cast.mp3",
	"piece_place": "res://assets/audio/sfx/piece_place.mp3",
	"ui_click": "res://assets/audio/sfx/ui_click.mp3",
	"victory_fanfare": "res://assets/audio/sfx/victory_fanfare.mp3",
	"dungeon_ambience": "res://assets/audio/sfx/dungeon_ambience.mp3",
}

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

var music_volume: float = 0.8:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		music_player.volume_db = linear_to_db(music_volume)

var sfx_volume: float = 1.0

var _sfx_cache: Dictionary = {}


func _ready() -> void:
	add_child(music_player)
	# Create pool of SFX players for overlapping sounds
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		_sfx_pool.append(player)

	EventBus.settings_changed.connect(_on_settings_changed)

	# Connect game events for automatic audio
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.piece_moved.connect(_on_piece_moved)
	EventBus.checkmate_declared.connect(_on_checkmate)
	EventBus.game_started.connect(_on_game_started)


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
	if not music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_out)
	await tween.finished
	music_player.stop()


func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	# Find a free player in the pool
	for player in _sfx_pool:
		if not player.playing:
			player.stream = _sfx_cache[path]
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return
	# All busy — use the first one (oldest sound)
	_sfx_pool[0].stream = _sfx_cache[path]
	_sfx_pool[0].volume_db = linear_to_db(sfx_volume)
	_sfx_pool[0].play()


func play_sfx_by_name(sfx_name: String) -> void:
	if SFX.has(sfx_name):
		play_sfx(SFX[sfx_name])


func play_sfx_3d(path: String, pos: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	player.stream = _sfx_cache[path]
	player.position = pos
	player.volume_db = linear_to_db(sfx_volume)
	player.play()
	player.finished.connect(player.queue_free)


# --- Event-driven audio ---

func _on_game_started(_mode: String) -> void:
	play_sfx_by_name("dungeon_ambience")


func _on_battle_started(_attacker: Node3D, _defender: Node3D) -> void:
	play_sfx_by_name("sword_draw")


func _on_battle_finished() -> void:
	play_sfx_by_name("armor_fall")


func _on_piece_moved(_piece: Node3D, _from: Vector2i, _to: Vector2i) -> void:
	play_sfx_by_name("piece_place")


func _on_checkmate(_loser: int) -> void:
	play_sfx_by_name("victory_fanfare")


func _on_settings_changed(key: String, value: Variant) -> void:
	match key:
		"music_volume":
			music_volume = value
		"sfx_volume":
			sfx_volume = value
			for player in _sfx_pool:
				player.volume_db = linear_to_db(sfx_volume)
