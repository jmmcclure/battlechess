extends Control
## In-game pause menu toggled with ESC.

@onready var resume_button: Button = $Overlay/Panel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Overlay/Panel/VBoxContainer/SettingsButton
@onready var resign_button: Button = $Overlay/Panel/VBoxContainer/ResignButton
@onready var quit_button: Button = $Overlay/Panel/VBoxContainer/QuitButton

var _settings_instance: Control = null


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	resign_button.pressed.connect(_on_resign)
	quit_button.pressed.connect(_on_quit_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_instance and _settings_instance.visible:
			_settings_instance.visible = false
			return
		if visible:
			_on_resume()
		elif GameManager.current_state in [
			GameManager.GameState.PLAYING,
			GameManager.GameState.BATTLE_ANIM,
		]:
			_show_pause()
		get_viewport().set_input_as_handled()


func _show_pause() -> void:
	visible = true
	GameManager.pause_game()


func _on_resume() -> void:
	visible = false
	if _settings_instance:
		_settings_instance.queue_free()
		_settings_instance = null
	GameManager.resume_game()


func _on_settings() -> void:
	if _settings_instance == null:
		var scene := load("res://scenes/ui/settings_panel.tscn") as PackedScene
		_settings_instance = scene.instantiate()
		_settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_settings_instance)
		_settings_instance.settings_closed.connect(func() -> void:
			_settings_instance.queue_free()
			_settings_instance = null
		)


func _on_resign() -> void:
	visible = false
	GameManager.resume_game()
	# The player who resigns loses — the side whose turn it is
	EventBus.resign_requested.emit(0)  # Color determined by game_controller
	GameManager.end_game("resign", 1)  # Opponent wins


func _on_quit_to_menu() -> void:
	visible = false
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
