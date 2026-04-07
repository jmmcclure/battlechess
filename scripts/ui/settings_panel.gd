extends Control
## Settings panel for game options.

signal settings_closed

@onready var gore_toggle: CheckButton = $Panel/VBoxContainer/GoreToggle
@onready var anim_speed_slider: HSlider = $Panel/VBoxContainer/AnimSpeedSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXSlider
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOption
@onready var skip_toggle: CheckButton = $Panel/VBoxContainer/SkipToggle
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton


func _ready() -> void:
	# Initialize from current settings
	gore_toggle.button_pressed = GameManager.gore_enabled
	anim_speed_slider.value = GameManager.animation_speed
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume
	skip_toggle.button_pressed = GameManager.battle_skip_enabled

	difficulty_option.clear()
	difficulty_option.add_item("Peasant (Easy)", 1)
	difficulty_option.add_item("Squire (Medium)", 2)
	difficulty_option.add_item("Knight (Hard)", 3)
	difficulty_option.add_item("Grandmaster (Expert)", 4)
	difficulty_option.selected = GameManager.ai_difficulty - 1

	# Connect signals
	gore_toggle.toggled.connect(_on_gore_toggled)
	anim_speed_slider.value_changed.connect(_on_anim_speed_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	skip_toggle.toggled.connect(_on_skip_toggled)
	close_button.pressed.connect(_on_close)


func _on_gore_toggled(enabled: bool) -> void:
	GameManager.gore_enabled = enabled
	EventBus.settings_changed.emit("gore_enabled", enabled)


func _on_anim_speed_changed(value: float) -> void:
	GameManager.animation_speed = value
	EventBus.settings_changed.emit("animation_speed", value)


func _on_music_changed(value: float) -> void:
	AudioManager.music_volume = value
	EventBus.settings_changed.emit("music_volume", value)


func _on_sfx_changed(value: float) -> void:
	AudioManager.sfx_volume = value
	EventBus.settings_changed.emit("sfx_volume", value)


func _on_difficulty_changed(index: int) -> void:
	GameManager.ai_difficulty = index + 1
	EventBus.settings_changed.emit("ai_difficulty", index + 1)


func _on_skip_toggled(enabled: bool) -> void:
	GameManager.battle_skip_enabled = enabled
	EventBus.settings_changed.emit("battle_skip_enabled", enabled)


func _on_close() -> void:
	visible = false
	settings_closed.emit()
